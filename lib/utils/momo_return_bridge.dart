/// Callback khi MoMo redirect về app (`viecnow://momo-return`).
class MomoReturnBridge {
  MomoReturnBridge._();

  static void Function(String orderId)? onMomoReturn;

  static bool handlesUri(Uri uri) =>
      uri.scheme == 'viecnow' && uri.host == 'momo-return';

  static void dispatch(Uri uri) {
    if (!handlesUri(uri)) return;
    final orderId = uri.queryParameters['orderId'];
    if (orderId != null && orderId.isNotEmpty) {
      onMomoReturn?.call(orderId);
    } else {
      onMomoReturn?.call('');
    }
  }
}
