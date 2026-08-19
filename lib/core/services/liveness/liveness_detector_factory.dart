// import 'package:camera/camera.dart';
// import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:web/web.dart' as web;
// import 'liveness_models.dart';
// import 'liveness_detector_mobile.dart';
// import 'liveness_detector_web.dart';

// LivenessDetector createLivenessDetector(CameraController controller) {
//   if (kIsWeb) {
//     final video = web.document.querySelector('video') as web.HTMLVideoElement;
//     return WebLivenessDetector(video);
//   }
//   return MobileLivenessDetector(controller);
// }

// liveness_detector_factory.dart
import 'package:camera/camera.dart';
import 'liveness_models.dart';

import 'liveness_detector_stub.dart'
    if (dart.library.html) 'liveness_detector_web.dart'
    if (dart.library.io) 'liveness_detector_mobile.dart';

LivenessDetector createLivenessDetector(CameraController controller) =>
    createPlatformLivenessDetector(controller);