// lib/debug/otp_test_screen.dart
//
// TEMPORARY debug screen — just for manually testing your EXISTING
// OTPService (the current Firestore-based version) end-to-end, without
// needing to wire up your real signup/forgot-password screens yet.
//
// HOW TO USE:
//   1. Add this file to your project (e.g. lib/debug/otp_test_screen.dart)
//   2. Temporarily point your app's home route to OtpTestScreen(), OR
//      push it from anywhere with:
//        Navigator.push(context, MaterialPageRoute(builder: (_) => const OtpTestScreen()));
//   3. Run the app, enter a real email you can check, tap "Send OTP"
//   4. Check your inbox for the code, type it in, tap "Verify OTP"
//   5. Delete this file once you're done testing (it's not meant for
//      production — it has no styling, no validation polish, just raw
//      buttons to exercise the service).
//
// WIRE-UP NEEDED FROM YOU:
//   Update the import path below to match wherever your actual
//   otp_service.dart currently lives (e.g. 'package:theydi/services/otp_service.dart').

import 'package:flutter/material.dart';
import '../core/services/otp_service.dart';

class OtpTestScreen extends StatefulWidget {
  const OtpTestScreen({super.key});

  @override
  State<OtpTestScreen> createState() => _OtpTestScreenState();
}

class _OtpTestScreenState extends State<OtpTestScreen> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController(text: 'Test User');
  final _otpController = TextEditingController();

  String _log = '';
  bool _isLoading = false;

  void _appendLog(String line) {
    setState(() {
      _log =
          '$_log\n${DateTime.now().toIso8601String().substring(11, 19)}  $line';
    });
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty) {
      _appendLog('❌ Enter an email first.');
      return;
    }

    setState(() => _isLoading = true);
    _appendLog('Sending OTP to $email ...');

    try {
      final success = await OTPService.sendOTP(email: email, name: name);
      if (success) {
        _appendLog(
            '✅ sendOTP() returned true — check your inbox for the code.');
      } else {
        _appendLog(
            '❌ sendOTP() returned false — check console/logs for the error.');
      }
    } catch (e) {
      _appendLog('❌ sendOTP() threw an exception: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    if (email.isEmpty || otp.isEmpty) {
      _appendLog('❌ Enter both email and the code you received.');
      return;
    }

    setState(() => _isLoading = true);
    _appendLog('Verifying code $otp for $email ...');

    try {
      final result = await OTPService.verifyOTP(email: email, inputOtp: otp);
      final valid = result['valid'] == true;
      final message = result['message'] ?? '(no message)';
      _appendLog(valid ? '✅ Valid: $message' : '❌ Invalid: $message');
    } catch (e) {
      _appendLog('❌ verifyOTP() threw an exception: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testWrongOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _appendLog('❌ Enter an email first.');
      return;
    }

    setState(() => _isLoading = true);
    _appendLog('Trying an intentionally WRONG code (000000) for $email ...');

    try {
      final result =
          await OTPService.verifyOTP(email: email, inputOtp: '000000');
      final valid = result['valid'] == true;
      // We expect this to be false — if it's somehow true, that's a bug.
      _appendLog(valid
          ? '⚠️ UNEXPECTED: wrong code was accepted! (${result['message']})'
          : '✅ Correctly rejected: ${result['message']}');
    } catch (e) {
      _appendLog('❌ threw an exception: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OTP Service — Debug Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Use a real email you can check. This screen calls your '
              'existing OTPService directly — delete this file once done testing.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name (for email greeting)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _sendOtp,
              child: const Text('1. Send OTP'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _otpController,
              decoration: const InputDecoration(
                labelText: 'Enter code from email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOtp,
                    child: const Text('2. Verify OTP'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _testWrongOtp,
                    child: const Text('Test wrong code'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Log:', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  reverse: true,
                  child: Text(
                    _log.isEmpty ? '(nothing yet)' : _log,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
