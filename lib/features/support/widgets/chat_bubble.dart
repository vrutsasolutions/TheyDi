import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../models/chat_message.dart';
import 'feedback_buttons.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final ValueChanged<bool>? onFeedback;

  const ChatBubble({
    super.key,
    required this.message,
    this.onFeedback,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == MessageSender.user;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () async {
            await Clipboard.setData(
              ClipboardData(text: message.text),
            );

            if (!context.mounted) return;

            HapticFeedback.lightImpact();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Message copied"),
                duration: Duration(seconds: 1),
              ),
            );
          },
          child: Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: const BoxConstraints(
                  maxWidth: 280,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isUser ? TheyDiColors.primary : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isUser ? 18 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  message.text,
                  style: TheyDiTextStyles.bodyMedium.copyWith(
                    color: isUser ? Colors.white : TheyDiColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('hh:mm a').format(message.timestamp),
                style: TheyDiTextStyles.caption.copyWith(
                  color: TheyDiColors.textMuted,
                  fontSize: 10,
                ),
              ),
              if (!isUser && onFeedback != null) ...[
                const SizedBox(height: 6),
                FeedbackButtons(
                  onHelpful: () => onFeedback?.call(true),
                  onNotHelpful: () => onFeedback?.call(false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
