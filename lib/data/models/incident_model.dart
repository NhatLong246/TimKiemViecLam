import 'package:cloud_firestore/cloud_firestore.dart';

/// status: 'pending' | 'reviewing' | 'resolved' | 'dismissed'
class IncidentModel {
  final String incidentId;
  final String groupId;
  final String jobId;
  final String reportedBy;       // employerId
  final String workerId;         // candidateId bị khiếu nại
  final String workerName;       // tên nhân viên
  final String description;
  final List<String> imageBase64s; // nhiều ảnh minh chứng
  final double deductAmount;     // số tiền trừ lương
  final double compensationAmount; // số tiền bồi thường
  final String status;
  final DateTime createdAt;

  const IncidentModel({
    required this.incidentId,
    required this.groupId,
    required this.jobId,
    required this.reportedBy,
    required this.workerId,
    this.workerName = '',
    required this.description,
    this.imageBase64s = const [],
    required this.deductAmount,
    required this.compensationAmount,
    required this.status,
    required this.createdAt,
  });

  factory IncidentModel.fromMap(Map<String, dynamic> map, String docId) {
    return IncidentModel(
      incidentId: docId,
      groupId: map['groupId'] as String? ?? '',
      jobId: map['jobId'] as String? ?? '',
      reportedBy: map['reportedBy'] as String? ?? '',
      workerId: map['workerId'] as String? ?? '',
      workerName: map['workerName'] as String? ?? '',
      description: map['description'] as String? ?? '',
      imageBase64s: List<String>.from(map['imageBase64s'] as List? ?? []),
      deductAmount: (map['deductAmount'] as num?)?.toDouble() ?? 0.0,
      compensationAmount: (map['compensationAmount'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'groupId': groupId,
        'jobId': jobId,
        'reportedBy': reportedBy,
        'workerId': workerId,
        'workerName': workerName,
        'description': description,
        'imageBase64s': imageBase64s,
        'deductAmount': deductAmount,
        'compensationAmount': compensationAmount,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
