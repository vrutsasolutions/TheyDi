import 'package:cloud_functions/cloud_functions.dart';

class EmailJSService {
  /// Send OTP Email (Using Cloud Functions now, keeping method name to avoid breaking imports)
  static Future<bool> sendOTPEmail({
    required String toEmail,
    required String toName,
    required String otp,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('sendSignupOtpEmail');
          
      await callable.call({
        'toEmail': toEmail,
        'toName': toName,
        'otp': otp,
      });

      print('OTP email sent to $toEmail via Cloud Functions');
      return true;
    } catch (e) {
      print('sendOTPEmail error: $e');
      return false;
    }
  }

  /// Send Notification Email (Using Cloud Functions now)
  static Future<bool> sendNotificationEmail({
    required String toEmail,
    required String toName,
    required String title,
    required String message,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('sendSystemNotificationEmail');
          
      await callable.call({
        'toEmail': toEmail,
        'toName': toName,
        'title': title,
        'message': message,
      });

      print('Notification email sent to $toEmail via Cloud Functions');
      return true;
    } catch (e) {
      print('sendNotificationEmail error: $e');
      return false;
    }
  }
}