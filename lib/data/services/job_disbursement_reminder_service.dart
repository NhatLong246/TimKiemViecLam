import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/group_chat_model.dart';
import '../models/job_post_model.dart';
import '../../utils/work_day_helper.dart';
import 'group_chat_service.dart';
import 'job_attendance_completion_service.dart';
import 'job_post_service.dart';
import 'job_workflow_service.dart';
import 'notification_service.dart';

/// Sau khi hết ngày làm (endDate), tự gửi thông báo cho NTD:
/// kiểm tra điểm danh → nhắc yêu cầu giải ngân (lặp nhẹ nếu chưa xử lý).
class JobDisbursementReminderService {
  JobDisbursementReminderService._();
  static final instance = JobDisbursementReminderService._();

  final _db = FirebaseFirestore.instance;
  final _groups = GroupChatService();
  final _jobs = JobPostService();
  final _workflow = JobWorkflowService();
  final _completion = JobAttendanceCompletionService();
  final _notif = NotificationService();

  static const _reminderInterval = Duration(days: 2);

  final _jobsInFlight = <String>{};

  /// Gọi mỗi phút cùng [AttendanceAutoNotifyService] khi NTD đăng nhập.
  Future<void> runForEmployer(String employerId) async {
    if (employerId.isEmpty) return;
    try {
      final groups = await _groups.listEmployerJobGroups(employerId);
      final byJob = <String, GroupChatModel>{};
      for (final g in groups) {
        if (g.jobId.isEmpty || g.isDissolved) continue;
        final existing = byJob[g.jobId];
        if (existing == null ||
            g.memberIds.length > existing.memberIds.length) {
          byJob[g.jobId] = g;
        }
      }
      for (final g in byJob.values) {
        await _processGroup(g, employerId);
      }
      await _processJobsWithoutGroup(employerId, byJob.keys.toSet());
    } catch (_) {}
  }

  /// Bài đã hết hạn nhưng chưa có nhóm (chưa tuyển UV).
  Future<void> _processJobsWithoutGroup(
    String employerId,
    Set<String> jobsWithGroup,
  ) async {
    final snap = await _db
        .collection('jobPosts')
        .where('employerId', isEqualTo: employerId)
        .get();
    for (final doc in snap.docs) {
      if (jobsWithGroup.contains(doc.id)) continue;
      final data = Map<String, dynamic>.from(doc.data());
      data['jobId'] = doc.id;
      final job = JobPostModel.fromMap(data);
      if (!_isActiveJob(job)) continue;
      if (!WorkDayHelper.isWorkPeriodEnded(job)) continue;
      if (await _workflow.hasCompletedDisbursement(job.jobId)) continue;

      if (!await _claimOnce(job.jobId, 'noGroupEndedNotifiedAt')) continue;

      await _notif.create(
        recipientId: employerId,
        type: 'job_work_period_ended',
        title: 'Bài đăng đã hết hạn',
        body:
            '"${job.title}" đã qua ngày làm (${_formatRange(job)}). '
            'Chưa có nhân viên — bạn có thể đóng bài trong Quản lý bài đăng.',
        data: {'jobId': job.jobId, 'hasGroup': false},
      );
    }
  }

  Future<void> _processGroup(GroupChatModel group, String employerId) async {
    if (group.employerId != employerId) return;
    if (_jobsInFlight.contains(group.jobId)) return;
    _jobsInFlight.add(group.jobId);
    try {
      await _processGroupImpl(group, employerId);
    } finally {
      _jobsInFlight.remove(group.jobId);
    }
  }

