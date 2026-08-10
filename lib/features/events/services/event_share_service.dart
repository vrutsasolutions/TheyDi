
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../events/models/event_model.dart';

/// Generates shareable deep-link for an event.
/// Format: https://theydi.app/event/{eventId}
class EventShareService {
  EventShareService._();

  static const String _baseUrl = 'https://theydi-cefdf.web.app/event';

  static String eventLink(String eventId) => '$_baseUrl/$eventId';

  /// Builds a rich share text for an event invite.
  static String buildShareText(EventModel event) {
    final price = event.isFree ? 'Free' : '₹${event.price.toInt()}';
    return '🎉 ${event.title}\n'
        '📅 ${formatShareDate(event.dateTime)}\n'
        '📍 ${event.venue}, ${event.city}\n'
        '💰 $price\n\n'
        'Join me on TheyDi 👇\n'
        '${eventLink(event.id)}';
  }

  /// Human-readable share-friendly date, e.g. "Mon, Aug 10 · 6:30 PM"
  static String formatShareDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day} · $hour:$minute $period';
  }

  // ── External share URL builders ────────────────────────────────────────────

  static String whatsAppUrl(EventModel event) {
    final text = Uri.encodeComponent(buildShareText(event));
    return 'https://wa.me/?text=$text';
  }

  static String instagramUrl(EventModel event) => 'instagram://';

  static String facebookUrl(EventModel event) {
    final link = Uri.encodeComponent(eventLink(event.id));
    return 'https://www.facebook.com/sharer/sharer.php?u=$link';
  }

  static String twitterUrl(EventModel event) {
    final text = Uri.encodeComponent(
        '${event.title} – Join me on TheyDi!\n${eventLink(event.id)}');
    return 'https://twitter.com/intent/tweet?text=$text';
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  static Future<void> copyLink(BuildContext context, EventModel event) async {
    await Clipboard.setData(ClipboardData(text: eventLink(event.id)));
    if (context.mounted) _showToast(context, '🔗 Link copied to clipboard!');
  }

  /// Copies share text (used for Instagram, which has no direct share intent
  /// for arbitrary text — the user pastes it manually into a story/DM).
  static Future<void> copyShareTextForInstagram(
      BuildContext context, EventModel event) async {
    await Clipboard.setData(ClipboardData(text: buildShareText(event)));
    if (context.mounted) {
      _showToast(context, 'Link copied! Paste it in Instagram.');
    }
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