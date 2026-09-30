import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/referral_service.dart';
import '../../../../core/theme/app_theme.dart';

class InviteFriendsScreen extends StatefulWidget {
  const InviteFriendsScreen({super.key});

  @override
  State<InviteFriendsScreen> createState() => _InviteFriendsScreenState();
}

class _InviteFriendsScreenState extends State<InviteFriendsScreen>
    with SingleTickerProviderStateMixin {
  late Future<String> _codeFuture;
  late Future<ReferralStats> _statsFuture;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _codeFuture = ReferralService.instance.ensureReferralCode();
      _statsFuture = ReferralService.instance.getReferralStats();
    });
  }

  String _errorText(Object error) => error is FirebaseFunctionsException
      ? (error.message ?? 'Could not prepare your invite link.')
      : 'Could not prepare your invite link.';

  @override
  Widget build(BuildContext context) {
    final signedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite & Earn'),
        backgroundColor: TheyDiColors.surface,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _reload,
              tooltip: 'Refresh'),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: TheyDiColors.primary,
          labelColor: TheyDiColors.primary,
          unselectedLabelColor: TheyDiColors.textSecondary,
          tabs: const [
            Tab(text: 'Invite & Progress'),
            Tab(text: 'Reward History'),
          ],
        ),
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
          child: !signedIn
              ? const Center(child: Text('Sign in to invite connections.'))
              : FutureBuilder<String>(
                  future: _codeFuture,
                  builder: (ctx, codeSnap) {
                    if (codeSnap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: TheyDiColors.primary));
                    }
                    if (codeSnap.hasError || !codeSnap.hasData) {
                      return Center(
                          child: Text(_errorText(codeSnap.error ?? ''),
                              style: TheyDiTextStyles.bodyMedium,
                              textAlign: TextAlign.center));
                    }
                    final code = codeSnap.data!;
                    return FutureBuilder<ReferralStats>(
                      future: _statsFuture,
                      builder: (ctx2, statsSnap) {
                        final stats =
                            statsSnap.data ?? ReferralStats.empty();
                        final loading = statsSnap.connectionState ==
                            ConnectionState.waiting;
                        return TabBarView(
                          controller: _tabCtrl,
                          children: [
                            _InviteTab(
                                code: code,
                                stats: stats,
                                loading: loading,
                                onShare: () =>
                                    ReferralService.instance.shareInvite(code),
                                onCopy: () =>
                                    ReferralService.instance
                                        .copyInviteLink(context, code)),
                            _HistoryTab(stats: stats, loading: loading),
                          ],
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1 — Invite & Progress
// ═══════════════════════════════════════════════════════════════════════════
class _InviteTab extends StatelessWidget {
  final String code;
  final ReferralStats stats;
  final bool loading;
  final VoidCallback onShare;
  final VoidCallback onCopy;

  const _InviteTab({
    required this.code,
    required this.stats,
    required this.loading,
    required this.onShare,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // Credit balance
        _CreditCard(
            balance: stats.creditBalance,
            totalEarned: stats.totalCreditEarned,
            loading: loading),
        const SizedBox(height: 16),
        // Code card
        _CodeCard(
            code: code,
            link: ReferralService.instance.inviteLink(code),
            onShare: onShare,
            onCopy: onCopy),
        const SizedBox(height: 20),
        // Progress
        if (loading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(
                      color: TheyDiColors.primary)))
        else ...[
          _ProgressCard(
            icon: Icons.people_alt_rounded,
            label: 'Total Referrals',
            progress: stats.normalProgress,
            batchSize: stats.normalMilestoneSize,
            remaining: stats.normalRemainingToNext,
            maxReward: stats.normalMaxReward,
            color: TheyDiColors.primary,
          ).animate().fade(duration: 280.ms),
          const SizedBox(height: 12),
          _ProgressCard(
            icon: Icons.favorite_rounded,
            label: 'Women Referrals',
            progress: stats.womenProgress,
            batchSize: stats.womenMilestoneSize,
            remaining: stats.womenRemainingToNext,
            maxReward: stats.womenMaxReward,
            color: const Color(0xFFE91E8C),
          ).animate().fade(duration: 280.ms, delay: 60.ms),
        ],
        const SizedBox(height: 20),
        _HowItWorks(stats: stats),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 2 — Reward History
// ═══════════════════════════════════════════════════════════════════════════
class _HistoryTab extends StatelessWidget {
  final ReferralStats stats;
  final bool loading;

  const _HistoryTab({required this.stats, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: TheyDiColors.primary));
    }

    if (stats.history.isEmpty && stats.creditHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 48, color: TheyDiColors.textMuted),
            const SizedBox(height: 12),
            Text('No referrals yet',
                style: TheyDiTextStyles.labelMedium
                    .copyWith(color: TheyDiColors.textMuted)),
            const SizedBox(height: 6),
            Text('Share your link to start earning.',
                style: TheyDiTextStyles.caption
                    .copyWith(color: TheyDiColors.textMuted)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // Credit transactions
        if (stats.creditHistory.isNotEmpty) ...[
          Text('Event Credit',
              style: TheyDiTextStyles.labelLarge
                  .copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...stats.creditHistory.map((tx) => _CreditTxRow(tx: tx)),
          const SizedBox(height: 20),
        ],
        // Referral history
        if (stats.history.isNotEmpty) ...[
          Text('Referred Members',
              style: TheyDiTextStyles.labelLarge
                  .copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...stats.history.map((e) => _ReferralRow(entry: e)),
        ],
      ],
    );
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _CreditCard extends StatelessWidget {
  final double balance;
  final double totalEarned;
  final bool loading;

  const _CreditCard(
      {required this.balance,
      required this.totalEarned,
      required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: TheyDiColors.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: loading
          ? const Center(
              child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)))
          : Row(
              children: [
                const Icon(Icons.wallet_rounded,
                    color: Colors.white, size: 34),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Available Credit',
                          style: TheyDiTextStyles.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('₹${balance.toStringAsFixed(2)}',
                          style: TheyDiTextStyles.displayMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 26)),
                      if (totalEarned > 0)
                        Text('Total earned: ₹${totalEarned.toStringAsFixed(2)}',
                            style: TheyDiTextStyles.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
                if (balance > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('Use at checkout',
                        style: TheyDiTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  final String code;
  final String link;
  final VoidCallback onShare;
  final VoidCallback onCopy;

  const _CodeCard(
      {required this.code,
      required this.link,
      required this.onShare,
      required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            TheyDiColors.card,
            TheyDiColors.primary.withValues(alpha: 0.06)
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: TheyDiColors.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: TheyDiColors.primary.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.qr_code_2_rounded,
                size: 14, color: TheyDiColors.primary),
            const SizedBox(width: 6),
            Text('Your invite code',
                style: TheyDiTextStyles.caption.copyWith(
                    color: TheyDiColors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
          ]),
          const SizedBox(height: 8),
          SelectableText(code,
              style: TheyDiTextStyles.displaySmall.copyWith(
                  color: TheyDiColors.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: TheyDiColors.textPrimary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.link, size: 14, color: TheyDiColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(link,
                      style: TheyDiTextStyles.bodySmall
                          .copyWith(color: TheyDiColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCopy,
                icon: Icon(Icons.copy_outlined,
                    size: 16, color: TheyDiColors.primary),
                label: Text('Copy',
                    style: TheyDiTextStyles.labelMedium.copyWith(
                        color: TheyDiColors.primary,
                        fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: TheyDiColors.primary.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
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
                        color: TheyDiColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_rounded,
                      size: 16, color: Colors.white),
                  label: Text('Share',
                      style: TheyDiTextStyles.labelMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int progress;
  final int batchSize;
  final int remaining;
  final double maxReward;
  final Color color;

  const _ProgressCard({
    required this.icon,
    required this.label,
    required this.progress,
    required this.batchSize,
    required this.remaining,
    required this.maxReward,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = batchSize == 0 ? 0.0 : progress / batchSize;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TheyDiTextStyles.labelMedium
                          .copyWith(fontWeight: FontWeight.w700)),
                  Text('Up to ₹${maxReward.toStringAsFixed(0)} per ${batchSize} referrals',
                      style: TheyDiTextStyles.caption
                          .copyWith(color: TheyDiColors.textSecondary)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$progress / $batchSize',
                  style: TheyDiTextStyles.caption
                      .copyWith(color: color, fontWeight: FontWeight.w700)),
              Text(
                  progress == 0
                      ? 'Invite $batchSize eligible members to unlock up to ₹${maxReward.toStringAsFixed(0)} credit.'
                      : 'Invite $remaining more eligible member${remaining == 1 ? '' : 's'} to unlock up to ₹${maxReward.toStringAsFixed(0)} credit.',
                  style: TheyDiTextStyles.caption
                      .copyWith(color: TheyDiColors.textSecondary),
                  textAlign: TextAlign.right),
            ],
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  final ReferralStats stats;
  const _HowItWorks({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How it works',
            style: TheyDiTextStyles.labelLarge
                .copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _Step(number: '1', text: 'Share your code',
            sub: 'Your friend signs up using your invite link or code.'),
        _Step(number: '2', text: 'They book an event',
            sub: 'A referral counts only when they complete their first confirmed, paid event booking.'),
        _Step(number: '3', text: 'Earn proportionally',
            sub: 'Every ${stats.normalMilestoneSize} referrals = up to ₹${stats.normalMaxReward.toStringAsFixed(0)} credit (based on booking amounts). Every ${stats.womenMilestoneSize} women referrals = up to ₹${stats.womenMaxReward.toStringAsFixed(0)}.'),
        _Step(number: '4', text: 'Use at checkout',
            sub: 'Apply your credit balance when booking any paid event. Non-withdrawable.',
            isLast: true),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String text;
  final String sub;
  final bool isLast;

  const _Step(
      {required this.number,
      required this.text,
      required this.sub,
      this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                gradient: TheyDiColors.gradientPrimary,
                shape: BoxShape.circle),
            child: Center(
                child: Text(number,
                    style: TheyDiTextStyles.caption.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700))),
          ),
          if (!isLast)
            Container(width: 2, height: 32, color: TheyDiColors.divider),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text,
                    style: TheyDiTextStyles.labelMedium
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(sub,
                    style: TheyDiTextStyles.caption
                        .copyWith(color: TheyDiColors.textSecondary)),
                SizedBox(height: isLast ? 0 : 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CreditTxRow extends StatelessWidget {
  final CreditTransaction tx;
  const _CreditTxRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isEarned = tx.type == 'referral_reward';
    final color = isEarned ? TheyDiColors.primary : TheyDiColors.error;
    final sign = isEarned ? '+' : '';
    final dateStr = DateFormat('d MMM yy').format(tx.createdAt);
    final label = isEarned
        ? 'Milestone ${tx.milestoneKey ?? ''} reward'
        : 'Used at checkout';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TheyDiColors.divider),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(
              isEarned ? Icons.add_circle_outline : Icons.remove_circle_outline,
              color: color,
              size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TheyDiTextStyles.labelMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(dateStr,
                  style: TheyDiTextStyles.caption
                      .copyWith(color: TheyDiColors.textSecondary)),
            ],
          ),
        ),
        Text('$sign₹${tx.amount.abs().toStringAsFixed(2)}',
            style: TheyDiTextStyles.labelLarge
                .copyWith(color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _ReferralRow extends StatelessWidget {
  final ReferralEntry entry;
  const _ReferralRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isWomen = entry.isWomen;
    final isEligible = entry.isEligible;
    final initial = entry.inviteeName.isNotEmpty
        ? entry.inviteeName[0].toUpperCase()
        : '?';
    final dateStr = entry.attributedAt != null
        ? DateFormat('d MMM yy').format(entry.attributedAt!)
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TheyDiColors.divider),
      ),
      child: Row(children: [
        // Avatar
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: isWomen
                  ? const LinearGradient(
                      colors: [Color(0xFFFF6BAE), Color(0xFFE91E8C)])
                  : TheyDiColors.gradientPrimary,
              borderRadius: BorderRadius.circular(11),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: entry.inviteePhoto.isNotEmpty
                  ? Image.network(entry.inviteePhoto,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                          child: Text(initial,
                              style: TheyDiTextStyles.labelMedium
                                  .copyWith(color: Colors.white))))
                  : Center(
                      child: Text(initial,
                          style: TheyDiTextStyles.labelMedium
                              .copyWith(color: Colors.white))),
            ),
          ),
          if (isWomen)
            Positioned(
              bottom: -4,
              right: -4,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                    color: Color(0xFFE91E8C), shape: BoxShape.circle),
                child: const Center(
                    child: Text('♀',
                        style: TextStyle(
                            fontSize: 8, color: Colors.white, height: 1))),
              ),
            ),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.inviteeName,
                  style: TheyDiTextStyles.labelMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Row(children: [
                Text(dateStr,
                    style: TheyDiTextStyles.caption
                        .copyWith(color: TheyDiColors.textSecondary)),
                if (entry.firstBookingAmount != null) ...[
                  Text(' · ₹${entry.firstBookingAmount!.toStringAsFixed(0)} booking',
                      style: TheyDiTextStyles.caption
                          .copyWith(color: TheyDiColors.textSecondary)),
                ],
              ]),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Status + reward
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: isEligible
                  ? TheyDiColors.primary.withValues(alpha: 0.12)
                  : TheyDiColors.textMuted.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              isEligible ? '✓ Counted' : 'Pending',
              style: TheyDiTextStyles.caption.copyWith(
                  color: isEligible
                      ? TheyDiColors.primary
                      : TheyDiColors.textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 10),
            ),
          ),
          if (entry.calculatedReward != null &&
              entry.calculatedReward! > 0) ...[
            const SizedBox(height: 4),
            Text('+₹${entry.calculatedReward!.toStringAsFixed(2)}',
                style: TheyDiTextStyles.caption.copyWith(
                    color: TheyDiColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 10)),
          ],
        ]),
      ]),
    );
  }
}