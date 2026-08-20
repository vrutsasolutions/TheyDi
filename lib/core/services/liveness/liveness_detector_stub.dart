// liveness_detector_stub.dart
// Default/fallback — chosen only if neither dart.library.html nor
// dart.library.io matches (shouldn't happen on Flutter's supported
// targets, but keeps the conditional-import chain safe).
import 'package:camera/camera.dart';
import 'liveness_models.dart';

LivenessDetector createPlatformLivenessDetector(CameraController controller) {
  throw UnsupportedError(
    'Liveness detection is not supported on this platform.',
  );
}