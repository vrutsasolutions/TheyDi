// import 'dart:async';
// import 'dart:convert';
// import 'dart:js_interop';
// import 'package:web/web.dart' as web;
// import 'liveness_models.dart';
// import 'package:camera/camera.dart';

// @JS('theydiInitLandmarker')
// external JSPromise theydiInitLandmarker();

// @JS('theydiDetect')
// external JSAny? theydiDetect(web.HTMLVideoElement video);

// @JS('theydiDetectImage')
// external JSPromise theydiDetectImage(JSString base64Jpeg);

// class WebLivenessDetector implements LivenessDetector {
//   final web.HTMLVideoElement videoElement;
//   WebLivenessDetector(this.videoElement);

//   final _controller = StreamController<LivenessFrame>.broadcast();
//   Timer? _timer;

//   @override
//   Future<void> init() async {
//     await theydiInitLandmarker().toDart;
//     _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
//   }

//   void _tick() {
//     final result = theydiDetect(videoElement);
//     if (result == null) return;
//     final map = (result as JSObject).dartify() as Map;
//     final leftEAR = (map['leftEAR'] as num).toDouble();
//     final rightEAR = (map['rightEAR'] as num).toDouble();
//     final blinkLeft = (map['blinkLeft'] as num).toDouble();
//     final blinkRight = (map['blinkRight'] as num).toDouble();
//     final noseX = (map['noseX'] as num).toDouble();
//     final leftCheekX = (map['leftCheekX'] as num).toDouble();
//     final rightCheekX = (map['rightCheekX'] as num).toDouble();

//     final mid = (leftCheekX + rightCheekX) / 2;
//     final span = (rightCheekX - leftCheekX).abs().clamp(0.01, 1.0);
//     final yaw = ((noseX - mid) / span).clamp(-1.0, 1.0);

//     _controller.add(LivenessFrame(
//       leftEAR: leftEAR, rightEAR: rightEAR,
//       blinkLeft: blinkLeft, blinkRight: blinkRight, yaw: yaw,
//     ));
//   }

//   @override
//   Future<Map<String, List<double>>?> pointsFromImage(List<int> jpegBytes) async {
//     final b64 = base64Encode(jpegBytes);
//     final result = await theydiDetectImage(b64.toJS).toDart;
//     if (result == null) return null;
//     final map = (result as JSObject).dartify() as Map;
//     return map.map((k, v) => MapEntry(
//         k as String, (v as List).map((e) => (e as num).toDouble()).toList()));
//   }

//   @override
//   Stream<LivenessFrame> frames() => _controller.stream;

//   @override
//   Future<void> dispose() async {
//     _timer?.cancel();
//     await _controller.close();
//   }
// }

// LivenessDetector createPlatformLivenessDetector(CameraController controller) {
//   final video = web.document.querySelector('video');
//   if (video == null || video is! web.HTMLVideoElement) {
//     throw StateError(
//       'No active camera <video> element found for web liveness detection.',
//     );
//   }
//   return WebLivenessDetector(video);
// }

// ─────────────────────────────────────────────────────────────────────────────
// liveness_detector_web.dart
//
// Flutter Web implementation of LivenessDetector, backed by MediaPipe Face
// Landmarker running in JS (loaded via a small glue script — see
// web/index.html). Only ever imported on web (via the conditional import in
// liveness_detector_factory.dart, dart.library.html) — never on
// Android/iOS.
//
// Requires three JS globals to already be defined on `window` before init()
// is called: theydiInitLandmarker, theydiDetect, theydiDetectImage.
//
// NOTE on faceCount / faceBox / yawDegrees (read this before Step 4):
// The CURRENT index.html's theydiDetect() does not yet return faceCount or
// faceBox, and its yaw is a normalized nose-offset value, not a real
// geometric degree. This file reads faceCount/faceBox defensively (falls
// back to sensible defaults if absent) so it compiles and runs against
// today's index.html, but the values won't be fully accurate until
// index.html is updated in Step 4. See the comment block at the bottom of
// this file for the exact JS changes Step 4 needs to make.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:camera/camera.dart';
import 'package:web/web.dart' as web;
import 'liveness_models.dart';

@JS('theydiInitLandmarker')
external JSPromise theydiInitLandmarker();

@JS('theydiDetect')
external JSAny? theydiDetect(web.HTMLVideoElement video);

@JS('theydiDetectImage')
external JSPromise theydiDetectImage(JSString base64Jpeg);

class WebLivenessDetector implements LivenessDetector {
  final web.HTMLVideoElement videoElement;
  WebLivenessDetector(this.videoElement);

  final _controller = StreamController<LivenessFrame>.broadcast();
  Timer? _timer;

