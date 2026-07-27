import 'package:flutter/material.dart';

/// Centralized utility for converting technical errors into user-friendly messages.
class AppErrorUtils {
  AppErrorUtils._();

  /// Converts technical exception strings into clean, polite, human-readable user messages.
  static String getFriendlyMessage(dynamic error) {
    if (error == null) return 'Something went wrong. Please try again.';

    String msg = error.toString().trim();

    // Clean technical prefixes
    msg = msg.replaceAll(RegExp(r'^(Exception|Error|HttpsError):\s*'), '');
    msg = msg.replaceAll(RegExp(r'\[[a-zA-Z0-9_\-\/]+\]\s*'), '');

    final lower = msg.toLowerCase();

    // Common Auth errors
    if (lower.contains('invalid-credential') ||
        lower.contains('wrong-password') ||
        lower.contains('user-not-found')) {
      return 'Incorrect email or password. Please check your details and try again.';
    }

    if (lower.contains('email-already-in-use')) {
      return 'An account with this email already exists. Please sign in instead.';
    }

    if (lower.contains('weak-password')) {
      return 'Please choose a stronger password (at least 6 characters).';
    }

    if (lower.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }

    // Network & Connectivity errors
    if (lower.contains('network-request-failed') ||
        lower.contains('unavailable') ||
        lower.contains('socketexception') ||
        lower.contains('connection failed')) {
      return 'Network issue. Please check your internet connection and try again.';
    }

    // Permission & Auth state errors
    if (lower.contains('permission-denied')) {
      return 'Access denied. You do not have permission to perform this action.';
    }

    if (lower.contains('unauthenticated')) {
      return 'Your session has expired. Please log in again.';
    }

    if (lower.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }

    // Payment & Payout errors
    if (lower.contains('ip not whitelisted')) {
      return 'Payment gateway configuration issue. Please contact support.';
    }

    if (lower.contains('payout account') ||
        (lower.contains('failed-precondition') && lower.contains('payout'))) {
      return 'Please complete your payout account details in Personal Details first.';
    }

    // Parse JSON error messages if present
    if (msg.contains('{') && msg.contains('}')) {
      final match = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(msg);
      if (match != null && match.group(1) != null) {
        return match.group(1)!;
      }
      return 'An error occurred while processing your request. Please try again.';
    }

    // Format remaining plain text string cleanly
    if (msg.isNotEmpty) {
      // Remove any leading punctuation or spaces
      msg = msg.replaceAll(RegExp(r'^[\s:_]+'), '');
      if (msg.isNotEmpty) {
        msg = msg[0].toUpperCase() + msg.substring(1);
        if (!msg.endsWith('.') && !msg.endsWith('!') && !msg.endsWith('?')) {
          msg = '$msg.';
        }
      }
    }

    return msg.isEmpty ? 'Something went wrong. Please try again.' : msg;
  }

  /// Displays a floating, user-friendly error SnackBar.
  static void showErrorSnackBar(BuildContext context, dynamic error) {
    final message = getFriendlyMessage(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
