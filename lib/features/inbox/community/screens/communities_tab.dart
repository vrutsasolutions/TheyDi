import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../models/community_model.dart';
import '../services/community_service.dart';
import '../../inbox_shared_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ══════════════════════════════════════════════════════════════════════════

// User city stream for location-based community suggestions.
final _userCityForCommProvider = StreamProvider.autoDispose<String>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value('');
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => (doc.data()?['city'] as String?) ?? '');
});

// All communities, client-filtered into My/Suggestions/Requested below.
// Simple for now — same "real logic comes later" placeholder spirit as the
// Home feed's Social/Professional classification: a proper recommendation
// query (by interest, location, mutual members) can replace the
// client-side split later.
final allCommunitiesProvider =
    StreamProvider.autoDispose<List<CommunityModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('communities')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => CommunityModel.fromFirestore(d)).toList());
});

final myCommunityRequestsProvider =
    StreamProvider.autoDispose<List<CommunityJoinRequest>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('communityRequests')
      .snapshots()
      .map((s) =>
          s.docs.map((d) => CommunityJoinRequest.fromFirestore(d)).toList());
});

// ══════════════════════════════════════════════════════════════════════════
// SHELL — nested sub-tab bar (My Communities / Suggestions / Requested)
// ══════════════════════════════════════════════════════════════════════════

class CommunitiesTab extends ConsumerStatefulWidget {
  const CommunitiesTab({super.key});

  @override
  ConsumerState<CommunitiesTab> createState() => _CommunitiesTabState();
}

