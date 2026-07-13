import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/friends_service.dart';
import '../models/circle_model.dart';
import '../../../shared/widgets/avatar_online_status_dot.dart';

// ── Providers ──

final _myCirclesProvider = StreamProvider.autoDispose<List<CircleModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('circles')
      .where('memberUids', arrayContains: uid)
      .orderBy('lastMessageAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => CircleModel.fromFirestore(d)).toList());
});

final _friendsProvider =
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

final _requestsProvider =
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

// ── Main Screen ──

class CirclesListScreen extends ConsumerStatefulWidget {
  final bool isSelectionMode;
  final String? eventId;

  const CirclesListScreen({
    super.key,
    this.isSelectionMode = false,
    this.eventId,
  });


  @override
  ConsumerState<CirclesListScreen> createState() => _CirclesListScreenState();
}

class _CirclesListScreenState extends ConsumerState<CirclesListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedFriendUids = {};
  final Set<String> _selectedCircleIds = {};
  

  Future<void> _sendEventShare({
  required BuildContext context,
  required String eventId,
  required List<String> selectedFriendUids,
  required List<String> selectedCircleIds,
}) async {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Event Share feature is under development.'),
    ),
  );

  if (context.mounted) {
    context.pop();
  }
}

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: widget.isSelectionMode ? 3 : 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(_requestsProvider);
    final pendingCount = requestsAsync.asData?.value.length ?? 0;
    final selectedCount = _selectedFriendUids.length + _selectedCircleIds.length;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── App Bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: TheyDiColors.textPrimary),
                          onPressed: () => context.pop(),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Friend Circles',
                            style: TheyDiTextStyles.displayMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!widget.isSelectionMode) ...[
  const SizedBox(width: 8),
  GestureDetector(
    onTap: () => context.push(AppRoutes.createCircle),
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        gradient: TheyDiColors.gradientPrimary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            'New',
            style: TheyDiTextStyles.labelMedium.copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
    ),
  ),
],
                      ],
                    );
                  },
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
                    const Tab(text: 'All'),
                    const Tab(text: 'Friends'),
                    const Tab(text: 'Circles'),
                    if (!widget.isSelectionMode)
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Requests'),
                            if (pendingCount > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 18,
                                height: 18,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
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
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Tab Views ──
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _AllTab(
                      isSelectionMode: widget.isSelectionMode,
                      selectedFriendUids: _selectedFriendUids,
                      selectedCircleIds: _selectedCircleIds,
                      onFriendSelected: _toggleFriend,
                      onCircleSelected: _toggleCircle,
                    ),
                    _FriendsTab(
                      isSelectionMode: widget.isSelectionMode,
                      selectedFriendUids: _selectedFriendUids,
                      onFriendSelected: _toggleFriend,
                    ),
                    _CirclesTab(
                      isSelectionMode: widget.isSelectionMode,
                      selectedCircleIds: _selectedCircleIds,
                      onCircleSelected: _toggleCircle,
                    ),
                    if (!widget.isSelectionMode) _RequestsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.isSelectionMode
          ? (widget.eventId != null
              ? _EventShareSelectionBar(
                  selectedCount: selectedCount,
                  selectedCircleCount: _selectedCircleIds.length,
                  onCancel: () => context.pop(),
                  onSend: selectedCount == 0
                      ? null
                      : () => _sendEventShare(
                            context: context,
                            eventId: widget.eventId!,
                            selectedFriendUids: _selectedFriendUids.toList(),
                            selectedCircleIds: _selectedCircleIds.toList(),
                          ),
                )
              : _SelectionBar(
                  selectedCount: selectedCount,
                  onCancel: () => context.pop(),
                  onDone: selectedCount == 0
                      ? null
                      : () => context.pop({
                            'friendUids': _selectedFriendUids.toList(),
                            'circleIds': _selectedCircleIds.toList(),
                          }),
                ))
          : null,
    );
  }

  void _toggleFriend(String uid) {
    setState(() {
      if (!_selectedFriendUids.add(uid)) _selectedFriendUids.remove(uid);
    });
  }

  void _toggleCircle(String id) {
    setState(() {
      if (!_selectedCircleIds.add(id)) _selectedCircleIds.remove(id);
    });
  }
}

// ══════════════════════════════════════════
// TAB 1 — ALL
// ══════════════════════════════════════════

