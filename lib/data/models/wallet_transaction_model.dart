import 'package:cloud_firestore/cloud_firestore.dart';

/// Giao dịch ví employer — collection `walletTransactions`.
class WalletTransactionModel {
  final String id;
  final String userId;
  final String type; // deposit | payment | withdrawal | refund
  final double amount;
  final String description;
  final String status; // pending | completed | failed
  final String? paymentMethod; // momo | wallet
  final String? orderId;
  final String? requestId;
  final String? payUrl;
  final String? momoTransId;
  final String? momoPhone;
  final String? jobId;
  final DateTime? createdAt;
  final DateTime? completedAt;

  const WalletTransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.description,
    required this.status,
    this.paymentMethod,
    this.orderId,
    this.requestId,
    this.payUrl,
    this.momoTransId,
    this.momoPhone,
    this.jobId,
    this.createdAt,
    this.completedAt,
  });

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isCredit =>
      (type == 'deposit' || type == 'refund') && isCompleted;
  bool get isDebit =>
      (type == 'payment' || type == 'withdrawal') && isCompleted;

  factory WalletTransactionModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final m = doc.data() ?? {};
    return WalletTransactionModel.fromMap(m, id: doc.id);
  }

  factory WalletTransactionModel.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    return WalletTransactionModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      type: map['type'] as String? ?? 'deposit',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      description: map['description'] as String? ?? '',
      status: map['status'] as String? ?? 'completed',
      paymentMethod: map['paymentMethod'] as String?,
      orderId: map['orderId'] as String?,
      requestId: map['requestId'] as String?,
      payUrl: map['payUrl'] as String?,
      momoTransId: map['momoTransId'] as String?,
      momoPhone: map['momoPhone'] as String?,
      jobId: map['jobId'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'type': type,
        'amount': amount,
        'description': description,
        'status': status,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        if (orderId != null) 'orderId': orderId,
        if (requestId != null) 'requestId': requestId,
        if (payUrl != null) 'payUrl': payUrl,
        if (momoTransId != null) 'momoTransId': momoTransId,
        if (jobId != null) 'jobId': jobId,
      };
}
