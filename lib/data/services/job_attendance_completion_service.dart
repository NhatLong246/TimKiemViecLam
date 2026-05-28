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
  final String message;

  JobDisbursementReadiness({
    required this.canDisburse,
    required this.canRequestDisbursement,
    required this.workPeriodEnded,
    required this.requiredDays,
    required this.completedDays,
    required this.mandatoryDates,
    required this.incompleteDates,
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
        message: 'Không tìm thấy bài đăng công việc',
      );
    }

    final workPeriodEnded = WorkDayHelper.isWorkPeriodEnded(job);
    final scheduled = await _scheduleSvc.listScheduledDates(groupId);
    final mandatory =
        WorkDayHelper.mandatoryDates(job, scheduledDates: scheduled);

    if (mandatory.isEmpty) {
      return JobDisbursementReadiness(
        canDisburse: false,
        canRequestDisbursement: workPeriodEnded,
        workPeriodEnded: workPeriodEnded,
        requiredDays: 0,
        completedDays: 0,
        mandatoryDates: mandatory,
        incompleteDates: const [],
        message: workPeriodEnded
            ? 'Công việc đã kết thúc. Chưa có lịch ngày làm — liên hệ Admin hoặc đóng nhóm.'
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
        message: 'Chưa có nhân viên trong nhóm',
      );
    }

    final sessions = await _attendance.fetchAllByJob(jobId);
    final byDate = {for (final s in sessions) s.date: s};

    final incomplete = <String>[];
    var completed = 0;
    for (final date in mandatory) {
      if (WorkDayHelper.isDayAttendanceComplete(
        byDate[date],
        candidateIds,
      )) {
        completed++;
      } else {
        incomplete.add(date);
      }
    }

    final n = mandatory.length;
    final can = completed == n;
    final canRequest = can || workPeriodEnded;

    return JobDisbursementReadiness(
      canDisburse: can,
      canRequestDisbursement: canRequest,
      workPeriodEnded: workPeriodEnded,
      requiredDays: n,
      completedDays: completed,
      mandatoryDates: mandatory,
      incompleteDates: incomplete,
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
        return completed >= 1
            ? 'Công việc đã kết thúc. Đủ điểm danh trong ngày làm.'
            : 'Công việc đã kết thúc. Không có điểm danh trong ngày làm. '
                'Bạn có thể gửi yêu cầu giải ngân để Admin xem xét.';
      }
      return 'Công việc đã kết thúc. Trong thời hạn điểm danh đủ $completed/$n ngày '
          '(thiếu $incompleteCount ngày). '
          'Không cần điểm danh thêm — gửi yêu cầu giải ngân để Admin xem xét.';
    }
    if (n == 1) {
      return 'Đang trong thời gian làm việc. Cần hoàn tất điểm danh đầu ca và cuối ca.';
    }
    return 'Đang trong thời gian làm việc. Đã điểm danh $completed/$n ngày. '
        'Còn $incompleteCount ngày trong lịch chưa đủ trước khi giải ngân.';
  }
}
