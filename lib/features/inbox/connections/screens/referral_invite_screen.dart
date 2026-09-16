import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/services/referral_service.dart';
import '../../../../core/theme/app_theme.dart';

class ReferralInviteScreen extends StatefulWidget {
  final String referralCode;

  const ReferralInviteScreen({super.key, required this.referralCode});

  @override
  State<ReferralInviteScreen> createState() => _ReferralInviteScreenState();
}

class _ReferralInviteScreenState extends State<ReferralInviteScreen> {
  late final Future<ReferralCodeValidation> _validationFuture;

  @override
  void initState() {
    super.initState();
    final code = ReferralService.instance.normalizeReferralCode(widget.referralCode);
    ReferralService.instance.savePendingReferralCode(code);
    _validationFuture = ReferralService.instance.validateReferralCode(code);
  }

  Future<void> _continue() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (mounted) context.go(AppRoutes.home);
      return;
    }
    if (mounted) context.go(AppRoutes.signupStep1);
  }

  @override
  Widget build(BuildContext context) {
    final code = ReferralService.instance.normalizeReferralCode(widget.referralCode);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [TheyDiColors.cardLight, TheyDiColors.surface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: FutureBuilder<ReferralCodeValidation>(
                future: _validationFuture,
                builder: (context, snapshot) {
                  final waiting =
                      snapshot.connectionState == ConnectionState.waiting;
                  final validation = snapshot.data;
                  final valid = validation?.valid == true;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: TheyDiColors.gradientPrimary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: TheyDiColors.primary.withValues(alpha: 0.3),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.group_add_outlined,
                            color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        valid && validation?.referrerName != null
                            ? '${validation!.referrerName} invited you to TheyDi'
                            : 'You are invited to TheyDi',
                        style: TheyDiTextStyles.displayMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        waiting
                            ? 'Checking invite...'
                            : valid
                                ? 'Use code $code when you join. We will keep it ready through signup.'
                                : validation?.error ?? 'This invite link is invalid.',
                        style: TheyDiTextStyles.bodyMedium.copyWith(
                          color: valid || waiting
                              ? TheyDiColors.textSecondary
                              : TheyDiColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: waiting || !valid
                              ? null
                              : TheyDiColors.gradientPrimary,
                          color: waiting || !valid
                              ? TheyDiColors.divider
                              : null,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: waiting || !valid
                              ? null
                              : [
                                  BoxShadow(
                                    color: TheyDiColors.primary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                        ),
                        child: ElevatedButton(
                          onPressed: waiting || !valid ? null : _continue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            disabledBackgroundColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            FirebaseAuth.instance.currentUser == null
                                ? 'Join TheyDi'
                                : 'Open TheyDi',
                            style: TheyDiTextStyles.labelLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: ReferralService.instance.openStore,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: TheyDiColors.primary
                                  .withValues(alpha: 0.35)),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('Get the App',
                            style: TheyDiTextStyles.labelLarge
                                .copyWith(color: TheyDiColors.primary)),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}