import 'package:url_launcher/url_launcher.dart';

/// Mở app MoMo / MoMo Test qua deeplink `momo://` (không dùng WebView).
class MomoAppLauncher {
  MomoAppLauncher._();

  static const sandboxDownloadUrl =
      'https://test-payment.momo.vn/download';

  static bool isMomoScheme(String url) =>
      url.startsWith('momo://') || url.startsWith('momo:');

  /// Trả về `true` nếu đã gửi intent mở app.
  static Future<bool> openSandboxApp(String deeplink) async {
    final uri = Uri.parse(deeplink);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
