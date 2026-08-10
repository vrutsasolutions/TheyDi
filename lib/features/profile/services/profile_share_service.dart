import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Generates shareable deep-link for a user profile.
/// Format: https://theydi.app/user/{userId}
class ProfileShareService {
  ProfileShareService._();

  static const String _baseUrl = 'https://theydi-cefdf.web.app/user';

  static String profileLink(String userId) => '$_baseUrl/$userId';

  /// Builds rich share text for a profile invite.
  static String buildShareText({
    required String userId,
    required String displayName,
    required String city,
    required String bio,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('👤 Check out $displayName\'s profile on TheyDi!');
    if (city.isNotEmpty) buffer.writeln('📍 $city');
    if (bio.isNotEmpty) buffer.writeln('💬 $bio');
    buffer.writeln();
    buffer.writeln('Connect on TheyDi 👇');
    buffer.write(profileLink(userId));
    return buffer.toString();
  }

  // ── External URL builders ──────────────────────────────────────────────────

  static String whatsAppUrl({
    required String userId,
    required String displayName,
    required String city,
    required String bio,
  }) {
    final text = Uri.encodeComponent(buildShareText(
      userId: userId,
      displayName: displayName,
      city: city,
      bio: bio,
    ));
    return 'https://wa.me/?text=$text';
  }

  static String instagramUrl() => 'instagram://';

  static String facebookUrl(String userId) {
    final link = Uri.encodeComponent(profileLink(userId));
    return 'https://www.facebook.com/sharer/sharer.php?u=$link';
  }

  static String twitterUrl({
    required String userId,
    required String displayName,
  }) {
    final text = Uri.encodeComponent(
        'Connect with $displayName on TheyDi!\n${profileLink(userId)}');
    return 'https://twitter.com/intent/tweet?text=$text';
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  static Future<void> copyLink(BuildContext context, String userId) async {
    await Clipboard.setData(ClipboardData(text: profileLink(userId)));
    if (context.mounted) _showToast(context, '🔗 Profile link copied!');
  }

  static Future<bool> launchExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  static void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
