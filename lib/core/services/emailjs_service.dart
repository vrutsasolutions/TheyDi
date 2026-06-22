import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailJSService {
  // Paste your EmailJS keys here
  static const String _serviceId = 'service_bwvuxh8';
  static const String _otpTemplateId = 'template_m9o5rjx';
  static const String _notifTemplateId = 'template_01jcw7u';
  static const String _publicKey = 'NoGpT1SchJ8I8ffHU';
  static const String _apiUrl = 'https://api.emailjs.com/api/v1.0/email/send';

  /// Send OTP Email
  static Future<bool> sendOTPEmail({
    required String toEmail,
    required String toName,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': _serviceId,
          'template_id': _otpTemplateId,
          'user_id': _publicKey,
          'template_params': {
            'to_email': toEmail,
            'to_name': toName,
            'otp_code': otp,
          },
        }),
      );

      if (response.statusCode == 200) {
        print('OTP email sent to $toEmail');
        return true;
      } else {
        print('EmailJS error: ${response.body}');
        return false;
      }
    } catch (e) {
      print('sendOTPEmail error: $e');
      return false;
    }
  }

  /// Send Notification Email (events/friends only)
  static Future<bool> sendNotificationEmail({
    required String toEmail,
    required String toName,
    required String title,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': _serviceId,
          'template_id': _notifTemplateId,
          'user_id': _publicKey,
          'template_params': {
            'to_email': toEmail,
            'to_name': toName,
            'notification_title': title,
            'notification_message': message,
          },
        }),
      );

      if (response.statusCode == 200) {
        print('Notification email sent to $toEmail');
        return true;
      } else {
        print('EmailJS error: ${response.body}');
        return false;
      }
    } catch (e) {
      print('sendNotificationEmail error: $e');
      return false;
    }
  }
}