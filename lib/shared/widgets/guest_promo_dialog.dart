// lib/shared/widgets/guest_promo_banner.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/router/app_routes.dart';
import '../../core/utils/platform_helper.dart';

/// Popup dialog shown to guests browsing a shared profile, event, or
/// circle link on the web. Prompts them to either join in the browser
/// or grab the native app. Call GuestPromoDialog.show(context) once,
/// after the screen's data has finished loading.
class GuestPromoDialog {
  GuestPromoDialog._();

  // TODO: replace with your real store listings once published.
  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.theydi.app';
  static const _appStoreUrl = 'https://apps.apple.com/app/idXXXXXXXXX';

  static Future<void> _openApp() async {
    final os = detectMobileOs(); // 'android' | 'ios' | null
    final url = os == 'ios' ? _appStoreUrl : _playStoreUrl;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: TheyDiColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/theydi_logo.png',
                  width: 64,
                  height: 64,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: TheyDiColors.gradientPrimary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text('T',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 28)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Get the full TheyDi experience',
                  style: TheyDiTextStyles.headlineMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text('Join events, chat, and connect with people nearby',
                  style: TheyDiTextStyles.bodySmall
                      .copyWith(color: TheyDiColors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: TheyDiColors.gradientPrimary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push(AppRoutes.signupStep1);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Join TheyDi',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              if (kIsWeb) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openApp();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: TheyDiColors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Get the App',
                        style: TheyDiTextStyles.labelMedium
                            .copyWith(color: TheyDiColors.textPrimary)),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Maybe later',
                    style: TheyDiTextStyles.caption
                        .copyWith(color: TheyDiColors.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}