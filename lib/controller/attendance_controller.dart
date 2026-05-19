import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../data/models/attendance_model.dart';
import '../data/services/attendance_service.dart';
import '../controller/login_controller.dart';

class AttendanceController extends GetxController {
  final _service = AttendanceService();
  final _auth = Get.find<AuthController>();

  // ─── State ────────────────────────────────────────────────────────────────
  final sessions = <AttendanceModel>[].obs;
  final currentSession = Rxn<AttendanceModel>();
  final isLoading = false.obs;
  final isSaving = false.obs;

  // Bản sao records đang edit (chưa save)
  final editRecords = <AttendanceRecord>[].obs;

  // ─── Load phiên điểm danh theo job ───────────────────────────────────────
  void loadSessionsByJob(String jobId) {
    isLoading.value = true;
    _service.streamByJob(jobId).listen(
      (data) {
        sessions.assignAll(data);
        isLoading.value = false;
      },
      onError: (_) => isLoading.value = false,
    );
  }

  // ─── Tạo phiên điểm danh mới cho hôm nay ─────────────────────────────────
  Future<void> startSession({
    required String jobId,
    required String groupId,
    required List<AttendanceRecord> workers,
    required String expectedStartTime,
  }) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final employerId = _auth.currentUser?.id ?? '';

    final session = AttendanceModel(
      attendanceId: '',
      jobId: jobId,
      groupId: groupId,
      employerId: employerId,
      date: today,
      expectedStartTime: expectedStartTime,
      records: workers,
      createdAt: DateTime.now(),
    );

    final id = await _service.createSession(session);
    final saved = AttendanceModel(
      attendanceId: id,
      jobId: session.jobId,
      groupId: session.groupId,
      employerId: session.employerId,
      date: session.date,
      expectedStartTime: session.expectedStartTime,
      records: session.records,
      createdAt: session.createdAt,
    );

    currentSession.value = saved;
    editRecords.assignAll(saved.records);
  }

  // ─── Load phiên theo ngày cụ thể ─────────────────────────────────────────
  Future<void> loadSessionByDate(String jobId, String date) async {
    isLoading.value = true;
    final s = await _service.getSessionByDate(jobId, date);
    currentSession.value = s;
    editRecords.assignAll(s?.records ?? []);
    isLoading.value = false;
  }

  // ─── Đặt trạng thái 1 record ─────────────────────────────────────────────
  void markStatus(int index, String status, {int lateMinutes = 0}) {
    if (index < 0 || index >= editRecords.length) return;
    editRecords[index] = editRecords[index].copyWith(
      status: status,
      lateMinutes: lateMinutes,
    );
    editRecords.refresh();
  }

  // ─── Lưu tất cả records ──────────────────────────────────────────────────
  Future<void> saveAll() async {
    final id = currentSession.value?.attendanceId;
    if (id == null || id.isEmpty) return;

    isSaving.value = true;
    await _service.saveAllRecords(id, editRecords.toList());
    isSaving.value = false;
    Get.snackbar('Thành công', 'Đã lưu điểm danh',
        snackPosition: SnackPosition.BOTTOM);
  }

  // ─── Helper ──────────────────────────────────────────────────────────────
  int get totalOnTime =>
      editRecords.where((r) => r.status == 'on_time').length;
  int get totalLate => editRecords.where((r) => r.status == 'late').length;
  int get totalAbsent => editRecords.where((r) => r.status == 'absent').length;
}
