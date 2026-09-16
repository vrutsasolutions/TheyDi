import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/services/friends_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/avatar_online_status_dot.dart';
import '../../inbox_shared_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ══════════════════════════════════════════════════════════════════════════

// FIX: this used to add `.orderBy('addedAt', descending: true)` directly
// in the Firestore query. Firestore silently excludes any document
// missing the field you order by — so any friend doc without an
// `addedAt` field (e.g. connections made before that field existed, or
// added through an older code path) would never appear in this list at
// all, even though the document is really there. This is the same class
// of bug already fixed in circles_tab.dart's myCirclesProvider. Fixed
// here the same way: fetch unordered and sort client-side, with
// undated docs falling back to the end instead of disappearing.
final connectionsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('friends')
      .snapshots()
      .map((s) {
    final connections =
        s.docs.map((d) => {'uid': d.id, ...d.data()}).toList();
    connections.sort((a, b) {
      final aTime = a['addedAt'] as Timestamp?;
      final bTime = b['addedAt'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return connections;
  });
});

final pendingRequestsCountProvider = StreamProvider.autoDispose<int>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(0);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('friendRequests')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) => s.docs.length);
});

// "Requests I sent" — a new capability. FriendsService (existing) only
// tracks incoming requests (users/{uid}/friendRequests). Sending a request
// now also mirrors a doc to users/{myUid}/sentFriendRequests/{toUid} so
// this tab has something cheap to query. See _sendFriendRequest /
// _cancelSentRequest below.
// FIX: combining .where('status') with .orderBy('createdAt') on a
// different field requires a Firestore composite index. Until that index
// exists in the console, this query fails on every load — which is what
// was showing as the Sent tab getting stuck. Sorting client-side avoids
// needing the index at all.
final sentRequestsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('sentFriendRequests')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) {
    final sent = s.docs.map((d) => {'toUid': d.id, ...d.data()}).toList();
    sent.sort((a, b) {
      final aTime = a['createdAt'] as Timestamp?;
      final bTime = b['createdAt'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return sent;
  });
});

// Placeholder suggestion algorithm — same "real logic comes later" spirit
// as Home's Social/Professional split and Communities' Recommended list.
// Just pulls a capped page of users and filters out anyone already
// connected/pending in either direction; a real version would rank by
// shared interests, city, mutual connections, etc.
final suggestionsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) async* {
  final myUid = FirebaseAuth.instance.currentUser?.uid;
  if (myUid == null) {
    yield [];
    return;
  }
  final db = FirebaseFirestore.instance;

  final friendsSnap =
      await db.collection('users').doc(myUid).collection('friends').get();
  final receivedSnap = await db
      .collection('users')
      .doc(myUid)
      .collection('friendRequests')
      .get();
  final sentSnap = await db
      .collection('users')
      .doc(myUid)
      .collection('sentFriendRequests')
      .get();

  final excluded = <String>{
    myUid,
    ...friendsSnap.docs.map((d) => d.id),
    ...receivedSnap.docs.map((d) => d.data()['fromUid'] as String? ?? ''),
    ...sentSnap.docs.map((d) => d.id),
  };

  final candidatesSnap = await db.collection('users').limit(40).get();
  final suggestions = candidatesSnap.docs
      .where((d) => !excluded.contains(d.id))
      .take(15)
      .map((d) => {'uid': d.id, ...d.data()})
      .toList();

  yield suggestions;
});

// ══════════════════════════════════════════════════════════════════════════
// FRIEND-REQUEST ACTIONS (send / cancel — new; accept/decline reuse the
// existing FriendsService)
// ══════════════════════════════════════════════════════════════════════════

Future<void> _sendFriendRequest({
  required String toUid,
  required String toName,
  required String myUid,
  required String myName,
}) async {
  final db = FirebaseFirestore.instance;
  final batch = db.batch();
  batch.set(
    db.collection('users').doc(toUid).collection('friendRequests').doc(myUid),
    {
      'fromUid': myUid,
      'fromName': myName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    },
  );
  batch.set(
    db
        .collection('users')
        .doc(myUid)
        .collection('sentFriendRequests')
        .doc(toUid),
    {
      'toUid': toUid,
      'toName': toName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    },
  );
  await batch.commit();
}

