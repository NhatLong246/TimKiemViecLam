import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controller/login_controller.dart';
import '../models/attendance_model.dart';
import '../models/group_chat_model.dart';
import '../models/user_model.dart';
import 'attendance_service.dart';
import 'group_chat_service.dart';
import 'work_schedule_service.dart';
import 'job_disbursement_reminder_service.dart';

/// Tự động tạo phiên + gửi thông báo điểm danh đầu/cuối ca theo giờ phân công.
class AttendanceAutoNotifyService {
  AttendanceAutoNotifyService._();
  static final instance = AttendanceAutoNotifyService._();

  final _attendance = AttendanceService();
  final _schedule = WorkScheduleService();
  final _groupChat = GroupChatService();
  final _db = FirebaseFirestore.instance;

  Timer? _pollTimer;
  bool _employerRunInFlight = false;

  static const _defaultShiftStart = '08:00';
  static const _defaultShiftEnd = '17:00';

  void startEmployerPolling() {
    _pollTimer?.cancel();
    final user = Get.find<AuthController>().currentUser;
    if (user == null || user.role != 'employer') return;

    unawaited(_runForEmployer(user.id));
    _pollTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _runForEmployer(user.id),
    );
  }

  void stopEmployerPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _runForEmployer(String employerId) async {
    if (_employerRunInFlight) return;
    _employerRunInFlight = true;
    try {
      final groups = await _groupChat.listEmployerJobGroups(employerId);
      final byJob = <String, GroupChatModel>{};
      for (final g in groups) {
        if (g.jobId.isEmpty) continue;
        final existing = byJob[g.jobId];
        if (existing == null ||
            g.memberIds.length > existing.memberIds.length) {
          byJob[g.jobId] = g;
        }
      }
      for (final g in byJob.values) {
        await runScheduledForGroup(g);
      }
      await JobDisbursementReminderService.instance.runForEmployer(employerId);
    } catch (_) {
    } finally {
      _employerRunInFlight = false;
    }
  }

  /// Gọi khi NTD mở công cụ điểm danh (trước khi vào màn hình).
  Future<void> onEmployerOpensAttendance(GroupChatModel group) async {
    await runScheduledForGroup(group);
  }

  /// Kiểm tra giờ ca từ phân công hôm nay; tự gửi nếu đến giờ mà NTD chưa bấm bắt đầu.
  Future<void> runScheduledForGroup(GroupChatModel group) async {
    if (group.jobId.isEmpty) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final shift = await _resolveShift(group.groupId, today);
    final log = await _readLog(group.jobId, today);
    final now = DateTime.now();

    if (!(log['checkInSent'] == true) && !_isBeforeTime(now, shift.start)) {
      final session = await _ensureTodaySession(
        group: group,
        expectedStart: shift.start,
      );
      if (session != null) {
        await _writeLog(group.jobId, today, checkInSent: true);
        await _notifyAllEmployees(
          group: group,
          session: session,
          isCheckIn: true,
        );
      }
    }

    if (!(log['checkOutSent'] == true) && !_isBeforeTime(now, shift.end)) {
      final session = await _attendance.getSessionByDate(group.jobId, today);
      if (session != null) {
        await _writeLog(group.jobId, today, checkOutSent: true);
        await _notifyAllEmployees(
          group: group,
          session: session,
          isCheckIn: false,
        );
      }
    }
  }

  /// Sau khi NTD bấm "Bắt đầu điểm danh" — gửi thông báo đầu ca ngay.
  Future<void> onEmployerStartedSession({
    required GroupChatModel group,
    required AttendanceModel session,
  }) async {
    final today = session.date;
    if (group.jobId.isEmpty) return;
    final log = await _readLog(group.jobId, today);
    if (log['checkInSent'] == true) return;

    await _writeLog(group.jobId, today, checkInSent: true);
    await _notifyAllEmployees(
      group: group,
      session: session,
      isCheckIn: true,
    );
  }

  Future<({String start, String end})> resolveShiftForDisplay(
    String groupId,
  ) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _resolveShift(groupId, today);
  }

  Future<({String start, String end})> _resolveShift(
    String groupId,
    String date,
  ) async {
    final ws = await _schedule.getByDate(groupId, date);
    if (ws != null) {
      return (start: ws.shiftStart, end: ws.shiftEnd);
    }
    return (start: _defaultShiftStart, end: _defaultShiftEnd);
  }

  /// Log theo **job** (không theo từng group trùng job).
  Future<Map<String, dynamic>> _readLog(String jobId, String date) async {
    final snap = await _logRef(jobId, date).get();
    if (!snap.exists) return {};
    return Map<String, dynamic>.from(snap.data() as Map? ?? {});
  }

  Future<void> _writeLog(
    String jobId,
    String date, {
    bool? checkInSent,
    bool? checkOutSent,
  }) async {
    final data = <String, dynamic>{};
    if (checkInSent == true) {
      data['checkInSent'] = true;
      data['checkInSentAt'] = FieldValue.serverTimestamp();
    }
    if (checkOutSent == true) {
      data['checkOutSent'] = true;
      data['checkOutSentAt'] = FieldValue.serverTimestamp();
    }
    if (data.isEmpty) return;
    await _logRef(jobId, date).set(data, SetOptions(merge: true));
  }

  DocumentReference<Map<String, dynamic>> _logRef(String jobId, String date) =>
      _db.collection('jobPosts').doc(jobId).collection('attendanceNotifyLog').doc(date);

  Future<AttendanceModel?> _ensureTodaySession({
    required GroupChatModel group,
    required String expectedStart,
  }) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    var session = await _attendance.getSessionByDate(group.jobId, today);
    if (session != null) return session;

    final members = await _groupChat.getGroupMembers(group.memberIds);
    final workers = _workersFromMembers(members, group.employerId);
    if (workers.isEmpty) return null;

    final id = await _attendance.createSession(
      AttendanceModel(
        attendanceId: '',
        jobId: group.jobId,
        groupId: group.groupId,
        employerId: group.employerId,
        date: today,
        expectedStartTime: expectedStart,
        records: workers,
        createdAt: DateTime.now(),
      ),
    );

    return AttendanceModel(
      attendanceId: id,
      jobId: group.jobId,
      groupId: group.groupId,
      employerId: group.employerId,
      date: today,
      expectedStartTime: expectedStart,
      records: workers,
      createdAt: DateTime.now(),
    );
  }

  List<AttendanceRecord> _workersFromMembers(
    List<UserModel> members,
    String employerId,
  ) {
    return members
        .where((u) => u.id != employerId)
        .map(
          (u) => AttendanceRecord(
            candidateId: u.id,
            candidateName: '${u.firstName} ${u.lastName}'.trim(),
            status: 'not_marked',
            lateMinutes: 0,
          ),
        )
        .toList();
  }

  Future<void> _notifyAllEmployees({
    required GroupChatModel group,
    required AttendanceModel session,
    required bool isCheckIn,
  }) async {
    for (final r in session.records) {
      if (r.candidateId.isEmpty) continue;
      await _groupChat.sendAttendanceRequest(
        groupId: group.groupId,
        jobId: session.jobId,
        attendanceId: session.attendanceId,
        targetUserId: r.candidateId,
        targetName:
            r.candidateName.isNotEmpty ? r.candidateName : 'Nhân viên',
        isCheckIn: isCheckIn,
        expectedStartTime: session.expectedStartTime,
      );
    }
  }

  bool _isBeforeTime(DateTime now, String hhmm) {
    final t = _parseToday(hhmm);
    return now.isBefore(t);
  }

  DateTime _parseToday(String hhmm) {
    final parts = hhmm.split(':');
    final h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, h, m);
  }
}
