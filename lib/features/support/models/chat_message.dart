import 'package:flutter/foundation.dart';

/// ---------------------------------------------------------------------------
/// Message Sender
/// ---------------------------------------------------------------------------
/// user  -> Message sent by the user
/// darla -> Message sent by AI Assistant
/// ---------------------------------------------------------------------------
enum MessageSender {
  user,
  darla,
}

/// ---------------------------------------------------------------------------
/// ChatMessage Model
/// ---------------------------------------------------------------------------
/// Stores every message shown in the Darla chat.
///
/// Includes:
/// • Sender (User / Darla)
/// • Message text
/// • Timestamp
/// • Typing indicator
/// • Feedback (Helpful / Not Helpful)
/// ---------------------------------------------------------------------------
@immutable
class ChatMessage {
  /// Unique message id
  final String id;

  /// Message text
  final String text;

  /// Who sent the message
  final MessageSender sender;

  /// Message creation time
  final DateTime timestamp;

  /// Used for "Darla is typing..."
  final bool isTyping;

  /// User feedback
  ///
  /// null  -> Not answered yet
  /// true  -> 👍 Helpful
  /// false -> 👎 Not Helpful
  final bool? isHelpful;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.isTyping = false,
    this.isHelpful,
  });

  /// -------------------------------------------------------------------------
  /// Creates a modified copy of the current message.
  /// -------------------------------------------------------------------------
  ChatMessage copyWith({
    String? id,
    String? text,
    MessageSender? sender,
    DateTime? timestamp,
    bool? isTyping,
    bool? isHelpful,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      isTyping: isTyping ?? this.isTyping,
      isHelpful: isHelpful ?? this.isHelpful,
    );
  }

  /// -------------------------------------------------------------------------
  /// Convert model to JSON
  /// -------------------------------------------------------------------------
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'sender': sender.name,
      'timestamp': timestamp.toIso8601String(),
      'isTyping': isTyping,
      'isHelpful': isHelpful,
    };
  }

  /// -------------------------------------------------------------------------
  /// Create model from JSON
  /// -------------------------------------------------------------------------
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      text: json['text'] as String,
      sender:
          json['sender'] == 'user' ? MessageSender.user : MessageSender.darla,
      timestamp: DateTime.parse(json['timestamp']),
      isTyping: json['isTyping'] ?? false,
      isHelpful: json['isHelpful'],
    );
  }
}
