import '../../utils/work_day_helper.dart';
import 'attendance_service.dart';
import 'job_post_service.dart';
import 'work_schedule_service.dart';

/// Đánh giá điểm danh vs giải ngân.
///
/// - **Trong thời hạn làm:** cần đủ N/N ngày mới giải ngân.
/// - **Đã hết hạn:** không bắt “điểm danh thêm”; chỉ xét ngày đã qua, vẫn cho gửi
///   yêu cầu giải ngân để Admin xem xét nếu thiếu điểm danh.
class JobDisbursementReadiness {
  /// Đủ điểm danh mọi ngày bắt buộc — giải ngân “đủ điều kiện”.
  final bool canDisburse;

  /// Mở luồng giải ngân (đủ điểm danh hoặc đã hết hạn công việc).
  final bool canRequestDisbursement;

  final bool workPeriodEnded;
  final int requiredDays;
  final int completedDays;
  final List<String> mandatoryDates;
  final List<String> incompleteDates;
  final List<String> displayDates; // NEW: All dates to show in UI (mandatory + actual sessions)
  final String message;

  JobDisbursementReadiness({
    required this.canDisburse,
    required this.canRequestDisbursement,
    required this.workPeriodEnded,
    required this.requiredDays,
    required this.completedDays,
    required this.mandatoryDates,
    required this.incompleteDates,
    required this.displayDates,
    required this.message,
  });
}

class JobAttendanceCompletionService {
  final _attendance = AttendanceService();
  final _jobSvc = JobPostService();
  final _scheduleSvc = WorkScheduleService();

  Future<JobDisbursementReadiness> evaluate({
    required String jobId,
    required String groupId,
    required List<String> candidateIds,
  }) async {
    final job = await _jobSvc.getJobPostById(jobId);
    if (job == null) {
      return JobDisbursementReadiness(
        canDisburse: false,
        canRequestDisbursement: false,
        workPeriodEnded: false,
        requiredDays: 0,
        completedDays: 0,
        mandatoryDates: [],
        incompleteDates: [],
        displayDates: [],
        message: 'Không tìm thấy bài đăng công việc',
      );
    }

    final workPeriodEnded = WorkDayHelper.isWorkPeriodEnded(job);
    final scheduled = await _scheduleSvc.listScheduledDates(groupId);
    final mandatory = WorkDayHelper.mandatoryDates(
      job,
      scheduledDates: scheduled,
    );

    final sessions = await _attendance.fetchAllByJob(jobId);
    final byDate = {for (final s in sessions) s.date: s};

    final displayDates = WorkDayHelper.validAttendanceDisplayDates(
      mandatoryDates: mandatory,
      sessionDates: byDate.keys,
    );

    if (mandatory.isEmpty && displayDates.isEmpty) {
      return JobDisbursementReadiness(
        canDisburse: false,
        canRequestDisbursement: workPeriodEnded,
        workPeriodEnded: workPeriodEnded,
        requiredDays: 0,
        completedDays: 0,
        mandatoryDates: mandatory,
        incompleteDates: const [],
        displayDates: const [],
        message: workPeriodEnded
            ? 'Công việc đã kết thúc. Vui lòng gửi yêu cầu giải ngân.'
            : 'Chưa xác định số ngày làm (cần ngày kết thúc hoặc lịch làm)',
      );
    }

    if (candidateIds.isEmpty) {
      return JobDisbursementReadiness(
        canDisburse: false,
        canRequestDisbursement: workPeriodEnded,
        workPeriodEnded: workPeriodEnded,
        requiredDays: mandatory.length,
        completedDays: 0,
        mandatoryDates: mandatory,
        incompleteDates: mandatory,
        displayDates: displayDates,
        message: 'Chưa có nhân viên trong nhóm',
      );
    }

    final incomplete = <String>[];
    var completed = 0;
    for (final date in mandatory) {
      if (WorkDayHelper.isDayAttendanceComplete(byDate[date], candidateIds)) {
        completed++;
      } else {
        incomplete.add(date);
      }
    }

    final n = mandatory.length;
    final can = n > 0 && completed == n;
    final canRequest = can;

    return JobDisbursementReadiness(
      canDisburse: can,
      canRequestDisbursement: canRequest,
      workPeriodEnded: workPeriodEnded,
      requiredDays: n,
      completedDays: completed,
      mandatoryDates: mandatory,
      incompleteDates: incomplete,
      displayDates: displayDates,
      message: _message(
        can: can,
        workPeriodEnded: workPeriodEnded,
        completed: completed,
        n: n,
        incompleteCount: incomplete.length,
      ),
    );
  }

