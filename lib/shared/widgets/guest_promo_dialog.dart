// lib/shared/widgets/guest_promo_dialog.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/router/app_routes.dart';

/// Popup shown to a guest (web-only) when they tap into something that
/// needs an account — Inbox, Profile, Create Experience, My Experiences.
/// The title/message are contextual per screen; the two actions are
/// always the same: Log In or Create Account. Call
/// GuestPromoDialog.show(context, title: ..., message: ...) once when
/// the guest lands on that screen.
class GuestPromoDialog {
  GuestPromoDialog._();

  static Future<void> show(
    BuildContext context, {
    String title = 'Get the full TheyDi experience',
    String message = 'Join events, chat, and connect with people nearby',
  }) {
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
              Text(title,
                  style: TheyDiTextStyles.headlineMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(message,
                  style: TheyDiTextStyles.bodySmall
                      .copyWith(color: TheyDiColors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),

              // ── Log In ──
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
                      context.push(AppRoutes.login);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Log In',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),

              // ── Create Account ──
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push(AppRoutes.signupStep1);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: TheyDiColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Create Account',
                      style: TheyDiTextStyles.labelMedium
                          .copyWith(color: TheyDiColors.textPrimary)),
                ),
              ),

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