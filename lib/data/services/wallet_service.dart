import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:viecnow/data/models/wallet_summary_model.dart';
import 'package:viecnow/data/models/wallet_transaction_model.dart';
import 'package:viecnow/data/services/wallet_deposit_service.dart';
import 'package:viecnow/data/services/wallet_withdraw_service.dart';

/// Backend ví employer: số dư, lịch sử, hạn mức, sao kê.
class WalletService {
  final _firestore = FirebaseFirestore.instance;
  final WalletDepositService deposit = WalletDepositService();
  final WalletWithdrawService withdraw = WalletWithdrawService();

  Stream<WalletSummaryModel> watchSummary(String userId) {
    if (userId.isEmpty) {
      return Stream.value(const WalletSummaryModel());
    }
    return _firestore.collection('users').doc(userId).snapshots().map((snap) {
      return WalletSummaryModel.fromMap(snap.data());
    });
  }

  Stream<List<WalletTransactionModel>> watchTransactions(String userId) {
    if (userId.isEmpty) {
      return Stream.value(const []);
    }
    return _firestore
        .collection('walletTransactions')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => WalletTransactionModel.fromDoc(d))
              .toList();
          list.sort((a, b) {
            final ta = a.createdAt;
            final tb = b.createdAt;
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
          });
          return list;
        });
  }

  Future<void> setSpendingLimit(String userId, double? limitVnd) async {
    if (userId.isEmpty) throw Exception('Chưa đăng nhập');
    await _firestore.collection('users').doc(userId).set({
      'walletSpendingLimit': limitVnd,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Ghi chi tiêu từ ví (đăng tin, thanh toán lương, …).
  Future<void> recordPayment({
    required String userId,
    required double amount,
    required String description,
    String? jobId,
    String idempotencyKey = '',
  }) async {
    if (userId.isEmpty) throw Exception('Chưa đăng nhập');
    if (amount <= 0) throw Exception('Số tiền không hợp lệ');

    final userRef = _firestore.collection('users').doc(userId);
    final userSnap = await userRef.get();
    if (!userSnap.exists) throw Exception('Không tìm thấy tài khoản');

    final data = userSnap.data()!;
    final balance = (data['walletBalance'] as num?)?.toDouble() ?? 0;
    final limit = (data['walletSpendingLimit'] as num?)?.toDouble();
    if (balance < amount) {
      throw Exception(
        'Số dư không đủ (${_vnd(balance)}). Vui lòng nạp thêm tiền.',
      );
    }
    if (limit != null && limit > 0 && amount > limit) {
      throw Exception('Vượt hạn mức chi tiêu ${_vnd(limit)}/giao dịch');
    }

    if (idempotencyKey.isNotEmpty) {
      final dup = await _firestore
          .collection('walletTransactions')
          .where('userId', isEqualTo: userId)
          .where('idempotencyKey', isEqualTo: idempotencyKey)
          .limit(1)
          .get();
      if (dup.docs.isNotEmpty) return;
    }

    final txRef = _firestore.collection('walletTransactions').doc();
    final batch = _firestore.batch();
    batch.set(txRef, {
      'userId': userId,
      'type': 'payment',
      'amount': amount,
      'description': description,
      'status': 'completed',
      'paymentMethod': 'wallet',
      if (jobId != null) 'jobId': jobId,
      if (idempotencyKey.isNotEmpty) 'idempotencyKey': idempotencyKey,
      'balanceBefore': balance,
      'balanceAfter': balance - amount,
      'createdAt': FieldValue.serverTimestamp(),
      'completedAt': FieldValue.serverTimestamp(),
    });
    batch.set(userRef, {
      'walletBalance': FieldValue.increment(-amount),
      'totalSpent': FieldValue.increment(amount),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<WalletTransactionModel?> findPendingMomoDeposit(String userId) async {
    final snap = await _firestore
        .collection('walletTransactions')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .where('paymentMethod', isEqualTo: 'momo')
        .limit(5)
        .get();
    for (final doc in snap.docs) {
      final tx = WalletTransactionModel.fromDoc(doc);
      if (tx.payUrl != null && tx.payUrl!.isNotEmpty) return tx;
    }
    return null;
  }

  /// Xử lý hoàn tiền và đền bù khi doanh nghiệp hủy Job.
  Future<void> processJobCancellationRefund({
    required String employerId,
    required String jobId,
    required double totalBudget,
    required List<String> candidateIds,
    bool compensateCandidates = true,
  }) async {
    if (employerId.isEmpty) throw Exception('Chưa đăng nhập');
    final refundKey = 'job_cancel_refund_$jobId';
    final existingRefund = await _firestore
        .collection('walletTransactions')
        .where('idempotencyKey', isEqualTo: refundKey)
        .limit(1)
        .get();
    if (existingRefund.docs.isNotEmpty) return;

    final batch = _firestore.batch();
    final uniqueCandidateIds = candidateIds.toSet().toList();

    // Chỉ đền bù khi nghiệp vụ yêu cầu (job đã đủ người) và có ứng viên hợp lệ.
    if (compensateCandidates && uniqueCandidateIds.isNotEmpty) {
      final compensationTotal = totalBudget * 0.1;
      final compensationPerUser = compensationTotal / uniqueCandidateIds.length;
      final refundAmount = totalBudget * 0.9;

      // Hoàn tiền 90% cho employer
      final employerRef = _firestore.collection('users').doc(employerId);
      batch.set(employerRef, {
        'walletBalance': FieldValue.increment(refundAmount),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final empTxRef = _firestore.collection('walletTransactions').doc();
      batch.set(empTxRef, {
        'userId': employerId,
        'type': 'refund',
        'amount': refundAmount,
        'description': 'Hoàn tiền 90% do hủy công việc đã có ứng viên',
        'status': 'completed',
        'paymentMethod': 'wallet',
        'jobId': jobId,
        'idempotencyKey': refundKey,
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Cộng tiền cho mỗi ứng viên
      for (final candidateId in uniqueCandidateIds) {
        final candidateRef = _firestore.collection('users').doc(candidateId);
        batch.set(candidateRef, {
          'walletBalance': FieldValue.increment(compensationPerUser),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final candTxRef = _firestore.collection('walletTransactions').doc();
        batch.set(candTxRef, {
          'userId': candidateId,
          'type': 'compensation',
          'amount': compensationPerUser,
          'description': 'Đền bù do doanh nghiệp hủy công việc',
          'status': 'completed',
          'paymentMethod': 'wallet',
          'jobId': jobId,
          'idempotencyKey': 'job_cancel_comp_${jobId}_$candidateId',
          'createdAt': FieldValue.serverTimestamp(),
          'completedAt': FieldValue.serverTimestamp(),
        });
      }
    } else {
      // Job chưa đủ điều kiện đền bù -> hoàn tiền 100%.
      final refundAmount = totalBudget;
      final employerRef = _firestore.collection('users').doc(employerId);
      batch.set(employerRef, {
        'walletBalance': FieldValue.increment(refundAmount),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final empTxRef = _firestore.collection('walletTransactions').doc();
      batch.set(empTxRef, {
        'userId': employerId,
        'type': 'refund',
        'amount': refundAmount,
        'description': 'Hoàn tiền 100% do hủy công việc',
        'status': 'completed',
        'paymentMethod': 'wallet',
        'jobId': jobId,
        'idempotencyKey': refundKey,
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  String buildStatementText({
    required String userId,
    required WalletSummaryModel summary,
    required List<WalletTransactionModel> transactions,
    String? companyName,
    DateTime? from,
    DateTime? to,
  }) {
    final fmt = NumberFormat('#,###', 'vi_VN');
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final now = DateTime.now();
    final start = from ?? now.subtract(const Duration(days: 90));
    final end = to ?? now;

    final filtered = transactions.where((t) {
      if (!t.isCompleted) return false;
      final d = t.createdAt;
      if (d == null) return false;
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();

    final buf = StringBuffer()
      ..writeln('SAO KÊ VÍ VIECNOW')
      ..writeln('Mã tài khoản: $userId');
    if (companyName != null && companyName.trim().isNotEmpty) {
      buf.writeln('Đơn vị: ${companyName.trim()}');
    }
    buf
      ..writeln(
        'Kỳ: ${DateFormat('dd/MM/yyyy').format(start)} — ${DateFormat('dd/MM/yyyy').format(end)}',
      )
      ..writeln('In lúc: ${df.format(now)}')
      ..writeln('')
      ..writeln('Số dư khả dụng: ${fmt.format(summary.walletBalance.toInt())}đ')
      ..writeln('Tổng đã nạp: ${fmt.format(summary.totalDeposited.toInt())}đ')
      ..writeln('Tổng đã chi: ${fmt.format(summary.totalSpent.toInt())}đ');
    if (summary.hasSpendingLimit) {
      buf.writeln(
        'Hạn mức chi/giao dịch: ${fmt.format(summary.walletSpendingLimit!.toInt())}đ',
      );
    }
    buf
      ..writeln('')
      ..writeln('--- Chi tiết giao dịch (${filtered.length}) ---');

    if (filtered.isEmpty) {
      buf.writeln('(Không có giao dịch hoàn tất trong kỳ)');
    } else {
      for (final t in filtered) {
        final sign = t.isCredit ? '+' : '-';
        final date = t.createdAt != null ? df.format(t.createdAt!) : '—';
        buf.writeln(
          '$date | ${t.description} | $sign${fmt.format(t.amount.toInt())}đ | ${t.type}',
        );
      }
    }
    buf.writeln('\n— ViecNow • Tiền app —');
    return buf.toString();
  }

  static String _vnd(double v) =>
      '${NumberFormat('#,###', 'vi_VN').format(v.toInt())}đ';
}
