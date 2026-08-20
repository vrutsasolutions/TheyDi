
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'liveness_models.dart';

class MobileLivenessDetector implements LivenessDetector {
  final CameraController controller;
  MobileLivenessDetector(this.controller);

  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // needed for eye-open probabilities
      enableContours: true, // needed for pointsFromImage() geometry
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  final _streamController = StreamController<LivenessFrame>.broadcast();
  bool _busy = false;

  // ── Live challenge (blink / head-turn / hold-still / face guide) ─────────
  @override
  Future<void> init() async {
    await controller.startImageStream(_onFrame);
  }

  void _onFrame(CameraImage image) async {
    if (_busy) return;
    _busy = true;
    try {
      final inputImage = _toInputImage(image, controller.description);
      if (inputImage == null) return;
      final faces = await _detector.processImage(inputImage);

      // Emit a frame even when 0 or 2+ faces are found — the screen needs
      // this to show "Face not detected" / "Multiple faces detected"
      // banners. Only when exactly 1 face is present do we compute real
      // blink/yaw signals and a face box; otherwise we send neutral
      // defaults and faceBox: null.
      if (faces.length != 1) {
        _streamController.add(LivenessFrame(
          leftEAR: 0,
          rightEAR: 0,
          blinkLeft: 0,
          blinkRight: 0,
          yawDegrees: 0,
          faceCount: faces.length,
          faceBox: null,
        ));
        return;
      }

      final face = faces.first;
      final leftOpen = face.leftEyeOpenProbability ?? 1.0;
      final rightOpen = face.rightEyeOpenProbability ?? 1.0;
      final yawDeg = face.headEulerAngleY ?? 0.0;

      final imgWidth = image.width.toDouble();
      final imgHeight = image.height.toDouble();
      final box = face.boundingBox;
      final faceBox = FaceBox(
        left: (box.left / imgWidth).clamp(0.0, 1.0),
        top: (box.top / imgHeight).clamp(0.0, 1.0),
        width: (box.width / imgWidth).clamp(0.0, 1.0),
        height: (box.height / imgHeight).clamp(0.0, 1.0),
      );

      _streamController.add(LivenessFrame(
        leftEAR: leftOpen,
        rightEAR: rightOpen,
        blinkLeft: 1 - leftOpen,
        blinkRight: 1 - rightOpen,
        yawDegrees: yawDeg,
        faceCount: 1,
        faceBox: faceBox,
      ));
    } catch (_) {
      // Skip a bad frame — the stream just won't emit for this tick.
      // The challenge state machine (screen side) tolerates gaps.
    } finally {
      _busy = false;
    }
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription camera) {
    try {
      final builder = BytesBuilder();
      for (final plane in image.planes) {
        builder.add(plane.bytes);
      }
      final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
          InputImageRotation.rotation0deg;
      final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.nv21;
      return InputImage.fromBytes(
        bytes: builder.toBytes(),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<LivenessFrame> frames() => _streamController.stream;

  // ── Post-capture point extraction (no live camera needed) ────────────────
  // Deliberately independent of `controller`/image-stream state — this runs
  // AFTER both stills are captured, when the camera preview may already be
  // torn down. Only needs the JPEG bytes.
  @override
  Future<Map<String, List<double>>?> pointsFromImage(List<int> jpegBytes) =>
      _pointsFromBytes(Uint8List.fromList(jpegBytes));

  Future<Map<String, List<double>>?> _pointsFromBytes(Uint8List jpegBytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/liveness_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await file.writeAsBytes(jpegBytes);
    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await _detector.processImage(inputImage);
      if (faces.isEmpty) return null;
      return _extractPoints(faces.first);
    } finally {
      await file.delete().catchError((_) => file);
    }
  }

  Map<String, List<double>>? _extractPoints(Face face) {
    final faceContour = face.contours[FaceContourType.face]?.points;
    final leftEye = face.contours[FaceContourType.leftEye]?.points;
    final rightEye = face.contours[FaceContourType.rightEye]?.points;
    final noseBottom = face.contours[FaceContourType.noseBottom]?.points;
    final upperLipTop = face.contours[FaceContourType.upperLipTop]?.points;
    final leftBrow = face.contours[FaceContourType.leftEyebrowTop]?.points;

    if (faceContour == null ||
        leftEye == null ||
        rightEye == null ||
        noseBottom == null ||
        upperLipTop == null ||
        leftBrow == null ||
        faceContour.isEmpty ||
        leftEye.isEmpty ||
        rightEye.isEmpty ||
        noseBottom.isEmpty ||
        upperLipTop.isEmpty ||
        leftBrow.isEmpty) {
      return null;
    }

    List<int> extreme(List points, bool minX) {
      final sorted = [...points]
        ..sort((a, b) => minX ? a.x.compareTo(b.x) : b.x.compareTo(a.x));
      final p = sorted.first;
      return [p.x, p.y];
    }

    final leftEyeOuter = extreme(leftEye, true);
    final rightEyeOuter = extreme(rightEye, false);
    final noseTip = noseBottom[noseBottom.length ~/ 2];
    final mouthCenter = upperLipTop[upperLipTop.length ~/ 2];
    final leftJaw = extreme(faceContour, true);
    final rightJaw = extreme(faceContour, false);
    final mouthLeft = extreme(upperLipTop, true);
    final mouthRight = extreme(upperLipTop, false);
    final leftBrowPt = leftBrow[leftBrow.length ~/ 2];

    return {
      'leftEyeOuter': leftEyeOuter.map((e) => e.toDouble()).toList(),
      'rightEyeOuter': rightEyeOuter.map((e) => e.toDouble()).toList(),
      'noseTip': [noseTip.x.toDouble(), noseTip.y.toDouble()],
      'mouthCenter': [mouthCenter.x.toDouble(), mouthCenter.y.toDouble()],
      'leftJaw': leftJaw.map((e) => e.toDouble()).toList(),
      'rightJaw': rightJaw.map((e) => e.toDouble()).toList(),
      'mouthLeft': mouthLeft.map((e) => e.toDouble()).toList(),
      'mouthRight': mouthRight.map((e) => e.toDouble()).toList(),
      'leftBrow': [leftBrowPt.x.toDouble(), leftBrowPt.y.toDouble()],
    };
  }

  @override
  Future<void> dispose() async {
    try {
      await controller.stopImageStream();
    } catch (_) {
      // Stream may already be stopped (e.g. capture already paused it).
    }
    await _detector.close();
    await _streamController.close();
  }
}

// ── Platform factory entry point ────────────────────────────────────────────
// Called by liveness_detector_factory.dart via conditional import. Keeps
// the class name (MobileLivenessDetector) out of the factory file so the
// factory never references a platform-specific symbol directly.
LivenessDetector createPlatformLivenessDetector(CameraController controller) =>
    MobileLivenessDetector(controller);