  Future<void> _processGroupImpl(GroupChatModel group, String employerId) async {
    final job = await _jobs.getJobPostById(group.jobId);
    if (job == null || !_isActiveJob(job)) return;
    if (!WorkDayHelper.isWorkPeriodEnded(job)) return;
    if (await _workflow.hasCompletedDisbursement(job.jobId)) return;

    final candidateIds = group.memberIds
        .where((id) => id.isNotEmpty && id != group.employerId)
        .toList();
    if (candidateIds.isEmpty) return;

    final active = await _workflow.getActiveRequestForJob(job.jobId);
    if (active != null) {
      await _maybeNotifyPendingAdmin(job, group, employerId, active.status);
      return;
    }

    final readiness = await _completion.evaluate(
      jobId: job.jobId,
      groupId: group.groupId,
      candidateIds: candidateIds,
    );

    final log = await _readLog(job.jobId);
    final now = DateTime.now();

    if (log['workPeriodEndedNotifiedAt'] == null) {
      if (!await _claimOnce(job.jobId, 'workPeriodEndedNotifiedAt')) return;
      await _sendWorkPeriodEnded(
        employerId: employerId,
        job: job,
        group: group,
        readiness: readiness,
      );
      if (readiness.canDisburse) {
        await _writeLog(job.jobId, readyNotifiedAt: now);
      }
      return;
    }

    if (readiness.canDisburse && log['readyNotifiedAt'] == null) {
      if (!await _claimOnce(job.jobId, 'readyNotifiedAt')) return;
      await _sendReadyToDisburse(employerId, job, group, readiness);
      await _writeLog(job.jobId, lastReminderAt: now);
      return;
    }

    if (!_shouldSendReminder(log['lastReminderAt'])) return;
    if (!await _claimPeriodicReminder(job.jobId)) return;

    if (readiness.canDisburse) {
      await _sendReadyToDisburse(employerId, job, group, readiness);
    } else {
      await _sendAttendanceIncompleteReminder(
        employerId,
        job,
        group,
        readiness,
      );
    }
  }

  Future<void> _maybeNotifyPendingAdmin(
    JobPostModel job,
    GroupChatModel group,
    String employerId,
    String status,
  ) async {
    if (status != 'pending_admin') return;
    if (!await _claimOnce(job.jobId, 'pendingAdminNotifiedAt')) return;

    await _notif.create(
      recipientId: employerId,
      type: 'disbursement_pending',
      title: 'Đang chờ Admin duyệt giải ngân',
      body:
          '"${job.title}" (${_formatRange(job)}): yêu cầu giải ngân đã gửi. '
          'Bạn sẽ được báo khi Admin cho phép thanh toán.',
      data: {
        'jobId': job.jobId,
        'groupId': group.groupId,
      },
    );
  }

