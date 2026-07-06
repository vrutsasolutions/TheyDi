import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/circle_join_service.dart';
import '../../../core/services/notification_service.dart';
import 'package:theydi/features/circles/models/circle_model.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _joinedCirclesProvider =
    StreamProvider.autoDispose<List<CircleModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('circles')
      .where('memberUids', arrayContains: uid)
      .orderBy('lastMessageAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => CircleModel.fromFirestore(d)).toList());
});

final _pendingCircleRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return [];

  // Find circles where user has a pending join request
  final circlesSnap = await FirebaseFirestore.instance
      .collection('circles')
      .limit(100)
      .get();

  final pending = <Map<String, dynamic>>[];
  for (final doc in circlesSnap.docs) {
    final requestDoc = await FirebaseFirestore.instance
        .collection('circles')
        .doc(doc.id)
        .collection('joinRequests')
        .doc(uid)
        .get();
    if (requestDoc.exists &&
        (requestDoc.data()?['status'] as String?) == 'pending') {
      final data = doc.data();
      pending.add({
        'id': doc.id,
        'name': data['name'] ?? '',
        'description': data['description'] ?? '',
        'memberCount':
            (data['memberUids'] as List?)?.length ?? 0,
        'creatorName': data['creatorName'] ?? '',
      });
    }
  }
  return pending;
});

final _suggestedCirclesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return CircleJoinService.getSuggestedCircles();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class CircleDiscoveryScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const CircleDiscoveryScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<CircleDiscoveryScreen> createState() =>
      _CircleDiscoveryScreenState();
}

