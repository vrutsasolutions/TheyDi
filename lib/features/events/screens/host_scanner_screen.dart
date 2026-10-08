// ─────────────────────────────────────────────────────────────────────────────
// HostScannerScreen — Camera QR scanner for event hosts
//
// Route args (via GoRouter extra map):
//   eventId    : String
//   eventTitle : String
//
// Features:
//   • mobile_scanner camera viewfinder (Android + Web)
//   • Real-time "Checked In: X / Y" counter via attendanceStream
//   • Three scan result overlays:
//       ✓  checked_in          → green
//       ⚠  already_checked_in  → amber
//       ✕  invalid             → red
//   • Manual code entry fallback (paste/type QR payload)
//   • Prevents double-processing while a scan is in flight
//   • Torch toggle (Android only — gracefully hidden on web)
//
// File 10 in the QR Check-in series.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_theme.dart';
import '../services/qr_checkin_service.dart';

class HostScannerScreen extends StatefulWidget {
  final String eventId;
  final String eventTitle;

  const HostScannerScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  State<HostScannerScreen> createState() => _HostScannerScreenState();
}

class _HostScannerScreenState extends State<HostScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _scannerCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  StreamSubscription<Map<String, int>>? _attendanceSub;
  int _checkedInCount = 0;
  int _totalCount = 0;

  _ScanResultState? _scanResult;
  Timer? _overlayTimer;
  bool _processing = false;
  bool _torchOn = false;

  final _manualCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startAttendanceStream();
    _loadTotalCount();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scannerCtrl.start();
    else if (state == AppLifecycleState.paused) _scannerCtrl.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerCtrl.dispose();
    _attendanceSub?.cancel();
    _overlayTimer?.cancel();
    _manualCtrl.dispose();
    super.dispose();
  }

  void _startAttendanceStream() {
    _attendanceSub = QrCheckInService.attendanceStream(widget.eventId).listen((data) {
      if (mounted) setState(() => _checkedInCount = data['checkedIn'] ?? 0);
    });
  }

  Future<void> _loadTotalCount() async {
    final count = await QrCheckInService.confirmedAttendeeCount(widget.eventId);
    if (mounted) setState(() => _totalCount = count);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    _processPayload(raw);
  }

  Future<void> _processPayload(String payload) async {
    if (_processing) return;
    setState(() => _processing = true);
    await _scannerCtrl.stop();

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final result = await QrCheckInService.validateAndCheckIn(
      qrPayload: payload,
      eventId: widget.eventId,
      hostUid: uid,
    );

    HapticFeedback.mediumImpact();

    _ScanResultState scanState;
    if (result.success) {
      scanState = _ScanResultState.checkedIn(
        name: result.attendeeName ?? 'Attendee', time: result.checkedInAt ?? '');
    } else if (result.isAlreadyCheckedIn) {
      scanState = _ScanResultState.alreadyCheckedIn(
        name: result.attendeeName ?? 'Attendee');
    } else {
      scanState = _ScanResultState.invalid(
        message: result.errorMessage ?? 'Invalid QR code.');
    }

    if (!mounted) return;
    setState(() { _scanResult = scanState; _processing = false; });

    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) { setState(() => _scanResult = null); _scannerCtrl.start(); }
    });
  }

  void _toggleTorch() {
    _scannerCtrl.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  void _showManualEntry() {
    _scannerCtrl.stop();
    _manualCtrl.clear();
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TheyDiColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Enter QR Code', style: TheyDiTextStyles.headlineMedium),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Ask the attendee to copy their QR payload and paste it here.',
            style: TheyDiTextStyles.bodySmall.copyWith(color: TheyDiColors.textSecondary)),
          const SizedBox(height: 14),
          TextField(
            controller: _manualCtrl,
            autofocus: true,
            style: TheyDiTextStyles.labelMedium.copyWith(fontFamily: 'monospace', fontSize: 12),
            decoration: InputDecoration(
              hintText: 'theydi:checkin:...',
              hintStyle: TheyDiTextStyles.caption.copyWith(color: TheyDiColors.textMuted),
              filled: true, fillColor: TheyDiColors.card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TheyDiTextStyles.labelMedium.copyWith(color: TheyDiColors.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, _manualCtrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: TheyDiColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Validate', style: TextStyle(color: Colors.white))),
        ],
      ),
    ).then((payload) {
      if (payload != null && payload.isNotEmpty) _processPayload(payload);
      else _scannerCtrl.start();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        MobileScanner(controller: _scannerCtrl, onDetect: _onDetect),
        _ScannerOverlay(),
        // Top bar
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(children: [
              _CircleBtn(icon: Icons.arrow_back_ios_new, onTap: () => Navigator.of(context).pop()),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Scan QR Codes',
                  style: TheyDiTextStyles.displayMedium.copyWith(color: Colors.white)),
                Text(widget.eventTitle,
                  style: TheyDiTextStyles.caption.copyWith(color: Colors.white70),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              if (!kIsWeb)
                _CircleBtn(
                  icon: _torchOn ? Icons.flashlight_off_rounded : Icons.flashlight_on_rounded,
                  onTap: _toggleTorch),
            ]),
          )),
        ),
        // Attendance counter
        Positioned(
          top: 100, right: 20,
          child: _AttendanceCounter(
            checkedIn: _checkedInCount, total: _totalCount,
          ).animate().fade(duration: 400.ms)),
        // Scan frame
        Center(child: _ScanFrame()),
        // Bottom bar
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: SafeArea(child: _BottomBar(onManualEntry: _showManualEntry))),
        // Result overlay
        if (_scanResult != null)
          _ScanResultOverlay(
            result: _scanResult!,
            onDismiss: () {
              _overlayTimer?.cancel();
              setState(() => _scanResult = null);
              _scannerCtrl.start();
            },
          ),
        // Processing spinner
        if (_processing)
          const ColoredBox(
            color: Colors.black38,
            child: Center(child: CircularProgressIndicator(color: Colors.white))),
      ]),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _VignettePainter(), child: const SizedBox.expand());
}