  static String _message({
    required bool can,
    required bool workPeriodEnded,
    required int completed,
    required int n,
    required int incompleteCount,
  }) {
    if (can) {
      return n == 1
          ? 'Đã hoàn tất điểm danh 1 ngày làm việc. Có thể giải ngân.'
          : 'Đã hoàn tất điểm danh $n/$n ngày. Có thể giải ngân.';
    }
    if (workPeriodEnded) {
      if (n == 1) {
        return 'Công việc đã kết thúc. Vui lòng hoàn tất điểm danh ca làm việc để giải ngân.';
      }
      return 'Công việc đã kết thúc. Đã điểm danh $completed/$n ngày (thiếu $incompleteCount ngày). '
          'Vui lòng hoàn tất điểm danh trước khi giải ngân.';
    }
    if (n == 1) {
      return 'Đang trong thời gian làm việc. Cần hoàn tất điểm danh đầu ca và cuối ca.';
    }
    return 'Đang trong thời gian làm việc. Đã điểm danh $completed/$n ngày. '
        'Còn $incompleteCount ngày trong lịch chưa đủ trước khi giải ngân.';
  }

  /// Tính toán lương thực tế cho từng ứng viên dựa trên điểm danh hợp lệ
  Future<Map<String, double>> calculateCandidateSalaries({
    required String jobId,
    required List<String> candidateIds,
  }) async {
    final job = await _jobSvc.getJobPostById(jobId);
    if (job == null) return {};

    final sessions = await _attendance.fetchAllByJob(jobId);
    final byDate = {for (final s in sessions) s.date: s};

    // Calculate mandatory days
    final scheduled = await _scheduleSvc.listScheduledDates(job.jobId);
    final mandatory = WorkDayHelper.mandatoryDates(
      job,
      scheduledDates: scheduled,
    );

    final salaries = <String, double>{};

    for (final cid in candidateIds) {
      int attendedDays = 0;
      for (final date in mandatory) {
        // A day is attended if the candidate has checked in and checked out (or just checked in if valid)
        // We reuse WorkDayHelper.isDayAttendanceComplete but check for specific candidate
        final session = byDate[date];
        if (session != null) {
          final record = session.records
              .where((r) => r.candidateId == cid)
              .firstOrNull;
          if (record != null &&
              (record.checkInTime != null && record.checkInTime!.isNotEmpty)) {
            // Consider it attended if they checked in. We don't strictly require checkout for basic salary calculation
            // unless we want to be strict.
            attendedDays++;
          }
        }
      }

      double earned = 0;
      switch (job.salaryType) {
        case 'per_hour':
          final hours = job.workHoursPerDay ?? 0.0;
          earned = job.salary * hours * attendedDays;
          break;
        case 'per_day':
          earned = job.salary * attendedDays;
          break;
        case 'per_month':
          // Prorate by 30 days
          earned = (job.salary / 30) * attendedDays;
          break;
        case 'fixed':
        default:
          final reqDays = mandatory.length;
          if (reqDays > 0) {
            earned = (job.salary / reqDays) * attendedDays;
          } else {
            earned = job.salary;
          }
          break;
      }
      salaries[cid] = earned;
    }

    return salaries;
  }
}
