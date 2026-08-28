import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/services/referral_service.dart';
import '../../../core/theme/app_theme.dart';

class InviteFriendsScreen extends StatefulWidget {
  const InviteFriendsScreen({super.key});

  @override
  State<InviteFriendsScreen> createState() => _InviteFriendsScreenState();
}

class _InviteFriendsScreenState extends State<InviteFriendsScreen> {
  late final Future<String> _codeFuture;

  @override
  void initState() {
    super.initState();
    _codeFuture = ReferralService.instance.ensureReferralCode();
  }

  Future<void> _share(String code) async {
    await ReferralService.instance.shareInvite(code);
  }

  Future<void> _copy(String code) async {
    await ReferralService.instance.copyInviteLink(context, code);
  }

  String _errorText(Object error) {
    if (error is FirebaseFunctionsException) {
      return error.message ?? 'Could not prepare your invite link.';
    }
    return 'Could not prepare your invite link.';
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Friends'),
        backgroundColor: TheyDiColors.surface,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [TheyDiColors.cardLight, TheyDiColors.surface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: !signedIn
                ? const Center(child: Text('Sign in to invite friends.'))
                : FutureBuilder<String>(
                    future: _codeFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: TheyDiColors.primary,
                          ),
                        );
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return Center(
                          child: Text(
                            _errorText(snapshot.error ?? ''),
                            style: TheyDiTextStyles.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      final code = snapshot.data!;
                      final link = ReferralService.instance.inviteLink(code);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bring your people in',
                              style: TheyDiTextStyles.displayMedium),
                          const SizedBox(height: 8),
                          Text(
                            'Share your invite link with friends who should be on TheyDi.',
                            style: TheyDiTextStyles.bodyMedium
                                .copyWith(color: TheyDiColors.textSecondary),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: TheyDiColors.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: TheyDiColors.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Your code', style: TheyDiTextStyles.caption),
                                const SizedBox(height: 6),
                                SelectableText(
                                  code,
                                  style: TheyDiTextStyles.displaySmall.copyWith(
                                    color: TheyDiColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(link, style: TheyDiTextStyles.bodySmall),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _copy(code),
                                  icon: const Icon(Icons.copy_outlined),
                                  label: const Text('Copy Link'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _share(code),
                                  icon: const Icon(Icons.share_outlined),
                                  label: const Text('Share'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