  // ── Live challenge (blink / head-turn / hold-still / face guide) ─────────
  @override
  Future<void> init() async {
    await theydiInitLandmarker().toDart;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  void _tick() {
    final result = theydiDetect(videoElement);

    // No face found this frame — emit faceCount: 0 so the screen can show
    // "Face not detected" instead of silently stalling.
    if (result == null) {
      _controller.add(const LivenessFrame(
        leftEAR: 0,
        rightEAR: 0,
        blinkLeft: 0,
        blinkRight: 0,
        yawDegrees: 0,
        faceCount: 0,
        faceBox: null,
      ));
      return;
    }

    final map = (result as JSObject).dartify() as Map;

    // faceCount: today's index.html always resolves a single face's
    // landmarks when one is found (numFaces: 1 in the landmarker config),
    // so it doesn't report a count yet. Default to 1 when the field is
    // absent (current behavior); once Step 4 adds real multi-face
    // counting to the JS side, this will pick it up automatically.
    final faceCount = (map['faceCount'] as num?)?.toInt() ?? 1;

    if (faceCount != 1) {
      // 0 handled above (result == null); this covers a future 2+ case
      // once Step 4's JS reports faceCount explicitly.
      _controller.add(LivenessFrame(
        leftEAR: 0,
        rightEAR: 0,
        blinkLeft: 0,
        blinkRight: 0,
        yawDegrees: 0,
        faceCount: faceCount,
        faceBox: null,
      ));
      return;
    }

    final leftEAR = (map['leftEAR'] as num).toDouble();
    final rightEAR = (map['rightEAR'] as num).toDouble();
    final blinkLeft = (map['blinkLeft'] as num).toDouble();
    final blinkRight = (map['blinkRight'] as num).toDouble();
    final noseX = (map['noseX'] as num).toDouble();
    final leftCheekX = (map['leftCheekX'] as num).toDouble();
    final rightCheekX = (map['rightCheekX'] as num).toDouble();

    // yawDegrees: today's JS only gives a normalized nose-offset-vs-
    // cheek-span value (-1..1), not a true geometric yaw angle. We scale
    // it to an approximate degree range (±45°) so the ±20° threshold used
    // by the screen behaves reasonably in the meantime. Step 4 replaces
    // this with a real degree value computed from MediaPipe's
    // facialTransformationMatrixes output — see the note at the bottom of
    // this file.
    final mid = (leftCheekX + rightCheekX) / 2;
    final span = (rightCheekX - leftCheekX).abs().clamp(0.01, 1.0);
    final normalizedYaw = ((noseX - mid) / span).clamp(-1.0, 1.0);
    final yawDegrees = normalizedYaw * 45;

    // faceBox: not yet provided by today's JS — read defensively, stays
    // null (no overlay drawn) until Step 4 adds it.
    FaceBox? faceBox;
    final boxData = map['faceBox'];
    if (boxData is Map) {
      faceBox = FaceBox(
        left: (boxData['left'] as num).toDouble(),
        top: (boxData['top'] as num).toDouble(),
        width: (boxData['width'] as num).toDouble(),
        height: (boxData['height'] as num).toDouble(),
      );
    }

    _controller.add(LivenessFrame(
      leftEAR: leftEAR,
      rightEAR: rightEAR,
      blinkLeft: blinkLeft,
      blinkRight: blinkRight,
      yawDegrees: yawDegrees,
      faceCount: faceCount,
      faceBox: faceBox,
    ));
  }

  @override
  Stream<LivenessFrame> frames() => _controller.stream;

  // ── Post-capture point extraction (no live video element needed) ─────────
  // Sends the still JPEG straight to MediaPipe as base64 — does not touch
  // `videoElement`, so this still works even if called after the preview
  // has been torn down. Unchanged from the previous version.
  @override
  Future<Map<String, List<double>>?> pointsFromImage(List<int> jpegBytes) async {
    final b64 = base64Encode(jpegBytes);
    final result = await theydiDetectImage(b64.toJS).toDart;
    if (result == null) return null;
    final map = (result as JSObject).dartify() as Map;
    return map.map((k, v) => MapEntry(
        k as String, (v as List).map((e) => (e as num).toDouble()).toList()));
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await _controller.close();
  }
}

// ── Platform factory entry point ────────────────────────────────────────────
// Called by liveness_detector_factory.dart via conditional import. Keeps
// the class name (WebLivenessDetector) out of the factory file so the
// factory never references a platform-specific symbol directly.
//
// Must be called while the camera preview's <video> element is still in the
// DOM (i.e. right when the live challenge screen opens) — not after capture,
// when the preview may already be disposed. Unchanged from the previous
// version.
LivenessDetector createPlatformLivenessDetector(CameraController controller) {
  final video = web.document.querySelector('video');
  if (video == null || video is! web.HTMLVideoElement) {
    throw StateError(
      'No active camera <video> element found for web liveness detection. '
      'createPlatformLivenessDetector() must be called while the camera '
      'preview is mounted.',
    );
  }
  return WebLivenessDetector(video);
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 4 PREVIEW — exact JS changes web/index.html will need (not applied
// yet, per your instruction). Listed here so Step 4's diff is easy to
// review against this file's expectations:
//
// 1. theydiDetect(video) must return `faceCount` — the number of faces
//    MediaPipe found this frame (0, 1, 2+). Requires changing the
//    landmarker's `numFaces` option from 1 to something like 3 (so it can
//    actually see a second face to report), then
//    `faceCount: result.faceLandmarks?.length || 0` in the returned object.
//
// 2. theydiDetect(video) must return `faceBox: {left, top, width, height}`
//    (normalized 0-1, matching this file's FaceBox shape) — derived from
//    the min/max x/y of the first face's landmarks.
//
// 3. (Optional, more accurate) theydiDetect(video) can return a real
//    `yawDegrees` computed from `result.facialTransformationMatrixes[0]`
//    (rotation matrix -> Euler Y angle in degrees), instead of this
//    file's ±45°-scaled approximation. If provided, this file should read
//    `map['yawDegrees']` directly instead of computing normalizedYaw * 45.
// ─────────────────────────────────────────────────────────────────────────────