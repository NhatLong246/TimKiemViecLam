import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:viecnow/data/services/wallet_deposit_service.dart';
import 'package:viecnow/utils/momo_app_launcher.dart';
import 'package:viecnow/utils/momo_return_bridge.dart';

/// Thanh toán MoMo sandbox — quay lại app tự xác nhận sau khi thanh toán.
class MomoCheckoutScreen extends StatefulWidget {
  final String payUrl;
  final String? deeplink;
  final String orderId;
  final String requestId;
  final int amount;
  final String userId;

  const MomoCheckoutScreen({
    super.key,
    required this.payUrl,
    this.deeplink,
    required this.orderId,
    required this.requestId,
    required this.amount,
    required this.userId,
  });

  @override
  State<MomoCheckoutScreen> createState() => _MomoCheckoutScreenState();
}

class _MomoCheckoutScreenState extends State<MomoCheckoutScreen>
    with WidgetsBindingObserver {
  final _deposit = WalletDepositService();
  WebViewController? _webCtrl;
  bool _checking = false;
  bool _loaded = false;
  bool _openedApp = false;
  bool _wentToMomo = false;
  DateTime? _lastAutoCheck;

  static const _momoPink = Color(0xFFA50064);

  bool get _hasDeeplink =>
      widget.deeplink != null && widget.deeplink!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MomoReturnBridge.onMomoReturn = _onMomoReturnLink;

    if (_hasDeeplink) {
      _loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openMomoSandboxApp();
      });
    } else {
      _webCtrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: _onNavigationRequest,
            onPageFinished: (_) {
              if (mounted) setState(() => _loaded = true);
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.payUrl));
    }
  }

  @override
  void dispose() {
    MomoReturnBridge.onMomoReturn = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _wentToMomo) {
      _scheduleAutoConfirm();
    }
  }

  void _onMomoReturnLink(String orderId) {
    if (orderId.isNotEmpty && orderId != widget.orderId) return;
    _scheduleAutoConfirm();
  }

  void _scheduleAutoConfirm() {
    final now = DateTime.now();
    if (_lastAutoCheck != null &&
        now.difference(_lastAutoCheck!) < const Duration(seconds: 2)) {
      return;
    }
    _lastAutoCheck = now;
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _confirmPayment(auto: true);
    });
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final url = request.url;
    if (MomoReturnBridge.handlesUri(Uri.parse(url))) {
      _onMomoReturnLink(Uri.parse(url).queryParameters['orderId'] ?? '');
      return NavigationDecision.prevent;
    }
    if (MomoAppLauncher.isMomoScheme(url)) {
      _openMomoSandboxApp(url: url);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  Future<void> _openMomoSandboxApp({String? url}) async {
    final target = (url ?? widget.deeplink)?.trim();
    if (target == null || target.isEmpty) {
      Get.snackbar(
        'MoMo',
        'Không có liên kết mở app. Tải MoMo Test: ${MomoAppLauncher.sandboxDownloadUrl}',
        duration: const Duration(seconds: 5),
      );
      return;
    }

    try {
      final ok = await MomoAppLauncher.openSandboxApp(target);
      if (!mounted) return;
      setState(() {
        _openedApp = ok;
        if (ok) _wentToMomo = true;
      });
      if (!ok) {
        Get.snackbar(
          'Chưa cài MoMo Test',
          'Tải app sandbox: ${MomoAppLauncher.sandboxDownloadUrl}\n'
          'Đăng nhập SĐT 0917003000, OTP 000000',
          backgroundColor: Colors.orange.shade100,
          duration: const Duration(seconds: 6),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Không mở được MoMo', e.toString());
    }
  }

  Future<void> _openSandboxDownload() async {
    final uri = Uri.parse(MomoAppLauncher.sandboxDownloadUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _confirmPayment({bool auto = false}) async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final ok = await _deposit.confirmMomoDeposit(
        userId: widget.userId,
        orderId: widget.orderId,
        requestId: widget.requestId,
        amount: widget.amount,
      );
      if (!mounted) return;
      if (ok) {
        Get.back(result: true);
      } else if (!auto) {
        Get.snackbar(
          'Chưa thanh toán',
          'Vui lòng hoàn tất trên MoMo Test rồi thử lại',
          backgroundColor: Colors.orange.shade100,
          colorText: Colors.orange.shade900,
        );
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          auto ? 'Chưa cộng được tiền' : 'Chưa thanh toán',
          '${e.toString().replaceFirst('Exception: ', '')}\n'
          'Thử bấm "Kiểm tra thanh toán" sau vài giây.',
          backgroundColor: Colors.orange.shade100,
          colorText: Colors.orange.shade900,
          duration: const Duration(seconds: 5),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Widget _buildDeeplinkPanel() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _momoPink,
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: const Text(
                'MoMo',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _checking
                  ? 'Đang xác nhận thanh toán...'
                  : _openedApp
                      ? 'Đã mở MoMo Test'
                      : 'Thanh toán trên app MoMo Test',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF212121),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Sau khi thanh toán xong, quay lại app này — tiền sẽ được cộng tự động.\n\n'
              'Số tiền: ${widget.amount.toString().replaceAllMapped(
                    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                    (m) => '${m[1]}.',
                  )}đ\n'
              'SĐT test: 0917003000 • OTP: 000000',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF757575),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _openSandboxDownload,
              child: const Text('Chưa có app? Tải MoMo Test'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _momoPink,
        foregroundColor: Colors.white,
        title: const Text(
          'Thanh toán MoMo',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () async {
            await _deposit.markDepositFailed(widget.orderId, widget.userId);
            if (mounted) Get.back(result: false);
          },
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFFCE4EC),
            child: const Text(
              'Thanh toán trên MoMo Test, sau đó quay lại app — hệ thống tự cộng tiền.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF880E4F)),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                if (_hasDeeplink)
                  _buildDeeplinkPanel()
                else if (_webCtrl != null)
                  WebViewWidget(controller: _webCtrl!),
                if (!_loaded)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  if (_hasDeeplink)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _openMomoSandboxApp(),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Mở lại app MoMo Sandbox'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _momoPink,
                            side: const BorderSide(color: _momoPink, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _checking ? null : () => _confirmPayment(),
                      icon: _checking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(
                        _checking ? 'Đang kiểm tra...' : 'Kiểm tra thanh toán',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _momoPink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
