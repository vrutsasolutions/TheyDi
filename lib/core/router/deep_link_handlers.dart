// deep_link_handlers.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:theydi/core/router/app_routes.dart';
import 'package:theydi/core/theme/app_theme.dart';
import 'package:theydi/core/utils/platform_helper.dart';
import 'package:theydi/features/events/models/event_model.dart';
import 'package:theydi/features/events/screens/event_detail_screen.dart';
import 'package:theydi/features/circles/models/circle_model.dart';
import 'package:theydi/features/circles/screens/circle_info_screen.dart';

// ── Shared "sign in required" gate used by both deep-link screens below ──
class _SignInRequiredGate extends StatelessWidget {
  final String message;
  final String redirectPath;
  const _SignInRequiredGate(
      {required this.message, required this.redirectPath});

  // TODO: replace with your real store listings once published.
  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.theydi.app';
  static const _appStoreUrl = 'https://apps.apple.com/app/idXXXXXXXXX';

  Future<void> _openApp() async {
    final os = detectMobileOs(); // 'android' | 'ios' | null
    final url = os == 'ios' ? _appStoreUrl : _playStoreUrl;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline,
                  size: 48, color: TheyDiColors.textMuted),
              const SizedBox(height: 16),
              Text(message,
                  style: const TextStyle(color: TheyDiColors.textPrimary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go(
                    AppRoutes.login,
                    extra: {'redirectTo': redirectPath},
                  ),
                  child: const Text('Sign In'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go(AppRoutes.signupStep1),
                  child: const Text('Join TheyDi'),
                ),
              ),
              if (kIsWeb) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _openApp,
                    child: const Text('Get the App'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class DeepLinkEventScreen extends StatelessWidget {
  final String eventId;
  const DeepLinkEventScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) {
    // /events/{id} requires auth per Firestore rules — a guest link-tap
    // can't read it. Ask them to sign in, then send them right back here.
    if (FirebaseAuth.instance.currentUser == null) {
      return _SignInRequiredGate(
        message: 'Sign in to view this event',
        redirectPath: '/event/$eventId',
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection('events').doc(eventId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: TheyDiColors.primary));
          }
          if (snapshot.hasError) {
            return const Center(
                child: Text('Could not load this event',
                    style: TextStyle(color: TheyDiColors.textPrimary)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
                child: Text('Event not found',
                    style: TextStyle(color: TheyDiColors.textPrimary)));
          }
          final event = EventModel.fromFirestore(snapshot.data!);
          return EventDetailScreen(event: event);
        },
      ),
    );
  }
}

class DeepLinkCircleScreen extends StatelessWidget {
  final String circleId;
  const DeepLinkCircleScreen({super.key, required this.circleId});

  @override
  Widget build(BuildContext context) {
    // /circles/{id} also requires auth per Firestore rules — same guard.
    if (FirebaseAuth.instance.currentUser == null) {
      return _SignInRequiredGate(
        message: 'Sign in to view this circle',
        redirectPath: '/circle/$circleId',
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('circles')
            .doc(circleId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: TheyDiColors.primary));
          }
          if (snapshot.hasError) {
            return const Center(
                child: Text('Could not load this circle',
                    style: TextStyle(color: TheyDiColors.textPrimary)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
                child: Text('Circle not found',
                    style: TextStyle(color: TheyDiColors.textPrimary)));
          }
          final circle = CircleModel.fromFirestore(snapshot.data!);

          // A circle can also contain messages/members a non-member
          // shouldn't see. If CircleInfoScreen assumes the viewer is a
          // member (e.g. it queries /circles/{id}/messages), that'll need
          // its own guest-safe check too — flagged below.
          return CircleInfoScreen(circle: circle);
        },
      ),
    );
  }
}