  /// Nhắc lặp: chỉ ghi mốc khi đã qua [_reminderInterval] (transaction tránh trùng).
  Future<bool> _claimPeriodicReminder(String jobId) async {
    try {
      return await _db.runTransaction<bool>((tx) async {
        final ref = _logRef(jobId);
        final snap = await tx.get(ref);
        final data = snap.data();
        if (!_shouldSendReminder(data?['lastReminderAt'])) return false;
        tx.set(
          ref,
          {'lastReminderAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
        return true;
      });
    } catch (_) {
      return false;
    }
  }

  /// Chỉ một client/process được gửi thông báo cho mỗi mốc (tránh trùng khi poll song song).
  Future<bool> _claimOnce(String jobId, String field) async {
    try {
      return await _db.runTransaction<bool>((tx) async {
        final ref = _logRef(jobId);
        final snap = await tx.get(ref);
        final data = snap.data();
        if (data != null && data[field] != null) return false;
        tx.set(
          ref,
          {field: FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
        return true;
      });
    } catch (_) {
      return false;
    }
  }

  Future<void> _sendWorkPeriodEnded({
    required String employerId,
    required JobPostModel job,
    required GroupChatModel group,
    required JobDisbursementReadiness readiness,
  }) async {
    final range = _formatRange(job);
    final body = readiness.canDisburse
        ? '"${job.title}" ($range) đã kết thúc. '
            'Đủ điểm danh ${readiness.completedDays}/${readiness.requiredDays} ngày — '
            'mở Giải ngân để thanh toán.'
        : '"${job.title}" ($range) đã kết thúc. '
            'Trong thời hạn chỉ đủ ${readiness.completedDays}/${readiness.requiredDays} ngày. '
            'Không cần điểm danh thêm — gửi yêu cầu giải ngân để Admin xem xét.';

    await _notif.create(
      recipientId: employerId,
      type: readiness.canDisburse
          ? 'disbursement_ready'
          : 'job_work_period_ended',
      title: 'Công việc đã hết hạn — cần giải ngân',
      body: body,
      data: {
        'jobId': job.jobId,
        'groupId': group.groupId,
        'canDisburse': readiness.canDisburse,
      },
    );
  }

  Future<void> _sendReadyToDisburse(
    String employerId,
    JobPostModel job,
    GroupChatModel group,
    JobDisbursementReadiness readiness,
  ) async {
    await _notif.create(
      recipientId: employerId,
      type: 'disbursement_ready',
      title: 'Có thể yêu cầu giải ngân',
      body:
          '"${job.title}": đã đủ ${readiness.requiredDays} ngày điểm danh. '
          'Mở Giải ngân / Kết thúc ca để gửi yêu cầu cho Admin.',
      data: {
        'jobId': job.jobId,
        'groupId': group.groupId,
        'canDisburse': true,
      },
    );
  }

  Future<void> _sendAttendanceIncompleteReminder(
    String employerId,
    JobPostModel job,
    GroupChatModel group,
    JobDisbursementReadiness readiness,
  ) async {
    await _notif.create(
      recipientId: employerId,
      type: 'disbursement_reminder',
      title: 'Nhắc: giải ngân sau khi hết hạn',
      body:
          '"${job.title}" đã kết thúc. Điểm danh đủ ${readiness.completedDays}/'
          '${readiness.requiredDays} ngày trong thời hạn. '
          'Mở Giải ngân để gửi yêu cầu (Admin xem xét).',
      data: {
        'jobId': job.jobId,
        'groupId': group.groupId,
        'canDisburse': false,
      },
    );
  }

  bool _isActiveJob(JobPostModel job) {
    return job.status == 'approved' || job.status == 'active';
  }

  String _formatRange(JobPostModel job) {
    final f = DateFormat('dd/MM/yyyy');
    final start = f.format(job.startDate);
    if (job.endDate != null) {
      return '$start–${f.format(job.endDate!)}';
    }
    return start;
  }

  bool _shouldSendReminder(dynamic lastReminderAt) {
    if (lastReminderAt == null) return true;
    DateTime? dt;
    if (lastReminderAt is Timestamp) {
      dt = lastReminderAt.toDate();
    } else if (lastReminderAt is DateTime) {
      dt = lastReminderAt;
    }
    if (dt == null) return true;
    return DateTime.now().difference(dt) >= _reminderInterval;
  }

  DocumentReference<Map<String, dynamic>> _logRef(String jobId) =>
      _db.collection('jobPosts').doc(jobId).collection('workflowReminders').doc('disbursement');

  Future<Map<String, dynamic>> _readLog(String jobId) async {
    final snap = await _logRef(jobId).get();
    if (!snap.exists) return {};
    return Map<String, dynamic>.from(snap.data() ?? {});
  }

  Future<void> _writeLog(
    String jobId, {
    DateTime? workPeriodEndedNotifiedAt,
    DateTime? readyNotifiedAt,
    DateTime? lastReminderAt,
    DateTime? pendingAdminNotifiedAt,
    bool? noGroupEndedNotifiedAt,
  }) async {
    final data = <String, dynamic>{};
    if (workPeriodEndedNotifiedAt != null) {
      data['workPeriodEndedNotifiedAt'] =
          Timestamp.fromDate(workPeriodEndedNotifiedAt);
    }
    if (readyNotifiedAt != null) {
      data['readyNotifiedAt'] = Timestamp.fromDate(readyNotifiedAt);
    }
    if (lastReminderAt != null) {
      data['lastReminderAt'] = Timestamp.fromDate(lastReminderAt);
    }
    if (pendingAdminNotifiedAt != null) {
      data['pendingAdminNotifiedAt'] =
          Timestamp.fromDate(pendingAdminNotifiedAt);
    }
    if (noGroupEndedNotifiedAt == true) {
      data['noGroupEndedNotifiedAt'] = FieldValue.serverTimestamp();
    }
    if (data.isEmpty) return;
    await _logRef(jobId).set(data, SetOptions(merge: true));
  }
}
