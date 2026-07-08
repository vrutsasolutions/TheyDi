import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ForgotPasswordService {
  // Automatically switches between Local Emulator and Live Server
  static String get baseUrl {
    if (kDebugMode) {
      if (!kIsWeb && Platform.isAndroid) {
        return "http://10.0.2.2:5001/theydi-cefdf/asia-south1";
      }
      return "http://127.0.0.1:5001/theydi-cefdf/asia-south1";
    }
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

      print("STATUS: ${response.statusCode}");
      print("BODY: ${response.body}");

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

      print("STATUS: ${response.statusCode}");
      print("BODY: ${response.body}");

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

      print("STATUS: ${response.statusCode}");
      print("BODY: ${response.body}");

      return jsonDecode(response.body);
    } catch (e) {
      return {
        "success": false,
        "message": "Connection error: ${e.toString()}"
      };
    }
  }
}