import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

/// Grabs one JPEG frame from a video on Flutter Web.
///
/// [videoPath] is the blob/object URL image_picker gives you for a
/// just-picked video file on web (XFile.path there is already a
/// `blob:...` URL — no need to read the bytes yourself first).
///
/// How it works: create a hidden `<video>` element pointed at that blob
/// URL, wait for its metadata to load, seek to a moment early in the clip,
/// wait for the seek to actually land, then draw that frame into an
/// offscreen `<canvas>` and export it as JPEG bytes. Every step has a
/// timeout so a video the browser can't decode (unsupported codec, etc.)
/// fails fast instead of hanging the send flow.
///
/// NOTE: if your Flutter SDK has moved off `dart:html` in favor of
/// `package:web` + `dart:js_interop` (Flutter's newer web interop), the
/// same approach applies — you'd swap `html.VideoElement` /
/// `html.CanvasElement` for the `package:web` equivalents. Included here
/// with `dart:html` since it's still the simpler, widely-supported path
/// for this kind of one-off DOM task at time of writing.
Future<Uint8List?> generateWebThumbnail(String videoPath) async {
  final video = html.VideoElement()
    ..src = videoPath
    ..muted = true
    ..crossOrigin = 'anonymous'
    ..preload = 'auto';

  try {
    // Wait for enough metadata to know the video's dimensions.
    await video.onLoadedMetadata.first.timeout(const Duration(seconds: 6));

    if (video.videoWidth == 0 || video.videoHeight == 0) return null;

    // Seek a little into the clip rather than frame 0, which is
    // sometimes a black/blank frame for freshly-recorded video.
    final seekTarget = video.duration > 1 ? 0.5 : 0.0;
    final seeked = video.onSeeked.first.timeout(const Duration(seconds: 6));
    video.currentTime = seekTarget;
    await seeked;

    final canvas = html.CanvasElement(
      width: video.videoWidth,
      height: video.videoHeight,
    );
    final ctx = canvas.context2D;
    ctx.drawImage(video, 0, 0);

    final blob = await canvas.toBlob('image/jpeg', 0.7);
    final reader = html.FileReader();
    final completer = Completer<Uint8List?>();
    reader.onLoadEnd.first.then((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(result.asUint8List());
      } else if (result is Uint8List) {
        completer.complete(result);
      } else {
        completer.complete(null);
      }
    });
    reader.onError.first.then((_) => completer.complete(null));
    reader.readAsArrayBuffer(blob);

    return await completer.future.timeout(const Duration(seconds: 6));
  } catch (_) {
    return null;
  } finally {
    video.remove();
  }
}