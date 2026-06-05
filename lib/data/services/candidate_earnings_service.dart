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

  /// Lấy số dư ví hiện tại của ứng viên (tính toán lại từ gốc để đảm bảo chính xác tuyệt đối)
  Future<double> getTotalEarnings(String candidateId) async {
    // 1. Tổng tiền nhận được từ lịch sử
    final earningsSnap = await _db.collection('candidateEarnings')
        .where('candidateId', isEqualTo: candidateId)
        .get();
    double earned = 0.0;
    for (var doc in earningsSnap.docs) {
      earned += (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
    }

    // 2. Tổng tiền đã rút thành công
    final withdrawalsSnap = await _db.collection('walletTransactions')
        .where('userId', isEqualTo: candidateId)
        .where('type', isEqualTo: 'withdraw')
        .where('status', isEqualTo: 'completed')
        .get();
    double withdrawn = 0.0;
    for (var doc in withdrawalsSnap.docs) {
      withdrawn += (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
    }

    // 3. Số dư thực tế
    double actualBalance = earned - withdrawn;
    if (actualBalance < 0) actualBalance = 0;

    // Đồng bộ ngược lại vào user document để sửa các lỗi sai lệch trước đây
    try {
      await _db.collection('users').doc(candidateId).set(
        {'walletBalance': actualBalance},
        SetOptions(merge: true),
      );
    } catch (_) {}

    return actualBalance;
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
