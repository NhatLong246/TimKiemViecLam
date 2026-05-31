import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Chữ ký HMAC SHA256 — giống [momo-wallet/payment nodejs/MoMo.js](https://github.com/momo-wallet/payment/blob/master/nodejs/MoMo.js).
class MomoSignature {
  MomoSignature._();

  /// Create payment — thứ tự field theo comment trong MoMo.js:
  /// accessKey, amount, extraData, ipnUrl, orderId, orderInfo, partnerCode,
  /// redirectUrl, requestId, requestType
  static String createPaymentRaw({
    required String accessKey,
    required String amount,
    required String extraData,
    required String ipnUrl,
    required String orderId,
    required String orderInfo,
    required String partnerCode,
    required String redirectUrl,
    required String requestId,
    required String requestType,
  }) {
    return 'accessKey=$accessKey'
        '&amount=$amount'
        '&extraData=$extraData'
        '&ipnUrl=$ipnUrl'
        '&orderId=$orderId'
        '&orderInfo=$orderInfo'
        '&partnerCode=$partnerCode'
        '&redirectUrl=$redirectUrl'
        '&requestId=$requestId'
        '&requestType=$requestType';
  }

  /// Query — [php/atm/query_transaction.php](https://github.com/momo-wallet/payment/blob/master/php/atm/query_transaction.php)
  static String queryPaymentRaw({
    required String accessKey,
    required String orderId,
    required String partnerCode,
    required String requestId,
  }) {
    return 'accessKey=$accessKey'
        '&orderId=$orderId'
        '&partnerCode=$partnerCode'
        '&requestId=$requestId';
  }

  /// Refund — developers.momo.vn payment-api/refund
  static String refundRaw({
    required String accessKey,
    required String amount,
    required String description,
    required String orderId,
    required String partnerCode,
    required String requestId,
    required String transId,
  }) {
    return 'accessKey=$accessKey'
        '&amount=$amount'
        '&description=$description'
        '&orderId=$orderId'
        '&partnerCode=$partnerCode'
        '&requestId=$requestId'
        '&transId=$transId';
  }

  /// Refund query — cùng format chữ ký với payment query.
  static String refundQueryRaw({
    required String accessKey,
    required String orderId,
    required String partnerCode,
    required String requestId,
  }) =>
      queryPaymentRaw(
        accessKey: accessKey,
        orderId: orderId,
        partnerCode: partnerCode,
        requestId: requestId,
      );

  static String hmacSha256(String secretKey, String raw) {
    return Hmac(sha256, utf8.encode(secretKey))
        .convert(utf8.encode(raw))
        .toString();
  }
}
