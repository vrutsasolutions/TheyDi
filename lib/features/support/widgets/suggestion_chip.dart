import 'package:flutter/material.dart';

/// ===========================================================
/// SuggestionChip Widget
///
/// Displays a tappable suggestion for Darla AI.
/// Example:
///  • Create an Event
///  • Verify My Profile
///  • Payment Issues
/// ===========================================================
class SuggestionChip extends StatelessWidget {
  /// Text displayed inside the chip
  final String title;

  /// Icon displayed before the title
  final IconData icon;

  /// Callback when the chip is tapped
  final VoidCallback onTap;

  const SuggestionChip({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.grey.shade300,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// Suggestion Icon
            Icon(
              icon,
              size: 18,
              color: Theme.of(context).primaryColor,
            ),

            const SizedBox(width: 8),

            /// Suggestion Text
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
