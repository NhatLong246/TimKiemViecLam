import 'package:cloud_firestore/cloud_firestore.dart';

/// status: 'on_time' | 'late' | 'absent' | 'not_marked'
class AttendanceRecord {
  final String candidateId;
  final String candidateName;
  final String status;
  final int lateMinutes;
  final String? checkInTime;
  final String? checkOutTime;
  final String? checkInPhotoUrl;
  final String? checkOutPhotoUrl;

  const AttendanceRecord({
    required this.candidateId,
    required this.candidateName,
    required this.status,
    required this.lateMinutes,
    this.checkInTime,
    this.checkOutTime,
    this.checkInPhotoUrl,
    this.checkOutPhotoUrl,
  });

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      candidateId: map['candidateId'] as String? ?? '',
      candidateName: map['candidateName'] as String? ?? '',
      status: map['status'] as String? ?? 'not_marked',
      lateMinutes: map['lateMinutes'] as int? ?? 0,
      checkInTime: map['checkInTime'] as String?,
      checkOutTime: map['checkOutTime'] as String?,
      checkInPhotoUrl: map['checkInPhotoUrl'] as String?,
      checkOutPhotoUrl: map['checkOutPhotoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'candidateId': candidateId,
        'candidateName': candidateName,
        'status': status,
        'lateMinutes': lateMinutes,
        if (checkInTime != null) 'checkInTime': checkInTime,
        if (checkOutTime != null) 'checkOutTime': checkOutTime,
        if (checkInPhotoUrl != null) 'checkInPhotoUrl': checkInPhotoUrl,
        if (checkOutPhotoUrl != null) 'checkOutPhotoUrl': checkOutPhotoUrl,
      };

  AttendanceRecord copyWith({
    String? status,
    int? lateMinutes,
    String? checkInTime,
    String? checkOutTime,
    String? checkInPhotoUrl,
    String? checkOutPhotoUrl,
  }) {
    return AttendanceRecord(
      candidateId: candidateId,
      candidateName: candidateName,
      status: status ?? this.status,
      lateMinutes: lateMinutes ?? this.lateMinutes,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      checkInPhotoUrl: checkInPhotoUrl ?? this.checkInPhotoUrl,
      checkOutPhotoUrl: checkOutPhotoUrl ?? this.checkOutPhotoUrl,
    );
  }
}

class AttendanceModel {
  final String attendanceId;
  final String jobId;
  final String groupId;
  final String employerId;
  final String date; // "YYYY-MM-DD"
  final String expectedStartTime; // "HH:mm"
  final List<AttendanceRecord> records;
  final DateTime createdAt;

  const AttendanceModel({
    required this.attendanceId,
    required this.jobId,
    required this.groupId,
    required this.employerId,
    required this.date,
    required this.expectedStartTime,
    required this.records,
    required this.createdAt,
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> map, String docId) {
    final rawRecords = map['records'] as List? ?? [];
    return AttendanceModel(
      attendanceId: docId,
      jobId: map['jobId'] as String? ?? '',
      groupId: map['groupId'] as String? ?? '',
      employerId: map['employerId'] as String? ?? '',
      date: map['date'] as String? ?? '',
      expectedStartTime: map['expectedStartTime'] as String? ?? '08:00',
      records: rawRecords
          .map((r) => AttendanceRecord.fromMap(r as Map<String, dynamic>))
          .toList(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'jobId': jobId,
        'groupId': groupId,
        'employerId': employerId,
        'date': date,
        'expectedStartTime': expectedStartTime,
        'records': records.map((r) => r.toMap()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
      };
}
