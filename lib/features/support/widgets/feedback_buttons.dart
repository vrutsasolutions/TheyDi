import 'package:flutter/material.dart';

/// ===============================================================
/// Feedback Buttons Widget
///
/// Displays:
/// 👍 Helpful
/// 👎 Not Helpful
///
/// Usage:
/// FeedbackButtons(
///   onHelpful: () {},
///   onNotHelpful: () {},
/// )
/// ===============================================================
class FeedbackButtons extends StatefulWidget {
  final VoidCallback? onHelpful;
  final VoidCallback? onNotHelpful;

  const FeedbackButtons({
    super.key,
    this.onHelpful,
    this.onNotHelpful,
  });

  @override
  State<FeedbackButtons> createState() => _FeedbackButtonsState();
}

class _FeedbackButtonsState extends State<FeedbackButtons> {
  bool? _isHelpful;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ==============================
        // Helpful Button
        // ==============================
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            setState(() => _isHelpful = true);
            widget.onHelpful?.call();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: _isHelpful == true
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHelpful == true ? Colors.green : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.thumb_up_alt_outlined,
                  size: 16,
                  color:
                      _isHelpful == true ? Colors.green : Colors.grey.shade700,
                ),
                const SizedBox(width: 5),
                Text(
                  'Helpful',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isHelpful == true
                        ? Colors.green
                        : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 10),

        // ==============================
        // Not Helpful Button
        // ==============================
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            setState(() => _isHelpful = false);
            widget.onNotHelpful?.call();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: _isHelpful == false
                  ? Colors.red.withValues(alpha: 0.12)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHelpful == false ? Colors.red : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.thumb_down_alt_outlined,
                  size: 16,
                  color:
                      _isHelpful == false ? Colors.red : Colors.grey.shade700,
                ),
                const SizedBox(width: 5),
                Text(
                  'Not Helpful',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        _isHelpful == false ? Colors.red : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
