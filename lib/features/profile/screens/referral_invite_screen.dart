import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/services/referral_service.dart';
import '../../../core/theme/app_theme.dart';

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
                      const Icon(Icons.group_add_outlined,
                          color: TheyDiColors.primary, size: 54),
                      const SizedBox(height: 18),
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
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: waiting || !valid ? null : _continue,
                        child: Text(
                          FirebaseAuth.instance.currentUser == null
                              ? 'Join TheyDi'
                              : 'Open TheyDi',
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: ReferralService.instance.openStore,
                        child: const Text('Get the App'),
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
