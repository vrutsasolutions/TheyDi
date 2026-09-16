import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/referral_service.dart';
import '../../../../core/theme/app_theme.dart';

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
        title: const Text('Invite Connections'),
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
                ? const Center(child: Text('Sign in to invite connections.'))
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
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: TheyDiColors.gradientPrimary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: TheyDiColors.primary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.card_giftcard_rounded,
                                color: Colors.white, size: 30),
                          ),
                          const SizedBox(height: 18),
                          Text('Bring your people in',
                              style: TheyDiTextStyles.displayMedium),
                          const SizedBox(height: 8),
                          Text(
                            'Share your invite link with connections who should be on TheyDi.',
                            style: TheyDiTextStyles.bodyMedium
                                .copyWith(color: TheyDiColors.textSecondary),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  TheyDiColors.card,
                                  TheyDiColors.primary.withValues(alpha: 0.06),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color: TheyDiColors.primary
                                      .withValues(alpha: 0.2)),
                              boxShadow: [
                                BoxShadow(
                                  color: TheyDiColors.primary
                                      .withValues(alpha: 0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.qr_code_2_rounded,
                                        size: 14,
                                        color: TheyDiColors.primary),
                                    const SizedBox(width: 6),
                                    Text('Your code',
                                        style: TheyDiTextStyles.caption
                                            .copyWith(
                                                color: TheyDiColors.primary,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  code,
                                  style: TheyDiTextStyles.displaySmall.copyWith(
                                    color: TheyDiColors.primary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: TheyDiColors.textPrimary
                                        .withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.link,
                                          size: 14,
                                          color: TheyDiColors.textMuted),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(link,
                                            style: TheyDiTextStyles.bodySmall
                                                .copyWith(
                                                    color: TheyDiColors
                                                        .textSecondary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _copy(code),
                                  icon: Icon(Icons.copy_outlined,
                                      size: 16, color: TheyDiColors.primary),
                                  label: Text('Copy Link',
                                      style: TheyDiTextStyles.labelMedium
                                          .copyWith(
                                              color: TheyDiColors.primary,
                                              fontWeight: FontWeight.w700)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                        color: TheyDiColors.primary
                                            .withValues(alpha: 0.4)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: TheyDiColors.gradientPrimary,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: TheyDiColors.primary
                                            .withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: () => _share(code),
                                    icon: const Icon(Icons.ios_share_rounded,
                                        size: 16, color: Colors.white),
                                    label: Text('Share',
                                        style: TheyDiTextStyles.labelMedium
                                            .copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                    ),
                                  ),
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