import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/community_model.dart';

/// Generates shareable deep-link for a community.
/// Format: https://theydi.app/community/{communityId}
class CommunityShareService {
  CommunityShareService._();

  static const String _baseUrl = 'https://theydi-cefdf.web.app/community';

  static String communityLink(String communityId) => '$_baseUrl/$communityId';

  /// Builds a rich share text for a community invite.
  static String buildShareText(CommunityModel community) {
    return '👥 Join my community on TheyDi!\n'
        '📌 ${community.name}\n'
        '${community.description.isNotEmpty ? '💬 ${community.description}\n' : ''}'
        '👤 ${community.memberCount} member${community.memberCount == 1 ? '' : 's'}\n\n'
        'Tap to join 👇\n'
        '${communityLink(community.id)}';
  }

  // ── External share URL builders ────────────────────────────────────────────

  static String whatsAppUrl(CommunityModel community) {
    final text = Uri.encodeComponent(buildShareText(community));
    return 'https://wa.me/?text=$text';
  }

  static String instagramUrl(CommunityModel community) => 'instagram://';

  static String facebookUrl(CommunityModel community) {
    final link = Uri.encodeComponent(communityLink(community.id));
    return 'https://www.facebook.com/sharer/sharer.php?u=$link';
  }

  static String twitterUrl(CommunityModel community) {
    final text = Uri.encodeComponent(
        'Join "${community.name}" on TheyDi!\n${communityLink(community.id)}');
    return 'https://twitter.com/intent/tweet?text=$text';
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  static Future<void> copyLink(BuildContext context, CommunityModel community) async {
    await Clipboard.setData(ClipboardData(text: communityLink(community.id)));
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