Future<void> _cancelSentRequest({
  required String myUid,
  required String toUid,
}) async {
  final db = FirebaseFirestore.instance;
  final batch = db.batch();
  batch.delete(db
      .collection('users')
      .doc(toUid)
      .collection('friendRequests')
      .doc(myUid));
  batch.delete(db
      .collection('users')
      .doc(myUid)
      .collection('sentFriendRequests')
      .doc(toUid));
  await batch.commit();
}

// ══════════════════════════════════════════════════════════════════════════
// SHELL — nested sub-tab bar (Chats / Suggestions / Requests / Sent)
// ══════════════════════════════════════════════════════════════════════════

class ConnectionsTab extends ConsumerStatefulWidget {
  const ConnectionsTab({super.key});

  @override
  ConsumerState<ConnectionsTab> createState() => _ConnectionsTabState();
}

class _ConnectionsTabState extends ConsumerState<ConnectionsTab>
    with SingleTickerProviderStateMixin {
  static const _tabs = ['Chats', 'Suggestions', 'Requests', 'Sent'];
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
    final pendingCount =
        ref.watch(pendingRequestsCountProvider).asData?.value ?? 0;
    final badges = {2: pendingCount};

    return Column(
      children: [
        InboxSubTabBar(
          controller: _tabController,
          tabs: _tabs,
          badges: badges,
        ).animate().fade(duration: 250.ms),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _ChatsSubTab(),
              _SuggestionsSubTab(),
              _RequestsReceivedSubTab(),
              _RequestsSentSubTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// SUB-TAB 1 — Chats (existing connections, tap to message)
// ══════════════════════════════════════════════════════════════════════════

class _ChatsSubTab extends ConsumerWidget {
  const _ChatsSubTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionsAsync = ref.watch(connectionsProvider);

    return connectionsAsync.when(
      data: (connections) {
        if (connections.isEmpty) {
          return const InboxEmptyState(
            icon: Icons.chat_bubble_outline,
            title: 'No chats yet',
            message: 'People you connect with will show up here.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          itemCount: connections.length,
          itemBuilder: (context, index) {
            final c = connections[index];
            return _ConnectionCard(
              uid: c['uid'] ?? '',
              displayName: c['displayName'] ?? 'Member',
            )
                .animate(delay: Duration(milliseconds: 40 * index))
                .fade(duration: 300.ms)
                .slideY(begin: 0.06, end: 0);
          },
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: TheyDiColors.primary)),
      error: (e, st) => const InboxEmptyState(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: 'Could not load your connections.',
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  final String uid;
  final String displayName;
  const _ConnectionCard({required this.uid, required this.displayName});

  @override
  Widget build(BuildContext context) {
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final city = data['city'] ?? '';
        final photoUrl = data['profileImageUrl'] ?? data['photoUrl'] ?? '';

        return PressableScale(
          onTap: () => context.push(AppRoutes.userProfile,
              extra: {'uid': uid, 'requestId': null}),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
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
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: TheyDiColors.gradientPrimary,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color:
                                TheyDiColors.primary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: photoUrl.isNotEmpty
                            ? Image.network(
                                photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(initial,
                                      style: TheyDiTextStyles.labelLarge
                                          .copyWith(color: Colors.white)),
                                ),
                              )
                            : Center(
                                child: Text(initial,
                                    style: TheyDiTextStyles.labelLarge
                                        .copyWith(color: Colors.white)),
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: 1,
                      right: 1,
                      child: AvatarOnlineStatusDot(uid: uid, size: 11),
                    ),
                  ],
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName,
                          style: TheyDiTextStyles.labelLarge
                              .copyWith(letterSpacing: -0.1)),
                      if (city.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 11, color: TheyDiColors.textMuted),
                            const SizedBox(width: 3),
                            Text(city, style: TheyDiTextStyles.caption),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                PressableScale(
                  onTap: () => context.push(AppRoutes.dmChat,
                      extra: {'otherUid': uid, 'otherName': displayName}),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: TheyDiColors.gradientPrimary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: TheyDiColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.chat_bubble_outline,
                        color: Colors.white, size: 16),
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

// ══════════════════════════════════════════════════════════════════════════
// SUB-TAB 2 — Suggestions
// ══════════════════════════════════════════════════════════════════════════

class _SuggestionsSubTab extends ConsumerWidget {
  const _SuggestionsSubTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(suggestionsProvider);

    return suggestionsAsync.when(
      data: (people) {
        if (people.isEmpty) {
          return const InboxEmptyState(
            icon: Icons.person_search_outlined,
            title: 'No suggestions right now',
            message: 'Check back soon — we\'ll surface people to meet here.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          itemCount: people.length,
          itemBuilder: (context, index) {
            final p = people[index];
            return _SuggestionCard(
              uid: p['uid'] ?? '',
              displayName: p['displayName'] ?? 'Member',
              city: p['city'] ?? '',
              photoUrl: p['profileImageUrl'] ?? p['photoUrl'] ?? '',
            )
                .animate(delay: Duration(milliseconds: 40 * index))
                .fade(duration: 300.ms)
                .slideY(begin: 0.06, end: 0);
          },
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: TheyDiColors.primary)),
      error: (e, st) => const InboxEmptyState(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: 'Could not load suggestions.',
      ),
    );
  }
}

class _SuggestionCard extends StatefulWidget {
  final String uid;
  final String displayName;
  final String city;
  final String photoUrl;

  const _SuggestionCard({
    required this.uid,
    required this.displayName,
    required this.city,
    required this.photoUrl,
  });

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  bool _busy = false;
  bool _sent = false;

  Future<void> _connect() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || _busy) return;
    setState(() => _busy = true);
    try {
      final myDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .get();
      final myName = (myDoc.data()?['displayName'] as String?) ?? 'Member';
      await _sendFriendRequest(
        toUid: widget.uid,
        toName: widget.displayName,
        myUid: myUid,
        myName: myName,
      );
      if (mounted) setState(() => _sent = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.displayName.isNotEmpty
        ? widget.displayName[0].toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: TheyDiColors.gradientPrimary,
              borderRadius: BorderRadius.circular(15),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: widget.photoUrl.isNotEmpty
                  ? Image.network(
                      widget.photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(initial,
                            style: TheyDiTextStyles.labelLarge
                                .copyWith(color: Colors.white)),
                      ),
                    )
                  : Center(
                      child: Text(initial,
                          style: TheyDiTextStyles.labelLarge
                              .copyWith(color: Colors.white)),
                    ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.displayName,
                    style: TheyDiTextStyles.labelLarge
                        .copyWith(letterSpacing: -0.1)),
                if (widget.city.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 11, color: TheyDiColors.textMuted),
                      const SizedBox(width: 3),
                      Text(widget.city, style: TheyDiTextStyles.caption),
                    ],
                  ),
                ],
              ],
            ),
          ),
          PressableScale(
            onTap: (_busy || _sent) ? () {} : _connect,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: _sent ? null : TheyDiColors.gradientPrimary,
                color: _sent ? TheyDiColors.card : null,
                borderRadius: BorderRadius.circular(11),
                border:
                    _sent ? Border.all(color: TheyDiColors.divider) : null,
                boxShadow: _sent
                    ? null
                    : [
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
                  : Text(
                      _sent ? 'Sent' : 'Connect',
                      style: TheyDiTextStyles.labelMedium.copyWith(
                        color:
                            _sent ? TheyDiColors.textSecondary : Colors.white,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// SUB-TAB 3 — Requests received (reuses the existing FriendsService)
// ══════════════════════════════════════════════════════════════════════════

class _RequestsReceivedSubTab extends StatelessWidget {
  const _RequestsReceivedSubTab();

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FriendsService.streamFriendRequests(myUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: TheyDiColors.primary));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const InboxEmptyState(
            icon: Icons.mark_email_unread_outlined,
            title: 'No pending requests',
            message: 'Requests people send you will show up here.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _RequestReceivedCard(
              requestId: doc.id,
              fromUid: data['fromUid'] ?? '',
              fromName: data['fromName'] ?? 'Someone',
              myUid: myUid,
            )
                .animate(delay: Duration(milliseconds: 40 * index))
                .fade(duration: 300.ms)
                .slideY(begin: 0.06, end: 0);
          },
        );
      },
    );
  }
}

