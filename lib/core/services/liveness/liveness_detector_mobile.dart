import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/services.dart' show DeviceOrientation;
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
    } catch (e) {
      // Skip a bad frame — the stream just won't emit for this tick.
      // The challenge state machine (screen side) tolerates gaps.
      // Logged (debug only) instead of silently swallowed, so a systemic
      // problem (e.g. every frame throwing) is visible during development.
      if (kDebugMode) {
        debugPrint('MobileLivenessDetector: frame processing error: $e');
      }
    } finally {
      _busy = false;
    }
  }

  // Builds the ML Kit InputImage for one camera frame.
  //
  // ROOT CAUSE (Android): CameraController used to be configured with
  // ImageFormatGroup.yuv420, which on Android delivers CameraImage as 3
  // *separate* planes (Y, U, V — YUV_420_888) with row strides that are
  // frequently larger than the image width (padding). The old code
  // concatenated the 3 planes' raw bytes back-to-back and labelled the
  // result "nv21" (via a fallback, since ML Kit's format enum doesn't
  // recognise Android's YUV_420_888 raw format code at all). That is not
  // valid NV21 data — NV21 is Y followed by *interleaved* VU bytes, and
  // padding was never stripped. ML Kit therefore received corrupt image
  // bytes and either found 0 faces or threw (caught by the empty catch
  // block above), on every single frame — while the camera preview kept
  // working fine because it's a completely separate GPU texture path.
  //
  // Fix: CameraController now requests ImageFormatGroup.nv21 on Android
  // (see face_verification_screen.dart), so image.planes.length == 1 and
  // the bytes are already valid NV21 (converted natively by the camera
  // plugin via libyuv). The 3-plane branch below is kept only as a
  // defensive fallback (e.g. iOS, or an OEM camera HAL that ignores the
  // requested format) and does a proper stride/pixel-stride-aware
  // YUV_420_888 -> NV21 conversion instead of naive concatenation.
  InputImage? _toInputImage(CameraImage image, CameraDescription camera) {
    try {
      final Uint8List bytes = image.planes.length == 1
          ? image.planes.first.bytes
          : _yuv420ToNv21(image);

      final rotation = _rotationFor(camera);

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          // NV21 output (both the native conversion and _yuv420ToNv21
          // below) is always tightly packed, so stride == width.
          bytesPerRow: image.width,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MobileLivenessDetector: failed to build InputImage: $e');
      }
      return null;
    }
  }

  // Stride/pixel-stride-aware YUV_420_888 (3-plane) -> NV21 (single-plane,
  // interleaved VU) converter. Only used as a fallback when the camera
  // plugin hands back 3 planes despite requesting nv21 — see comment above.
  //
  // NOTE: the `camera` package's Plane class (camera-0.10.6) exposes pixel
  // stride as `bytesPerPixel`, NOT `pixelStride` (that name doesn't exist
  // on this Plane type — using it is a compile error, not a runtime one).
  // `bytesPerPixel` is the same concept: how many bytes to skip between
  // consecutive chroma samples in that plane's byte buffer.
  Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final nv21 = Uint8List(width * height + 2 * ((width + 1) ~/ 2) * ((height + 1) ~/ 2));

    // Y plane: copy row by row, stripping any row-stride padding.
    var outIndex = 0;
    for (var row = 0; row < height; row++) {
      final rowStart = row * yPlane.bytesPerRow;
      nv21.setRange(outIndex, outIndex + width, yPlane.bytes, rowStart);
      outIndex += width;
    }

    // Chroma planes: NV21 wants interleaved V,U (in that order) at half
    // resolution. Respect each plane's own row stride and pixel stride —
    // bytesPerPixel is often 2 on Android because U/V physically share an
    // interleaved buffer with the *other* chroma plane.
    final uRowStride = uPlane.bytesPerRow;
    final vRowStride = vPlane.bytesPerRow;
    final int uPixelStride = uPlane.bytesPerPixel ?? 1;
    final int vPixelStride = vPlane.bytesPerPixel ?? 1;
    final chromaHeight = (height + 1) ~/ 2;
    final chromaWidth = (width + 1) ~/ 2;

    for (var row = 0; row < chromaHeight; row++) {
      final uRowStart = row * uRowStride;
      final vRowStart = row * vRowStride;
      for (var col = 0; col < chromaWidth; col++) {
        final int uIndex = uRowStart + col * uPixelStride;
        final int vIndex = vRowStart + col * vPixelStride;
        nv21[outIndex++] = vPlane.bytes[vIndex]; // V first
        nv21[outIndex++] = uPlane.bytes[uIndex]; // U second
      }
    }

    return nv21;
  }

  // Combines the camera's fixed sensor orientation with the device's
  // current orientation, as ML Kit requires — using sensorOrientation
  // alone (the old code) is only correct when the phone happens to be
  // held in the same orientation the sensor was mounted at.
  InputImageRotation _rotationFor(CameraDescription camera) {
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
          InputImageRotation.rotation0deg;
    }
    final deviceDegrees = _deviceOrientationDegrees(controller.value.deviceOrientation);
    int rotationCompensation;
    if (camera.lensDirection == CameraLensDirection.front) {
      rotationCompensation = (camera.sensorOrientation + deviceDegrees) % 360;
    } else {
      rotationCompensation = (camera.sensorOrientation - deviceDegrees + 360) % 360;
    }
    return InputImageRotationValue.fromRawValue(rotationCompensation) ??
        InputImageRotation.rotation0deg;
  }

  int _deviceOrientationDegrees(DeviceOrientation orientation) {
    switch (orientation) {
      case DeviceOrientation.portraitUp:
        return 0;
      case DeviceOrientation.landscapeLeft:
        return 90;
      case DeviceOrientation.portraitDown:
        return 180;
      case DeviceOrientation.landscapeRight:
        return 270;
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