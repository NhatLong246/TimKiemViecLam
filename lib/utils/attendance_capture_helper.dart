import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

/// Metadata gắn với ảnh điểm danh (giờ, vị trí, tên file).
class AttendanceCaptureMeta {
  final String fileName;
  final String capturedAt;
  final String locationLabel;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;

  const AttendanceCaptureMeta({
    required this.fileName,
    required this.capturedAt,
    required this.locationLabel,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
  });

  Map<String, dynamic> toMap() => {
        'fileName': fileName,
        'capturedAt': capturedAt,
        'locationLabel': locationLabel,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
      };
}

class AttendanceCaptureHelper {
  /// Lấy vị trí + tạo tên file chuẩn trước khi gửi ảnh điểm danh.
  static Future<AttendanceCaptureMeta> buildMeta({
    required String candidateId,
    required bool isCheckIn,
    String? imagePath,
  }) async {
    final now = DateTime.now();
    final capturedAt = DateFormat('dd/MM/yyyy HH:mm:ss').format(now);
    final phase = isCheckIn ? 'dau_ca' : 'cuoi_ca';
    final shortId = candidateId.length > 8
        ? candidateId.substring(0, 8)
        : candidateId;
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(now);
    final ext = _extensionFromPath(imagePath);
    final fileName = 'diemdanh_${phase}_${shortId}_$stamp$ext';

    final loc = await _resolveLocation();

    return AttendanceCaptureMeta(
      fileName: fileName,
      capturedAt: capturedAt,
      locationLabel: loc.label,
      latitude: loc.lat,
      longitude: loc.lng,
      accuracyMeters: loc.accuracy,
    );
  }

  static String _extensionFromPath(String? path) {
    if (path == null || path.isEmpty) return '.jpg';
    final i = path.lastIndexOf('.');
    if (i < 0) return '.jpg';
    final ext = path.substring(i).toLowerCase();
    if (ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.webp') {
      return ext;
    }
    return '.jpg';
  }

  static Future<({String label, double? lat, double? lng, double? accuracy})>
      _resolveLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return (
          label: 'GPS tắt — không có vị trí',
          lat: null,
          lng: null,
          accuracy: null,
        );
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return (
          label: 'Chưa cấp quyền vị trí',
          lat: null,
          lng: null,
          accuracy: null,
        );
      }

      Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        ).timeout(const Duration(seconds: 20));
      } on TimeoutException {
        final last = await Geolocator.getLastKnownPosition();
        if (last == null) {
          return (
            label: 'Không xác định được vị trí',
            lat: null,
            lng: null,
            accuracy: null,
          );
        }
        pos = last;
      }

      final lat = pos.latitude;
      final lng = pos.longitude;
      final acc = pos.accuracy;
      final label = StringBuffer()
        ..write('${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}');
      if (acc > 0) {
        label.write(' (±${acc.round()}m)');
      }

      return (label: label.toString(), lat: lat, lng: lng, accuracy: acc);
    } catch (_) {
      return (
        label: 'Không lấy được vị trí',
        lat: null,
        lng: null,
        accuracy: null,
      );
    }
  }
}
