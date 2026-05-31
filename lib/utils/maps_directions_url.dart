/// URL Google Maps chỉ đường (mở trong WebView trong app).
class MapsDirectionsUrl {
  MapsDirectionsUrl._();

  static String build({
    required String destinationLabel,
    double? destinationLat,
    double? destinationLng,
    double? originLat,
    double? originLng,
    String travelMode = 'driving',
  }) {
    final params = <String, String>{
      'api': '1',
      'travelmode': travelMode,
    };

    if (originLat != null && originLng != null) {
      params['origin'] = '$originLat,$originLng';
    }

    // Ưu tiên tên địa điểm (quận/thành phố) — tránh geocode lệch từ tọa độ 0,0.
    final label = destinationLabel.trim();
    if (label.isNotEmpty) {
      params['destination'] = label;
    } else if (_validCoord(destinationLat, destinationLng)) {
      params['destination'] = '$destinationLat,$destinationLng';
    }

    return Uri.https('www.google.com', '/maps/dir/', params).toString();
  }

  /// Mở app Google Maps (native) — ổn định hơn WebView trên Android.
  static String buildExternalLaunchUrl({
    required String destinationLabel,
    double? destinationLat,
    double? destinationLng,
    double? originLat,
    double? originLng,
  }) {
    return build(
      destinationLabel: destinationLabel,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      originLat: originLat,
      originLng: originLng,
    );
  }

  /// Android Maps mobile redirect → `intent://…` — WebView không mở được.
  /// Trả về URL https fallback nếu parse được.
  static String? httpsFromIntentUrl(String url) {
    if (!url.startsWith('intent:')) return null;

    final fallbackMatch = RegExp(
      r'S\.browser_fallback_url=([^;\s]+)',
      caseSensitive: false,
    ).firstMatch(url);
    if (fallbackMatch != null) {
      return Uri.decodeComponent(fallbackMatch.group(1)!);
    }

    if (url.startsWith('intent://')) {
      final body = url.substring('intent://'.length);
      final intentIdx = body.indexOf('#Intent');
      final path = intentIdx > 0 ? body.substring(0, intentIdx) : body;
      if (path.isNotEmpty) return 'https://$path';
    }
    return null;
  }

  static bool _validCoord(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat.abs() < 1e-6 && lng.abs() < 1e-6) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }
}