class _CommunitiesTabState extends ConsumerState<CommunitiesTab>
    with SingleTickerProviderStateMixin {
  static const _tabs = ['My Communities', 'Suggestions', 'Requested'];
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final allAsync = ref.watch(allCommunitiesProvider);
    final requestsAsync = ref.watch(myCommunityRequestsProvider);
    final userCity = ref.watch(_userCityForCommProvider).asData?.value ?? '';
    final requestedCount = requestsAsync.asData?.value.length ?? 0;

    return allAsync.when(
      data: (all) {
        final requestedIds =
            (requestsAsync.asData?.value ?? []).map((r) => r.communityId).toSet();
        final myCommunities = all.where((c) => c.isMember(uid)).toList();
        final suggestions = all
            .where((c) => !c.isMember(uid) && !requestedIds.contains(c.id))
            .toList()
          ..sort((a, b) {
            // City-matching communities first, then by member count
            final aCity = userCity.isNotEmpty && a.city.toLowerCase() == userCity.toLowerCase();
            final bCity = userCity.isNotEmpty && b.city.toLowerCase() == userCity.toLowerCase();
            if (aCity && !bCity) return -1;
            if (!aCity && bCity) return 1;
            return b.memberCount.compareTo(a.memberCount);
          });
        final requested = all.where((c) => requestedIds.contains(c.id)).toList();

        return Column(
          children: [
            InboxSubTabBar(
              controller: _tabController,
              tabs: _tabs,
              badges: {2: requestedCount},
            ).animate().fade(duration: 250.ms),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _CommunityList(
                    communities: myCommunities,
                    uid: uid,
                    emptyIcon: Icons.diversity_3_outlined,
                    emptyTitle: 'No communities yet',
                    emptyMessage:
                        'Communities you join will show up here.',
                  ),
                  _CommunityList(
                    communities: suggestions,
                    uid: uid,
                    emptyIcon: Icons.explore_outlined,
                    emptyTitle: 'No suggestions right now',
                    emptyMessage:
                        'Check back soon for communities to join.',
                  ),
                  _CommunityList(
                    communities: requested,
                    uid: uid,
                    isPendingList: true,
                    emptyIcon: Icons.hourglass_empty,
                    emptyTitle: 'No pending requests',
                    emptyMessage:
                        'Communities you\'ve asked to join will show up here.',
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: TheyDiColors.primary)),
      error: (e, st) => const Center(
        child: InboxEmptyState(
          icon: Icons.error_outline,
          title: 'Something went wrong',
          message: 'Could not load communities.',
        ),
      ),
    );
  }
}

class _CommunityList extends StatelessWidget {
  final List<CommunityModel> communities;
  final String uid;
  final bool isPendingList;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;

  const _CommunityList({
    required this.communities,
    required this.uid,
    this.isPendingList = false,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (communities.isEmpty) {
      return InboxEmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        message: emptyMessage,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: communities.length,
      itemBuilder: (context, index) {
        return _CommunityCard(
          community: communities[index],
          uid: uid,
          isPendingRequest: isPendingList,
        )
            .animate(delay: Duration(milliseconds: 40 * index))
            .fade(duration: 300.ms)
            .slideY(begin: 0.06, end: 0);
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// CARD
// ══════════════════════════════════════════════════════════════════════════

class _CommunityCard extends StatefulWidget {
  final CommunityModel community;
  final String uid;
  final bool isPendingRequest;

  const _CommunityCard({
    required this.community,
    required this.uid,
    this.isPendingRequest = false,
  });

  @override
  State<_CommunityCard> createState() => _CommunityCardState();
}

class _CommunityCardState extends State<_CommunityCard> {
  bool _busy = false;

  Future<void> _joinOrRequest() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final community = widget.community;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get();
      final userName =
          (userDoc.data()?['displayName'] as String?) ?? 'Member';
      if (community.requiresApproval) {
        await CommunityService.requestToJoin(community, userName: userName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Join request sent!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      } else {
        await CommunityService.joinCommunity(community, userName: userName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('You joined ${community.name}!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to join: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelRequest() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await CommunityService.cancelJoinRequest(widget.community.id);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final community = widget.community;
    final isMember = community.isMember(widget.uid);

    Widget trailing;
    if (isMember) {
      trailing =
          Icon(Icons.chevron_right, color: TheyDiColors.textMuted, size: 20);
    } else if (widget.isPendingRequest) {
      trailing = PressableScale(
        onTap: _cancelRequest,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: TheyDiColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: TheyDiColors.divider),
          ),
          child: _busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Requested',
                  style: TheyDiTextStyles.labelMedium.copyWith(
                      color: TheyDiColors.textSecondary, fontSize: 12)),
        ),
      );
    } else {
      trailing = PressableScale(
        onTap: _joinOrRequest,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: TheyDiColors.gradientPrimary,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: TheyDiColors.primary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: _busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(community.requiresApproval ? 'Request' : 'Join',
                  style: TheyDiTextStyles.labelMedium
                      .copyWith(color: Colors.white, fontSize: 12)),
        ),
      );
    }

    // Non-members: no outer tap wrapper — HitTestBehavior.opaque on PressableScale
    // would absorb taps meant for the inner Join button. Only members get the
    // card tap (opens chat). Non-members tap only the Join button itself.
    if (isMember) {
      return PressableScale(
        onTap: () => context.push(AppRoutes.communityChat, extra: community),
        child: _buildCard(context, community, trailing),
      );
    }
    return _buildCard(context, community, trailing);
  }

  Widget _buildCard(BuildContext context, CommunityModel community, Widget trailing) {
    return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: TheyDiColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TheyDiColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: TheyDiColors.gradientPrimary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: TheyDiColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: (community.coverImageUrl?.isNotEmpty ?? false)
                    ? Image.network(
                        community.coverImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(community.initials,
                              style: TheyDiTextStyles.labelMedium
                                  .copyWith(color: Colors.white)),
                        ),
                      )
                    : Center(
                        child: Text(community.initials,
                            style: TheyDiTextStyles.labelMedium
                                .copyWith(color: Colors.white)),
                      ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(community.name,
                      style: TheyDiTextStyles.labelMedium
                          .copyWith(letterSpacing: -0.1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${community.memberCount} member${community.memberCount == 1 ? '' : 's'}',
                    style: TheyDiTextStyles.caption
                        .copyWith(color: TheyDiColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
    );
  }
}