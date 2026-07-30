import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../circles/models/circle_model.dart';

/// Generates shareable deep-link for a circle.
/// Format: https://theydi.app/circle/{circleId}
class CircleShareService {
  CircleShareService._();

  static const String _baseUrl = 'https://theydi-cefdf.web.app/circle';

  static String circleLink(String circleId) => '$_baseUrl/$circleId';

  /// Builds a rich share text for a circle invite.
  static String buildShareText(CircleModel circle) {
    final typeLabel = circle.isEventCircle ? 'event circle' : 'circle';
    return '👥 Join my $typeLabel on TheyDi!\n'
        '📌 ${circle.name}\n'
        '${circle.description.isNotEmpty ? '💬 ${circle.description}\n' : ''}'
        '👤 ${circle.memberCount} member${circle.memberCount == 1 ? '' : 's'}\n\n'
        'Tap to join 👇\n'
        '${circleLink(circle.id)}';
  }

  // ── External share URL builders ────────────────────────────────────────────

  static String whatsAppUrl(CircleModel circle) {
    final text = Uri.encodeComponent(buildShareText(circle));
    return 'https://wa.me/?text=$text';
  }

  static String instagramUrl(CircleModel circle) => 'instagram://';

  static String facebookUrl(CircleModel circle) {
    final link = Uri.encodeComponent(circleLink(circle.id));
    return 'https://www.facebook.com/sharer/sharer.php?u=$link';
  }

  static String twitterUrl(CircleModel circle) {
    final text = Uri.encodeComponent(
        'Join "${circle.name}" on TheyDi!\n${circleLink(circle.id)}');
    return 'https://twitter.com/intent/tweet?text=$text';
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  static Future<void> copyLink(BuildContext context, CircleModel circle) async {
    await Clipboard.setData(ClipboardData(text: circleLink(circle.id)));
    if (context.mounted) _showToast(context, '🔗 Link copied to clipboard!');
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
        backgroundColor: Theme.of(context).colorScheme.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
