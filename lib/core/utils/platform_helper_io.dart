// lib/core/utils/platform_helper_io.dart
// Mobile/desktop only — dart:io and path_provider are safe here
import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String> getNativeTempDir() async {
  final dir = await getTemporaryDirectory();
  return dir.path;
}

Future<List<int>> readFileBytes(String path) async {
  return File(path).readAsBytes();
}

Future<List<int>> fetchBlobBytes(String blobUrl) async => [];

/// Not meaningful on native mobile/desktop — the app already knows
/// its own platform via Platform.isAndroid/isIOS, so there's no need
/// to sniff a browser user agent here. Only the web build's
/// detectMobileOs() actually needs this; on native it always
/// short-circuits to null before this would even be called.
String? detectMobileOsNative() => null;