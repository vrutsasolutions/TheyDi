import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'emailjs_service.dart';

class OTPService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate and send OTP
  static Future<bool> sendOTP({
    required String email,
    required String name,
  }) async {
    try {
      // Generate 6 digit OTP
      final otp = (100000 + Random().nextInt(900000)).toString();
      final expiresAt = DateTime.now().add(const Duration(minutes: 10));

      // Store OTP in Firestore
      await _firestore.collection('otps').doc(email).set({
        'otp': otp,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'attempts': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send via EmailJS
      final sent = await EmailJSService.sendOTPEmail(
        toEmail: email,
        toName: name,
        otp: otp,
      );

      return sent;
    } catch (e) {
      print('sendOTP error: $e');
      return false;
    }
  }

  /// Verify OTP entered by user
  static Future<Map<String, dynamic>> verifyOTP({
    required String email,
    required String inputOtp,
  }) async {
    try {
      final doc = await _firestore.collection('otps').doc(email).get();

      // OTP not found
      if (!doc.exists) {
        return {
          'valid': false,
          'message': 'OTP not found. Please request a new one.'
        };
      }

      final data = doc.data()!;
      final storedOtp = data['otp'] as String;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      final attempts = data['attempts'] as int;

      // Expired
      if (DateTime.now().isAfter(expiresAt)) {
        await _firestore.collection('otps').doc(email).delete();
        return {
          'valid': false,
          'message': 'OTP expired. Please request a new one.'
        };
      }

      // Too many attempts
      if (attempts >= 3) {
        await _firestore.collection('otps').doc(email).delete();
        return {
          'valid': false,
          'message': 'Too many attempts. Please request a new OTP.'
        };
      }

      // Wrong OTP
      if (storedOtp != inputOtp) {
        await _firestore.collection('otps').doc(email).update({
          'attempts': attempts + 1,
        });
        return {
          'valid': false,
          'message': 'Invalid OTP. ${2 - attempts} attempts remaining.'
        };
      }

      // Success — delete OTP
      await _firestore.collection('otps').doc(email).delete();
      return {'valid': true, 'message': 'Email verified successfully'};
    } catch (e) {
      print('verifyOTP error: $e');
      return {'valid': false, 'message': 'Verification failed. Try again.'};
    }
  }

  /// Clear OTP (for resend)
  static Future<void> clearOTP(String email) async {
    await _firestore.collection('otps').doc(email).delete();
  }
}
