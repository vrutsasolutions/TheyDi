import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_thumbnail/video_thumbnail.dart';

import 'video_thumbnail_helper_web.dart'
    if (dart.library.io) 'video_thumbnail_helper_stub.dart' as web_impl;

/// Generates a single JPEG thumbnail frame from a video, on every platform,
/// with no paid service involved.
///
/// This is meant to be called ONCE, by the sender, right after the video
/// itself is uploaded — the resulting bytes get uploaded through your
/// existing `CloudflareUpload.uploadBytes()` exactly like any other file,
/// and the returned URL is stored as `thumbnailUrl` on the message. Every
/// viewer (web or mobile) then just does `Image.network(thumbnailUrl)` —
/// no plugin, no per-viewer generation, no platform branching in the UI.
///
/// WHY TWO CODE PATHS:
/// - On Android/iOS, `video_thumbnail` uses the platform's native decoder
///   (MediaMetadataRetriever / AVFoundation) and works well on a local
///   file path.
/// - On web, that plugin has no implementation at all, so this uses a
///   hidden HTML `<video>` + `<canvas>` to grab a frame from the local
///   blob URL the browser gave the picked file. See
///   video_thumbnail_helper_web.dart for that half.
///
/// Either path can fail (corrupt file, browser can't decode the codec,
/// permissions, etc.) — this always returns null rather than throwing, so
/// callers can treat it as best-effort and never block sending the video.
class VideoThumbnailHelper {
  VideoThumbnailHelper._();

  /// [videoPath] is the local file path (mobile) or blob/object URL (web)
  /// of the just-picked video — NOT the uploaded Cloudflare URL. Grabbing
  /// the frame from the local file avoids waiting on a network round trip
  /// before you can send.
  static Future<Uint8List?> generate(String videoPath) async {
    if (videoPath.isEmpty) return null;
    try {
      if (kIsWeb) {
        return await web_impl.generateWebThumbnail(videoPath);
      }
      return await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 70,
      );
    } catch (_) {
      return null;
    }
  }
}