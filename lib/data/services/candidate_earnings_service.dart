import 'package:cloud_firestore/cloud_firestore.dart';

class EarningRecord {
  final String id;
  final String candidateId;
  final String jobId;
  final double amount;
  final String details;
  final DateTime createdAt;

  EarningRecord({
    required this.id,
    required this.candidateId,
    required this.jobId,
    required this.amount,
    required this.details,
    required this.createdAt,
  });

  factory EarningRecord.fromMap(Map<String, dynamic> map, String id) {
    return EarningRecord(
      id: id,
      candidateId: map['candidateId'] as String? ?? '',
      jobId: map['jobId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      details: map['details'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'candidateId': candidateId,
        'jobId': jobId,
        'amount': amount,
        'details': details,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

class CandidateEarningsService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _earnings =>
      _db.collection('candidateEarnings');

  /// Ghi nhận thu nhập (tracking ảo). amount có thể âm (trừ tiền đền bù).
  Future<void> addEarning({
    required String candidateId,
    required String jobId,
    required double amount,
    required String details,
  }) async {
    await _earnings.add({
      'candidateId': candidateId,
      'jobId': jobId,
      'amount': amount,
      'details': details,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Lấy tổng thu nhập (số dư ví)
  Future<double> getTotalEarnings(String candidateId) async {
    final snap = await _earnings
        .where('candidateId', isEqualTo: candidateId)
        .get();
    double total = 0.0;
    for (var doc in snap.docs) {
      total += (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  /// Lấy lịch sử thu nhập mới nhất
  Stream<List<EarningRecord>> streamEarnings(String candidateId) {
    return _earnings
        .where('candidateId', isEqualTo: candidateId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => EarningRecord.fromMap(d.data(), d.id)).toList());
  }
}
