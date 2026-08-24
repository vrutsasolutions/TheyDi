import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/face_verification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/liveness/liveness_models.dart';
import '../../../core/services/liveness/liveness_detector_factory.dart';
import '../../../core/services/liveness/face_match_service.dart';

/// Single source of truth for the face-similarity pass/fail threshold.
/// Referenced everywhere a verification decision is made — never
/// duplicated or hardcoded elsewhere in this file.
const double kVerificationThreshold = 0.85;

enum _Stage { intro, capture, review, processing, success, failed }

class FaceVerificationScreen extends StatefulWidget {
  final String userId;
  final VoidCallback? onComplete;

  const FaceVerificationScreen({
    super.key,
    required this.userId,
    this.onComplete,
  });

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  _Stage _stage = _Stage.intro;
  String _status = '';
  int _fails = 0;

  Uint8List? _selfieBytes;
  Uint8List? _secondBytes;
  Map<String, List<double>>? _selfiePoints;
  Map<String, List<double>>? _secondPoints;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TheyDiColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
       leading: (_stage == _Stage.processing || _stage == _Stage.capture)
            ? const SizedBox()
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                color: TheyDiColors.textPrimary,
                onPressed: () => context.pop(),
              ),
        title: Text(_appBarTitle(), style: TheyDiTextStyles.headlineMedium),
        centerTitle: true,
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  String _appBarTitle() {
    switch (_stage) {
      case _Stage.intro:
        return 'Identity Verification';
      case _Stage.capture:
        return 'Live Verification';
      case _Stage.review:
        return 'Review';
      case _Stage.processing:
        return 'Verifying…';
      case _Stage.success:
        return 'Verified ✅';
      case _Stage.failed:
        return 'Try Again';
    }
  }

 Widget _buildBody() {
    switch (_stage) {
      case _Stage.intro:
        return _buildIntro();
      case _Stage.capture:
        return _CameraCaptureView(
          key: const ValueKey('verify-cam'),
          preferFrontCamera: true,
          title: 'Live Verification',
          instruction: 'Position your face inside the box',
          onCaptured: (firstBytes, firstPoints, secondBytes, secondPoints) {
            setState(() {
              _selfieBytes = firstBytes;
              _selfiePoints = firstPoints;
              _secondBytes = secondBytes;
              _secondPoints = secondPoints;
              _stage = _Stage.review;
            });
          },
          onCancel: () => setState(() => _stage = _Stage.intro),
        );
      case _Stage.review:
        return _buildReview();
      case _Stage.processing:
        return _buildProcessing();
      case _Stage.success:
        return _buildSuccess();
      case _Stage.failed:
        return _buildFailed();
    }
  }

  // ── INTRO ──────────────────────────────────────────────────────────────
  Widget _buildIntro() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 16),
        Container(
          width: 100,
          height: 100,
          decoration: const BoxDecoration(
            gradient: TheyDiColors.gradientPrimary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.verified_user_outlined, color: Colors.white, size: 52),
        ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
        const SizedBox(height: 28),
        Text('Verify Your Identity',
                style: TheyDiTextStyles.displaySmall.copyWith(color: TheyDiColors.textPrimary),
                textAlign: TextAlign.center)
            .animate(delay: 100.ms)
            .fade(),
        const SizedBox(height: 10),
        Text(
          'Take a live selfie and one more live photo of yourself.\nWe verify your identity automatically using on-device face matching.',
          style: TheyDiTextStyles.bodySmall.copyWith(color: TheyDiColors.textSecondary),
          textAlign: TextAlign.center,
        ).animate(delay: 150.ms).fade(),
        const SizedBox(height: 32),
        const _StepCard(
          n: '1',
          icon: Icons.camera_front_outlined,
          title: 'Live Selfie',
          sub: 'Blink, turn your head, and hold still — captured automatically',
        ),
        const SizedBox(height: 12),
        const _StepCard(
          n: '2',
          icon: Icons.camera_alt_outlined,
          title: 'Live Image Capture',
          sub: 'One more quick live photo of you',
        ),
        const SizedBox(height: 12),
        const _StepCard(
          n: '3',
          icon: Icons.bolt_outlined,
          title: 'Automatic Verification',
          sub: 'Verified instantly — no manual review needed',
        ),
        const SizedBox(height: 36),
        _GradientButton(
          label: 'Start Verification',
          onTap: _confirmAndStart,
        ).animate(delay: 400.ms).fade(),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => context.pop(),
          child: Text('Do this later',
              style: TheyDiTextStyles.caption.copyWith(color: TheyDiColors.textMuted)),
        ).animate(delay: 450.ms).fade(),
      ]),
    );
  }

  Future<void> _confirmAndStart() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Before you start'),
        content: const Text(
          'Photos are captured automatically at certain moments — '
          'when you see "Hold still", please stop moving until it says '
          'captured. Moving during that moment can blur the photo and '
          'cause a retry.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Got it')),
        ],
      ),
    );
    if (proceed == true && mounted) {
      setState(() => _stage = _Stage.capture);
    }
  }

  // ── REVIEW (confirm both captures before submit) ──────────────────────
  Widget _buildReview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Confirm your photos',
              style: TheyDiTextStyles.labelLarge.copyWith(color: TheyDiColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Retake anything that looks unclear',
              style: TheyDiTextStyles.caption.copyWith(color: TheyDiColors.textSecondary)),
          const SizedBox(height: 16),
          _ReviewThumb(
            label: 'Live Selfie',
            bytes: _selfieBytes,
            onRetake: () => setState(() => _stage = _Stage.capture),
          ),
          const SizedBox(height: 16),
          _ReviewThumb(
            label: 'Live Image Capture',
            bytes: _secondBytes,
            onRetake: () => setState(() => _stage = _Stage.capture),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TheyDiColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TheyDiColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.lock_outline, size: 16, color: TheyDiColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your photos are encrypted and only used for identity verification.',
                  style: TheyDiTextStyles.caption.copyWith(color: TheyDiColors.primary),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 28),
          _GradientButton(label: 'Verify Now', onTap: _submit),
        ],
      ),
    );
  }

  // ── Submit: upload, then automatic face-match verification ───────────────
  Future<void> _submit() async {
    if (_selfieBytes == null || _secondBytes == null) return;

    setState(() {
      _stage = _Stage.processing;
      _status = 'Uploading selfie…';
    });

    try {
      final selfieUrl = await FaceVerificationService.uploadPhoto(
        userId: widget.userId,
        bytes: _selfieBytes!,
        suffix: '',
      );
      if (selfieUrl == null) {
        setState(() {
          _stage = _Stage.failed;
          _status = 'Failed to upload selfie. Check your connection.';
        });
        return;
      }

      setState(() => _status = 'Uploading second photo…');
      final secondUrl = await FaceVerificationService.uploadPhoto(
        userId: widget.userId,
        bytes: _secondBytes!,
        suffix: '_2',
      );
      if (secondUrl == null) {
        setState(() {
          _stage = _Stage.failed;
          _status = 'Failed to upload second photo. Please try again.';
        });
        return;
      }

      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      final userName = userDoc.data()?['displayName'] ?? 'User';

      // Creates verificationRequests/{uid} (status: pending) + sets the
      // user doc's verificationStatus to 'pending' — reused as-is from
      // the manual-review era. We immediately follow up with an automatic
      // approve/reject below instead of waiting for an admin, but this
      // call is still required because approveVerification()/
      // rejectVerification() both .update() this same document, which
      // fails if the document doesn't already exist.
      final submitted = await FaceVerificationService.submitVerificationRequest(
        userId: widget.userId,
        userName: userName,
        selfieUrl: selfieUrl,
        secondSelfieUrl: secondUrl,
      );
      if (!submitted) {
        _fails++;
        setState(() {
          _stage = _Stage.failed;
          _status = 'Submission failed. Please try again.';
        });
        return;
      }

      setState(() => _status = 'Verifying your face…');

      if (_selfiePoints == null || _secondPoints == null) {
        // Liveness passed, but landmark extraction on one of the two
        // stills failed (e.g. face partially out of frame at the exact
        // capture instant). Treat as a failed verification rather than
        // leaving the request stuck at 'pending' forever.
        _fails++;
        await FaceVerificationService.rejectVerification(
          userId: widget.userId,
          userName: userName,
          reason: 'Could not read facial landmarks clearly from the captures.',
        );
        setState(() {
          _stage = _Stage.failed;
          _status = "Face verification failed\n\n"
              "We couldn't verify that both captures belong to the same person.\n\n"
              "Please try again.";
        });
        return;
      }

      bool isMatch;
      try {
        final ratiosA = FaceMatchService.ratiosFromPoints(_selfiePoints!);
        final ratiosB = FaceMatchService.ratiosFromPoints(_secondPoints!);
        isMatch = FaceMatchService.isMatch(ratiosA, ratiosB, threshold: kVerificationThreshold);
      } catch (_) {
        isMatch = false;
      }

      if (isMatch) {
        final approved = await FaceVerificationService.approveVerification(
          userId: widget.userId,
          userName: userName,
        );
        if (approved) {
          setState(() => _stage = _Stage.success);
          widget.onComplete?.call();
        } else {
          _fails++;
          setState(() {
            _stage = _Stage.failed;
            _status = 'Verification failed to save. Please try again.';
          });
        }
      } else {
        _fails++;
        await FaceVerificationService.rejectVerification(
          userId: widget.userId,
          userName: userName,
          reason: 'Faces did not match closely enough between the two captures.',
        );
        setState(() {
          _stage = _Stage.failed;
          _status = "Face verification failed\n\n"
              "We couldn't verify that both captures belong to the same person.\n\n"
              "Please try again.";
        });
      }
    } catch (e) {
      _fails++;
      setState(() {
        _stage = _Stage.failed;
        _status = 'Error: ${e.toString()}';
      });
    }
  }

  void _retry() {
    setState(() {
      _stage = _Stage.intro;
      _selfieBytes = null;
      _secondBytes = null;
      _selfiePoints = null;
      _secondPoints = null;
    });
  }

  // ── PROCESSING ─────────────────────────────────────────────────────────
  Widget _buildProcessing() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(
          width: 72,
          height: 72,
          child: CircularProgressIndicator(color: TheyDiColors.primary, strokeWidth: 5),
        ),
        const SizedBox(height: 24),
        Text(_status,
            style: TheyDiTextStyles.bodyMedium.copyWith(color: TheyDiColors.textPrimary),
            textAlign: TextAlign.center),
      ]),
    );
  }

  // ── SUCCESS ────────────────────────────────────────────────────────────
  Widget _buildSuccess() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 40),
        Container(
          width: 100,
          height: 100,
          decoration: const BoxDecoration(
            gradient: TheyDiColors.gradientPrimary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline, color: Colors.white, size: 52),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 28),
        Text('Verification Successful ✓',
                style: TheyDiTextStyles.displaySmall.copyWith(color: TheyDiColors.textPrimary),
                textAlign: TextAlign.center)
            .animate(delay: 200.ms)
            .fade(),
        const SizedBox(height: 12),
        Text(
          'Your identity has been successfully verified.',
          style: TheyDiTextStyles.bodySmall.copyWith(color: TheyDiColors.textSecondary),
          textAlign: TextAlign.center,
        ).animate(delay: 300.ms).fade(),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: TheyDiColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: TheyDiColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.verified, color: TheyDiColors.primary, size: 16),
            const SizedBox(width: 8),
            Text('Verified',
                style: TheyDiTextStyles.labelMedium.copyWith(color: TheyDiColors.primary)),
          ]),
        ).animate(delay: 400.ms).fade(),
        const SizedBox(height: 40),
        _GradientButton(
          label: 'Got it!',
          onTap: () => context.pop(),
        ).animate(delay: 500.ms).fade(),
      ]),
    );
  }

  // ── FAILED ─────────────────────────────────────────────────────────────
  Widget _buildFailed() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 40),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: TheyDiColors.error.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: TheyDiColors.error, width: 2),
          ),
          child: Icon(Icons.error_outline, color: TheyDiColors.error, size: 44),
        ).animate().shake(duration: 500.ms),
        const SizedBox(height: 28),
        Text('Verification Failed',
            style: TheyDiTextStyles.headlineMedium.copyWith(color: TheyDiColors.error),
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(_status,
            style: TheyDiTextStyles.bodySmall.copyWith(color: TheyDiColors.textSecondary),
            textAlign: TextAlign.center),
        const SizedBox(height: 40),
        if (_fails < 3) _GradientButton(label: 'Try Again', onTap: _retry),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => context.pop(),
          child: Text('Skip for now',
              style: TheyDiTextStyles.caption.copyWith(color: TheyDiColors.textMuted)),
        ),
      ]),
    );
  }
}

