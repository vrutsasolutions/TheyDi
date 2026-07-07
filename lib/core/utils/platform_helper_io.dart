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