class _AllTab extends ConsumerWidget {
  final bool isSelectionMode;
  final Set<String> selectedFriendUids;
  final Set<String> selectedCircleIds;
  final ValueChanged<String> onFriendSelected;
  final ValueChanged<String> onCircleSelected;

  const _AllTab({
    required this.isSelectionMode,
    required this.selectedFriendUids,
    required this.selectedCircleIds,
    required this.onFriendSelected,
    required this.onCircleSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(_friendsProvider);
    final circlesAsync = ref.watch(_myCirclesProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        friendsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (friends) {
            if (friends.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text('Friends',
                    style: TheyDiTextStyles.labelLarge
                        .copyWith(color: TheyDiColors.textSecondary)),
                const SizedBox(height: 8),
                ...friends.take(5).map((f) => _FriendCard(
                      uid: f['uid'] ?? '',
                      displayName: f['displayName'] ?? 'User',
                      photoUrl: f['profileImageUrl'] ?? '',
                      isSelectionMode: isSelectionMode,
                      isSelected: selectedFriendUids.contains(f['uid'] ?? ''),
                      onSelected: onFriendSelected,
                    )),
                if (friends.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () {
                        final tabController = context
                            .findAncestorStateOfType<_CirclesListScreenState>()
                            ?._tabController;
                        tabController?.animateTo(1);
                      },
                      child: Text(
                        'See all ${friends.length} friends →',
                        style: TheyDiTextStyles.caption
                            .copyWith(color: TheyDiColors.primary),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        circlesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: TheyDiColors.primary),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (circles) {
            if (circles.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Text('Circles',
                    style: TheyDiTextStyles.labelLarge
                        .copyWith(color: TheyDiColors.textSecondary)),
                const SizedBox(height: 8),
                ...circles.map((c) => _CircleCard(
                      circle: c,
                      isSelectionMode: isSelectionMode,
                      isSelected: selectedCircleIds.contains(c.id),
                      onSelected: onCircleSelected,
                    )),
              ],
            );
          },
        ),
        Builder(builder: (context) {
          final friends = ref.watch(_friendsProvider).asData?.value ?? [];
          final circles = ref.watch(_myCirclesProvider).asData?.value ?? [];
          if (friends.isEmpty && circles.isEmpty) {
            return _EmptyState(
              icon: Icons.people_outline,
              title: 'Nothing here yet',
              subtitle:
                  'Connect with people at events or create a circle to get started',
            );
          }
          return const SizedBox.shrink();
        }),
      ],
    );
  }
}

// ══════════════════════════════════════════
// TAB 2 — FRIENDS (with Message button)
// ══════════════════════════════════════════

class _FriendsTab extends ConsumerWidget {
  final bool isSelectionMode;
  final Set<String> selectedFriendUids;
  final ValueChanged<String> onFriendSelected;

