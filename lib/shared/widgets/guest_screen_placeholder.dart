// lib/shared/widgets/guest_screen_placeholder.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_theme.dart';
import 'guest_promo_dialog.dart';

/// Drop-in replacement for a gated screen's body when the visitor is a
/// guest (web-only). Shows the contextual GuestPromoDialog once, then
/// leaves a neutral placeholder in its place — with its own small
/// "Log In" fallback in case the dialog gets dismissed — instead of the
/// real screen (which needs a signed-in user's data).
///
/// Usage inside an existing screen's build():
///   final isGuest = kIsWeb && ref.watch(isGuestModeProvider);
///   if (isGuest) {
///     return const GuestScreenPlaceholder(
///       icon: Icons.person_outline,
///       dialogTitle: 'This is your profile',
///       dialogMessage: 'Log in or create an account to set up your '
///           'profile and get discovered by people nearby.',
///       placeholderText: 'Log in to see your profile',
///     );
///   }
///   // ...existing body, unchanged
class GuestScreenPlaceholder extends StatefulWidget {
  final IconData icon;
  final String dialogTitle;
  final String dialogMessage;
  final String placeholderText;
  final String? appBarTitle;

  const GuestScreenPlaceholder({
    super.key,
    required this.icon,
    required this.dialogTitle,
    required this.dialogMessage,
    required this.placeholderText,
    this.appBarTitle,
  });

  @override
  State<GuestScreenPlaceholder> createState() =>
      _GuestScreenPlaceholderState();
}

class _GuestScreenPlaceholderState extends State<GuestScreenPlaceholder> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GuestPromoDialog.show(
        context,
        title: widget.dialogTitle,
        message: widget.dialogMessage,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.appBarTitle != null
          ? AppBar(
              title: Text(widget.appBarTitle!),
              backgroundColor: Colors.transparent,
              elevation: 0,
            )
          : null,
      backgroundColor: TheyDiColors.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 40, color: TheyDiColors.textMuted),
              const SizedBox(height: 12),
              Text(
                widget.placeholderText,
                style: TheyDiTextStyles.bodySmall
                    .copyWith(color: TheyDiColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.push(AppRoutes.login),
                child: Text('Log In',
                    style: TheyDiTextStyles.labelMedium
                        .copyWith(color: TheyDiColors.primary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}