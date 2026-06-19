import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/friends_service.dart';
import '../../../core/theme/app_theme.dart';

final _blockedUsersProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('blocked')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
});

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedUidsAsync = ref.watch(_blockedUsersProvider);

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
              // App bar
              Padding(
                padding: const EdgeInsets.only(
                  left: 8,
                  right: 20,
                  top: 24,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 4),
                    Text('Blocked Users',
                        style: TheyDiTextStyles.displayMedium),
                  ],
                ),
              ).animate().fade(duration: 300.ms),

              const SizedBox(height: 16),

              Expanded(
                child: blockedUidsAsync.when(
                  loading: () => const Center(
                    child:
                        CircularProgressIndicator(color: TheyDiColors.primary),
                  ),
                  error: (e, _) => Center(
                    child: Text('Failed to load: $e',
                        style: TheyDiTextStyles.bodySmall),
                  ),
                  data: (uids) {
                    if (uids.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.block_outlined,
                                size: 64, color: TheyDiColors.textMuted),
                            const SizedBox(height: 16),
                            Text('No blocked users',
                                style: TheyDiTextStyles.bodyMedium.copyWith(
                                    color: TheyDiColors.textSecondary)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: uids.length,
                      itemBuilder: (context, index) {
                        return _BlockedUserTile(uid: uids[index])
                            .animate(delay: (index * 50).ms)
                            .fade(duration: 300.ms)
                            .slideX(begin: 0.1, end: 0);
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

class _BlockedUserTile extends StatelessWidget {
  final String uid;
  const _BlockedUserTile({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 70);
        }
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final name = data?['displayName'] ?? data?['name'] ?? 'Unknown User';
        final photoUrl = data?['profileImageUrl'] ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: TheyDiColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TheyDiColors.divider),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: TheyDiColors.cardLight,
                backgroundImage:
                    photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty
                    ? const Icon(Icons.person,
                        color: TheyDiColors.textSecondary)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name, style: TheyDiTextStyles.labelLarge),
              ),
              TextButton(
                onPressed: () => _unblock(context, name),
                child: Text('Unblock',
                    style: TheyDiTextStyles.labelMedium
                        .copyWith(color: TheyDiColors.primary)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _unblock(BuildContext context, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TheyDiColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Unblock $name?', style: TheyDiTextStyles.headlineMedium),
        content: Text(
          'They will be able to see your profile and send you messages again.',
          style: TheyDiTextStyles.bodyMedium
              .copyWith(color: TheyDiColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TheyDiTextStyles.labelMedium
                    .copyWith(color: TheyDiColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Unblock',
                style: TheyDiTextStyles.labelMedium
                    .copyWith(color: TheyDiColors.primary)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FriendsService.unblockUser(otherUid: uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name unblocked')),
        );
      }
    }
  }
}
