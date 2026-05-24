import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viecnow/config/momo_config.dart';
import 'package:viecnow/data/services/momo_payment_service.dart';

class WalletWithdrawResult {
  final String orderId;
  final int amount;
  final String? momoTransId;

  const WalletWithdrawResult({
    required this.orderId,
    required this.amount,
    this.momoTransId,
  });
}

/// Rút tiền app → ví MoMo bằng **hoàn tiền (refund)** giao dịch nạp MoMo.
///
/// Tiền về đúng ví MoMo đã dùng khi nạp (sandbox: MoMo Test 0917003000).
class WalletWithdrawService {
  final _firestore = FirebaseFirestore.instance;
  final _momo = MomoPaymentService();

  static const int minAmount = 50000;

  Future<WalletWithdrawResult> withdrawToMomo({
    required String userId,
    required int amount,
    String note = '',
  }) async {
    if (!MomoConfig.isConfigured) {
      throw Exception('Chưa cấu hình MoMo');
    }
    if (amount < minAmount) {
      throw Exception('Số tiền rút tối thiểu ${minAmount ~/ 1000}.000đ');
    }

    final userRef = _firestore.collection('users').doc(userId);
    final userSnap = await userRef.get();
    if (!userSnap.exists) throw Exception('Không tìm thấy tài khoản');

    final balance =
        (userSnap.data()?['walletBalance'] as num?)?.toDouble() ?? 0;
    if (amount > balance) {
      throw Exception('Số dư app không đủ để rút');
    }

    final source = await _findDepositSource(userId, amount);
    if (source == null) {
      throw Exception(
        'Không đủ giao dịch nạp MoMo để hoàn tiền ($amount đ). '
        'Chỉ rút được trong số tiền đã nạp qua MoMo Test (0917003000).',
      );
    }

    final momoTransId = await _resolveMomoTransId(source);
    if (momoTransId == null || momoTransId.isEmpty) {
      throw Exception(
        'Giao dịch nạp thiếu mã MoMo (transId). Hãy nạp lại qua MoMo rồi thử rút.',
      );
    }

    final ids = MomoConfig.newOrderIds();
    final withdrawOrderId = ids.orderId;
    final refundIds = MomoConfig.newOrderIds();
    final txRef = _firestore.collection('walletTransactions').doc();
    final desc = note.isEmpty
        ? 'Rút tiền — hoàn về ví MoMo đã nạp'
        : 'Rút MoMo — $note';

    await txRef.set({
      'userId': userId,
      'type': 'withdrawal',
      'amount': amount.toDouble(),
      'description': desc,
      'status': 'pending',
      'paymentMethod': 'momo',
      'orderId': withdrawOrderId,
      'requestId': ids.requestId,
      'refundOrderId': refundIds.orderId,
      'sourceDepositOrderId': source.orderId,
      'balanceBefore': balance,
      'createdAt': FieldValue.serverTimestamp(),
    });

    try {
      final refund = await _momo.refundAndWait(
        refundOrderId: refundIds.orderId,
        requestId: refundIds.requestId,
        amount: amount,
        momoTransId: momoTransId,
        description: desc,
      );

      if (!refund.isSuccess) {
        throw Exception(_friendlyRefundError(refund));
      }

      final batch = _firestore.batch();
      batch.update(source.ref, {
        'refundedAmount': FieldValue.increment(amount.toDouble()),
      });
      batch.update(txRef, {
        'status': 'completed',
        'momoTransId': refund.transId ?? momoTransId,
        'balanceAfter': balance - amount,
        'completedAt': FieldValue.serverTimestamp(),
      });
      batch.set(
        userRef,
        {
          'walletBalance': FieldValue.increment(-amount.toDouble()),
          'totalWithdrawn': FieldValue.increment(amount.toDouble()),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await batch.commit();

      return WalletWithdrawResult(
        orderId: withdrawOrderId,
        amount: amount,
        momoTransId: refund.transId ?? momoTransId,
      );
    } catch (e) {
      await txRef.update({
        'status': 'failed',
        'failReason': e.toString().replaceFirst('Exception: ', ''),
      });
      rethrow;
    }
  }

  Future<_DepositSource?> _findDepositSource(
    String userId,
    int amount,
  ) async {
    final snap = await _firestore
        .collection('walletTransactions')
        .where('userId', isEqualTo: userId)
        .get();

    final deposits = <_DepositSource>[];
    for (final d in snap.docs) {
      final m = d.data();
      if (m['type'] != 'deposit' ||
          m['status'] != 'completed' ||
          m['paymentMethod'] != 'momo') {
        continue;
      }
      final total = (m['amount'] as num?)?.toDouble() ?? 0;
      final refunded = (m['refundedAmount'] as num?)?.toDouble() ?? 0;
      final refundable = total - refunded;
      if (refundable < amount) continue;

      deposits.add(_DepositSource(
        ref: d.reference,
        orderId: m['orderId'] as String? ?? '',
        requestId: m['requestId'] as String?,
        momoTransId: m['momoTransId'] as String?,
        refundable: refundable,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      ));
    }

    deposits.sort(
      (a, b) => _ts(a.createdAt).compareTo(_ts(b.createdAt)),
    );
    return deposits.isEmpty ? null : deposits.first;
  }

  Future<String?> _resolveMomoTransId(_DepositSource source) async {
    if (source.momoTransId != null && source.momoTransId!.isNotEmpty) {
      return source.momoTransId;
    }
    if (source.orderId.isEmpty) return null;

    final query = await _momo.queryPayment(orderId: source.orderId);
    if (!query.isPaid || query.transId == null) return null;

    await source.ref.update({'momoTransId': query.transId});
    return query.transId;
  }

  static String _friendlyRefundError(MomoRefundResult r) {
    switch (r.resultCode) {
      case 1002:
        return 'Giao dịch nạp chưa đủ điều kiện hoàn tiền trên MoMo.';
      case 1003:
        return 'Số tiền hoàn vượt số đã thanh toán.';
      case 41:
        return 'Mã hoàn tiền trùng — thử lại sau vài giây.';
      default:
        return '${r.message} (mã ${r.resultCode})';
    }
  }

  static int _ts(DateTime? d) => d?.millisecondsSinceEpoch ?? 0;
}

class _DepositSource {
  final DocumentReference<Map<String, dynamic>> ref;
  final String orderId;
  final String? requestId;
  final String? momoTransId;
  final double refundable;
  final DateTime? createdAt;

  _DepositSource({
    required this.ref,
    required this.orderId,
    this.requestId,
    this.momoTransId,
    required this.refundable,
    this.createdAt,
  });
}
