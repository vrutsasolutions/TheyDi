import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_theme.dart';
import 'circles/screens/circles_tab.dart';
import 'community/screens/communities_tab.dart';
import 'connections/screens/connections_tab.dart';
import 'inbox_shared_widgets.dart';

class InboxScreen extends StatefulWidget {
  final int initialTab;
  const InboxScreen({super.key, this.initialTab = 0});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = ['Connections', 'Circles', 'Communities'];
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, _tabs.length - 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Contextual header action per tab:
  //  - Connections → invite people (you can't "create" a connection, but
  //    you can bring more people onto the app to connect with)
  //  - Circles     → none. Circles are created by an experience's host
  //    from that experience's own flow, never from the Inbox.
  //  - Communities → create a new community (anyone can make one).
  Widget? _headerAction(int index) {
    switch (index) {
      case 0:
        return _HeaderActionButton(
          icon: Icons.person_add_alt_1,
          // NOTE: AppRoutes.inviteFriends already exists in your router
          // (confirmed via profile_screen.dart) — reusing it here.
          onPressed: () => context.push(AppRoutes.inviteFriends),
        );
      case 2:
        return _HeaderActionButton(
          icon: Icons.add_circle_outline,
          onPressed: () => context.push(AppRoutes.createCommunity),
        );
      default:
        return null;
    }
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + contextual action
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
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
                        Text('Inbox', style: TheyDiTextStyles.displayMedium),
                        const Spacer(),
                        if (_headerAction(_tabController.index) != null)
                          _headerAction(_tabController.index)!,
                      ],
                    ),
                  );
                },
              ).animate().fade(duration: 300.ms),

              const SizedBox(height: 12),

              // Tab row — same underline-tab treatment as the Home screen's
              // For You / Social / Professional tabs.
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: List.generate(_tabs.length, (i) {
                        final isSelected = _tabController.index == i;
                        return Padding(
                          padding: const EdgeInsets.only(right: 26),
                          child: PressableScale(
                            onTap: () => _tabController.animateTo(i),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _tabs[i],
                                  style: TheyDiTextStyles.labelLarge.copyWith(
                                    color: isSelected
                                        ? TheyDiColors.primary
                                        : TheyDiColors.textMuted,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  height: 3,
                                  width: isSelected ? 22 : 0,
                                  decoration: BoxDecoration(
                                    gradient: TheyDiColors.gradientPrimary,
                                    borderRadius: BorderRadius.circular(2),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: TheyDiColors.primary
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                },
              ).animate(delay: 100.ms).fade(duration: 300.ms),

              const SizedBox(height: 8),
              Divider(color: TheyDiColors.divider, height: 1),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    ConnectionsTab(),
                    CirclesTab(),
                    CommunitiesTab(),
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

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _HeaderActionButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: TheyDiColors.gradientPrimary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: TheyDiColors.primary.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    );
  }
}