// ── Review thumbnail with retake ──────────────────────────────────────────
class _ReviewThumb extends StatelessWidget {
  final String label;
  final Uint8List? bytes;
  final VoidCallback onRetake;

  const _ReviewThumb({required this.label, required this.bytes, required this.onRetake});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TheyDiColors.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TheyDiColors.divider),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: bytes != null
              ? Image.memory(bytes!, width: 64, height: 64, fit: BoxFit.cover)
              : Container(width: 64, height: 64, color: TheyDiColors.divider),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TheyDiTextStyles.labelMedium.copyWith(color: TheyDiColors.textPrimary)),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.check_circle, size: 14, color: TheyDiColors.primary),
                const SizedBox(width: 4),
                Text('Captured live',
                    style:
                        TheyDiTextStyles.caption.copyWith(color: TheyDiColors.textSecondary)),
              ]),
            ],
          ),
        ),
        TextButton(
          onPressed: onRetake,
          child: Text('Retake',
              style: TheyDiTextStyles.caption
                  .copyWith(color: TheyDiColors.primary, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ── Reusable widgets ────────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _GradientButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onTap != null
              ? TheyDiColors.gradientPrimary
              : const LinearGradient(colors: [Colors.grey, Colors.grey]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(label, style: TheyDiTextStyles.labelLarge.copyWith(color: Colors.white)),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String n, title, sub;
  final IconData icon;
  const _StepCard({required this.n, required this.icon, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TheyDiColors.divider),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(gradient: TheyDiColors.gradientPrimary, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TheyDiTextStyles.labelLarge.copyWith(color: TheyDiColors.textPrimary)),
              Text(sub, style: TheyDiTextStyles.caption.copyWith(color: TheyDiColors.textSecondary)),
            ],
          ),
        ),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: TheyDiColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(n,
                style: TheyDiTextStyles.caption
                    .copyWith(color: TheyDiColors.primary, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CameraCaptureView
// A real live-preview camera capture widget backed by CameraController.
// Works on mobile (native camera) AND web (getUserMedia via camera_web) —
// there is NO gallery / file-picker path anywhere in this widget.
//
// Guides the user through a 4-step active liveness challenge (blink x2 ->
// turn head RIGHT -> turn head LEFT -> hold still), shows a live face-guide
// box and no-face/multiple-face warnings, and auto-captures once the
// challenge completes — there is no manual shutter button anywhere in this
// widget.
// ─────────────────────────────────────────────────────────────────────────────
class _CameraCaptureView extends StatefulWidget {
  final bool preferFrontCamera;
  final String title;
  final String instruction;
  final void Function(
    Uint8List firstBytes,
    Map<String, List<double>>? firstPoints,
    Uint8List secondBytes,
    Map<String, List<double>>? secondPoints,
  ) onCaptured;
  final VoidCallback onCancel;

  const _CameraCaptureView({
    super.key,
    required this.preferFrontCamera,
    required this.title,
    required this.instruction,
    required this.onCaptured,
    required this.onCancel,
  });

  @override
  State<_CameraCaptureView> createState() => _CameraCaptureViewState();
}

class _CameraCaptureViewState extends State<_CameraCaptureView> with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initFuture;
  String? _error;
  bool _capturing = false;

  // ── Liveness challenge state ──────────────────────────────────────────
  LivenessDetector? _detector;
  StreamSubscription<LivenessFrame>? _frameSub;
  LivenessStep _step = LivenessStep.initialCapture;
  String? _livenessError;

  // Face presence, for the guide box + "no face"/"multiple faces" banners.
  int _faceCount = 1; // starts at 1 (neutral) until the first frame arrives
  FaceBox? _faceBox;

  // Blink detection: exactly 2 valid close->open cycles required.
  int _blinkCount = 0;
  bool _sawEyesClose = false;
  static const _requiredBlinks = 2;

  Uint8List? _firstBytes;
  Map<String, List<double>>? _firstPoints;

  // Head-turn / hold-still: require ~1s of continuous stable detection
  // before accepting the step, so a single noisy frame can't pass it.
  DateTime? _sustainStartedAt;
  static const _turnSustainDuration = Duration(milliseconds: 1000);
  static const _holdStillDuration = Duration(milliseconds: 900);

  // Thresholds. yawDegrees: positive = turned right, negative = turned
  // left (see liveness_models.dart). blinkLeft/Right: 0 = open, 1 = closed
  // — used instead of raw leftEAR/rightEAR because it's the one signal
  // that's genuinely comparable across platforms (mobile derives it as
  // 1 - eyeOpenProbability, web reads it from a MediaPipe blendshape
  // score — both land in a consistent 0-1 range).
  static const _yawTurnThresholdDeg = 20.0;
  static const _yawCenterThresholdDeg = 10.0;
  static const _eyesOpenThreshold = 0.2;
  static const _eyesClosedThreshold = 0.5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFuture = _setupCamera();
  }

  Future<void> _setupCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No camera found on this device.');
        return;
      }

      CameraDescription selected = cameras.first;
      for (final cam in cameras) {
        final wantsFront = widget.preferFrontCamera;
        if (wantsFront && cam.lensDirection == CameraLensDirection.front) {
          selected = cam;
          break;
        }
        if (!wantsFront && cam.lensDirection == CameraLensDirection.back) {
          selected = cam;
          break;
        }
      }

      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        // Web: MediaPipe reads frames off the <video> element directly, so
        // this only controls still-capture format — jpeg is fine.
        // Android: request nv21 so the camera plugin performs the
        // YUV_420_888 -> NV21 conversion natively (via libyuv). ML Kit's
        // InputImage.fromBytes() only understands single-plane NV21/YV12 —
        // yuv420 hands back 3 separate padded planes that, if naively
        // concatenated, produce corrupt bytes ML Kit can't read (this was
        // the root cause of face detection silently never firing on
        // Android). See liveness_detector_mobile.dart for the matching
        // 3-plane fallback converter kept for safety.
        // iOS: not yet verified on a real device — if ML Kit rejects frames
        // on iOS, switch this branch to ImageFormatGroup.bgra8888.
        imageFormatGroup: kIsWeb
            ? ImageFormatGroup.jpeg
            : Platform.isAndroid
                ? ImageFormatGroup.nv21
                : ImageFormatGroup.yuv420,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      await _startLiveness(controller);
    } catch (e) {
      setState(() => _error = 'Could not access camera: $e');
    }
  }

  // ── Liveness challenge ───────────────────────────────────────────────
