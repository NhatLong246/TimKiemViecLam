import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../common/styles/app_colors.dart';
import '../../controller/login_controller.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/group_chat_model.dart';
import '../../data/services/attendance_service.dart';
import '../../data/services/job_post_service.dart';
import '../../data/services/messaging_service.dart';
import '../../data/services/work_schedule_service.dart';
import '../../utils/work_day_helper.dart';
import '../../utils/attendance_capture_helper.dart';
import '../../widgets/attendance_photo_info.dart';

/// Điểm danh dành cho nhân viên / ứng viên (chụp ảnh đầu ca · cuối ca).
/// Arguments: `GroupChatModel` hoặc `Map` với `group` + `isCandidate`.
class CandidateAttendanceScreen extends StatefulWidget {
  const CandidateAttendanceScreen({super.key, this.group});

  /// Truyền trực tiếp khi `Get.to()` — không phụ thuộc bảng route.
  final GroupChatModel? group;

  @override
  State<CandidateAttendanceScreen> createState() =>
      _CandidateAttendanceScreenState();
}

class _CandidateAttendanceScreenState extends State<CandidateAttendanceScreen> {
  static const _primary = AppColors.candidatePrimary;

  GroupChatModel? _group;
  final _attendanceSvc = AttendanceService();
  final _messagingSvc = MessagingService();
  final _scheduleSvc = WorkScheduleService();
  final _jobSvc = JobPostService();
  final _auth = Get.find<AuthController>();

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  AttendanceModel? _session;
  AttendanceRecord? _myRecord;

