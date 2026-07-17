import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/friends_service.dart';
import '../../../shared/widgets/avatar_online_status_dot.dart';

class FriendRequestsScreen extends StatelessWidget {
  const FriendRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

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
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: TheyDiColors.textPrimary),
                      onPressed: () {
                        if (GoRouter.of(context).canPop()) {
                          context.pop();
                        } else {
                          context.go(AppRoutes.home);
                        }
                      },
                    ),
                    const SizedBox(width: 4),
                    Text('Friend Requests',
                        style: TheyDiTextStyles.displayMedium),
                  ],
                ),
              ).animate().fade(duration: 300.ms),

              const SizedBox(height: 16),

              // ── Requests List ──
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FriendsService.streamFriendRequests(myUid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: TheyDiColors.primary),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline,
                                size: 64, color: Colors.grey[700]),
                            const SizedBox(height: 16),
                            Text('No pending requests',
                                style: TheyDiTextStyles.headlineMedium),
                            const SizedBox(height: 8),
                            Text(
                              'Connect with attendees at events to grow your network',
                              style: TheyDiTextStyles.bodySmall
                                  .copyWith(color: TheyDiColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final fromUid = data['fromUid'] ?? '';
                        final fromName = data['fromName'] ?? 'Someone';

                        return _RequestCard(
                          requestId: doc.id,
                          fromUid: fromUid,
                          fromName: fromName,
                          myUid: myUid,
                        )
                            .animate(delay: Duration(milliseconds: 60 * index))
                            .fade(duration: 300.ms)
                            .slideY(begin: 0.1, end: 0);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

  Future<void> _accept() async {
    setState(() => _processing = true);
    try {
      await FriendsService.acceptFriendRequest(
        requestId: widget.requestId,
        fromUid: widget.fromUid,
        fromName: widget.fromName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You and ${widget.fromName} are now friends! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _decline() async {
    setState(() => _processing = true);
    try {
      await FriendsService.declineFriendRequest(
        requestId: widget.requestId,
        myUid: widget.myUid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Friend request from ${widget.fromName} declined.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
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
        final photoUrl = data['profileImageUrl'] ?? data['photoUrl'] ?? '';
        final interests = List<String>.from(data['interests'] ?? []);
        final initial =
            widget.fromName.isNotEmpty ? widget.fromName[0].toUpperCase() : '?';

        return GestureDetector(
          // ── Tap anywhere on card → open Friend Info Screen ──
          onTap: () => context.push(
            AppRoutes.friendInfo,
            extra: {
              'uid': widget.fromUid,
              'displayName': widget.fromName,
            },
          ),
          child: Container(
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
                Row(
                  children: [
                    // Avatar + online status dot
                    Stack(
                      clipBehavior: Clip.none,
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
                                ? Image.network(
                                    photoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        initial,
                                        style: TheyDiTextStyles.labelLarge
                                            .copyWith(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      initial,
                                      style:
                                          TheyDiTextStyles.labelLarge.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: AvatarOnlineStatusDot(
                            uid: widget.fromUid,
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
                          Text(widget.fromName,
                              style: TheyDiTextStyles.labelLarge),
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

                    // Arrow hint
                    Icon(Icons.chevron_right,
                        color: TheyDiColors.textMuted, size: 20),
                  ],
                ),

                // Interests
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
                                color: TheyDiColors.primary
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(i,
                                  style: TheyDiTextStyles.caption.copyWith(
                                      color: TheyDiColors.primary,
                                      fontSize: 10)),
                            ))
                        .toList(),
                  ),
                ],

                const SizedBox(height: 14),

                // Accept / Decline buttons
                Row(
                  children: [
                    // Decline
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
                    // Accept
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
          ),
        );
      },
    );
  }
}
