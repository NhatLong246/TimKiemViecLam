import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:viecnow/data/models/job_post_model.dart';
import 'package:viecnow/utils/location_helper.dart';
import 'package:viecnow/utils/maps_directions_url.dart';

/// Google Maps trong app — chỉ đường từ vị trí hiện tại đến nơi làm việc.
class JobDirectionsMapScreen extends StatefulWidget {
  final JobPostModel job;

  const JobDirectionsMapScreen({super.key, required this.job});

  @override
  State<JobDirectionsMapScreen> createState() => _JobDirectionsMapScreenState();
}

class _JobDirectionsMapScreenState extends State<JobDirectionsMapScreen> {
  static const _primary = Color(0xFF2E7D32);

  WebViewController? _webCtrl;
  bool _pageLoaded = false;
  bool _resolvingGps = true;
  String? _gpsHint;

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  Future<void> _initMap() async {
    setState(() {
      _resolvingGps = true;
      _pageLoaded = false;
    });

    Position? raw;
    if (mounted) {
      raw = await LocationHelper.getCurrentPosition(context);
    }
    final origin = LocationHelper.originForDirections(raw, widget.job);

    final url = MapsDirectionsUrl.build(
      destinationLabel: widget.job.mapsDestinationQuery,
      destinationLat: widget.job.locationLat,
      destinationLng: widget.job.locationLng,
      originLat: origin?.latitude,
      originLng: origin?.longitude,
    );

    if (!mounted) return;

    final ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
          onPageFinished: (_) {
            if (mounted) setState(() => _pageLoaded = true);
          },
        ),
      );

    if (!kIsWeb && ctrl.platform is AndroidWebViewController) {
      final android = ctrl.platform as AndroidWebViewController;
      await android.setMediaPlaybackRequiresUserGesture(false);
      await android.setUserAgent(
        'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      );
      await android.setGeolocationPermissionsPromptCallbacks(
        onShowPrompt: (_) async =>
            const GeolocationPermissionsResponse(allow: true, retain: true),
      );
    }

    await ctrl.loadRequest(Uri.parse(url));

    if (!mounted) return;
    setState(() {
      _resolvingGps = false;
      _gpsHint = _buildGpsHint(raw: raw, origin: origin);
      _webCtrl = ctrl;
    });
  }

  String? _buildGpsHint({required Position? raw, required Position? origin}) {
    if (origin != null) return null;
    if (raw != null && LocationHelper.isLikelyEmulatorFakeGps(raw)) {
      return 'Máy ảo đang dùng GPS mặc định (Mỹ). '
          'Extended Controls → Location → đặt TP.HCM, hoặc bấm "Mở Google Maps" bên dưới.';
    }
    if (raw != null) {
      return 'Vị trí GPS quá xa điểm làm việc — bản đồ chỉ hiển thị đích. '
          'Chọn "Vị trí của tôi" trên Maps hoặc mở app Google Maps.';
    }
    return 'Chưa lấy được GPS — chọn điểm xuất phát trên bản đồ hoặc mở Google Maps.';
  }

  Future<void> _openExternalMaps() async {
    Position? raw = await LocationHelper.getCurrentPosition(context);
    final origin = LocationHelper.originForDirections(raw, widget.job);
    final url = MapsDirectionsUrl.buildExternalLaunchUrl(
      destinationLabel: widget.job.mapsDestinationQuery,
      destinationLat: widget.job.locationLat,
      destinationLng: widget.job.locationLng,
      originLat: origin?.latitude,
      originLng: origin?.longitude,
    );
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không mở được Google Maps')),
        );
      }
    }
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final url = request.url;

    if (url.startsWith('intent:')) {
      final https = MapsDirectionsUrl.httpsFromIntentUrl(url);
      if (https != null && _webCtrl != null) {
        _webCtrl!.loadRequest(Uri.parse(https));
      }
      return NavigationDecision.prevent;
    }

    if (url.startsWith('geo:') ||
        url.startsWith('google.navigation:') ||
        url.startsWith('market:')) {
      return NavigationDecision.prevent;
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.job.locationDisplay;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chỉ đường',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Mở Google Maps',
            icon: const Icon(Icons.open_in_new),
            onPressed: _openExternalMaps,
          ),
          IconButton(
            tooltip: 'Làm mới vị trí',
            icon: const Icon(Icons.my_location),
            onPressed: _resolvingGps ? null : _initMap,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_gpsHint != null)
            Material(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _gpsHint!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _openExternalMaps,
                icon: const Icon(Icons.map, size: 20),
                label: const Text('Mở trong Google Maps'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                if (_webCtrl != null)
                  WebViewWidget(controller: _webCtrl!)
                else
                  const SizedBox.shrink(),
                if (_resolvingGps || !_pageLoaded)
                  Container(
                    color: Colors.white,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: _primary),
                        const SizedBox(height: 16),
                        Text(
                          _resolvingGps
                              ? 'Đang xác định vị trí của bạn...'
                              : 'Đang tải bản đồ...',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