  String get _uid => _auth.currentUser?.id ?? '';
  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      if (widget.group != null) {
        _group = widget.group;
      } else {
        final args = Get.arguments;
        if (args is Map && args['group'] is GroupChatModel) {
          _group = args['group'] as GroupChatModel;
        } else if (args is GroupChatModel) {
          _group = args;
        } else if (args is Map) {
          final groupId = (args['groupId'] ?? '').toString();
          if (groupId.isNotEmpty) {
            final snap = await FirebaseFirestore.instance
                .collection('groupChats')
                .doc(groupId)
                .get();
            if (!snap.exists) {
              throw Exception('Không tìm thấy nhóm');
            }
            _group = GroupChatModel.fromMap(snap.data()!, snap.id);
          }
        }
      }
      if (_group == null) {
        throw Exception('Thiếu thông tin nhóm');
      }
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final name = _displayName();
      final attendanceId = await _attendanceSvc.ensureCandidateRecord(
        jobId: _group!.jobId,
        groupId: _group!.groupId,
        employerId: _group!.employerId,
        candidateId: _uid,
        candidateName: name,
      );
      final session = await _attendanceSvc.getSessionByDate(_group!.jobId, _today);
      if (!mounted) return;
      setState(() {
        _session = session ??
            AttendanceModel(
              attendanceId: attendanceId,
              jobId: _group!.jobId,
              groupId: _group!.groupId,
              employerId: _group!.employerId,
              date: _today,
              expectedStartTime: '08:00',
              records: const [],
              createdAt: DateTime.now(),
            );
        _syncMyRecord();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _displayName() {
    final u = _auth.currentUser;
    if (u == null) return 'Nhân viên';
    final n = '${u.firstName} ${u.lastName}'.trim();
    return n.isNotEmpty ? n : 'Nhân viên';
  }

  void _syncMyRecord() {
    final session = _session;
    if (session == null) {
      _myRecord = null;
      return;
    }
    AttendanceRecord? found;
    for (final r in session.records) {
      if (r.candidateId == _uid) {
        found = r;
        break;
      }
    }
    _myRecord = found;
  }

  Future<void> _captureAndSubmit({required bool isCheckIn}) async {
    final session = _session;
    if (session == null || session.attendanceId.isEmpty) {
      Get.snackbar('Lỗi', 'Chưa có phiên điểm danh hôm nay');
      return;
    }

    final job = await _jobSvc.getJobPostById(_group!.jobId);
    final scheduled = await _scheduleSvc.listScheduledDates(_group!.groupId);
    if (!WorkDayHelper.isMandatoryWorkDay(
      _today,
      job: job,
      scheduledDates: scheduled,
    )) {
      Get.snackbar(
        'Không phải ngày làm',
        'Hôm nay không nằm trong lịch làm bắt buộc của công việc.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    final cam = await Permission.camera.request();
    if (!cam.isGranted) {
      Get.snackbar('Quyền camera', 'Cần quyền camera để chụp ảnh điểm danh');
      return;
    }
    await Permission.location.request();

    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 55,
      maxWidth: 900,
      maxHeight: 900,
    );
    if (picked == null) return;

    final captureMeta = await AttendanceCaptureHelper.buildMeta(
      candidateId: _uid,
      isCheckIn: isCheckIn,
      imagePath: picked.path,
    );

    final bytes = await File(picked.path).readAsBytes();
    if (bytes.lengthInBytes > 700 * 1024) {
      Get.snackbar('Ảnh quá lớn', 'Chụp lại gần hơn (tối đa ~700KB)');
      return;
    }

    final b64 = base64Encode(bytes);
    setState(() => _submitting = true);
    try {
      await _messagingSvc.submitAttendancePhotoFromRequest(
        groupId: _group!.groupId,
        jobId: _group!.jobId,
        attendanceId: session.attendanceId,
        isCheckIn: isCheckIn,
        photoBase64: b64,
        expectedStartTime: session.expectedStartTime,
        captureMeta: captureMeta,
      );
      await _load();
      if (!mounted) return;
      Get.snackbar(
        'Thành công',
        isCheckIn ? 'Đã gửi ảnh đầu ca' : 'Đã gửi ảnh cuối ca',
        backgroundColor: _primary,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      if (!isCheckIn && mounted) {
        final record = _myRecord;
        if ((record?.checkOutTime ?? '').isNotEmpty) {
          Get.snackbar(
            'Hoàn tất ca',
            'Bạn đã điểm danh cuối ca. NTD sẽ giải ngân và đánh giá sau khi kết thúc ngày.',
            duration: const Duration(seconds: 4),
          );
        }
      }
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        e.toString().replaceFirst('Exception: ', ''),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: Get.back,
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Điểm danh của tôi',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _load,
              style: FilledButton.styleFrom(backgroundColor: _primary),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final session = _session!;
    final record = _myRecord;
    final dateLabel =
        DateFormat('EEEE, dd/MM/yyyy', 'vi').format(DateTime.now());

    return RefreshIndicator(
      color: _primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.candidateGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _group!.jobTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dateLabel,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Giờ bắt đầu ca: ${session.expectedStartTime}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (record != null) _StatusChip(status: record.status),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _primary.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: _primary, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Chụp ảnh khi vào ca và tan ca. '
                    'Hệ thống ghi nhận giờ, vị trí GPS và tên ảnh để NTD đối chiếu.',
                    style: TextStyle(fontSize: 13, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ShiftCard(
                  label: 'Đầu ca',
                  icon: Icons.login_rounded,
                  color: const Color(0xFF1565C0),
                  time: record?.checkInTime,
                  capturedAt: record?.checkInCapturedAt,
                  locationLabel: record?.checkInLocation,
                  fileName: record?.checkInPhotoName,
                  photoBase64: record?.checkInPhotoUrl,
                  done: (record?.checkInTime ?? '').isNotEmpty,
                  enabled: !_submitting,
                  onCapture: () => _captureAndSubmit(isCheckIn: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ShiftCard(
                  label: 'Cuối ca',
                  icon: Icons.logout_rounded,
                  color: const Color(0xFF2E7D32),
                  time: record?.checkOutTime,
                  capturedAt: record?.checkOutCapturedAt,
                  locationLabel: record?.checkOutLocation,
                  fileName: record?.checkOutPhotoName,
                  photoBase64: record?.checkOutPhotoUrl,
                  done: (record?.checkOutTime ?? '').isNotEmpty,
                  enabled: !_submitting &&
                      (record?.checkInTime ?? '').isNotEmpty,
                  onCapture: () => _captureAndSubmit(isCheckIn: false),
                ),
              ),
            ],
          ),
          if (record != null && record.status == 'late') ...[
            const SizedBox(height: 16),
            Text(
              'Bạn đi trễ ${record.lateMinutes} phút so với giờ bắt đầu ca.',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
          if (_submitting) ...[
            const SizedBox(height: 24),
            const Center(
              child: CircularProgressIndicator(color: _primary),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'on_time':
        color = Colors.white;
        label = 'Đúng giờ';
        break;
      case 'late':
        color = const Color(0xFFFFE082);
        label = 'Trễ';
        break;
      case 'absent':
        color = const Color(0xFFEF9A9A);
        label = 'Vắng';
        break;
      default:
        color = Colors.white70;
        label = 'Chờ điểm danh';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.time,
    this.capturedAt,
    this.locationLabel,
    this.fileName,
    required this.photoBase64,
    required this.done,
    required this.enabled,
    required this.onCapture,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String? time;
  final String? capturedAt;
  final String? locationLabel;
  final String? fileName;
  final String? photoBase64;
  final bool done;
  final bool enabled;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      try {
        bytes = base64Decode(photoBase64!);
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (bytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                bytes,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 100,
              child: FilledButton.icon(
                onPressed: enabled ? onCapture : null,
                icon: const Icon(Icons.camera_alt, size: 20),
                label: Text(done ? 'Đã chụp' : 'Chụp ảnh'),
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
              ),
            ),
          AttendancePhotoInfo(
            capturedAt: capturedAt,
            time: time,
            locationLabel: locationLabel,
            fileName: fileName,
            textColor: color,
            dense: true,
          ),
          if (!enabled && !done && label == 'Cuối ca')
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Điểm danh đầu ca trước',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
