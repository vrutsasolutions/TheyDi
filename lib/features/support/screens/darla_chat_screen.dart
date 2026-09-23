import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/guest_mode_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/guest_promo_dialog.dart';
import '../models/chat_message.dart';
import '../services/ai_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/message_input.dart';
import '../widgets/suggestion_chip.dart';
import '../widgets/typing_indicator.dart';

class DarlaChatScreen extends ConsumerStatefulWidget {
  const DarlaChatScreen({super.key});

  @override
  ConsumerState<DarlaChatScreen> createState() => _DarlaChatScreenState();
}

class _DarlaChatScreenState extends ConsumerState<DarlaChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _controller = TextEditingController();
  final AIService _aiService = AIService.instance;

  final List<ChatMessage> _messages = [];

  bool _isTyping = false;

  // Guest mode (web only): how many messages a guest can send before
  // Darla asks them to sign in. Existing logged-in behavior is unlimited,
  // unchanged.
  static const _guestMessageLimit = 3;


  final List<String> _suggestedQuestions = [
    "Social Experiences",
    "Professional Experiences",
    "Circles",
    "Communities",
    "Connections",
    "Create an Experience",
    "Manage an Experience",
    "Payments & Refunds",
  ];

  @override
  void initState() {
    super.initState();
    _loadPersistedMessages();
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
            "Hi 👋\n\nI'm Darla, your TheyDi AI Support Assistant.\n\nI can help with social and professional experiences, Connections, Circles, Communities, bookings, payments, safety, and account support.\n\nWhat do you need help with today?",
        sender: MessageSender.darla,
        timestamp: DateTime.now(),
      ),
    );
  }

  String get _prefsKey {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return 'darla_chat_$uid';
  }


  Future<void> _loadPersistedMessages() async {
    final prefs = await SharedPreferences.getInstance();


    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final List<dynamic> decoded = jsonDecode(raw);
        final loaded = decoded
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
        if (loaded.isNotEmpty) {
          setState(() {
            _messages.clear();
            _messages.addAll(loaded);
          });
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom());
          return;
        }
      } catch (_) {}
    }
    // No saved messages — show welcome
    setState(() => _loadWelcomeMessage());
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_messages.map((m) => m.toJson()).toList());
    await prefs.setString(_prefsKey, encoded);
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
          toolbarHeight: 76,
          flexibleSpace: const AnimatedGradientHeader(),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
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
                backgroundColor: Colors.white,
                child: Icon(Icons.support_agent, color: TheyDiColors.primary),
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
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          "Online",
                          style: TheyDiTextStyles.labelSmall.copyWith(
                            color: Colors.white70,
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
              Expanded(
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: FloatingDotsBackground(),
                    ),
                    Column(
                      children: [
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

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: ChatBubble(
                                      message: message,
                                      isWelcomeMessage: index == 0 &&
                                          message.sender == MessageSender.darla,
                                      onFeedback: isLatestDarlaMessage && index != 0
                                          ? (isHelpful) =>
                                              _setFeedback(message, isHelpful)
                                          : null,
                                    ),
                                  ),
                                  if (index == 0 && _messages.length == 1)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 12,
                                        bottom: 12,
                                      ),
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _aiService.suggestedQuestions
                                            .map((q) {
                                          return GestureDetector(
                                            onTap: () =>
                                                _sendSuggestedQuestion(q),
                                            child: Container(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                horizontal: 14,
                                                vertical: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: TheyDiColors.primary
                                                      .withValues(alpha: 0.4),
                                                  width: 1.2,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.04),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                q,
                                                style: TheyDiTextStyles.bodySmall
                                                    .copyWith(
                                                  color: TheyDiColors.primary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
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
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final question = _suggestedQuestions[index];
                              return SuggestionChip(
                                title: question,
                                icon: Icons.help_outline_rounded,
                                onTap: () =>
                                    _sendSuggestedQuestion(question),
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
                  ],
                ),
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

    // Guest mode (web only): let them try Darla, then ask for sign-in
    // after a few messages instead of cutting them off with nothing.
    final isGuest = kIsWeb && ref.read(isGuestModeProvider);
    if (isGuest) {
      final userMessageCount =
          _messages.where((m) => m.sender == MessageSender.user).length;
      if (userMessageCount >= _guestMessageLimit) {
        GuestPromoDialog.show(
          context,
          title: 'Keep chatting with Darla',
          message: 'Log in or create an account to continue getting '
              'help from Darla.',
        );
        return;
      }
    }

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
    unawaited(_saveMessages());
    unawaited(_generateAIReply(trimmed));
  }

  void _sendSuggestedQuestion(String question) {
    final prompts = <String, String>{
      'Social Experiences':
          'I need help with social Experiences on TheyDi.',
      'Professional Experiences':
          'I need help with professional Experiences on TheyDi.',
      'Circles':
          'I need help understanding Circles on TheyDi.',
      'Communities':
          'I need help understanding Communities on TheyDi.',
      'Connections':
          'I need help understanding Connections on TheyDi.',
      'Create an Experience':
          'How do I create an Experience on TheyDi?',
      'Manage an Experience':
          'How do I manage an Experience I am hosting on TheyDi?',
      'Payments & Refunds':
          'I need help with payments or refunds for an Experience.',
    };

    final prompt = prompts[question] ?? question;
    _controller.text = prompt;
    _sendMessage(prompt);
  }

  Future<void> _generateAIReply(String userMessage) async {
    setState(() {
      _isTyping = true;
    });

    _scrollToBottom();

    // The current user message is already in _messages, so exclude it from
    // history here; getReply adds it as the newest user turn itself.
    final currentIndex = _messages.length - 1;
    final history = _messages
        .take(currentIndex)
        .where((message) => message.text.trim().isNotEmpty)
        .toList()
        .reversed
        .take(12)
        .toList()
        .reversed
        .map(
          (message) => <String, String>{
            'role': message.sender == MessageSender.user ? 'user' : 'assistant',
            'content': message.text,
          },
        )
        .toList();

    final response = await _aiService.getReply(
      userMessage,
      history: history,
    );

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
    unawaited(_saveMessages());
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
        _scrollController.position.maxScrollExtent,
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

    // Wipe persisted messages too
    SharedPreferences.getInstance().then((prefs) => prefs.remove(_prefsKey));
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

class AnimatedGradientHeader extends StatefulWidget {
  const AnimatedGradientHeader({super.key});

  @override
  State<AnimatedGradientHeader> createState() => _AnimatedGradientHeaderState();
}

class _AnimatedGradientHeaderState extends State<AnimatedGradientHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _color1;
  late Animation<Color?> _color2;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Subtle dark/light breathing effect
    _color1 = ColorTween(
      begin: const Color(0xFF065F46), // Deep dark green
      end: TheyDiColors.primary,      // Normal green
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _color2 = ColorTween(
      begin: TheyDiColors.secondary,   // Mid green
      end: const Color(0xFFA7F3D0),    // Very light mint
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _color1.value ?? TheyDiColors.primary,
                _color2.value ?? TheyDiColors.secondary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const FloatingDotsBackground(
              color: Colors.white, dotSizeMultiplier: 1.8),
        );
      },
    );
  }
}

class FloatingDotsBackground extends StatefulWidget {
  final Color? color;
  final double dotSizeMultiplier;
  const FloatingDotsBackground(
      {super.key, this.color, this.dotSizeMultiplier = 1.0});

  @override
  State<FloatingDotsBackground> createState() => _FloatingDotsBackgroundState();
}

class _FloatingDotsBackgroundState extends State<FloatingDotsBackground>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final int _dotCount = 40; // Small number of light dots
  late List<_Dot> _dots;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    final random = math.Random();
    _dots = List.generate(
      _dotCount,
      (i) => _Dot(
        x: random.nextDouble(),
        y: random.nextDouble(),
        speedX: (random.nextDouble() - 0.5) * 0.04, // Very slow moving
        speedY: (random.nextDouble() - 0.5) * 0.04,
        size: (random.nextDouble() * 2 + 1.5) *
            widget.dotSizeMultiplier, // Size scaled by multiplier
        opacity: random.nextDouble() * 0.15 + 0.05, // Very light (0.05 to 0.2)
      ),
    );
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final double dt = (elapsed - _lastElapsed).inMilliseconds / 1000.0;
    _lastElapsed = elapsed;

    setState(() {
      for (var dot in _dots) {
        dot.x += dot.speedX * dt;
        dot.y += dot.speedY * dt;

        // Wrap around edges
        if (dot.x < 0) dot.x += 1;
        if (dot.x > 1) dot.x -= 1;
        if (dot.y < 0) dot.y += 1;
        if (dot.y > 1) dot.y -= 1;
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DotsPainter(
        dots: _dots,
        color: widget.color ?? TheyDiColors.primary,
      ),
      size: Size.infinite,
    );
  }
}

class _Dot {
  double x;
  double y;
  final double speedX;
  final double speedY;
  final double size;
  final double opacity;
  _Dot({
    required this.x,
    required this.y,
    required this.speedX,
    required this.speedY,
    required this.size,
    required this.opacity,
  });
}

class _DotsPainter extends CustomPainter {
  final List<_Dot> dots;
  final Color color;
  final Paint _paint = Paint()..style = PaintingStyle.fill;

  _DotsPainter({required this.dots, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    for (var dot in dots) {
      _paint.color = color.withValues(alpha: dot.opacity);
      final offset = Offset(dot.x * size.width, dot.y * size.height);
      canvas.drawCircle(offset, dot.size, _paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => true;
}