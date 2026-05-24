import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:viecnow/config/momo_config.dart';
import 'package:viecnow/data/momo/momo_signature.dart';

class MomoCreateResult {
  final String orderId;
  final String requestId;
  final String payUrl;
  final String? deeplink;
  final String? qrCodeUrl;
  final int? resultCode;
  final String? message;

  const MomoCreateResult({
    required this.orderId,
    required this.requestId,
    required this.payUrl,
    this.deeplink,
    this.qrCodeUrl,
    this.resultCode,
    this.message,
  });

  bool get isSuccess => payUrl.isNotEmpty;
}

class MomoQueryResult {
  final int resultCode;
  final String message;
  final String? transId;

  const MomoQueryResult({
    required this.resultCode,
    required this.message,
    this.transId,
  });

  bool get isPaid => resultCode == 0;
}

/// REST MoMo v2 — port từ [momo-wallet/payment nodejs/MoMo.js](https://github.com/momo-wallet/payment/blob/master/nodejs/MoMo.js).
class MomoPaymentService {
  Future<MomoCreateResult> createPayment({
    required String orderId,
    required String requestId,
    required int amount,
    String orderInfo = 'pay with MoMo',
    String extraData = '',
    required String redirectUrl,
  }) async {
    if (!MomoConfig.isConfigured) {
      throw Exception('MoMo chưa được cấu hình (${MomoConfig.githubSample})');
    }

    final amountStr = amount.toString();
    final raw = MomoSignature.createPaymentRaw(
      accessKey: MomoConfig.accessKey,
      amount: amountStr,
      extraData: extraData,
      ipnUrl: MomoConfig.ipnUrl,
      orderId: orderId,
      orderInfo: orderInfo,
      partnerCode: MomoConfig.partnerCode,
      redirectUrl: redirectUrl,
      requestId: requestId,
      requestType: MomoConfig.requestType,
    );
    final signature =
        MomoSignature.hmacSha256(MomoConfig.secretKey, raw);

    final body = {
      'partnerCode': MomoConfig.partnerCode,
      'accessKey': MomoConfig.accessKey,
      'requestId': requestId,
      'amount': amountStr,
      'orderId': orderId,
      'orderInfo': orderInfo,
      'redirectUrl': redirectUrl,
      'ipnUrl': MomoConfig.ipnUrl,
      'extraData': extraData,
      'requestType': MomoConfig.requestType,
      'signature': signature,
      'lang': MomoConfig.lang,
    };

    final response = await http.post(
      Uri.parse(MomoConfig.createEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final resultCode = data['resultCode'] as int?;
    final message = data['message'] as String? ?? 'Không tạo được thanh toán';
    final payUrl = data['payUrl'] as String? ?? '';

    if (resultCode != 0 || payUrl.isEmpty) {
      throw Exception(message);
    }

    return MomoCreateResult(
      orderId: orderId,
      requestId: requestId,
      payUrl: payUrl,
      deeplink: data['deeplink'] as String?,
      qrCodeUrl: data['qrCodeUrl'] as String?,
      resultCode: resultCode,
      message: message,
    );
  }

  /// [orderId] mã đơn khi tạo thanh toán; [requestId] mới mỗi lần query (theo sample PHP).
  Future<MomoQueryResult> queryPayment({
    required String orderId,
    String? requestId,
  }) async {
    final queryRequestId =
        requestId ?? '${DateTime.now().millisecondsSinceEpoch}';
    final raw = MomoSignature.queryPaymentRaw(
      accessKey: MomoConfig.accessKey,
      orderId: orderId,
      partnerCode: MomoConfig.partnerCode,
      requestId: queryRequestId,
    );
    final signature =
        MomoSignature.hmacSha256(MomoConfig.secretKey, raw);

    final body = {
      'partnerCode': MomoConfig.partnerCode,
      'requestId': queryRequestId,
      'orderId': orderId,
      'requestType': MomoConfig.requestType,
      'signature': signature,
      'lang': MomoConfig.lang,
    };

    final response = await http.post(
      Uri.parse(MomoConfig.queryEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final code = data['resultCode'] ?? data['errorCode'];
    return MomoQueryResult(
      resultCode: code is int ? code : int.tryParse('$code') ?? -1,
      message: data['message'] as String? ??
          data['localMessage'] as String? ??
          'Không xác định',
      transId: data['transId']?.toString(),
    );
  }

  /// Hoàn tiền về ví MoMo đã thanh toán khi nạp (refund).
  Future<MomoRefundResult> refundPayment({
    required String refundOrderId,
    required String requestId,
    required int amount,
    required String momoTransId,
    String description = 'Rut tien ve MoMo ViecNow',
  }) async {
    final amountStr = amount.toString();
    final raw = MomoSignature.refundRaw(
      accessKey: MomoConfig.accessKey,
      amount: amountStr,
      description: description,
      orderId: refundOrderId,
      partnerCode: MomoConfig.partnerCode,
      requestId: requestId,
      transId: momoTransId,
    );
    final signature =
        MomoSignature.hmacSha256(MomoConfig.secretKey, raw);

    final body = {
      'partnerCode': MomoConfig.partnerCode,
      'orderId': refundOrderId,
      'requestId': requestId,
      'amount': amount,
      'transId': int.tryParse(momoTransId) ?? momoTransId,
      'lang': 'vi',
      'description': description,
      'signature': signature,
    };

    final client = http.Client();
    try {
      final response = await client
          .post(
            Uri.parse(MomoConfig.refundEndpoint),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 35));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final code = data['resultCode'] ?? data['errorCode'];
      return MomoRefundResult(
        resultCode: code is int ? code : int.tryParse('$code') ?? -1,
        message: data['message'] as String? ?? 'Không xác định',
        transId: data['transId']?.toString(),
        orderId: refundOrderId,
      );
    } finally {
      client.close();
    }
  }

  /// Kiểm tra kết quả hoàn tiền (dùng [refundOrderId] khi gọi refund).
  Future<MomoRefundResult> queryRefund({
    required String refundOrderId,
    String? requestId,
  }) async {
    final queryRequestId =
        requestId ?? '${DateTime.now().millisecondsSinceEpoch}';
    final raw = MomoSignature.refundQueryRaw(
      accessKey: MomoConfig.accessKey,
      orderId: refundOrderId,
      partnerCode: MomoConfig.partnerCode,
      requestId: queryRequestId,
    );
    final signature =
        MomoSignature.hmacSha256(MomoConfig.secretKey, raw);

    final response = await http.post(
      Uri.parse(MomoConfig.refundQueryEndpoint),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'partnerCode': MomoConfig.partnerCode,
        'orderId': refundOrderId,
        'requestId': queryRequestId,
        'lang': 'vi',
        'signature': signature,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final code = data['resultCode'] ?? data['errorCode'];
    return MomoRefundResult(
      resultCode: code is int ? code : int.tryParse('$code') ?? -1,
      message: data['message'] as String? ?? 'Không xác định',
      transId: data['transId']?.toString(),
      orderId: refundOrderId,
    );
  }

  Future<MomoRefundResult> refundAndWait({
    required String refundOrderId,
    required String requestId,
    required int amount,
    required String momoTransId,
    String description = 'Rut tien ve MoMo ViecNow',
    int maxAttempts = 8,
  }) async {
    var result = await refundPayment(
      refundOrderId: refundOrderId,
      requestId: requestId,
      amount: amount,
      momoTransId: momoTransId,
      description: description,
    );
    if (result.isSuccess) return result;

    if (!result.isPending) return result;

    for (var i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(seconds: 2));
      result = await queryRefund(refundOrderId: refundOrderId);
      if (result.isSuccess || !result.isPending) break;
    }
    return result;
  }
}

class MomoRefundResult {
  final int resultCode;
  final String message;
  final String? transId;
  final String orderId;

  const MomoRefundResult({
    required this.resultCode,
    required this.message,
    this.transId,
    required this.orderId,
  });

  bool get isSuccess => resultCode == 0;
  bool get isPending => resultCode == 7000 || resultCode == 7002;
}
