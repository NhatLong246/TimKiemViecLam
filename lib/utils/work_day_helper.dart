import 'package:intl/intl.dart';

import '../data/models/attendance_model.dart';
import '../data/models/job_post_model.dart';

/// Ngày bắt buộc điểm danh: ưu tiên lịch `workSchedules`, không có thì mọi ngày trong [startDate..endDate].
class WorkDayHelper {
  static String formatDate(DateTime d) =>
      DateFormat('yyyy-MM-dd').format(DateTime(d.year, d.month, d.day));

  static List<String> datesInRange(DateTime start, DateTime end) {
    final list = <String>[];
    var cur = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!cur.isAfter(last)) {
      list.add(formatDate(cur));
      cur = cur.add(const Duration(days: 1));
    }
    return list;
  }

  /// Lấy ngày làm việc "logic" hiện tại dựa trên giờ bắt đầu ca làm.
  /// Trả về đối tượng DateTime đại diện cho ngày logic.
  static DateTime getCurrentLogicalDateTime(JobPostModel? job) {
    final now = DateTime.now();
    if (job == null || job.startTime == null || job.startTime!.isEmpty || job.workHoursPerDay == null) {
      return now;
    }
    
    final parts = job.startTime!.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      
      final yesterdayStart = DateTime(now.year, now.month, now.day - 1, h, m);
      final minutesToAdd = (job.workHoursPerDay! * 60).toInt();
      final yesterdayEnd = yesterdayStart.add(Duration(minutes: minutesToAdd));
      
      if (now.isBefore(yesterdayEnd)) {
        return DateTime(now.year, now.month, now.day - 1);
      }
    }
    return now;
  }

  /// Phiên bản trả về chuỗi định dạng yyyy-MM-dd
  static String getCurrentLogicalDate(JobPostModel? job) {
    return formatDate(getCurrentLogicalDateTime(job));
  }

  /// Số ngày bắt buộc đi làm (ví dụ 8 ngày → 8 lần điểm danh).
  static int requiredWorkDayCount(JobPostModel job, {List<String>? scheduledDates}) {
    if (scheduledDates != null && scheduledDates.isNotEmpty) {
      return scheduledDates.length;
    }
    if (job.endDate == null) return 0;
    return datesInRange(job.startDate, job.endDate!).length;
  }

  /// Đã qua ngày [endDate] (tính từ ngày hôm sau).
  static bool isWorkPeriodEnded(JobPostModel job) {
    if (job.endDate == null) return false;
    final today = DateTime.now();
    final end = DateTime(
      job.endDate!.year,
      job.endDate!.month,
      job.endDate!.day,
    );
    final now = DateTime(today.year, today.month, today.day);
    return now.isAfter(end);
  }

  static List<String> mandatoryDates(JobPostModel job, {List<String>? scheduledDates}) {
    if (scheduledDates != null && scheduledDates.isNotEmpty) {
      return List<String>.from(scheduledDates)..sort();
    }
    if (job.endDate == null) return const [];
    return datesInRange(job.startDate, job.endDate!);
  }

  /// Một ngày trong ca: mọi nhân viên đã điểm danh đầu ca + cuối ca.
  static bool isDayAttendanceComplete(
    AttendanceModel? session,
    List<String> candidateIds,
  ) {
    if (session == null || candidateIds.isEmpty) return false;
    for (final cid in candidateIds) {
      AttendanceRecord? found;
      for (final r in session.records) {
        if (r.candidateId == cid) {
          found = r;
          break;
        }
      }
      if (found == null) return false;
      
      // Nếu đã đánh dấu vắng mặt thì coi như đã hoàn tất cho người này
      if (found.status == 'absent') continue;
      
      if ((found.checkInTime ?? '').isEmpty) return false;
      if ((found.checkOutTime ?? '').isEmpty) return false;
    }
    return true;
  }

  static bool isMandatoryWorkDay(
    String date, {
    required JobPostModel? job,
    required List<String> scheduledDates,
  }) {
    if (scheduledDates.isNotEmpty) {
      return scheduledDates.contains(date);
    }
    if (job == null || job.endDate == null) return false;
    return datesInRange(job.startDate, job.endDate!).contains(date);
  }
}
