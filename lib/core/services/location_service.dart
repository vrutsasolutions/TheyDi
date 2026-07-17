import 'dart:math';
import 'package:geolocator/geolocator.dart';

class LocationService {
  LocationService._();

  static Position? _cachedPosition;

  /// Get user's current GPS position (with permission handling)
  static Future<Position?> getCurrentPosition() async {
    if (_cachedPosition != null) return _cachedPosition;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      _cachedPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      return _cachedPosition;
    } catch (e) {
      return null;
    }
  }

  /// Clear cached position (call when user changes city)
  static void clearCache() {
    _cachedPosition = null;
  }

  /// Calculate distance between two points in kilometers
  /// Uses the Haversine formula
  static double calculateDistanceKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    if (lat1 == 0 && lon1 == 0) return -1; // No user location
    if (lat2 == 0 && lon2 == 0) return -1; // No event location

    const double earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degree) {
    return degree * pi / 180;
  }

  /// Format distance for display
  static String formatDistance(double km) {
    if (km < 0) return '';
    if (km < 1) return '${(km * 1000).round()} m away';
    if (km < 10) return '${km.toStringAsFixed(1)} km away';
    return '${km.round()} km away';
  }

  /// Predefined radius options
  static const List<Map<String, dynamic>> radiusOptions = [
    {'label': '2 km', 'value': 2.0},
    {'label': '5 km', 'value': 5.0},
    {'label': '10 km', 'value': 10.0},
    {'label': '20 km', 'value': 20.0},
    {'label': '50 km', 'value': 50.0},
    {'label': 'Entire City', 'value': -1.0},
  ];
}