class _CircleDiscoveryScreenState
    extends ConsumerState<CircleDiscoveryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );

    // Fire suggested circles notification
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final suggestions = await CircleJoinService.getSuggestedCircles();
      if (suggestions.isNotEmpty) {
        await NotificationService.notifySuggestedCircles(
          toUid: uid,
          count: suggestions.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            children: [
              // ── App Bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: TheyDiColors.textPrimary),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 4),
                    Text('Friend Circles',
                        style: TheyDiTextStyles.displayMedium),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.push(AppRoutes.circles),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: TheyDiColors.gradientPrimary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.group_outlined,
                                color: Colors.white, size: 15),
                            const SizedBox(width: 5),
                            Text('My Circles',
                                style: TheyDiTextStyles.labelMedium
                                    .copyWith(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fade(duration: 300.ms),

              const SizedBox(height: 12),

              // ── Tab Bar ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: TheyDiColors.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: TheyDiColors.primary,
                  unselectedLabelColor: TheyDiColors.textSecondary,
                  labelStyle: TheyDiTextStyles.labelMedium,
                  tabs: const [
                    Tab(text: 'Joined'),
                    Tab(text: 'Pending'),
                    Tab(text: 'Suggested'),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _JoinedTab(),
                    _PendingCirclesTab(),
                    _SuggestedCirclesTab(
                      onTabSwitch: () => _tabController.animateTo(2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — JOINED CIRCLES
// ══════════════════════════════════════════════════════════════════════════════

class _JoinedTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final joinedAsync = ref.watch(_joinedCirclesProvider);

    return joinedAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: TheyDiColors.primary)),
      error: (e, _) =>
          Center(child: Text('Error: $e', style: TheyDiTextStyles.bodySmall)),
      data: (circles) {
        if (circles.isEmpty) {
          return _EmptyState(
            icon: Icons.group_outlined,
            title: 'No circles yet',
            subtitle: 'Join a circle or create one to get started',
            actionLabel: 'Browse Suggested',
            onAction: null, // handled externally if needed
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: circles.length,
          itemBuilder: (ctx, i) => _JoinedCircleCard(circle: circles[i])
              .animate(delay: Duration(milliseconds: 50 * i))
              .fade(duration: 300.ms)
              .slideX(begin: 0.05, end: 0),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — PENDING REQUESTS
// ══════════════════════════════════════════════════════════════════════════════

class _PendingCirclesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(_pendingCircleRequestsProvider);

    return pendingAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: TheyDiColors.primary)),
      error: (e, _) =>
          Center(child: Text('Error: $e', style: TheyDiTextStyles.bodySmall)),
      data: (pending) {
        if (pending.isEmpty) {
          return const _EmptyState(
            icon: Icons.hourglass_empty_outlined,
            title: 'No pending requests',
            subtitle: 'Circles you have requested to join will appear here',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: pending.length,
          itemBuilder: (ctx, i) {
            final p = pending[i];
            return _PendingCircleCard(
              circleId: p['id'] ?? '',
              circleName: p['name'] ?? '',
              description: p['description'] ?? '',
              memberCount: p['memberCount'] ?? 0,
              creatorName: p['creatorName'] ?? '',
            )
                .animate(delay: Duration(milliseconds: 60 * i))
                .fade(duration: 300.ms)
                .slideY(begin: 0.1, end: 0);
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — SUGGESTED CIRCLES
// ══════════════════════════════════════════════════════════════════════════════

class _SuggestedCirclesTab extends ConsumerWidget {
  final VoidCallback? onTabSwitch;
  const _SuggestedCirclesTab({this.onTabSwitch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestedAsync = ref.watch(_suggestedCirclesProvider);

    return suggestedAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: TheyDiColors.primary)),
      error: (e, _) =>
          Center(child: Text('Error: $e', style: TheyDiTextStyles.bodySmall)),
      data: (suggestions) {
        if (suggestions.isEmpty) {
          return const _EmptyState(
            icon: Icons.explore_outlined,
            title: 'No suggestions yet',
            subtitle:
                'Update your city and interests in your profile for better circle suggestions',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: suggestions.length,
          itemBuilder: (ctx, i) {
            final s = suggestions[i];
            return _SuggestedCircleCard(
              circleId: s['id'] ?? '',
              circleName: s['name'] ?? '',
              description: s['description'] ?? '',
              memberCount: s['memberCount'] ?? 0,
              creatorUid: s['creatorUid'] ?? '',
              creatorName: s['creatorName'] ?? '',
            )
                .animate(delay: Duration(milliseconds: 60 * i))
                .fade(duration: 300.ms)
                .slideY(begin: 0.1, end: 0);
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _JoinedCircleCard extends StatelessWidget {
  final CircleModel circle;
  const _JoinedCircleCard({required this.circle});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return GestureDetector(
      onTap: () => context.push(AppRoutes.circleChat, extra: circle),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: TheyDiColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TheyDiColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: TheyDiColors.gradientPrimary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(circle.initials,
                    style: TheyDiTextStyles.displayMedium
                        .copyWith(color: Colors.white, fontSize: 18)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(circle.name,
                            style: TheyDiTextStyles.labelLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (circle.lastMessageAt != null)
                        Text(_timeAgo(circle.lastMessageAt!),
                            style: TheyDiTextStyles.caption
                                .copyWith(color: TheyDiColors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (circle.lastMessage != null &&
                      circle.lastMessage!.isNotEmpty)
                    Text(
                      circle.lastMessageSender == uid
                          ? 'You: ${circle.lastMessage}'
                          : '${circle.lastMessageSender ?? ''}: ${circle.lastMessage}',
                      style: TheyDiTextStyles.caption
                          .copyWith(color: TheyDiColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text('${circle.memberCount} members · Tap to chat',
                        style: TheyDiTextStyles.caption
                            .copyWith(color: TheyDiColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: TheyDiColors.textMuted),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dateTime.day}/${dateTime.month}';
  }
}

// ── Pending Circle Card ───────────────────────────────────────────────────────

class _PendingCircleCard extends StatelessWidget {
  final String circleId;
  final String circleName;
  final String description;
  final int memberCount;
  final String creatorName;

  const _PendingCircleCard({
    required this.circleId,
    required this.circleName,
    required this.description,
    required this.memberCount,
    required this.creatorName,
  });

  @override
  Widget build(BuildContext context) {
    final initials = circleName.isNotEmpty
        ? circleName.substring(0, circleName.length >= 2 ? 2 : 1).toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: TheyDiColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: TheyDiColors.gradientPrimary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(initials,
                  style: TheyDiTextStyles.displayMedium
                      .copyWith(color: Colors.white, fontSize: 16)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(circleName, style: TheyDiTextStyles.labelLarge),
                if (description.isNotEmpty)
                  Text(description,
                      style: TheyDiTextStyles.caption
                          .copyWith(color: TheyDiColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                Text('$memberCount members · By $creatorName',
                    style: TheyDiTextStyles.caption
                        .copyWith(color: TheyDiColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: TheyDiColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: TheyDiColors.primary.withValues(alpha: 0.4)),
            ),
            child: Text('Pending',
                style: TheyDiTextStyles.caption
                    .copyWith(color: TheyDiColors.primary, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

// ── Suggested Circle Card ─────────────────────────────────────────────────────

class _SuggestedCircleCard extends StatefulWidget {
  final String circleId;
  final String circleName;
  final String description;
  final int memberCount;
  final String creatorUid;
  final String creatorName;

  const _SuggestedCircleCard({
    required this.circleId,
    required this.circleName,
    required this.description,
    required this.memberCount,
    required this.creatorUid,
    required this.creatorName,
  });

  @override
  State<_SuggestedCircleCard> createState() => _SuggestedCircleCardState();
}

class _SuggestedCircleCardState extends State<_SuggestedCircleCard> {
  bool _loading = false;
  bool _requested = false;

  Future<void> _requestToJoin() async {
    setState(() => _loading = true);
    await CircleJoinService.sendJoinRequest(
      circleId: widget.circleId,
      circleName: widget.circleName,
      adminUid: widget.creatorUid,
    );
    if (mounted) setState(() {_loading = false; _requested = true;});
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.circleName.isNotEmpty
        ? widget.circleName
            .substring(0, widget.circleName.length >= 2 ? 2 : 1)
            .toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TheyDiColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: TheyDiColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(initials,
                      style: TheyDiTextStyles.displayMedium
                          .copyWith(color: Colors.white, fontSize: 16)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.circleName, style: TheyDiTextStyles.labelLarge),
                    if (widget.description.isNotEmpty)
                      Text(widget.description,
                          style: TheyDiTextStyles.caption.copyWith(
                              color: TheyDiColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    Text('${widget.memberCount} members · By ${widget.creatorName}',
                        style: TheyDiTextStyles.caption
                            .copyWith(color: TheyDiColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: _requested
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: TheyDiColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: TheyDiColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Text('Request Sent ✓',
                          style: TheyDiTextStyles.labelMedium
                              .copyWith(color: TheyDiColors.primary)),
                    ),
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: TheyDiColors.gradientPrimary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ElevatedButton(
                      onPressed: _loading ? null : _requestToJoin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.group_add_outlined,
                                    size: 15, color: Colors.white),
                                const SizedBox(width: 6),
                                Text('Request to Join',
                                    style: TheyDiTextStyles.labelMedium
                                        .copyWith(color: Colors.white)),
                              ],
                            ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: Colors.grey[700]),
            const SizedBox(height: 20),
            Text(title, style: TheyDiTextStyles.headlineMedium),
            const SizedBox(height: 8),
            Text(subtitle,
                style: TheyDiTextStyles.bodySmall
                    .copyWith(color: TheyDiColors.textSecondary),
                textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: TheyDiColors.gradientPrimary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(actionLabel!,
                      style: TheyDiTextStyles.labelLarge
                          .copyWith(color: Colors.white)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