class _RequestReceivedCard extends StatefulWidget {
  final String requestId;
  final String fromUid;
  final String fromName;
  final String myUid;

  const _RequestReceivedCard({
    required this.requestId,
    required this.fromUid,
    required this.fromName,
    required this.myUid,
  });

  @override
  State<_RequestReceivedCard> createState() => _RequestReceivedCardState();
}

class _RequestReceivedCardState extends State<_RequestReceivedCard> {
  bool _processing = false;

  Future<void> _accept() async {
    setState(() => _processing = true);
    try {
      await FriendsService.acceptFriendRequest(
        requestId: widget.requestId,
        fromUid: widget.fromUid,
        fromName: widget.fromName,
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _processing = true);
    try {
      await FriendsService.declineFriendRequest(
        requestId: widget.requestId,
        myUid: widget.myUid,
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial =
        widget.fromName.isNotEmpty ? widget.fromName[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: TheyDiColors.primary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: TheyDiColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(initial,
                      style: TheyDiTextStyles.labelLarge
                          .copyWith(color: Colors.white)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child:
                    Text(widget.fromName, style: TheyDiTextStyles.labelLarge),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PressableScale(
                  onTap: _processing ? () {} : _decline,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: TheyDiColors.surface,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: TheyDiColors.divider),
                    ),
                    child: Text('Decline',
                        style: TheyDiTextStyles.labelMedium
                            .copyWith(color: TheyDiColors.textSecondary)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PressableScale(
                  onTap: _processing ? () {} : _accept,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: TheyDiColors.gradientPrimary,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: TheyDiColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: _processing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
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
  }
}

// ══════════════════════════════════════════════════════════════════════════
// SUB-TAB 4 — Requests sent (new)
// ══════════════════════════════════════════════════════════════════════════

class _RequestsSentSubTab extends ConsumerWidget {
  const _RequestsSentSubTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sentAsync = ref.watch(sentRequestsProvider);
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return sentAsync.when(
      data: (sent) {
        if (sent.isEmpty) {
          return const InboxEmptyState(
            icon: Icons.outgoing_mail,
            title: 'No sent requests',
            message: 'Requests you send will show up here until accepted.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          itemCount: sent.length,
          itemBuilder: (context, index) {
            final s = sent[index];
            return _RequestSentCard(
              toUid: s['toUid'] ?? '',
              toName: s['toName'] ?? 'Member',
              myUid: myUid,
            )
                .animate(delay: Duration(milliseconds: 40 * index))
                .fade(duration: 300.ms)
                .slideY(begin: 0.06, end: 0);
          },
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: TheyDiColors.primary)),
      error: (e, st) => const InboxEmptyState(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: 'Could not load sent requests.',
      ),
    );
  }
}

class _RequestSentCard extends StatefulWidget {
  final String toUid;
  final String toName;
  final String myUid;

  const _RequestSentCard({
    required this.toUid,
    required this.toName,
    required this.myUid,
  });

  @override
  State<_RequestSentCard> createState() => _RequestSentCardState();
}

class _RequestSentCardState extends State<_RequestSentCard> {
  bool _busy = false;

  Future<void> _cancel() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _cancelSentRequest(myUid: widget.myUid, toUid: widget.toUid);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial =
        widget.toName.isNotEmpty ? widget.toName[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
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
            ),
            child: Center(
              child: Text(initial,
                  style: TheyDiTextStyles.labelLarge
                      .copyWith(color: Colors.white)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.toName, style: TheyDiTextStyles.labelLarge),
                const SizedBox(height: 2),
                Text('Waiting for response',
                    style: TheyDiTextStyles.caption
                        .copyWith(color: TheyDiColors.textSecondary)),
              ],
            ),
          ),
          PressableScale(
            onTap: _busy ? () {} : _cancel,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: TheyDiColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: TheyDiColors.divider),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Cancel',
                      style: TheyDiTextStyles.labelMedium.copyWith(
                          color: TheyDiColors.textSecondary, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}