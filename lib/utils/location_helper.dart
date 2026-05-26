import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:viecnow/data/models/job_post_model.dart';

/// Lấy vị trí GPS hiện tại (dùng cho chỉ đường, chat, …).
class LocationHelper {
  LocationHelper._();

  /// GPS mặc định của Android Emulator (Googleplex, Mỹ).
  static bool isLikelyEmulatorFakeGps(Position p) {
    const lat = 37.4219983;
    const lng = -122.084;
    return (p.latitude - lat).abs() < 0.02 && (p.longitude - lng).abs() < 0.02;
  }

  static bool isInVietnam(double lat, double lng) =>
      lat >= 8.0 && lat <= 24.0 && lng >= 102.0 && lng <= 110.0;

  static double _distanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _deg2rad(double d) => d * math.pi / 180.0;

  /// Bỏ tọa độ sai (emulator Mỹ, quá xa điểm làm việc ở VN).
  static Position? originForDirections(Position? pos, JobPostModel job) {
    if (pos == null) return null;
    if (isLikelyEmulatorFakeGps(pos)) return null;

    if (job.hasMapCoordinates) {
      final dLat = job.locationLat!;
      final dLng = job.locationLng!;
      if (isInVietnam(dLat, dLng) && !isInVietnam(pos.latitude, pos.longitude)) {
        return null;
      }
      if (_distanceKm(pos.latitude, pos.longitude, dLat, dLng) > 500) {
        return null;
      }
      return pos;
    }

    final q = job.mapsDestinationQuery.toLowerCase();
    final looksVn = q.contains('hcm') ||
        q.contains('hồ chí minh') ||
        q.contains('ho chi minh') ||
        q.contains('việt nam') ||
        q.contains('vietnam') ||
        q.contains('thủ đức') ||
        q.contains('thu duc');
    if (looksVn && !isInVietnam(pos.latitude, pos.longitude)) return null;

    return pos;
  }

  static Future<Position?> getCurrentPosition(BuildContext context) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng bật GPS để xem chỉ đường từ vị trí của bạn'),
          ),
        );
      }
      return null;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Cần quyền vị trí để chỉ đường. Vào Cài đặt → Ứng dụng để cấp.',
            ),
            action: SnackBarAction(
              label: 'Cài đặt',
              onPressed: Geolocator.openAppSettings,
            ),
          ),
        );
      }
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      ).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      return Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }
}
