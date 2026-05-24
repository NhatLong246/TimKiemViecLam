/// Cấu hình MoMo — theo repo chính thức [momo-wallet/payment](https://github.com/momo-wallet/payment).
///
/// Mặc định dùng key trong [nodejs/MoMo.js](https://github.com/momo-wallet/payment/blob/master/nodejs/MoMo.js)
/// (sandbox `test-payment.momo.vn`, đã kiểm tra resultCode = 0).
///
/// Khi go-live: đăng ký https://business.momo.vn/ hoặc https://test-business.momo.vn/
/// và thay partnerCode / accessKey / secretKey bằng key của merchant.
class MomoConfig {
  MomoConfig._();

  static const bool enabled = true;

  /// Sample [nodejs/MoMo.js](https://github.com/momo-wallet/payment/blob/master/nodejs/MoMo.js)
  static const String partnerCode = 'MOMO';
  static const String accessKey = 'F8BBA842ECF85';
  static const String secretKey = 'K951B6PE1waDMi640xX08PD3vg6EkVlz';

  static const String createEndpoint =
      'https://test-payment.momo.vn/v2/gateway/api/create';
  static const String queryEndpoint =
      'https://test-payment.momo.vn/v2/gateway/api/query';

  static const String refundEndpoint =
      'https://test-payment.momo.vn/v2/gateway/api/refund';

  static const String refundQueryEndpoint =
      'https://test-payment.momo.vn/v2/gateway/api/refund/query';

  /// IPN server (production cần HTTPS thật).
  static const String ipnUrl = 'https://callback.url/notify';

  /// Deep link quay lại app sau thanh toán (đăng ký scheme `viecnow` trên Android/iOS).
  static String returnRedirectUrl(String orderId) =>
      'viecnow://momo-return?orderId=$orderId';

  static const String requestType = 'captureWallet';
  static const String lang = 'en';

  static bool get isConfigured =>
      enabled &&
      partnerCode.isNotEmpty &&
      accessKey.isNotEmpty &&
      secretKey.isNotEmpty;

  /// `var orderId = requestId = partnerCode + timestamp` — MoMo.js
  static ({String orderId, String requestId}) newOrderIds() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final id = '$partnerCode$ts';
    return (orderId: id, requestId: id);
  }

  static const String githubSample =
      'https://github.com/momo-wallet/payment/blob/master/nodejs/MoMo.js';
}