  const _FriendsTab({
    required this.isSelectionMode,
    required this.selectedFriendUids,
    required this.onFriendSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(_friendsProvider);

    return friendsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: TheyDiColors.primary)),
      error: (e, _) => Center(
          child: Text('Failed to load: $e', style: TheyDiTextStyles.bodySmall)),
      data: (friends) {
        if (friends.isEmpty) {
          return _EmptyState(
            icon: Icons.person_outline,
            title: 'No friends yet',
            subtitle: 'Connect with attendees at events to grow your network',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final f = friends[index];
            return _FriendCard(
              uid: f['uid'] ?? '',
              displayName: f['displayName'] ?? 'User',
              photoUrl: f['profileImageUrl'] ?? '',
              isSelectionMode: isSelectionMode,
              isSelected: selectedFriendUids.contains(f['uid'] ?? ''),
              onSelected: onFriendSelected,
            )
                .animate(delay: Duration(milliseconds: 50 * index))
                .fade(duration: 300.ms)
                .slideX(begin: 0.05, end: 0);
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════
// TAB 3 — CIRCLES
// ══════════════════════════════════════════

class _CirclesTab extends ConsumerWidget {
  final bool isSelectionMode;
  final Set<String> selectedCircleIds;
  final ValueChanged<String> onCircleSelected;

  const _CirclesTab({
    required this.isSelectionMode,
    required this.selectedCircleIds,
    required this.onCircleSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circlesAsync = ref.watch(_myCirclesProvider);

    return circlesAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: TheyDiColors.primary)),
      error: (e, _) => Center(
          child: Text('Failed to load: $e', style: TheyDiTextStyles.bodySmall)),
      data: (circles) {
        if (circles.isEmpty) {
          return _EmptyState(
            icon: Icons.group_outlined,
            title: 'No circles yet',
            subtitle: 'Create a circle to start chatting with friends',
            actionLabel:
                isSelectionMode ? null : 'Create your first circle',
            onAction: isSelectionMode
                ? null
                : (context) => context.push(AppRoutes.createCircle),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: circles.length,
          itemBuilder: (context, index) {
            return _CircleCard(
              circle: circles[index],
              isSelectionMode: isSelectionMode,
              isSelected: selectedCircleIds.contains(circles[index].id),
              onSelected: onCircleSelected,
            )
                .animate(delay: Duration(milliseconds: 50 * index))
                .fade(duration: 300.ms)
                .slideX(begin: 0.05, end: 0);
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════
// TAB 4 — REQUESTS
// ══════════════════════════════════════════

class _RequestsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(_requestsProvider);
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return requestsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: TheyDiColors.primary)),
      error: (e, _) => Center(
          child: Text('Failed to load: $e', style: TheyDiTextStyles.bodySmall)),
      data: (requests) {
        if (requests.isEmpty) {
          return _EmptyState(
            icon: Icons.person_add_outlined,
            title: 'No pending requests',
            subtitle: 'Connect with attendees at events to grow your network',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final req = requests[index];
            return _RequestCard(
              requestId: req['id'] ?? '',
              fromUid: req['fromUid'] ?? '',
              fromName: req['fromName'] ?? 'Someone',
              myUid: myUid,
            )
                .animate(delay: Duration(milliseconds: 60 * index))
                .fade(duration: 300.ms)
                .slideY(begin: 0.1, end: 0);
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════
// HELPER WIDGETS
// ══════════════════════════════════════════

// ── Friend Card — with Message button ──
class _FriendCard extends StatelessWidget {
  final String uid;
  final String displayName;
  final String photoUrl;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<String>? onSelected;

  const _FriendCard({
    required this.uid,
    required this.displayName,
    required this.photoUrl,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final city = data['city'] ?? '';

        final photoUrl = data['profileImageUrl'] ?? '';

        return GestureDetector(
          onTap: isSelectionMode
              ? () => onSelected?.call(uid)
              : () => context.push(
                    AppRoutes.userProfile,
                    extra: {'uid': uid, 'requestId': null},
                  ),
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
                // Avatar
                // Avatar + Online Status Dot
Stack(
  children: [
    Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: TheyDiColors.gradientPrimary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: photoUrl.isNotEmpty
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    initial,
                    style: TheyDiTextStyles.labelLarge
                        .copyWith(color: Colors.white),
                  ),
                ),
              )
            : Center(
                child: Text(
                  initial,
                  style: TheyDiTextStyles.labelLarge
                      .copyWith(color: Colors.white),
                ),
              ),
      ),
    ),

    Positioned(
      right: 0,
      bottom: 0,
      child: AvatarOnlineStatusDot(
        uid: uid,
        size: 10,
      ),
    ),
  ],
),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: TheyDiTextStyles.labelMedium),
                      if (city.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 11, color: TheyDiColors.textMuted),
                            const SizedBox(width: 3),
                            Text(city, style: TheyDiTextStyles.caption),
                          ],
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // ── Message Button ──
                if (isSelectionMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onSelected?.call(uid),
                    activeColor: TheyDiColors.primary,
                  )
                else
                  GestureDetector(
                    onTap: () => context.push(
                      AppRoutes.dmChat,
                      extra: {
                        'otherUid': uid,
                        'otherName': displayName,
                      },
                    ),
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

// ── Circle Card ──
class _CircleCard extends StatelessWidget {
  final CircleModel circle;
  final String? profileImageUrl;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<String>? onSelected;

  const _CircleCard({
    required this.circle,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelected,
  }) : profileImageUrl = null;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return GestureDetector(
      onTap: isSelectionMode
          ? () => onSelected?.call(circle.id)
          : () => context.push(AppRoutes.circleChat, extra: circle),
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
              child: circle.profileImageUrl != null && circle.profileImageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        circle.profileImageUrl!,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Center(
                      child: Text(
                        circle.initials,
                        style: TheyDiTextStyles.displayMedium
                            .copyWith(color: Colors.white, fontSize: 18),
                      ),
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
            if (isSelectionMode)
              Checkbox(
                value: isSelected,
                onChanged: (_) => onSelected?.call(circle.id),
                activeColor: TheyDiColors.primary,
              )
            else
              Icon(Icons.arrow_forward_ios,
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

// ── Request Card ──
class _SelectionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onCancel;
  final VoidCallback? onDone;

  const _SelectionBar({
    required this.selectedCount,
    required this.onCancel,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: TheyDiColors.dark,
        border: Border(top: BorderSide(color: TheyDiColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            TextButton(
              onPressed: onCancel,
              child: Text(
                'Cancel',
                style: TheyDiTextStyles.labelMedium
                    .copyWith(color: TheyDiColors.textSecondary),
              ),
            ),
            const Spacer(),
            Text(
              '$selectedCount selected',
              style: TheyDiTextStyles.caption
                  .copyWith(color: TheyDiColors.textSecondary),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: TheyDiColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventShareSelectionBar extends StatelessWidget {
  final int selectedCount;
  final int selectedCircleCount;
  final VoidCallback onCancel;
  final VoidCallback? onSend;

  const _EventShareSelectionBar({
    required this.selectedCount,
    required this.selectedCircleCount,
    required this.onCancel,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final sendLabel = 'Send ($selectedCount)';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: TheyDiColors.dark,
        border: Border(top: BorderSide(color: TheyDiColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            TextButton(
              onPressed: onCancel,
              child: Text(
                'Cancel',
                style: TheyDiTextStyles.labelMedium
                    .copyWith(color: TheyDiColors.textSecondary),
              ),
            ),
            const Spacer(),
            Text(
              '$selectedCount selected',
              style: TheyDiTextStyles.caption
                  .copyWith(color: TheyDiColors.textSecondary),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: onSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: TheyDiColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    TheyDiColors.primary.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(sendLabel),
            ),
          ],
        ),
      ),
    );
  }
}


  // @override
  // Widget build(BuildContext context) {
  //   return Container(
  //     padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
  //     decoration: BoxDecoration(
  //       color: TheyDiColors.dark,
  //       border: Border(top: BorderSide(color: TheyDiColors.divider)),
  //     ),
  //     child: SafeArea(
  //       top: false,
  //       child: Row(
  //         children: [
  //           TextButton(
  //             onPressed: onCancel,
  //             child: Text(
  //               'Cancel',
  //               style: TheyDiTextStyles.labelMedium
  //                   .copyWith(color: TheyDiColors.textSecondary),
  //             ),
  //           ),
  //           const Spacer(),
  //           Text(
  //             '$selectedCount selected',
  //             style: TheyDiTextStyles.caption
  //                 .copyWith(color: TheyDiColors.textSecondary),
  //           ),
  //           const SizedBox(width: 12),
  //           ElevatedButton(
  //             onPressed: onDone,
  //             style: ElevatedButton.styleFrom(
  //               backgroundColor: TheyDiColors.primary,
  //               foregroundColor: Colors.white,
  //               shape: RoundedRectangleBorder(
  //                 borderRadius: BorderRadius.circular(12),
  //               ),
  //             ),
  //             child: const Text('Done'),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }


class _RequestCard extends StatefulWidget {
  final String requestId;
  final String fromUid;
  final String fromName;
  final String myUid;

  const _RequestCard({
    required this.requestId,
    required this.fromUid,
    required this.fromName,
    required this.myUid,
  });

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You and ${widget.fromName} are now friends! 🎉'),
          backgroundColor: Colors.green,
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Request declined'), backgroundColor: Colors.grey),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.fromUid)
          .get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final city = data['city'] ?? '';
        final photoUrl = data['profileImageUrl'] ?? '';
        final interests = List<String>.from(data['interests'] ?? []);
        final initial =
            widget.fromName.isNotEmpty ? widget.fromName[0].toUpperCase() : '?';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TheyDiColors.card,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: TheyDiColors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => context.push(
                  AppRoutes.userProfile,
                  extra: {
                    'uid': widget.fromUid,
                    'requestId': widget.requestId,
                  },
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
                              Icon(Icons.location_on_outlined,
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
                              color:
                                  TheyDiColors.primary.withValues(alpha: 0.12),
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
                            style: TheyDiTextStyles.labelMedium
                                .copyWith(color: TheyDiColors.textSecondary)),
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

// ── Empty State ──
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final void Function(BuildContext)? onAction;

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
                onTap: () => onAction!(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
