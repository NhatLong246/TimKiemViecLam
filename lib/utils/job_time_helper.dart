import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/models/job_post_model.dart';

class JobTimeHelper {
  static DateTime startDateTime(JobPostModel job) {
    return combineDateAndTime(job.startDate, job.startTime);
  }

  static DateTime combineDateAndTime(DateTime date, String? timeHm) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final minutes = parseTimeToMinutes(timeHm);
    if (minutes == null) return dateOnly;
    return dateOnly.add(Duration(minutes: minutes));
  }

  static int? parseTimeToMinutes(String? timeHm) {
    final raw = timeHm?.trim();
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  static bool hasStarted(JobPostModel job, {DateTime? now}) {
    final current = now ?? DateTime.now();
    return !current.isBefore(startDateTime(job));
  }

  static bool startsAfterNow(JobPostModel job, {DateTime? now}) {
    final current = now ?? DateTime.now();
    return current.isBefore(startDateTime(job));
  }

  static DateTime? startDateTimeFromMap(Map<String, dynamic> data) {
    final rawDate = data['startDate'];
    DateTime? date;
    if (rawDate is Timestamp) {
      date = rawDate.toDate();
    } else if (rawDate is DateTime) {
      date = rawDate;
    }
    if (date == null) return null;
    return combineDateAndTime(date, data['startTime'] as String?);
  }

  static bool hasStartedFromMap(Map<String, dynamic> data, {DateTime? now}) {
    final start = startDateTimeFromMap(data);
    if (start == null) return false;
    final current = now ?? DateTime.now();
    return !current.isBefore(start);
  }
}
