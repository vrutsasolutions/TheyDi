import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../models/circle_model.dart';
import '../../inbox_shared_widgets.dart';

// ── Provider ──
//
// FIX vs. the pattern used in circles_list_screen.dart: that screen does
// `.orderBy('lastMessageAt', descending: true)` directly in the Firestore
// query. Firestore excludes any document missing the field you order by —
// so a brand-new circle with no messages yet (lastMessageAt still null)
// would silently never show up in the list. Fixed here by fetching
// unordered and sorting client-side against `lastMessageAt ?? createdAt`,
// so new circles appear immediately (sorted as most-recent-first by
// creation time until they get their first message).
final myCirclesProvider = StreamProvider.autoDispose<List<CircleModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('circles')
      .where('memberUids', arrayContains: uid)
      .snapshots()
      .map((s) {
    final circles = s.docs.map((d) => CircleModel.fromFirestore(d)).toList();
    circles.sort((a, b) {
      final aTime = a.lastMessageAt ?? a.createdAt;
      final bTime = b.lastMessageAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
    return circles;
  });
});

// ── Tab ──

class CirclesTab extends ConsumerWidget {
  const CirclesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circlesAsync = ref.watch(myCirclesProvider);

    return CustomScrollView(
      slivers: [
        circlesAsync.when(
          data: (circles) {
            if (circles.isEmpty) {
              return const SliverToBoxAdapter(
                child: InboxEmptyState(
                  icon: Icons.groups_outlined,
                  title: 'No circles yet',
                  message:
                      'When you join an experience with a Circle, it will show up here.',
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final circle = circles[index];
                    return _CircleCard(circle: circle)
                        .animate(delay: Duration(milliseconds: 40 * index))
                        .fade(duration: 300.ms)
                        .slideY(begin: 0.06, end: 0);
                  },
                  childCount: circles.length,
                ),
              ),
            );
          },
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(
                  child:
                      CircularProgressIndicator(color: TheyDiColors.primary)),
            ),
          ),
          error: (e, st) => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),
      ],
    );
  }
}

class _CircleCard extends StatelessWidget {
  final CircleModel circle;
  const _CircleCard({required this.circle});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => context.push(AppRoutes.circleChat, extra: circle),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TheyDiColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TheyDiColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
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
                borderRadius: BorderRadius.circular(13),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: (circle.profileImageUrl?.isNotEmpty ?? false)
                    ? Image.network(
                        circle.profileImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(circle.initials,
                              style: TheyDiTextStyles.labelLarge
                                  .copyWith(color: Colors.white)),
                        ),
                      )
                    : Center(
                        child: Text(circle.initials,
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
                  Text(circle.name,
                      style: TheyDiTextStyles.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    (circle.lastMessage?.isNotEmpty ?? false)
                        ? '${circle.memberCount} member${circle.memberCount == 1 ? '' : 's'} · Tap to chat'
                        : '${circle.memberCount} member${circle.memberCount == 1 ? '' : 's'}',
                    style: TheyDiTextStyles.caption
                        .copyWith(color: TheyDiColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}