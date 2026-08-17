import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/location_constants.dart';

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
  static List<Map<String, dynamic>> get radiusOptions =>
      LocationConstants.radiusOptions;

  // ------------------------------------------------------------
  // Server-side "nearby event" notification support.
  //
  // Everything above this point is for client-side display (the
  // "browse events within X km" filter, distance labels, etc).
  // Everything below syncs the user's location to Firestore as flat
  // latitude/longitude fields so a Cloud Function can find nearby
  // users server-side when a new event is created and push them a
  // notification. These are separate concerns and can be used
  // independently.
  //
  // There is no separate in-app opt-in toggle for this — the OS/
  // browser location permission itself is the only gate. The first
  // time a user logs in, requestLocationOnce() triggers that OS
  // permission prompt automatically; after that, syncLocationToFirestore()
  // just tries to read the position directly and silently does
  // nothing if permission was ever denied.
  // ------------------------------------------------------------

  /// Fetches current position and saves it to the user's Firestore
  /// doc as flat latitude/longitude fields — this matches what
  /// notifyNearbyUsersAboutEvent (Cloud Function) reads when it
  /// scans users on every new event. Keep the field names in sync
  /// with that function if you ever rename them on either side.
  ///
  /// Returns false (and saves nothing) if there's no logged-in user
  /// or if a position couldn't be obtained — most commonly because
  /// the OS/browser location permission was denied.
  static Future<bool> syncLocationToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('LOCATION DEBUG: No logged-in user, cannot sync');
      return false;
    }

    print('LOCATION DEBUG: Fetching position...');
    final position = await getCurrentPosition();
    if (position == null) {
      print(
          'LOCATION DEBUG ERROR: getCurrentPosition() returned null (permission denied or service disabled)');
      return false;
    }
    print(
        'LOCATION DEBUG: Position obtained: ${position.latitude}, ${position.longitude}');

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'locationUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      print('LOCATION DEBUG: Saved successfully to users/${user.uid}');
      return true;
    } catch (e) {
      print('LOCATION DEBUG ERROR: Firestore write failed: $e');
      return false;
    }
  }

  /// Call once, right after a user logs in. Requests location (which
  /// triggers the OS/browser permission popup automatically the very
  /// first time) only if this user has never had a latitude saved
  /// before — so it never re-prompts on every login, and never
  /// overrides whatever the OS permission state already is.
  static Future<void> requestLocationOnce() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final alreadyHasLocation = doc.data()?.containsKey('latitude') ?? false;

    if (alreadyHasLocation) {
      print(
          'LOCATION DEBUG: Already have a saved location, skipping first-run request');
      return;
    }

    await syncLocationToFirestore();
  }
}
