import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';
import '../models/chat_message.dart';
import '../services/ai_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/message_input.dart';
import '../widgets/suggestion_chip.dart';
import '../widgets/typing_indicator.dart';

class DarlaChatScreen extends StatefulWidget {
  const DarlaChatScreen({super.key});

  @override
  State<DarlaChatScreen> createState() => _DarlaChatScreenState();
}

class _DarlaChatScreenState extends State<DarlaChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _controller = TextEditingController();
  final AIService _aiService = AIService.instance;

  final List<ChatMessage> _messages = [];

  bool _isTyping = false;

  final List<String> _suggestedQuestions = [
    "Create Event",
    "Edit Event",
    "Cancel Event",
    "Host Event",
    "Friend Circles",
    "Invite Friends",
    "Verification",
    "Payments",
    "Refunds",
    "Tickets",
    "Privacy",
    "Password",
    "Notifications",
    "Profile",
    "Delete Account",
    "Report User",
    "Block User",
    "Safety",
    "Hosting",
    "Contact Support",
    "Community Guidelines",
    "Location",
    "Account",
    "Login",
    "Settings",
  ];

  @override
  void initState() {
    super.initState();
    _loadWelcomeMessage();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadWelcomeMessage() {
    _messages.add(
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text:
            "Hi 👋\n\nI'm Darla, your TheyDi AI Support Assistant.\n\nI can help with:\n\n• Events\n\n• Friend Circles\n\n• Verification\n\n• Payments\n\n• Profile\n\n• Safety\n\nHow can I help today?",
        sender: MessageSender.darla,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (_messages.length <= 1) return true;

    final exit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Leave Chat"),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Are you sure you want to close Darla Support?"),
              const SizedBox(height: 18),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Stay"),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Exit"),
                ),
              ),
            ],
          ),
        );
      },
    );

    return exit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: TheyDiColors.surface,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: TheyDiColors.textPrimary,
          centerTitle: false,
          titleSpacing: 0,
          actions: [
            IconButton(
              tooltip: "Clear chat",
              onPressed: _showClearChatDialog,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
          title: Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: TheyDiColors.primary,
                child: Icon(
                  Icons.support_agent,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Darla",
                      style: TheyDiTextStyles.headlineMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          "Online",
                          style: TheyDiTextStyles.labelSmall.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Container(
  height: 62,
  color: Colors.white,
  alignment: Alignment.centerLeft,
  child: ListView.separated(
    padding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 10,
    ),
    scrollDirection: Axis.horizontal,
    itemCount: _suggestedQuestions.length,
    separatorBuilder: (_, __) => const SizedBox(width: 8),
    itemBuilder: (context, index) {
      final question = _suggestedQuestions[index];

      return SuggestionChip(
        title: question,
        icon: Icons.help_outline_rounded,
        onTap: () => _sendSuggestedQuestion(question),
      );
    },
  ),
),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isTyping && index == _messages.length) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 12),
                        child: TypingIndicator(),
                      );
                    }

                    final message = _messages[index];
                    final isLatestDarlaMessage =
                        message.sender == MessageSender.darla &&
                            index == _latestDarlaMessageIndex;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ChatBubble(
                        message: message,
                        onFeedback: isLatestDarlaMessage
                            ? (isHelpful) => _setFeedback(message, isHelpful)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              MessageInput(
                controller: _controller,
                onSend: () => _sendMessage(_controller.text),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int get _latestDarlaMessageIndex {
    for (var index = _messages.length - 1; index >= 0; index--) {
      if (_messages[index].sender == MessageSender.darla) {
        return index;
      }
    }
    return -1;
  }

  void _sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: trimmed,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(message);
      _controller.clear();
    });

    _scrollToBottom();
    unawaited(_generateAIReply(trimmed));
  }

  void _sendSuggestedQuestion(String question) {
    _controller.text = question;
    _sendMessage(question);
  }

  Future<void> _generateAIReply(String userMessage) async {
    setState(() {
      _isTyping = true;
    });

    _scrollToBottom();

    final response = await _aiService.getReply(userMessage);

    if (!mounted) return;

    final reply = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: response,
      sender: MessageSender.darla,
      timestamp: DateTime.now(),
    );

    setState(() {
      _isTyping = false;
      _messages.add(reply);
    });

    _scrollToBottom();
  }

  void _setFeedback(ChatMessage message, bool isHelpful) {
    final index = _messages.indexWhere((item) => item.id == message.id);
    if (index == -1) return;

    setState(() {
      _messages[index] = _messages[index].copyWith(isHelpful: isHelpful);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  void _clearConversation() {
    setState(() {
      _messages.clear();
      _loadWelcomeMessage();
    });

    _scrollToBottom();
  }

  Future<void> _showClearChatDialog() async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Clear Conversation"),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Do you want to remove all messages from this chat?",
              ),
              const SizedBox(height: 18),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel"),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Clear"),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (clear == true) {
      _clearConversation();
    }
  }
}
