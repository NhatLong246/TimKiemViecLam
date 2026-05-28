import 'package:cloud_firestore/cloud_firestore.dart';

/// Thông báo sau giải ngân — Admin và NTD phải xác nhận trước khi xóa bài đăng.
class DisbursementNoticeModel {
  final String noticeId;
  final String jobId;
  final String groupId;
  final String employerId;
  final String workDate;
  final double amount;
  final String jobTitle;
  final String status;
  final bool employerAck;
  final bool adminAck;
  final DateTime createdAt;

  const DisbursementNoticeModel({
    required this.noticeId,
    required this.jobId,
    required this.groupId,
    required this.employerId,
    required this.workDate,
    required this.amount,
    this.jobTitle = '',
    required this.status,
    this.employerAck = false,
    this.adminAck = false,
    required this.createdAt,
  });

  bool get isFullyAcknowledged => employerAck && adminAck;

  bool get canEmployerDisburse => status == 'approved';

  bool get isWaitingAdmin => status == 'pending_admin';

  factory DisbursementNoticeModel.fromMap(Map<String, dynamic> map, String id) {
    return DisbursementNoticeModel(
      noticeId: id,
      jobId: map['jobId'] as String? ?? '',
      groupId: map['groupId'] as String? ?? '',
      employerId: map['employerId'] as String? ?? '',
      workDate: map['workDate'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      jobTitle: map['jobTitle'] as String? ?? '',
      status: map['status'] as String? ?? 'pending_admin',
      employerAck: map['employerAck'] as bool? ?? false,
      adminAck: map['adminAck'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'jobId': jobId,
        'groupId': groupId,
        'employerId': employerId,
        'workDate': workDate,
        'amount': amount,
        'jobTitle': jobTitle,
        'status': status,
        'employerAck': employerAck,
        'adminAck': adminAck,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