// ── Liveness challenge ───────────────────────────────────────────────
  Future<void> _startLiveness(CameraController controller) async {
    // On web, the camera plugin's <video> element can take a moment to
    // actually attach to the DOM after CameraController.initialize()
    // resolves (PlatformView registration timing). createLivenessDetector()
    // throws immediately if it's not there yet — retry a few times with a
    // short delay instead of failing on the very first attempt.
    LivenessDetector? detector;
    for (var attempt = 0; attempt < 10 && detector == null; attempt++) {
      if (!mounted) return;
      try {
        detector = createLivenessDetector(controller);
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }

    if (detector == null) {
      if (!mounted) return;
      setState(() => _livenessError = 'Could not start liveness check. Please retry.');
      return;
    }

    try {
      await detector.init();
      if (!mounted) {
        await detector.dispose();
        return;
      }
      _detector = detector;
      _frameSub = detector.frames().listen(_onLivenessFrame);
    } catch (e) {
      if (!mounted) return;
      await detector.dispose();
      _detector = null;
      setState(() => _livenessError = 'Could not start liveness check. Please retry.');
    }
  }

  void _onLivenessFrame(LivenessFrame frame) {
    if (!mounted || _capturing) return;

    // Always track face presence for the guide box + banners, even when
    // we're not going to advance the challenge this frame.
    setState(() {
      _faceCount = frame.faceCount;
      _faceBox = frame.faceBox;
    });

    // Face not visible, or more than one person in frame — pause the
    // challenge (don't lose blink-count progress, but head-turn/hold
    // sustain timers reset since continuity is broken).
    if (frame.faceCount != 1) {
      _sustainStartedAt = null;
      return;
    }

       switch (_step) {
      case LivenessStep.initialCapture:
        // Snap the moment a single face is confidently detected — no
        // challenge required yet, this is just the baseline photo.
        _sustainStartedAt ??= DateTime.now();
        if (DateTime.now().difference(_sustainStartedAt!) >= const Duration(milliseconds: 400)) {
          _advanceStep(LivenessStep.blink);
          _captureFirst();
        } else {
          setState(() {});
        }
        break;

      case LivenessStep.blink:
        final eyesClosed =
            frame.blinkLeft > _eyesClosedThreshold && frame.blinkRight > _eyesClosedThreshold;
        final eyesOpen =
            frame.blinkLeft < _eyesOpenThreshold && frame.blinkRight < _eyesOpenThreshold;
        if (eyesClosed) {
          _sawEyesClose = true;
        } else if (eyesOpen && _sawEyesClose) {
          _sawEyesClose = false;
          final count = _blinkCount + 1;
          if (count >= _requiredBlinks) {
            _advanceStep(LivenessStep.headRight, blinkCount: count);
          } else {
            setState(() => _blinkCount = count);
          }
        }
        break;

      case LivenessStep.headRight:
        if (frame.yawDegrees >= _yawTurnThresholdDeg) {
          _sustainStartedAt ??= DateTime.now();
          if (DateTime.now().difference(_sustainStartedAt!) >= _turnSustainDuration) {
            _advanceStep(LivenessStep.headLeft);
          } else {
            setState(() {}); // refresh "hold..." caption
          }
        } else {
          if (_sustainStartedAt != null) setState(() => _sustainStartedAt = null);
        }
        break;

      case LivenessStep.headLeft:
        if (frame.yawDegrees <= -_yawTurnThresholdDeg) {
          _sustainStartedAt ??= DateTime.now();
          if (DateTime.now().difference(_sustainStartedAt!) >= _turnSustainDuration) {
            _advanceStep(LivenessStep.holdStill);
          } else {
            setState(() {});
          }
        } else {
          if (_sustainStartedAt != null) setState(() => _sustainStartedAt = null);
        }
        break;

      case LivenessStep.holdStill:
        final centered = frame.yawDegrees.abs() <= _yawCenterThresholdDeg;
        final eyesOpen =
            frame.blinkLeft < _eyesOpenThreshold && frame.blinkRight < _eyesOpenThreshold;
        if (centered && eyesOpen) {
          _sustainStartedAt ??= DateTime.now();
          if (DateTime.now().difference(_sustainStartedAt!) >= _holdStillDuration) {
            _advanceStep(LivenessStep.done);
            _autoCapture();
          } else {
            setState(() {});
          }
        } else {
          if (_sustainStartedAt != null) setState(() => _sustainStartedAt = null);
        }
        break;

      case LivenessStep.done:
        break;
    }
  }

  void _advanceStep(LivenessStep next, {int? blinkCount}) {
    if (!mounted) return;
    setState(() {
      _step = next;
      _sustainStartedAt = null;
      if (blinkCount != null) _blinkCount = blinkCount;
    });
  }

  String _stepInstruction() {
    switch (_step) {
      case LivenessStep.initialCapture:
        return 'Face detected — hold still';
      case LivenessStep.blink:
        return 'Blink your eyes 2 times';
      case LivenessStep.headRight:
        return 'Turn your head LEFT';
      case LivenessStep.headLeft:
        return 'Turn your head RIGHT';
      case LivenessStep.holdStill:
        return 'Look straight at the camera\nHold still';
      case LivenessStep.done:
        return 'Captured!';
    }
  }

  String? _stepSubCaption() {
    switch (_step) {
      case LivenessStep.initialCapture:
        return null;
      case LivenessStep.blink:
        return 'Blinks: $_blinkCount / $_requiredBlinks';
      case LivenessStep.headRight:
        return _sustainStartedAt != null ? 'Right turn detected — hold…' : null;
      case LivenessStep.headLeft:
        return _sustainStartedAt != null ? 'Left turn detected — hold…' : null;
      case LivenessStep.holdStill:
        return _sustainStartedAt != null ? 'Hold still…' : null;
      case LivenessStep.done:
        return null;
    }
  }

  Future<void> _captureFirst() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) return;

    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();

      Map<String, List<double>>? points;
      try {
        points = await _detector?.pointsFromImage(bytes);
      } catch (_) {
        points = null;
      }

      _firstBytes = bytes;
      _firstPoints = points;
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _sustainStartedAt = null; // clean slate for the blink step that follows
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _error = 'Capture failed: $e';
      });
    }
  }

  Future<void> _autoCapture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) return;
    if (_firstBytes == null) return; // safety — shouldn't happen, initialCapture runs first

    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();

      Map<String, List<double>>? points;
      try {
        points = await _detector?.pointsFromImage(bytes);
      } catch (_) {
        points = null;
      }

      await _frameSub?.cancel();
      _frameSub = null;
      await _detector?.dispose();
      _detector = null;

      if (!mounted) return;
      widget.onCaptured(_firstBytes!, _firstPoints, bytes, points);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _error = 'Capture failed: $e';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Web doesn't need this pause/resume dance at all — there's no OS-level
    // camera resource reclaim to cooperate with like on Android/iOS. Worse,
    // browser camera/mic permission prompts fire a brief `inactive` ->
    // `resumed` cycle as the tab loses/regains focus, which was causing
    // this handler to dispose the live CameraController mid-initialization
    // and then race a second setup against the first — the exact cause of
    // the "buildPreview() called on a disposed CameraController" crash
    // loop. Only run this logic on native platforms.
    if (kIsWeb) return;

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _frameSub?.cancel();
      _frameSub = null;
      _detector?.dispose();
      _detector = null;
      controller.dispose();
      // Clear the reference so _buildPreview() falls back to the loading
      // spinner instead of rendering a disposed controller.
      setState(() => _controller = null);
    } else if (state == AppLifecycleState.resumed) {
      _sawEyesClose = false;
      _sustainStartedAt = null;
      _blinkCount = 0;
      _firstBytes = null;
      _firstPoints = null;
      _step = LivenessStep.initialCapture;
      _initFuture = _setupCamera();
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _frameSub?.cancel();
    _detector?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller != null && _controller!.value.isInitialized;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
          child: Column(children: [
            Text(widget.title,
                style: TheyDiTextStyles.labelLarge.copyWith(color: TheyDiColors.textPrimary)),
            const SizedBox(height: 4),
            ..._buildStatusLines(ready),
            if (ready && _livenessError == null && _faceCount == 1) ...[
              const SizedBox(height: 12),
              _LivenessStepDots(currentStep: _step),
            ],
          ]),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: EdgeInsets.zero,
              child: AspectRatio(
                aspectRatio: (_controller != null && _controller!.value.isInitialized)
                    ? 1 / _controller!.value.aspectRatio
                    : 3 / 4,
                  child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    color: Colors.black,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildPreview(),
                            if (ready && _faceCount == 1 && _faceBox != null)
                              _faceGuideBox(constraints, _faceBox!),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onCancel,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: TheyDiColors.divider),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Back',
                    style: TheyDiTextStyles.labelLarge.copyWith(color: TheyDiColors.textSecondary)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Container(
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: TheyDiColors.inputFill,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _capturing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          const SizedBox(width: 10),
                          Text('Capturing…',
                              style: TheyDiTextStyles.labelMedium
                                  .copyWith(color: TheyDiColors.textSecondary)),
                        ],
                      )
                    : Text(
                        'Follow the instructions above',
                        style: TheyDiTextStyles.labelMedium
                            .copyWith(color: TheyDiColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  List<Widget> _buildStatusLines(bool ready) {
    if (!ready) {
      return [
        Text(widget.instruction,
            style: TheyDiTextStyles.caption.copyWith(color: TheyDiColors.textSecondary),
            textAlign: TextAlign.center),
      ];
    }
    if (_livenessError != null) {
      return [
        Text(_livenessError!,
            style: TheyDiTextStyles.caption.copyWith(color: TheyDiColors.error),
            textAlign: TextAlign.center),
      ];
    }
    if (_faceCount == 0) {
      return [
        Text('Face not detected',
            style: TheyDiTextStyles.labelMedium.copyWith(color: TheyDiColors.error),
            textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text('Please position your face inside the frame',
            style: TheyDiTextStyles.caption.copyWith(color: TheyDiColors.textSecondary),
            textAlign: TextAlign.center),
      ];
    }
    if (_faceCount > 1) {
      return [
        Text('Multiple faces detected',
            style: TheyDiTextStyles.labelMedium.copyWith(color: TheyDiColors.error),
            textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text('Only one person should be visible',
            style: TheyDiTextStyles.caption.copyWith(color: TheyDiColors.textSecondary),
            textAlign: TextAlign.center),
      ];
    }
    final sub = _stepSubCaption();
return [
  Text(_stepInstruction(),
      style: TheyDiTextStyles.caption.copyWith(color: TheyDiColors.textSecondary),
      textAlign: TextAlign.center),
  if (sub != null) ...[
    const SizedBox(height: 2),
    Text(sub,
        style: TheyDiTextStyles.caption
            .copyWith(color: TheyDiColors.primary, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center),
  ],
  if (_step == LivenessStep.initialCapture || _step == LivenessStep.holdStill) ...[
    const SizedBox(height: 8),
    AnimatedOpacity(
      opacity: _sustainStartedAt != null ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.pan_tool_outlined, size: 16, color: Colors.amber),
            SizedBox(width: 6),
            Text(
              "Don't move — capturing…",
              style: TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  ],
];
  }

  // Face guide box overlay.
  //
  // IMPORTANT: no mirror flip is applied here. `CameraPreview` below draws
  // the raw, unmirrored camera texture, and the detected `FaceBox` is
  // reported in that same coordinate space — so the box's normalized
  // left/top/width/height map directly onto the displayed preview with a
  // straight per-axis scale. Flipping the X coordinate here (as a previous
  // version of this file did, to "undo" an assumed mirrored preview) made
  // the box move in the OPPOSITE direction from the real face — face
  // right -> box left, and vice versa. Do not reintroduce a mirror flip
  // unless the preview itself is also mirrored to match, and even then,
  // prefer keeping both unmirrored — it's the only way the two are
  // guaranteed to stay in sync.
  //
  // The guide itself is a large centered rounded-square rather than the
  // raw detected rectangle: the detector's box is often tall and narrow
  // and doesn't read as a friendly face guide. We take the larger of the
  // detected width/height, pad it out, and center it on the detected
  // box's center — so it tracks the same movement as the real detected
  // box while looking like a proper face-guide square.
  Widget _faceGuideBox(BoxConstraints constraints, FaceBox box) {
   final centerX =(1.0 - (box.left + box.width / 2)).clamp(0.0, 1.0);
    final centerY = (box.top + box.height / 2).clamp(0.0, 1.0);

    final rawSize = box.width > box.height ? box.width : box.height;
    // Pad the detected size out generously and clamp to a sane range so
    // it always reads as a large square guide, never a sliver or one
    // that overflows the preview.
    final size = (rawSize * 1.6).clamp(0.28, 0.85);

    final left = (centerX - size / 2).clamp(0.0, 1.0 - size);
    final top = (centerY - size / 2).clamp(0.0, 1.0 - size);
    return Positioned(
      left: left * constraints.maxWidth,
      top: top * constraints.maxHeight,
      width: size * constraints.maxWidth,
      height: size * constraints.maxHeight,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: TheyDiColors.primary,
              width: 3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 40),
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center),
          ]),
        ),
      );
    }

    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        final controller = _controller;
        if (controller == null || !controller.value.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        // Show the ENTIRE camera frame with no cropping — BoxFit.contain
        // guarantees nothing is zoomed/cut off, at the cost of thin black
        // bars on the sides if the box and sensor proportions don't match
        // exactly. This is the most "zoomed out" the preview can be.
        //
        // Deliberately NOT mirrored — see the comment on _faceGuideBox()
        // above. The raw texture and the detected FaceBox share the same
        // coordinate space, and that's what keeps the guide box tracking
        // the real face correctly.
        return Center(
          child: AspectRatio(
            aspectRatio: 1 / controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
        );
      },
    );
  }
}

// ── Liveness step progress dots ─────────────────────────────────────────────
// Small 4-dot indicator shown under the instruction text so the user can
// see how many liveness steps remain — reuses the screen's existing color
// tokens, no new visual language introduced.
class _LivenessStepDots extends StatelessWidget {
  final LivenessStep currentStep;
  const _LivenessStepDots({required this.currentStep});

  static const _order = [
    LivenessStep.blink,
    LivenessStep.headRight,
    LivenessStep.headLeft,
    LivenessStep.holdStill,
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _order.indexOf(currentStep);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_order.length, (i) {
        final done = currentStep == LivenessStep.done || i < currentIndex;
        final active = i == currentIndex;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: active ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: (done || active) ? TheyDiColors.primary : TheyDiColors.divider,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}