import 'package:cloud_functions/cloud_functions.dart';

class ForgotPasswordService {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-south1');

  /// Sends a 6-digit OTP code to the user's email address
  Future<Map<String, dynamic>> sendOtp(String email) async {
    try {
      final callable = _functions.httpsCallable('sendOtp');
      final result = await callable.call({
        "email": email.trim(),
      });
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      return {
        "success": false,
        "message": e.message ?? "Failed to send OTP. Please check your email address."
      };
    } catch (e) {
      return {"success": false, "message": "Connection error: ${e.toString()}"};
    }
  }

  /// Verifies the 6-digit OTP entered by the user
  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final callable = _functions.httpsCallable('verifyOtp');
      final result = await callable.call({
        "email": email.trim(),
        "otp": otp.trim(),
      });
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      return {
        "success": false,
        "message": e.message ?? "Invalid or expired OTP."
      };
    } catch (e) {
      return {"success": false, "message": "Connection error: ${e.toString()}"};
    }
  }

  /// Resets the user's password in Firebase Auth with the new password
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String password,
  }) async {
    try {
      final callable = _functions.httpsCallable('resetPassword');
      final result = await callable.call({
        "email": email.trim(),
        "password": password,
      });
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      return {
        "success": false,
        "message": e.message ?? "Failed to reset password."
      };
    } catch (e) {
      return {"success": false, "message": "Connection error: ${e.toString()}"};
    }
  }
}

