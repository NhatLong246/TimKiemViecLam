import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../data/constants/full_time_policy.dart';
import '../data/models/application_model.dart';
import '../data/services/candidates_service.dart';
class CandidatesController extends GetxController {
  final _service = CandidatesService();
  final RxBool isLoadingFullTime = false.obs;
  final RxBool isLoadingPartTime = false.obs;
  final RxList<JobWithApplications> fullTimeJobs =
      <JobWithApplications>[].obs;
  final RxList<JobWithApplications> partTimeJobs =
      <JobWithApplications>[].obs;

  /// Lọc theo jobId khi mở từ Quản lý bài đăng.
  String? filterJobId;

  void setFilterJobId(String? jobId) {
    final value = jobId?.trim();
    filterJobId = (value == null || value.isEmpty) ? null : value;
  }

  List<JobWithApplications> filteredFullTimeJobs() =>
      _filterByJobId(fullTimeJobs);

  List<JobWithApplications> filteredPartTimeJobs() =>
      _filterByJobId(partTimeJobs);

  List<JobWithApplications> _filterByJobId(List<JobWithApplications> list) {
    if (filterJobId == null || filterJobId!.isEmpty) return list;
    return list.where((j) => j.job.jobId == filterJobId).toList();
  }

  // Tổng số đơn đang chờ duyệt (dùng cho tab badge)
  int get pendingFullTimeCount => fullTimeJobs
      .expand((j) => j.entries)
      .where((e) => e.application.status == 'pending')
      .length;

  int get pendingPartTimeCount => partTimeJobs
      .expand((j) => j.entries)
      .where((e) => e.application.status == 'pending')
      .length;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map && args['jobId'] is String) {
      filterJobId = args['jobId'] as String;
    }
    loadAll();
  }

  Future<void> loadAll() async {
    await Future.wait([loadFullTime(), loadPartTime()]);
  }

  Future<void> loadFullTime() async {
    try {
      isLoadingFullTime.value = true;
      fullTimeJobs.value = await _service.fetchByJobType('full_time');
    } catch (e) {
      _showError('Không tải được danh sách Full-time: $e');
    } finally {
      isLoadingFullTime.value = false;
    }
  }

  Future<void> loadPartTime() async {
    try {
      isLoadingPartTime.value = true;
      partTimeJobs.value = await _service.fetchByJobType('part_time');
    } catch (e) {
      _showError('Không tải được danh sách Part-time: $e');
    } finally {
      isLoadingPartTime.value = false;
    }
  }

  // ── Duyệt đơn ứng tuyển ───────────────────────────────────────────────────
  Future<void> accept(String appId, String jobId) async {
    try {
      await _service.acceptApplication(appId, jobId);
      _updateEntry(appId, 'accepted');
      _incrementFilledSlots(jobId);
      final isFullTime = _jobTypeOf(jobId) == 'full_time';
      if (!isFullTime) {
        await _refreshJobGroupChatId(jobId);
      }
      _showSuccess(
        isFullTime ? kFullTimeAcceptSuccess : 'Đã duyệt ứng viên',
      );
    } catch (e) {
      _showError('Không thể duyệt: $e');
    }
  }

  String? _jobTypeOf(String jobId) {
    for (final list in [fullTimeJobs, partTimeJobs]) {
      final idx = list.indexWhere((j) => j.job.jobId == jobId);
      if (idx >= 0) return list[idx].job.jobType;
    }
    return null;
  }

  Future<void> _refreshJobGroupChatId(String jobId) async {
    final snap = await FirebaseFirestore.instance
        .collection('jobPosts')
        .doc(jobId)
        .get();
    final gid = (snap.data()?['groupChatId'] ?? '').toString();
    if (gid.isNotEmpty) _updateGroupChatId(jobId, gid);
  }

  void _updateGroupChatId(String jobId, String groupId) {
    for (final list in [fullTimeJobs, partTimeJobs]) {
      final idx = list.indexWhere((j) => j.job.jobId == jobId);
      if (idx >= 0) {
        final j = list[idx];
        list[idx] = j.copyWithJob(j.job.copyWith(groupChatId: groupId));
        break;
      }
    }
  }

  // ── Từ chối đơn ứng tuyển ─────────────────────────────────────────────────
  Future<void> reject(String appId) async {
    try {
      await _service.rejectApplication(appId);
      _updateEntry(appId, 'rejected');
      _showSuccess('Đã từ chối ứng viên');
    } catch (e) {
      _showError('Không thể từ chối: $e');
    }
  }

  // ── Huỷ duyệt (accepted → pending) ────────────────────────────────────────
  Future<void> revokeAcceptance(String appId, String jobId) async {
    try {
      await _service.revokeAcceptance(appId, jobId);
      _updateEntry(appId, 'pending');
      _decrementFilledSlots(jobId);
      _showSuccess('Đã huỷ duyệt');
    } catch (e) {
      _showError('Không thể huỷ duyệt: $e');
    }
  }

  // ── Helpers cập nhật local state (tránh reload toàn bộ) ───────────────────
  void _updateEntry(String appId, String newStatus) {
    for (final list in [fullTimeJobs, partTimeJobs]) {
      bool changed = false;
      final newList = list.map((jwA) {
        final newEntries = jwA.entries.map((e) {
          if (e.application.appId == appId) {
            changed = true;
            return e.copyWithStatus(newStatus);
          }
          return e;
        }).toList();
        return changed ? jwA.copyWithEntries(newEntries) : jwA;
      }).toList();
      if (changed) {
        list.value = newList;
        break;
      }
    }
  }

  void _incrementFilledSlots(String jobId) =>
      _adjustFilledSlots(jobId, 1);

  void _decrementFilledSlots(String jobId) =>
      _adjustFilledSlots(jobId, -1);

  void _adjustFilledSlots(String jobId, int delta) {
    for (final list in [fullTimeJobs, partTimeJobs]) {
      final idx = list.indexWhere((j) => j.job.jobId == jobId);
      if (idx >= 0) {
        final j = list[idx];
        final newFilled = (j.job.filledSlots + delta).clamp(0, j.job.slots);
        list[idx] = j.copyWithJob(j.job.copyWith(filledSlots: newFilled));
        break;
      }
    }
  }

  void _showSuccess(String msg) => Get.snackbar(
        'Thành công',
        msg,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
        duration: const Duration(seconds: 2),
      );

  void _showError(String msg) => Get.snackbar(
        'Lỗi',
        msg,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
      );
}
