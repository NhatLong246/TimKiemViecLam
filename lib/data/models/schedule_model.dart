import 'package:cloud_firestore/cloud_firestore.dart';

/// Ca làm — collection `schedules` (xem `database_schema.md`).
class ScheduleModel {
  final String scheduleId;
  final String jobId;
  final String candidateId;
  final String employerId;
  final String date; // YYYY-MM-DD
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final String status; // scheduled | completed | cancelled
  final String? jobTitle;
  final String? jobLocation;
  final String? employerName;
  final DateTime? createdAt;

  const ScheduleModel({
    required this.scheduleId,
    required this.jobId,
    required this.candidateId,
    required this.employerId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.jobTitle,
    this.jobLocation,
    this.employerName,
    this.createdAt,
  });

  String get timeRange => '$startTime - $endTime';

  factory ScheduleModel.fromMap(Map<String, dynamic> map, String docId) {
    return ScheduleModel(
      scheduleId: docId,
      jobId: map['jobId'] as String? ?? '',
      candidateId: map['candidateId'] as String? ?? '',
      employerId: map['employerId'] as String? ?? '',
      date: map['date'] as String? ?? '',
      startTime: map['startTime'] as String? ?? '',
      endTime: map['endTime'] as String? ?? '',
      status: map['status'] as String? ?? 'scheduled',
      jobTitle: map['jobTitle'] as String?,
      jobLocation: map['jobLocation'] as String?,
      employerName: map['employerName'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'scheduleId': scheduleId,
        'jobId': jobId,
        'candidateId': candidateId,
        'employerId': employerId,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'status': status,
        if (jobTitle != null) 'jobTitle': jobTitle,
        if (jobLocation != null) 'jobLocation': jobLocation,
        if (employerName != null) 'employerName': employerName,
      };
}

/// Trạng thái hiển thị trên lịch candidate.
enum ScheduleDisplayKind {
  upcoming,
  ongoing,
  completed,
  cancelled,
  pending,
}

extension ScheduleDisplayKindX on ScheduleDisplayKind {
  String get label => switch (this) {
        ScheduleDisplayKind.upcoming => 'Sắp tới',
        ScheduleDisplayKind.ongoing => 'Đang diễn ra',
        ScheduleDisplayKind.completed => 'Đã hoàn thành',
        ScheduleDisplayKind.cancelled => 'Đã hủy',
        ScheduleDisplayKind.pending => 'Chờ xác nhận',
      };
}
