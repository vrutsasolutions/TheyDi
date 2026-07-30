// lib/core/utils/platform_helper_stub.dart
// Stub used on web — no dart:io, no path_provider
Future<String> getNativeTempDir() async => '';
Future<List<int>> readFileBytes(String path) async => [];
Future<List<int>> fetchBlobBytes(String blobUrl) async => [];

/// Not applicable outside web/io — never actually reached since
/// detectMobileOs() in platform_helper.dart only calls this when
/// kIsWeb is true, and the web build always resolves to
/// platform_helper_web.dart instead of this stub.
String? detectMobileOsNative() => null;