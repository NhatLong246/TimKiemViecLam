import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viecnow/config/momo_config.dart';
import 'package:viecnow/data/services/momo_payment_service.dart';

/// Nạp tiền ví employer qua MoMo.
class WalletDepositService {
  final _firestore = FirebaseFirestore.instance;
  final _momo = MomoPaymentService();

  /// Tạo giao dịch pending + yêu cầu thanh toán MoMo.
  Future<MomoCreateResult> startMomoDeposit({
    required String userId,
    required int amount,
    String note = '',
  }) async {
    if (amount < 10000) {
      throw Exception('Số tiền tối thiểu 10.000đ');
    }

    final ids = MomoConfig.newOrderIds();
    final orderId = ids.orderId;
    final requestId = ids.requestId;
    final orderInfo =
        note.isEmpty ? 'pay with MoMo' : 'pay with MoMo - $note';

    final txRef = _firestore.collection('walletTransactions').doc();
    await txRef.set({
      'userId': userId,
      'type': 'deposit',
      'amount': amount.toDouble(),
      'description':
          note.isEmpty ? 'Nạp tiền qua MoMo' : 'Nạp tiền qua MoMo — $note',
      'status': 'pending',
      'paymentMethod': 'momo',
      'orderId': orderId,
      'requestId': requestId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final momo = await _momo.createPayment(
      orderId: orderId,
      requestId: requestId,
      amount: amount,
      orderInfo: orderInfo,
      extraData: '',
      redirectUrl: MomoConfig.returnRedirectUrl(orderId),
    );

    await txRef.update({'payUrl': momo.payUrl});

    return momo;
  }

  /// Kiểm tra MoMo (có retry) và cộng ví khi thanh toán thành công.
  Future<bool> confirmMomoDeposit({
    required String userId,
    required String orderId,
    required String requestId,
    required int amount,
    int maxAttempts = 10,
  }) async {
    MomoQueryResult? lastQuery;
    for (var i = 0; i < maxAttempts; i++) {
      lastQuery = await _momo.queryPayment(orderId: orderId);
      if (lastQuery.isPaid) break;
      if (i < maxAttempts - 1) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    final query = lastQuery!;
    if (!query.isPaid) {
      throw Exception(
        '${query.message} (Mã ${query.resultCode}). '
        'Hãy đảm bảo đã thanh toán xong trên app MoMo Test.',
      );
    }

    final txSnap = await _firestore
        .collection('walletTransactions')
        .where('orderId', isEqualTo: orderId)
        .limit(1)
        .get();

    if (txSnap.docs.isEmpty) {
      throw Exception('Không tìm thấy giao dịch nạp tiền');
    }

    final txDoc = txSnap.docs.first;
    final txData = txDoc.data();
    if (txData['userId'] != userId) {
      throw Exception('Giao dịch không thuộc tài khoản hiện tại');
    }

    if (txData['status'] == 'completed') {
      return true;
    }

    final creditAmount = (txData['amount'] as num?)?.toDouble() ?? amount.toDouble();

    final batch = _firestore.batch();
    batch.update(txDoc.reference, {
      'status': 'completed',
      'momoTransId': query.transId,
      'completedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _firestore.collection('users').doc(userId),
      {
        'walletBalance': FieldValue.increment(creditAmount),
        'totalDeposited': FieldValue.increment(creditAmount),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
    return true;
  }

  Future<void> markDepositFailed(String orderId, String userId) async {
    final txSnap = await _firestore
        .collection('walletTransactions')
        .where('orderId', isEqualTo: orderId)
        .limit(1)
        .get();
    if (txSnap.docs.isEmpty) return;
    final data = txSnap.docs.first.data();
    if (data['userId'] != userId) return;
    if (data['status'] == 'pending') {
      await txSnap.docs.first.reference.update({'status': 'failed'});
    }
  }
}
