import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Reusable empty state for any Inbox tab (Connections / Circles /
/// Communities) with no data yet.
class InboxEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool compact;

  const InboxEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 16 : 48),
      child: Column(
        children: [
          Icon(icon, size: compact ? 36 : 56, color: Colors.grey[700]),
          const SizedBox(height: 12),
          Text(title,
              style: compact
                  ? TheyDiTextStyles.labelLarge
                  : TheyDiTextStyles.headlineMedium),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TheyDiTextStyles.bodySmall
                .copyWith(color: TheyDiColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Gentle scale-down-on-tap wrapper used throughout Home, Explore, and
/// Inbox so interactive elements feel consistently tactile. Duplicated
/// (rather than imported across features) so each feature folder stays
/// self-contained — move this into a shared/widgets file if you'd rather
/// have one copy app-wide.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const PressableScale({super.key, required this.child, required this.onTap});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Pill-style segmented sub-tab bar used *inside* a top-level Inbox tab
/// (e.g. Connections' Chats/Suggestions/Requests/Sent, Communities'
/// My/Suggestions/Requested). Deliberately different from the main Inbox
/// tab row's underline style, so it reads as "a layer inside this tab"
/// rather than a second identical tab bar.
class InboxSubTabBar extends StatefulWidget {
  final TabController controller;
  final List<String> tabs;
  final Map<int, int> badges; // tab index -> count, 0/absent = no badge

  const InboxSubTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    this.badges = const {},
  });

  @override
  State<InboxSubTabBar> createState() => _InboxSubTabBarState();
}

class _InboxSubTabBarState extends State<InboxSubTabBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TheyDiColors.divider),
      ),
      child: Row(
        children: List.generate(widget.tabs.length, (i) {
          final isSelected = widget.controller.index == i;
          final badgeCount = widget.badges[i] ?? 0;
          return Expanded(
            child: PressableScale(
              onTap: () => widget.controller.animateTo(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient: isSelected ? TheyDiColors.gradientPrimary : null,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: TheyDiColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Text(
                      widget.tabs[i],
                      textAlign: TextAlign.center,
                      style: TheyDiTextStyles.caption.copyWith(
                        color: isSelected
                            ? Colors.white
                            : TheyDiColors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        top: -6,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: TheyDiColors.error,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: TheyDiColors.card, width: 1.5),
                          ),
                          constraints: const BoxConstraints(
                              minWidth: 16, minHeight: 16),
                          alignment: Alignment.center,
                          child: Text(
                            badgeCount > 9 ? '9+' : '$badgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}