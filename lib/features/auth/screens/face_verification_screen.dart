// ─────────────────────────────────────────────────────────────────────────────
// face_verification_screen.dart
// Works on BOTH web and mobile — true live camera capture (no gallery/file
// picker path at all). Uses the `camera` package so on web it opens a real
// getUserMedia() viewfinder instead of falling back to a browser file input.
// User captures a live selfie + a live photo of their government ID.
// Admin reviews manually and approves/rejects.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/face_verification_service.dart';
import '../../../core/theme/app_theme.dart';

enum _Stage { intro, captureSelfie, captureId, review, processing, success, failed }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TheyDiColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: (_stage == _Stage.processing ||
                _stage == _Stage.captureSelfie ||
                _stage == _Stage.captureId)
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
      case _Stage.captureSelfie:
        return 'Live Selfie';
      case _Stage.captureId:
        return 'Live Capture';
      case _Stage.review:
        return 'Review';
      case _Stage.processing:
        return 'Submitting…';
      case _Stage.success:
        return 'Submitted ✅';
      case _Stage.failed:
        return 'Try Again';
    }
  }

  Widget _buildBody() {
    switch (_stage) {
      case _Stage.intro:
        return _buildIntro();
      case _Stage.captureSelfie:
        return _CameraCaptureView(
          key: const ValueKey('selfie-cam'),
          preferFrontCamera: true,
          title: 'Live Selfie',
          instruction: 'Center your face in the frame and hold still',
          onCaptured: (bytes) {
            setState(() {
              _selfieBytes = bytes;
              _stage = _Stage.captureId;
            });
          },
          onCancel: () => setState(() => _stage = _Stage.intro),
        );
      case _Stage.captureId:
        return _CameraCaptureView(
          key: const ValueKey('second-cam'),
          preferFrontCamera: true,
          title: 'Live Image Capture',
          instruction: 'Take one more live photo of yourself, then submit',
          onCaptured: (bytes) {
            setState(() {
              _secondBytes = bytes;
              _stage = _Stage.review;
            });
          },
          onCancel: () => setState(() => _stage = _Stage.captureSelfie),
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
          'Take a live selfie and one more live photo of yourself.\nOur team will review and verify your account.',
          style: TheyDiTextStyles.bodySmall.copyWith(color: TheyDiColors.textSecondary),
          textAlign: TextAlign.center,
        ).animate(delay: 150.ms).fade(),
        const SizedBox(height: 32),
        const _StepCard(
          n: '1',
          icon: Icons.camera_front_outlined,
          title: 'Live Selfie',
          sub: 'Center your face and take a quick photo',
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
          icon: Icons.admin_panel_settings_outlined,
          title: 'Manual Review',
          sub: 'Our team verifies within a few hours',
        ),
        const SizedBox(height: 36),
        _GradientButton(
          label: 'Start Verification',
          onTap: () => setState(() => _stage = _Stage.captureSelfie),
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
            onRetake: () => setState(() => _stage = _Stage.captureSelfie),
          ),
          const SizedBox(height: 16),
          _ReviewThumb(
            label: 'Live Image Capture',
            bytes: _secondBytes,
            onRetake: () => setState(() => _stage = _Stage.captureId),
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
          _GradientButton(label: 'Submit for Review', onTap: _submit),
        ],
      ),
    );
  }

  // ── Submit ─────────────────────────────────────────────────────────────
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

      setState(() => _status = 'Submitting for review…');
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      final userName = userDoc.data()?['displayName'] ?? 'User';

      final submitted = await FaceVerificationService.submitVerificationRequest(
        userId: widget.userId,
        userName: userName,
        selfieUrl: selfieUrl,
        secondSelfieUrl: secondUrl,
      );

      if (submitted) {
        setState(() => _stage = _Stage.success);
        widget.onComplete?.call();
      } else {
        _fails++;
        setState(() {
          _stage = _Stage.failed;
          _status = 'Submission failed. Please try again.';
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
          child: const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 52),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 28),
        Text('Documents Submitted! 🎉',
                style: TheyDiTextStyles.displaySmall.copyWith(color: TheyDiColors.textPrimary),
                textAlign: TextAlign.center)
            .animate(delay: 200.ms)
            .fade(),
        const SizedBox(height: 12),
        Text(
          'Your selfie and ID have been sent for review.\nOur team will verify your identity and notify you once done.\n\nThis usually takes a few hours.',
          style: TheyDiTextStyles.bodySmall.copyWith(color: TheyDiColors.textSecondary),
          textAlign: TextAlign.center,
        ).animate(delay: 300.ms).fade(),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: TheyDiColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: TheyDiColors.warning.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.pending_outlined, color: TheyDiColors.warning, size: 16),
            const SizedBox(width: 8),
            Text('Pending Review',
                style: TheyDiTextStyles.labelMedium.copyWith(color: TheyDiColors.warning)),
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
        Text('Submission Failed',
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
// there is NO gallery / file-picker path anywhere in this widget, so the
// only way to produce a photo is to be looking at the live feed and tap
// the shutter button.
// ─────────────────────────────────────────────────────────────────────────────
class _CameraCaptureView extends StatefulWidget {
  final bool preferFrontCamera;
  final String title;
  final String instruction;
  final ValueChanged<Uint8List> onCaptured;
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
        imageFormatGroup: kIsWeb ? ImageFormatGroup.jpeg : ImageFormatGroup.yuv420,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (e) {
      setState(() => _error = 'Could not access camera: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initFuture = _setupCamera();
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) return;

    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      widget.onCaptured(bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Capture failed: $e');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
          child: Column(children: [
            Text(widget.title,
                style: TheyDiTextStyles.labelLarge.copyWith(color: TheyDiColors.textPrimary)),
            const SizedBox(height: 4),
            Text(widget.instruction,
                style: TheyDiTextStyles.caption.copyWith(color: TheyDiColors.textSecondary),
                textAlign: TextAlign.center),
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
                    child: _buildPreview(),
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
              child: _GradientButton(
                label: _capturing ? 'Capturing…' : 'Capture',
                onTap: (_controller != null && !_capturing) ? _capture : null,
              ),
            ),
          ]),
        ),
      ],
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