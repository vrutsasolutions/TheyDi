// lib/shared/widgets/guest_promo_banner.dart  — NEW FILE, create this
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/router/app_routes.dart';
import '../../core/utils/platform_helper.dart';

/// Persistent bottom banner shown to guests browsing a shared profile,
/// event, or circle link on the web. Prompts them to either join in the
/// browser or grab the native app — same pattern as Instagram/Pinterest's
/// web "Get the app" banners. Only render this when the viewer is a guest.
class GuestPromoBanner extends StatefulWidget {
  const GuestPromoBanner({super.key});

  @override
  State<GuestPromoBanner> createState() => _GuestPromoBannerState();
}

class _GuestPromoBannerState extends State<GuestPromoBanner> {
  bool _dismissed = false;

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
    if (_dismissed) return const SizedBox.shrink();

    return Material(
      color: TheyDiColors.card,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: TheyDiColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text('T',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Get the full TheyDi experience',
                        style: TheyDiTextStyles.labelMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('Join events, chat, and connect nearby',
                        style: TheyDiTextStyles.caption
                            .copyWith(color: TheyDiColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () => context.push(AppRoutes.signupStep1),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: TheyDiColors.divider),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Join',
                    style: TheyDiTextStyles.caption.copyWith(
                        color: TheyDiColors.textPrimary,
                        fontWeight: FontWeight.w700)),
              ),
              if (kIsWeb) ...[
                const SizedBox(width: 6),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: TheyDiColors.gradientPrimary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextButton(
                    onPressed: _openApp,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Get App',
                        style: TheyDiTextStyles.caption.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.close,
                    size: 18, color: TheyDiColors.textMuted),
                onPressed: () => setState(() => _dismissed = true),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}