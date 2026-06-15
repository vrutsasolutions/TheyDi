import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/friends_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/circle_join_service.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _connectedFriendsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('friends')
      .orderBy('addedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) {
            final data = d.data();
            return {'uid': d.id, ...data};
          }).toList());
});

final _pendingRequestsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('friendRequests')
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) {
            final data = d.data();
            return {'id': d.id, ...data};
          }).toList());
});

final _suggestedFriendsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return CircleJoinService.getSuggestedFriends();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class FriendsHubScreen extends ConsumerStatefulWidget {
  const FriendsHubScreen({super.key});

  @override
  ConsumerState<FriendsHubScreen> createState() => _FriendsHubScreenState();
}

class _FriendsHubScreenState extends ConsumerState<FriendsHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Fire suggested-friends notification if there are suggestions
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final suggestions = await CircleJoinService.getSuggestedFriends();
      if (suggestions.isNotEmpty) {
        await NotificationService.notifySuggestedFriends(
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
    final pendingAsync = ref.watch(_pendingRequestsProvider);
    final pendingCount = pendingAsync.asData?.value?.length ?? 0;

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
                    Text('Friends', style: TheyDiTextStyles.displayMedium),
                    const Spacer(),
                    // Friend requests shortcut
                    GestureDetector(
                      onTap: () => context.push(AppRoutes.friendRequests),
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
                            const Icon(Icons.person_add_outlined,
                                color: Colors.white, size: 15),
                            const SizedBox(width: 5),
                            Text('Requests',
                                style: TheyDiTextStyles.labelMedium
                                    .copyWith(color: Colors.white)),
                            if (pendingCount > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 18,
                                height: 18,
                                decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle),
                                child: Center(
                                  child: Text('$pendingCount',
                                      style: TextStyle(
                                          color: TheyDiColors.primary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ],
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
                  tabs: [
                    const Tab(text: 'Connected'),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Pending'),
                          if (pendingCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle),
                              child: Center(
                                child: Text('$pendingCount',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Tab(text: 'Suggested'),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ConnectedTab(),
                    _PendingTab(),
                    _SuggestedFriendsTab(),
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
// TAB 1 — CONNECTED FRIENDS
// ══════════════════════════════════════════════════════════════════════════════

class _ConnectedTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(_connectedFriendsProvider);

    return friendsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: TheyDiColors.primary)),
      error: (e, _) => Center(
          child: Text('Error: $e', style: TheyDiTextStyles.bodySmall)),
      data: (friends) {
        if (friends.isEmpty) {
          return _EmptyState(
            icon: Icons.people_outline,
            title: 'No friends yet',
            subtitle: 'Attend events to connect with people',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: friends.length,
          itemBuilder: (ctx, i) {
            final f = friends[i];
            return _ConnectedFriendCard(
              uid: f['uid'] ?? '',
              displayName: f['displayName'] ?? 'User',
            )
                .animate(delay: Duration(milliseconds: 50 * i))
                .fade(duration: 300.ms)
                .slideX(begin: 0.05, end: 0);
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — PENDING REQUESTS
// ══════════════════════════════════════════════════════════════════════════════

class _PendingTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(_pendingRequestsProvider);
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return requestsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: TheyDiColors.primary)),
      error: (e, _) => Center(
          child: Text('Error: $e', style: TheyDiTextStyles.bodySmall)),
      data: (requests) {
        if (requests.isEmpty) {
          return _EmptyState(
            icon: Icons.person_add_outlined,
            title: 'No pending requests',
            subtitle: 'Friend requests you receive will appear here',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: requests.length,
          itemBuilder: (ctx, i) {
            final req = requests[i];
            return _PendingRequestCard(
              requestId: req['id'] ?? '',
              fromUid: req['fromUid'] ?? '',
              fromName: req['fromName'] ?? 'Someone',
              myUid: myUid,
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
// TAB 3 — SUGGESTED FRIENDS
// ══════════════════════════════════════════════════════════════════════════════

class _SuggestedFriendsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestedAsync = ref.watch(_suggestedFriendsProvider);

    return suggestedAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: TheyDiColors.primary)),
      error: (e, _) => Center(
          child: Text('Error: $e', style: TheyDiTextStyles.bodySmall)),
      data: (suggestions) {
        if (suggestions.isEmpty) {
          return _EmptyState(
            icon: Icons.person_search_outlined,
            title: 'No suggestions yet',
            subtitle: 'Attend more events to discover people with similar interests',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: suggestions.length,
          itemBuilder: (ctx, i) {
            final s = suggestions[i];
            return _SuggestedFriendCard(
              uid: s['uid'] ?? '',
              displayName: s['displayName'] ?? 'User',
              city: s['city'] ?? '',
              photoUrl: s['photoUrl'] ?? '',
              interests: List<String>.from(s['interests'] ?? []),
              bio: s['bio'] ?? '',
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

class _ConnectedFriendCard extends StatelessWidget {
  final String uid;
  final String displayName;
  const _ConnectedFriendCard({required this.uid, required this.displayName});

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final city = data['city'] ?? '';
        final photoUrl = data['photoUrl'] ?? '';
        final isOnline = data['isOnline'] == true;

        return GestureDetector(
          onTap: () => context.push(AppRoutes.userProfile,
              extra: {'uid': uid, 'requestId': null}),
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
                // Avatar with online dot
                Stack(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: TheyDiColors.gradientPrimary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: photoUrl.isNotEmpty
                            ? Image.network(photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                      child: Text(initial,
                                          style: TheyDiTextStyles.labelLarge
                                              .copyWith(color: Colors.white)),
                                    ))
                            : Center(
                                child: Text(initial,
                                    style: TheyDiTextStyles.labelLarge
                                        .copyWith(color: Colors.white)),
                              ),
                      ),
                    ),
                    if (isOnline)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: TheyDiColors.card, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: TheyDiTextStyles.labelMedium),
                      if (city.isNotEmpty)
                        Row(children: [
                          const Icon(Icons.location_on_outlined,
                              size: 11, color: TheyDiColors.textMuted),
                          const SizedBox(width: 3),
                          Text(city, style: TheyDiTextStyles.caption),
                        ]),
                      if (isOnline)
                        Text('Online',
                            style: TheyDiTextStyles.caption.copyWith(
                                color: Colors.greenAccent, fontSize: 10)),
                    ],
                  ),
                ),
                // Message button
                GestureDetector(
                  onTap: () => context.push(AppRoutes.dmChat,
                      extra: {'otherUid': uid, 'otherName': displayName}),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: TheyDiColors.gradientPrimary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 5),
                        Text('Message',
                            style: TheyDiTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Pending Request Card ──────────────────────────────────────────────────────

class _PendingRequestCard extends StatefulWidget {
  final String requestId;
  final String fromUid;
  final String fromName;
  final String myUid;

  const _PendingRequestCard({
    required this.requestId,
    required this.fromUid,
    required this.fromName,
    required this.myUid,
  });

  @override
  State<_PendingRequestCard> createState() => _PendingRequestCardState();
}

class _PendingRequestCardState extends State<_PendingRequestCard> {
  bool _processing = false;
  bool _responded = false;
  String _responseLabel = '';

  Future<void> _accept() async {
    setState(() => _processing = true);
    await FriendsService.acceptFriendRequest(
      requestId: widget.requestId,
      fromUid: widget.fromUid,
      fromName: widget.fromName,
    );
    if (mounted) {
      setState(() {
        _processing = false;
        _responded = true;
        _responseLabel = 'Accepted';
      });
    }
  }

  Future<void> _decline() async {
    setState(() => _processing = true);
    await FriendsService.declineFriendRequest(
      requestId: widget.requestId,
      myUid: widget.myUid,
    );
    if (mounted) {
      setState(() {
        _processing = false;
        _responded = true;
        _responseLabel = 'Declined';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial =
        widget.fromName.isNotEmpty ? widget.fromName[0].toUpperCase() : '?';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.fromUid)
          .get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final city = data['city'] ?? '';
        final photoUrl = data['photoUrl'] ?? '';
        final interests = List<String>.from(data['interests'] ?? []);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TheyDiColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: TheyDiColors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => context.push(AppRoutes.userProfile,
                    extra: {
                      'uid': widget.fromUid,
                      'requestId': widget.requestId
                    }),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: TheyDiColors.gradientPrimary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: photoUrl.isNotEmpty
                            ? Image.network(photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                      child: Text(initial,
                                          style: TheyDiTextStyles.labelLarge
                                              .copyWith(color: Colors.white)),
                                    ))
                            : Center(
                                child: Text(initial,
                                    style: TheyDiTextStyles.labelLarge
                                        .copyWith(color: Colors.white)),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.fromName,
                              style: TheyDiTextStyles.labelLarge),
                          if (city.isNotEmpty)
                            Row(children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 11, color: TheyDiColors.textMuted),
                              const SizedBox(width: 3),
                              Text(city, style: TheyDiTextStyles.caption),
                            ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (interests.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: interests
                      .take(4)
                      .map((i) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: TheyDiColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(i,
                                style: TheyDiTextStyles.caption.copyWith(
                                    color: TheyDiColors.primary, fontSize: 10)),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 14),
              if (_responded)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _responseLabel == 'Accepted'
                        ? Colors.green.withValues(alpha: 0.12)
                        : TheyDiColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: TheyDiColors.divider),
                  ),
                  child: Center(
                    child: Text(
                      _responseLabel == 'Accepted'
                          ? '✅ Connected with ${widget.fromName}'
                          : 'Request declined',
                      style: TheyDiTextStyles.labelMedium.copyWith(
                        color: _responseLabel == 'Accepted'
                            ? Colors.green
                            : TheyDiColors.textMuted,
                      ),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _processing ? null : _decline,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: TheyDiColors.divider),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text('Decline',
                            style: TheyDiTextStyles.labelMedium.copyWith(
                                color: TheyDiColors.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: TheyDiColors.gradientPrimary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ElevatedButton(
                          onPressed: _processing ? null : _accept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: _processing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text('Accept',
                                  style: TheyDiTextStyles.labelMedium
                                      .copyWith(color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Suggested Friend Card ─────────────────────────────────────────────────────

class _SuggestedFriendCard extends StatefulWidget {
  final String uid;
  final String displayName;
  final String city;
  final String photoUrl;
  final List<String> interests;
  final String bio;

  const _SuggestedFriendCard({
    required this.uid,
    required this.displayName,
    required this.city,
    required this.photoUrl,
    required this.interests,
    required this.bio,
  });

  @override
  State<_SuggestedFriendCard> createState() => _SuggestedFriendCardState();
}

class _SuggestedFriendCardState extends State<_SuggestedFriendCard> {
  bool _loading = false;
  bool _sent = false;

  Future<void> _sendRequest() async {
    setState(() => _loading = true);
    await FriendsService.sendFriendRequest(toUid: widget.uid, toName: widget.displayName);
    if (mounted) setState(() {_loading = false; _sent = true;});
  }

  @override
  Widget build(BuildContext context) {
    final initial =
        widget.displayName.isNotEmpty ? widget.displayName[0].toUpperCase() : '?';

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
          GestureDetector(
            onTap: () => context.push(AppRoutes.userProfile,
                extra: {'uid': widget.uid, 'requestId': null}),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: TheyDiColors.gradientPrimary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: widget.photoUrl.isNotEmpty
                        ? Image.network(widget.photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                                  child: Text(initial,
                                      style: TheyDiTextStyles.labelLarge
                                          .copyWith(color: Colors.white)),
                                ))
                        : Center(
                            child: Text(initial,
                                style: TheyDiTextStyles.labelLarge
                                    .copyWith(color: Colors.white)),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.displayName,
                          style: TheyDiTextStyles.labelLarge),
                      if (widget.city.isNotEmpty)
                        Row(children: [
                          const Icon(Icons.location_on_outlined,
                              size: 11, color: TheyDiColors.textMuted),
                          const SizedBox(width: 3),
                          Text(widget.city, style: TheyDiTextStyles.caption),
                        ]),
                      if (widget.bio.isNotEmpty)
                        Text(widget.bio,
                            style: TheyDiTextStyles.caption.copyWith(
                                color: TheyDiColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.interests.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.interests
                  .take(4)
                  .map((i) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: TheyDiColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(i,
                            style: TheyDiTextStyles.caption.copyWith(
                                color: TheyDiColors.primary, fontSize: 10)),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: _sent
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
                      onPressed: _loading ? null : _sendRequest,
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
                                const Icon(Icons.person_add_outlined,
                                    size: 15, color: Colors.white),
                                const SizedBox(width: 6),
                                Text('Connect',
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

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
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
          ],
        ),
      ),
    );
  }
}
