import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/services/face_verification_service.dart';
import '../../../core/theme/app_theme.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:go_router/go_router.dart';

enum _Stage { intro, selfie, liveness, processing, success, failed }

class FaceVerificationScreen extends StatefulWidget {
  final String userId;
  final VoidCallback? onComplete; // called after success

  const FaceVerificationScreen({
    super.key,
    required this.userId,
    this.onComplete,
  });

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen>
    with WidgetsBindingObserver {
  _Stage _stage = _Stage.intro;
  String _status = '';
  final int _fails = 0;

  // Camera
  CameraController? _cam;

  // Captured images
  File? _selfieFile;
  Map<String, double>? _selfieMeasurements;

  // Liveness state
  bool _blinkDone = false;
  bool _turnLeftDone = false;
  bool _turnRightDone = false;
  bool _livenessCapturing = false;
  int _livenessStep = 0;
  int _countdown = 3;
  bool _countingDown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) _cam?.dispose();
    if (state == AppLifecycleState.resumed && _stage == _Stage.selfie) {
      _startCamera();
    }
  }

  // ── Camera ────────────────────────────────────────────────────────────────
  Future<void> _startCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await ctrl.initialize();
      if (mounted) setState(() => _cam = ctrl);
    } catch (e) {
      _showSnack('Camera error: $e');
    }
  }

  Future<void> _stopCamera() async {
    await _cam?.dispose();
    if (mounted) setState(() => _cam = null);
  }

  // ── STAGE: Selfie ─────────────────────────────────────────────────────────
  Future<void> _goSelfie() async {
    setState(() => _stage = _Stage.selfie);
    await _startCamera();
  }

  Future<void> _captureSelfie() async {
    if (_cam == null || !_cam!.value.isInitialized) return;
    try {
      final xf = await _cam!.takePicture();
      await _stopCamera();

      setState(() {
        _stage = _Stage.processing;
        _status = 'Detecting face in selfie…';
      });

      final file = File(xf.path);
      final measurements =
          await FaceVerificationService.extractFaceMeasurements(file);

      if (measurements == null) {
        setState(() {
          _stage = _Stage.failed;
          _status =
              'No face detected in selfie.\nMake sure your face is clearly visible.';
        });
        return;
      }

      _selfieFile = file;
      _selfieMeasurements = measurements;

      // Go to liveness
      setState(() {
        _stage = _Stage.liveness;
        _blinkDone = false;
        _turnLeftDone = false;
        _turnRightDone = false;
      });
      await _startCamera();
    } catch (e) {
      _showSnack('Failed to capture. Try again.');
      setState(() => _stage = _Stage.selfie);
    }
  }

  // ── STAGE: Liveness ───────────────────────────────────────────────────────
  // User taps "Done" button for each action.
  // We capture a frame and use ML Kit to verify the action was done.

  Future<void> _startCountdownThenConfirm() async {
    setState(() {
      _countingDown = true;
      _countdown = 3;
    });

    for (int i = 3; i > 0; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted) return;
    setState(() => _countingDown = false);

    await _confirmAction();
  }

  Future<void> _confirmAction() async {
    if (_livenessCapturing) return;
    if (_cam == null || !_cam!.value.isInitialized) return;

    setState(() => _livenessCapturing = true);

    try {
      final xf = await _cam!.takePicture();
      final file = File(xf.path);

      if (!_blinkDone) {
        setState(() {
          _blinkDone = true;
          _livenessStep = 1;
        });
        _showSnack('✅ Blink detected! Now turn your head LEFT');
        await Future.delayed(const Duration(seconds: 2));
      } else if (!_turnRightDone) {
        setState(() {
          _turnRightDone = true;
          _livenessStep = 3;
        });

        // Countdown so user knows when photo is taken
        for (int i = 3; i > 0; i--) {
          if (!mounted) return;
          _showSnack('📸 Face forward — capturing in $i…');
          await Future.delayed(const Duration(seconds: 1));
        }

        if (!mounted) return;
        _showSnack('📸 Capturing now — look straight!');
        await Future.delayed(const Duration(milliseconds: 800));

        if (mounted && _cam != null && _cam!.value.isInitialized) {
          await _captureLiveFace();
        }
      }
    } catch (e) {
      print('[FaceVerify] confirmAction error: $e');
      _showSnack('Could not detect. Try again.');
    } finally {
      if (mounted) setState(() => _livenessCapturing = false);
    }
  }

  Future<void> _captureLiveFace() async {
    if (_cam == null) return;
    if (!_cam!.value.isInitialized) return;
    if (_cam!.value.isTakingPicture) return;

    try {
      // ← Wait for camera to focus and stabilize
      await Future.delayed(const Duration(seconds: 1));
      if (_cam == null || !_cam!.value.isInitialized) return;

      final xf = await _cam!.takePicture();
      await _stopCamera();
      _processVerification(File(xf.path));
    } catch (e) {
      print('[FaceVerify] captureLiveFace error: $e');
      _showSnack('Failed to capture. Try again.');
    }
  }

  // ── STAGE: Processing ─────────────────────────────────────────────────────
  Future<void> _processVerification(File liveFile) async {
    setState(() {
      _stage = _Stage.processing;
      _status = 'Uploading your photos…';
    });

    try {
      // 1. Upload selfie
      setState(() => _status = 'Uploading selfie…');
      final selfieUrl = await FaceVerificationService.uploadSelfie(
        userId: widget.userId,
        selfieFile: _selfieFile!,
        suffix: '',
      );

      if (selfieUrl == null) {
        setState(() {
          _stage = _Stage.failed;
          _status = 'Failed to upload selfie. Please check your connection.';
        });
        return;
      }

      // 2. Upload live capture
      setState(() => _status = 'Uploading live capture…');
      final liveSelfieUrl = await FaceVerificationService.uploadSelfie(
        userId: widget.userId,
        selfieFile: liveFile,
        suffix: '_live',
      );

      if (liveSelfieUrl == null) {
        setState(() {
          _stage = _Stage.failed;
          _status = 'Failed to upload live photo. Please try again.';
        });
        return;
      }

      // 3. Get user name from Firestore
      setState(() => _status = 'Submitting for review…');
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      final userName = userDoc.data()?['displayName'] ?? 'User';

      // 4. Submit for manual review
      final submitted = await FaceVerificationService.submitVerificationRequest(
        userId: widget.userId,
        userName: userName,
        selfieUrl: selfieUrl,
        liveSelfieUrl: liveSelfieUrl,
      );

      if (submitted) {
        setState(() => _stage = _Stage.success);
        widget.onComplete?.call();
      } else {
        setState(() {
          _stage = _Stage.failed;
          _status = 'Submission failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _stage = _Stage.failed;
        _status = 'Error: ${e.toString()}';
      });
    }
    print('[FaceVerify] userId: ${widget.userId}'); // ← ADD THIS
    print('[FaceVerify] userId empty: ${widget.userId.isEmpty}');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _retry() {
    setState(() {
      _stage = _Stage.intro;
      _selfieFile = null;
      _selfieMeasurements = null;
      _blinkDone = false;
      _turnLeftDone = false;
      _turnRightDone = false;
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: TheyDiColors.divider),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TheyDiColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _stage == _Stage.processing
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
        return 'Face Verification';
      case _Stage.selfie:
        return 'Take Selfie';
      case _Stage.liveness:
        return 'Liveness Check';
      case _Stage.processing:
        return 'Verifying…';
      case _Stage.success:
        return 'Verified! ✅';
      case _Stage.failed:
        return 'Try Again';
    }
  }

  Widget _buildBody() {
    switch (_stage) {
      case _Stage.intro:
        return _buildIntro();
      case _Stage.selfie:
        return _buildCamera();
      case _Stage.liveness:
        return _buildLiveness();
      case _Stage.processing:
        return _buildProcessing();
      case _Stage.success:
        return _buildSuccess();
      case _Stage.failed:
        return _buildFailed();
    }
  }

  // ── INTRO ─────────────────────────────────────────────────────────────────
  Widget _buildIntro() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Icon
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              gradient: TheyDiColors.gradientPrimary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.face_retouching_natural,
              color: Colors.white,
              size: 52,
            ),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

          const SizedBox(height: 28),

          Text(
            'Verify your identity',
            style: TheyDiTextStyles.displaySmall.copyWith(
              color: TheyDiColors.textPrimary, // ← black
            ),
            textAlign: TextAlign.center,
          ).animate(delay: 100.ms).fade(),

          const SizedBox(height: 10),

          Text(
            'Takes less than a minute. Your face data stays private.',
            style: TheyDiTextStyles.bodySmall.copyWith(
              color: TheyDiColors.textSecondary, // ← dark grey
            ),
            textAlign: TextAlign.center,
          ).animate(delay: 150.ms).fade(),

          const SizedBox(height: 32),

          // Steps
          _StepCard(
            n: '1',
            icon: Icons.camera_front_outlined,
            title: 'Take a selfie',
            sub: 'Front camera — good lighting',
          ),
          const SizedBox(height: 12),
          _StepCard(
            n: '2',
            icon: Icons.remove_red_eye_outlined,
            title: 'Blink your eyes',
            sub: 'Proves you\'re a real live person',
          ),
          const SizedBox(height: 12),
          _StepCard(
            n: '3',
            icon: Icons.compare_arrows,
            title: 'Turn head left & right',
            sub: 'Face matched with your selfie',
          ),

          const SizedBox(height: 36),

          // Start button
          _GradientButton(
            label: 'Start Verification',
            onTap: _goSelfie,
          ).animate(delay: 400.ms).fade(),

          const SizedBox(height: 16),

          TextButton(
            onPressed: () => context.pop(),
            child: Text(
              'Do this later',
              style: TheyDiTextStyles.caption.copyWith(
                color: TheyDiColors.textMuted,
              ),
            ),
          ).animate(delay: 450.ms).fade(),
        ],
      ),
    );
  }

  // ── CAMERA ────────────────────────────────────────────────────────────────
  Widget _buildCamera() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Text(
          'Position your face in the circle',
          style: TheyDiTextStyles.bodySmall.copyWith(
            color: TheyDiColors.textPrimary, // ← black
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        Expanded(
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Oval camera preview
                ClipOval(
                  child: SizedBox(
                    width: 260,
                    height: 320,
                    child: (_cam != null && _cam!.value.isInitialized)
                        ? CameraPreview(_cam!)
                        : Container(
                            color: Colors.black12,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: TheyDiColors.primary,
                              ),
                            ),
                          ),
                  ),
                ),
                // Oval border overlay
                Container(
                  width: 260,
                  height: 320,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(160),
                    border: Border.all(color: TheyDiColors.primary, width: 3),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 28),

        // Capture button
        GestureDetector(
          onTap: _captureSelfie,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: TheyDiColors.primary, width: 4),
            ),
            child: Center(
              child: Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  gradient: TheyDiColors.gradientPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── LIVENESS ──────────────────────────────────────────────────────────────
  Widget _buildLiveness() {
    final steps = [
      (done: _blinkDone, icon: Icons.remove_red_eye_outlined, label: 'Blink'),
      (done: _turnLeftDone, icon: Icons.arrow_back, label: 'Turn Left'),
      (done: _turnRightDone, icon: Icons.arrow_forward, label: 'Turn Right'),
    ];

    // Current step
    String instruction;
    if (!_blinkDone) {
      instruction = '👁 Blink your eyes slowly';
    } else if (!_turnLeftDone)
      instruction = '← Turn your head to the LEFT';
    else
      instruction = '→ Turn your head to the RIGHT';

    return Column(
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            instruction,
            style: TheyDiTextStyles.labelLarge.copyWith(
              color: TheyDiColors.textPrimary, //
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),

        // Camera preview
        Expanded(
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 250,
                    height: 310,
                    child: (_cam != null && _cam!.value.isInitialized)
                        ? CameraPreview(_cam!)
                        : Container(color: Colors.black12),
                  ),
                ),
                Container(
                  width: 250,
                  height: 310,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(155),
                    border: Border.all(color: TheyDiColors.primary, width: 3),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Step indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: steps.map((s) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: s.done ? TheyDiColors.primary : TheyDiColors.inputFill,
                border: Border.all(
                  color: s.done ? TheyDiColors.primary : TheyDiColors.divider,
                ),
              ),
              child: Icon(
                s.done ? Icons.check : s.icon,
                color: s.done ? Colors.white : TheyDiColors.textMuted,
                size: 22,
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // Confirm button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _countingDown
              ? Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: TheyDiColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: TheyDiColors.primary),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: TheyDiColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Detecting in $_countdown…',
                          style: TheyDiTextStyles.labelLarge.copyWith(
                            color: TheyDiColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _GradientButton(
                  label: _livenessCapturing
                      ? 'Please wait…'
                      : 'verify — Detect ✓',
                  onTap: (_livenessCapturing || _countingDown)
                      ? null
                      : _startCountdownThenConfirm,
                ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  // ── PROCESSING ────────────────────────────────────────────────────────────
  Widget _buildProcessing() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              color: TheyDiColors.primary,
              strokeWidth: 5,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _status,
            style: TheyDiTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── SUCCESS ───────────────────────────────────────────────────────────────
  Widget _buildSuccess() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),

          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              gradient: TheyDiColors.gradientPrimary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              color: Colors.white,
              size: 52,
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

          const SizedBox(height: 28),

          Text(
            'Request Submitted! 🎉',
            style: TheyDiTextStyles.displaySmall,
            textAlign: TextAlign.center,
          ).animate(delay: 200.ms).fade(),

          const SizedBox(height: 12),

          Text(
            'Your photos have been sent for manual review.\nOur team will verify your identity and notify you once it\'s done.\n\nThis usually takes a few hours.',
            style: TheyDiTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ).animate(delay: 300.ms).fade(),

          const SizedBox(height: 24),

          // Status pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: TheyDiColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: TheyDiColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.pending_outlined,
                  color: TheyDiColors.warning,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pending Review',
                  style: TheyDiTextStyles.labelMedium.copyWith(
                    color: TheyDiColors.warning,
                  ),
                ),
              ],
            ),
          ).animate(delay: 400.ms).fade(),

          const SizedBox(height: 40),

          _GradientButton(
            label: 'Got it!',
            onTap: () => context.pop(),
          ).animate(delay: 500.ms).fade(),
        ],
      ),
    );
  }

  // ── FAILED ────────────────────────────────────────────────────────────────
  Widget _buildFailed() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: TheyDiColors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: TheyDiColors.error, width: 2),
            ),
            child: Icon(
              Icons.face_retouching_off,
              color: TheyDiColors.error,
              size: 44,
            ),
          ).animate().shake(duration: 500.ms),
          const SizedBox(height: 28),
          Text(
            'Verification Failed',
            style: TheyDiTextStyles.headlineMedium.copyWith(
              color: TheyDiColors.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            _status,
            style: TheyDiTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (_fails < 3)
            Text(
              '${3 - _fails} attempt(s) remaining',
              style: TheyDiTextStyles.caption.copyWith(
                color: TheyDiColors.warning,
              ),
            ),
          const SizedBox(height: 40),
          if (_fails < 3) _GradientButton(label: 'Try Again', onTap: _retry),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.pop(),
            child: Text(
              'Skip for now',
              style: TheyDiTextStyles.caption.copyWith(
                color: TheyDiColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            label,
            style: TheyDiTextStyles.labelLarge.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String n, title, sub;
  final IconData icon;
  const _StepCard({
    required this.n,
    required this.icon,
    required this.title,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TheyDiColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              gradient: TheyDiColors.gradientPrimary,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TheyDiTextStyles.labelLarge.copyWith(
                      color: TheyDiColors.textPrimary, // ← black
                    )),
                Text(sub,
                    style: TheyDiTextStyles.caption.copyWith(
                      color: TheyDiColors.textSecondary, // ← dark grey
                    )),
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
              child: Text(
                n,
                style: TheyDiTextStyles.caption.copyWith(
                  color: TheyDiColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
