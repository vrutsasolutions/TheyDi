import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ForgotPasswordService {
  // Automatically switches between Local Emulator and Live Server
  static String get baseUrl {
    // Return live URL directly since the Firebase Emulator is not running
    return "https://asia-south1-theydi-cefdf.cloudfunctions.net";
  }

  /// Sends a 6-digit OTP code to the user's email address
  Future<Map<String, dynamic>> sendOtp(String email) async {
    final url = Uri.parse("$baseUrl/sendOtp");

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "email": email.trim(),
        }),
      );



      if (response.statusCode != 200) {
        return {
          "success": false,
          "message": "Server error (${response.statusCode}): ${response.body}"
        };
      }
      return jsonDecode(response.body);
    } catch (e) {
      return {
        "success": false,
        "message": "Connection error: ${e.toString()}"
      };
    }
  }

  /// Verifies the 6-digit OTP entered by the user
  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final url = Uri.parse("$baseUrl/verifyOtp");

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "email": email.trim(),
          "otp": otp.trim(),
        }),
      );



      if (response.statusCode != 200) {
        return {
          "success": false,
          "message": "Server error (${response.statusCode}): ${response.body}"
        };
      }
      return jsonDecode(response.body);
    } catch (e) {
      return {
        "success": false,
        "message": "Connection error: ${e.toString()}"
      };
    }
  }

  /// Resets the user's password in Firebase Auth with the new password
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse("$baseUrl/resetPassword");

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "email": email.trim(),
          "password": password,
        }),
      );



      if (response.statusCode != 200) {
        return {
          "success": false,
          "message": "Server error (${response.statusCode}): ${response.body}"
        };
      }
      return jsonDecode(response.body);
    } catch (e) {
      return {
        "success": false,
        "message": "Connection error: ${e.toString()}"
      };
    }
  }
}