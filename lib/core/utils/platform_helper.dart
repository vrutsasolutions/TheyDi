// lib/core/utils/platform_helper.dart
//
// Conditional imports — Flutter picks the right file at compile time:
//   dart.library.html  → web (Chrome/browser)
//   dart.library.io    → mobile/desktop
//
// This file is the ONLY one imported by chat screens.

import 'package:flutter/foundation.dart' show kIsWeb;

import 'platform_helper_stub.dart'
    if (dart.library.html) 'platform_helper_web.dart'
    if (dart.library.io) 'platform_helper_io.dart';

/// Temp directory path — empty string on web (not needed).
Future<String> getTempDirPath() async {
  if (kIsWeb) return '';
  return getNativeTempDir();
}

/// Read file bytes from a local path (mobile/desktop only).
Future<List<int>> getFileBytes(String path) async {
  if (kIsWeb) return [];
  return readFileBytes(path);
}

/// Fetch bytes from a blob: URL (web only via dart:html).
/// On mobile this returns empty — blob URLs don't exist on mobile.
Future<List<int>> getBlobBytes(String blobUrl) async {
  if (!kIsWeb) return [];
  return fetchBlobBytes(blobUrl);
}

/// Guesses the visitor's mobile OS from the browser (web only), so a
/// shared-link guest can be routed to the right app store. Returns
/// 'android', 'ios', or null (desktop web, or native app builds).
String? detectMobileOs() {
  if (!kIsWeb) return null;
  return detectMobileOsNative();
}