class _VignettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double cutout = 240;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: cutout, height: cutout),
        const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.62));
  }
  @override bool shouldRepaint(covariant CustomPainter _) => false;
}

class _ScanFrame extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 240, height: 240, child: CustomPaint(painter: _CornerPainter()));
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const len = 28.0; const thick = 3.5; const r = 16.0;
    final p = Paint()..color = Colors.white..strokeWidth = thick..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    // top-left
    canvas.drawLine(Offset(r, 0), Offset(r + len, 0), p);
    canvas.drawLine(Offset(0, r), Offset(0, r + len), p);
    canvas.drawArc(Rect.fromLTWH(0, 0, r*2, r*2), -3.14159, 3.14159/2, false, p);
    // top-right
    canvas.drawLine(Offset(size.width - r - len, 0), Offset(size.width - r, 0), p);
    canvas.drawLine(Offset(size.width, r), Offset(size.width, r + len), p);
    canvas.drawArc(Rect.fromLTWH(size.width - r*2, 0, r*2, r*2), -3.14159/2, 3.14159/2, false, p);
    // bottom-left
    canvas.drawLine(Offset(r, size.height), Offset(r + len, size.height), p);
    canvas.drawLine(Offset(0, size.height - r - len), Offset(0, size.height - r), p);
    canvas.drawArc(Rect.fromLTWH(0, size.height - r*2, r*2, r*2), 3.14159/2, 3.14159/2, false, p);
    // bottom-right
    canvas.drawLine(Offset(size.width - r - len, size.height), Offset(size.width - r, size.height), p);
    canvas.drawLine(Offset(size.width, size.height - r - len), Offset(size.width, size.height - r), p);
    canvas.drawArc(Rect.fromLTWH(size.width - r*2, size.height - r*2, r*2, r*2), 0, 3.14159/2, false, p);
  }
  @override bool shouldRepaint(covariant CustomPainter _) => false;
}

