import 'dart:typed_data';

/// Never actually called — VideoThumbnailHelper only calls the web
/// implementation when kIsWeb is true. This stub exists purely so the
/// conditional import in video_thumbnail_helper.dart has something valid
/// to resolve to on Android/iOS/desktop, where dart:html isn't available.
Future<Uint8List?> generateWebThumbnail(String videoPath) async => null;