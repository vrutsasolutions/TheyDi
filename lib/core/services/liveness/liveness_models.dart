// enum LivenessStep { blink, headLeft, headRight, holdStill, done }

// class LivenessFrame {
//   final double leftEAR;
//   final double rightEAR;
//   final double blinkLeft;
//   final double blinkRight;
//   final double yaw; // -1 (left) .. 0 (center) .. 1 (right)
//   const LivenessFrame({
//     required this.leftEAR,
//     required this.rightEAR,
//     required this.blinkLeft,
//     required this.blinkRight,
//     required this.yaw,
//   });
// }

// abstract class LivenessDetector {
//   Future<void> init();
//   Stream<LivenessFrame> frames();
//   /// Extract matchable geometric points from a single captured JPEG.
//   Future<Map<String, List<double>>?> pointsFromImage(List<int> jpegBytes);
//   Future<void> dispose();
// }





// ─────────────────────────────────────────────────────────────────────────────
// liveness_models.dart
//
// Shared types for the active-liveness verification module. No platform
// code here (no camera, no ML Kit, no JS interop) — this file must stay
// dependency-free so both liveness_detector_mobile.dart and
// liveness_detector_web.dart can import it without pulling in
// platform-specific code.
// ─────────────────────────────────────────────────────────────────────────────

/// The ordered steps of the active liveness challenge shown to the user.
/// FaceVerificationScreen walks through these in order — blink (x2) →
/// turn head RIGHT → turn head LEFT → hold still — only after `done` is
/// reached does auto-capture fire.
enum LivenessStep { initialCapture, blink, headRight, headLeft, holdStill, done }

/// Normalized bounding box of the detected face, in 0.0–1.0 fractions of
/// the camera preview's width/height (NOT pixels) — so the UI's face-guide
/// overlay can position itself correctly regardless of the actual preview
/// widget size.
class FaceBox {
  final double left;
  final double top;
  final double width;
  final double height;

  const FaceBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}

/// One frame's worth of face-signal data, emitted continuously while the
/// camera is live. Consumed by the challenge state machine to decide when
/// each LivenessStep has been satisfied.
class LivenessFrame {
  /// Eye-open probability, left eye. 1.0 = fully open, 0.0 = fully closed.
  final double leftEAR;

  /// Eye-open probability, right eye. 1.0 = fully open, 0.0 = fully closed.
  final double rightEAR;

  /// Derived "how closed" signal, left eye — 0 = open, 1 = closed. This is
  /// the signal actually used for blink counting (see FaceVerificationScreen)
  /// because it's comparable across both mobile (1 - eyeOpenProbability)
  /// and web (MediaPipe blendshape score) — raw leftEAR/rightEAR ranges
  /// differ between the two platforms and are not directly comparable.
  final double blinkLeft;

  /// Derived "how closed" signal, right eye (see blinkLeft).
  final double blinkRight;

  /// Head yaw in DEGREES — positive = turned right, negative = turned
  /// left, 0 = facing straight ahead. Matches the ±20° thresholds from the
  /// liveness spec directly, no extra scaling needed at the call site.
  final double yawDegrees;

  /// How many faces were detected in this frame. The challenge must only
  /// progress when this is exactly 1 — 0 means "no face found", 2+ means
  /// "more than one person in frame", both of which pause the challenge.
  final int faceCount;

  /// Normalized bounding box of the primary detected face, for the face
  /// guide overlay. Null when faceCount != 1 (nothing sensible to draw).
  final FaceBox? faceBox;

  const LivenessFrame({
    required this.leftEAR,
    required this.rightEAR,
    required this.blinkLeft,
    required this.blinkRight,
    required this.yawDegrees,
    required this.faceCount,
    this.faceBox,
  });
}

/// Platform-agnostic contract for a liveness detector. Implemented by
/// MobileLivenessDetector (google_mlkit_face_detection) and
/// WebLivenessDetector (MediaPipe via JS interop). FaceVerificationScreen
/// only ever talks to this interface — it never references the platform
/// classes directly, so the screen's code is identical on Android and Web.
abstract class LivenessDetector {
  /// Starts the underlying detector (camera image stream on mobile,
  /// MediaPipe landmarker + polling timer on web).
  Future<void> init();

  /// Continuous stream of per-frame signals while the camera is live.
  /// Used to drive the blink / head-turn / hold-still challenge.
  Stream<LivenessFrame> frames();

  /// One-shot landmark extraction from a captured still JPEG. Used after
  /// capture to compute the geometric points fed into FaceMatchService —
  /// does NOT require the live camera frame stream to be running.
  Future<Map<String, List<double>>?> pointsFromImage(List<int> jpegBytes);

  /// Stops the detector and releases any resources (image stream,
  /// polling timer, native detector handles).
  Future<void> dispose();
}