class _AttendanceCounter extends StatelessWidget {
  final int checkedIn; final int total;
  const _AttendanceCounter({required this.checkedIn, required this.total});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        color: Colors.black.withValues(alpha: 0.65),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$checkedIn',
            style: TheyDiTextStyles.displayLarge.copyWith(color: Colors.white, fontSize: 28, height: 1)),
          const SizedBox(height: 2),
          Text(total > 0 ? 'of $total' : 'checked in',
            style: TheyDiTextStyles.caption.copyWith(color: Colors.white60)),
          const SizedBox(height: 2),
          Text('Checked In',
            style: TheyDiTextStyles.caption.copyWith(color: Colors.greenAccent, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final VoidCallback onManualEntry;
  const _BottomBar({required this.onManualEntry});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(gradient: LinearGradient(
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text("Point the camera at an attendee's QR code",
          style: TheyDiTextStyles.caption.copyWith(color: Colors.white70),
          textAlign: TextAlign.center),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity, height: 50,
          child: OutlinedButton.icon(
            onPressed: onManualEntry,
            icon: const Icon(Icons.keyboard_outlined, size: 18, color: Colors.white70),
            label: Text('Enter Code Manually',
              style: TheyDiTextStyles.labelMedium.copyWith(color: Colors.white70)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ),
      ]),
    );
  }
}

class _ScanResultState {
  final _ScanOutcome outcome;
  final String primaryText;
  final String secondaryText;
  const _ScanResultState._({required this.outcome, required this.primaryText, required this.secondaryText});

  factory _ScanResultState.checkedIn({required String name, required String time}) =>
      _ScanResultState._(outcome: _ScanOutcome.checkedIn,
        primaryText: '✓  Checked In', secondaryText: name.isNotEmpty ? name : 'Attendee');

  factory _ScanResultState.alreadyCheckedIn({required String name}) =>
      _ScanResultState._(outcome: _ScanOutcome.alreadyCheckedIn,
        primaryText: '⚠  Already Checked In',
        secondaryText: name.isNotEmpty ? '$name has already been checked in.' : 'This ticket was already scanned.');

  factory _ScanResultState.invalid({required String message}) =>
      _ScanResultState._(outcome: _ScanOutcome.invalid,
        primaryText: '✕  Invalid Ticket', secondaryText: message);

  Color get color => switch (outcome) {
    _ScanOutcome.checkedIn => const Color(0xFF16A34A),
    _ScanOutcome.alreadyCheckedIn => const Color(0xFFD97706),
    _ScanOutcome.invalid => const Color(0xFFDC2626),
  };

  IconData get icon => switch (outcome) {
    _ScanOutcome.checkedIn => Icons.check_circle_rounded,
    _ScanOutcome.alreadyCheckedIn => Icons.warning_amber_rounded,
    _ScanOutcome.invalid => Icons.cancel_rounded,
  };
}

enum _ScanOutcome { checkedIn, alreadyCheckedIn, invalid }

class _ScanResultOverlay extends StatelessWidget {
  final _ScanResultState result;
  final VoidCallback onDismiss;
  const _ScanResultOverlay({required this.result, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: result.color.withValues(alpha: 0.88),
        child: SafeArea(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(result.icon, color: Colors.white, size: 80)
              .animate().scale(begin: const Offset(0.4, 0.4), end: const Offset(1.0, 1.0),
                duration: 300.ms, curve: Curves.elasticOut),
          const SizedBox(height: 20),
          Text(result.primaryText, style: const TextStyle(color: Colors.white, fontSize: 26,
              fontWeight: FontWeight.w800, height: 1.1), textAlign: TextAlign.center)
            .animate(delay: 80.ms).fade(duration: 250.ms),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(result.secondaryText,
              style: const TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w500, height: 1.4),
              textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis)
              .animate(delay: 120.ms).fade(duration: 250.ms)),
          const SizedBox(height: 40),
          Text('Tap anywhere to scan next',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13))
            .animate(delay: 1800.ms).fade(duration: 400.ms),
        ]))),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}