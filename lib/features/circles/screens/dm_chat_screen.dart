import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/friends_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/platform_helper.dart';

const _kEmojis = [
  '😀',
  '😂',
  '😍',
  '😎',
  '🥳',
  '😢',
  '😡',
  '🤔',
  '👋',
  '👍',
  '👏',
  '🙏',
  '❤️',
  '🔥',
  '🎉',
  '✅',
  '💯',
  '😅',
  '🤣',
  '😊',
  '😇',
  '🥰',
  '😘',
  '😜',
  '😴',
  '🤗',
  '🤩',
  '😬',
  '🙄',
  '😏',
  '😒',
  '😔',
  '😤',
  '😭',
  '😱',
  '😳',
  '🤯',
  '🤪',
  '🥺',
  '😋',
  '🤤',
  '🤑',
  '🤫',
  '🤭',
  '🧐',
  '🥴',
  '😷',
  '🤧',
  '👌',
  '✌️',
  '🤞',
  '🤙',
  '💪',
  '🙌',
  '👀',
  '💀',
  '🎊',
  '🌟',
  '💫',
  '⚡',
];

const _kReportReasons = [
  'Spam or unwanted messages',
  'Harassment or bullying',
  'Fake profile or impersonation',
  'Inappropriate content',
  'Scam or fraud',
  'Other',
];

final _sharedPlayer = ap.AudioPlayer();

class DmChatScreen extends ConsumerStatefulWidget {
  final String otherUid;
  final String otherName;
  const DmChatScreen(
      {super.key, required this.otherUid, required this.otherName});

  @override
  ConsumerState<DmChatScreen> createState() => _DmChatScreenState();
}

class _DmChatScreenState extends ConsumerState<DmChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  String? _chatId;
  bool _chatLoading = true;
  bool _showEmojiPicker = false;
  bool _notificationsMuted = false;
  DateTime? _clearedAt;

  // ── Voice ──────────────────────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isUploading = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  double _dragOffset = 0;
  static const double _cancelThreshold = 80.0;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() => setState(() {}));
    _initChat();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _recordTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Chat init ──────────────────────────────────────────────────────────────
  String _generateChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> _initChat() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    // Enforce Allow Messages privacy toggle on the *target user*.
    final otherUserSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.otherUid)
        .get();

    final otherPrivacy =
        otherUserSnap.data()?['privacySettings'] as Map<String, dynamic>?;
    final allowMessages = (otherPrivacy?['allowMessages'] as bool?) ?? true;

    // Owner can always message themselves; otherwise block when disabled.
    if (widget.otherUid != myUid && !allowMessages) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Messaging is disabled for this user.'),
        ),
      );
      context.pop();
      return;
    }

    final chatId = _generateChatId(myUid, widget.otherUid);
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    if (!(await chatRef.get()).exists) {
      await chatRef.set({
        'participants': [myUid, widget.otherUid],
        'type': 'dm',
        'lastMessage': null,
        'lastMessageSenderId': null,
        'updatedAt': Timestamp.now(),
        'createdAt': Timestamp.now(),
      });
    }
    final clearDoc = await chatRef.collection('clearedBy').doc(myUid).get();
    if (clearDoc.exists) {
      final ts = clearDoc.data()?['clearedAt'] as Timestamp?;
      if (ts != null) _clearedAt = ts.toDate();
    }
    final muteDoc = await chatRef.collection('mutedBy').doc(myUid).get();
    if (mounted) {
      setState(() {
        _chatId = chatId;
        _chatLoading = false;
        _notificationsMuted = muteDoc.exists;
      });
    }
  }

  // ── Text send ──────────────────────────────────────────────────────────────
  Future<void> _sendMessage([String? override]) async {
    final text = (override ?? _messageController.text).trim();
    if (text.isEmpty || _isSending || _chatId == null) return;
    setState(() {
      _isSending = true;
      _showEmojiPicker = false;
    });
    _messageController.clear();
    try {
      final myUid = FirebaseAuth.instance.currentUser!.uid;
      String myName = FirebaseAuth.instance.currentUser?.displayName ?? 'Me';
      try {
        final d = await FirebaseFirestore.instance
            .collection('users')
            .doc(myUid)
            .get();
        if (d.exists) myName = d.data()?['displayName'] ?? myName;
      } catch (_) {}
      final now = Timestamp.now();
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .add({
        'senderId': myUid,
        'senderName': myName,
        'type': 'text',
        'text': text,
        'timestamp': now,
        'seen': false,
        'readBy': [myUid],
      });
      await FirebaseFirestore.instance.collection('chats').doc(_chatId).update({
        'lastMessage': text,
        'lastMessageSenderId': myUid,
        'updatedAt': now,
        'deletedFor': FieldValue.arrayRemove([myUid, widget.otherUid]),
      });
      await NotificationService.send(
        toUid: widget.otherUid,
        title: 'New message from $myName 💬',
        body: text.length > 50 ? '${text.substring(0, 50)}...' : text,
        type: 'social',
        fromUid: myUid,
        chatId: _chatId,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) _showSnack('Failed: $e', Colors.red);
    }
    if (mounted) setState(() => _isSending = false);
  }

  // ── Voice recording ────────────────────────────────────────────────────────
  Future<bool> _requestMicPermission() async {
    if (kIsWeb) {
      // The record package handles browser mic permission automatically
      return await _recorder.hasPermission();
    }
    final status = await Permission.microphone.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                  backgroundColor: TheyDiColors.card,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: Text('Microphone Access',
                      style: TheyDiTextStyles.headlineMedium),
                  content: Text(
                      'Microphone access is required to send voice messages.',
                      style: TheyDiTextStyles.bodySmall
                          .copyWith(color: TheyDiColors.textSecondary)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          openAppSettings();
                        },
                        child: Text('Open Settings',
                            style: TextStyle(color: TheyDiColors.primary))),
                  ],
                ));
      }
      return false;
    }
    return status.isGranted;
  }

  Future<void> _startRecording() async {
    if (!await _requestMicPermission()) return;
    try {
      if (kIsWeb) {
        await _recorder.start(
          const RecordConfig(),
          path: '', // web uses blob URL internally, path ignored
        );
      } else {
        final tmpDir = await getTempDirPath();
        final path =
            '$tmpDir/voice_${DateTime.now().millisecondsSinceEpoch}.aac';
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
        HapticFeedback.mediumImpact();
      }
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
        _dragOffset = 0;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recordSeconds++);
        if (_recordSeconds >= 120) _stopAndSendRecording();
      });
    } catch (e) {
      if (mounted) _showSnack('Could not start recording: $e', Colors.red);
    }
  }

  Future<void> _stopAndSendRecording() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    final duration = _recordSeconds;
    try {
      // stop() returns file path on mobile, blob URL on web
      final path = await _recorder.stop();
      if (!kIsWeb) HapticFeedback.lightImpact();
      setState(() {
        _isRecording = false;
        _recordSeconds = 0;
        _dragOffset = 0;
      });

      if (duration < 1) return;

      if (path == null || path.isEmpty) {
        if (mounted) {
          _showSnack('Recording failed — no audio captured', Colors.red);
        }
        return;
      }
      await _uploadAndSendVoice(path, duration);
    } catch (e) {
      setState(() {
        _isRecording = false;
        _recordSeconds = 0;
      });
      if (mounted) _showSnack('Recording failed: $e', Colors.red);
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {}
    if (!kIsWeb) HapticFeedback.heavyImpact();
    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
      _dragOffset = 0;
    });
    if (mounted) {
      _showSnack('Recording cancelled', Colors.grey.shade700,
          duration: const Duration(seconds: 2));
    }
  }

  Future<void> _uploadAndSendVoice(String filePath, int durationSecs) async {
    if (_chatId == null) return;
    setState(() => _isUploading = true);
    try {
      final myUid = FirebaseAuth.instance.currentUser!.uid;
      String myName = FirebaseAuth.instance.currentUser?.displayName ?? 'Me';
      try {
        final d = await FirebaseFirestore.instance
            .collection('users')
            .doc(myUid)
            .get();
        if (d.exists) myName = d.data()?['displayName'] ?? myName;
      } catch (_) {}

      final List<int> bytes;
      final String ext;
      if (kIsWeb) {
        bytes = await getBlobBytes(filePath);
        ext = 'webm';
      } else {
        bytes = await getFileBytes(filePath);
        ext = 'aac';
      }

      if (bytes.isEmpty) {
        if (mounted) {
          _showSnack('Audio capture failed — please try again', Colors.red);
        }
        setState(() => _isUploading = false);
        return;
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('voice_messages')
          .child(_chatId!)
          .child(fileName);

      final contentType = kIsWeb ? 'audio/webm' : 'audio/aac';
      final snapshot = await storageRef.putData(
        Uint8List.fromList(bytes),
        SettableMetadata(contentType: contentType),
      );
      final audioUrl = await snapshot.ref.getDownloadURL();

      final now = Timestamp.now();
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .add({
        'senderId': myUid,
        'senderName': myName,
        'type': 'voice',
        'audioUrl': audioUrl,
        'duration': durationSecs,
        'text': '🎤 Voice message',
        'timestamp': now,
        'seen': false,
        'readBy': [myUid],
      });

      await FirebaseFirestore.instance.collection('chats').doc(_chatId).update({
        'lastMessage': '🎤 Voice message',
        'lastMessageSenderId': myUid,
        'updatedAt': now,
        'deletedFor': FieldValue.arrayRemove([myUid, widget.otherUid]),
      });

      await NotificationService.send(
        toUid: widget.otherUid,
        title: 'Voice message from $myName 🎤',
        body: 'Sent a voice message',
        type: 'social',
        fromUid: myUid,
        chatId: _chatId,
      );

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Expanded(child: Text('Upload failed. Tap to retry.')),
            GestureDetector(
              onTap: () => _uploadAndSendVoice(filePath, durationSecs),
              child: const Text('Retry',
                  style: TextStyle(
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 6),
        ));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _openFriendInfo() => context.push(AppRoutes.friendInfo, extra: {
        'uid': widget.otherUid,
        'displayName': widget.otherName,
      });

  void _openUserProfile() => context.push(AppRoutes.userProfile, extra: {
        'uid': widget.otherUid,
        'requestId': null,
      });

  Future<void> _toggleMuteNotifications() async {
    if (_chatId == null) return;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    final muteRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('mutedBy')
        .doc(myUid);

    if (_notificationsMuted) {
      await muteRef.delete();
    } else {
      await muteRef.set({
        'mutedAt': Timestamp.now(),
        'otherUid': widget.otherUid,
      });
    }

    if (!mounted) return;
    setState(() => _notificationsMuted = !_notificationsMuted);
    _showSnack(
      _notificationsMuted
          ? 'Notifications muted for ${widget.otherName}'
          : 'Notifications unmuted for ${widget.otherName}',
      TheyDiColors.primary,
    );
  }

  Future<void> _deleteChat() async {
    if (_chatId == null) return;
    final confirmed = await _confirmDialog(
      title: 'Delete Chat?',
      body:
          'This removes the conversation from your chat list and clears messages from your view. ${widget.otherName} will still see their copy.',
      confirm: 'Delete',
      confirmColor: Colors.red,
    );
    if (!confirmed) return;

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;
    final now = Timestamp.now();
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(_chatId);

    await chatRef.collection('clearedBy').doc(myUid).set({'clearedAt': now});
    await chatRef.collection('deletedBy').doc(myUid).set({
      'deletedAt': now,
      'otherUid': widget.otherUid,
    });
    await chatRef.update({
      'deletedFor': FieldValue.arrayUnion([myUid]),
    });

    if (!mounted) return;
    _showSnack('Chat deleted', Colors.red);
    context.pop();
  }

  Future<void> _blockUser() async {
    final confirmed = await _confirmDialog(
      title: 'Block ${widget.otherName}?',
      body:
          'They won\'t be able to send friend requests or see your profile. This also removes the friendship.',
      confirm: 'Block',
      confirmColor: Colors.red,
    );
    if (!confirmed) return;

    await FriendsService.blockUser(otherUid: widget.otherUid);
    if (!mounted) return;
    _showSnack('${widget.otherName} blocked', Colors.red);
    context.pop();
  }

  Future<void> _reportUser() async {
    String? selectedReason;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: BoxDecoration(
            color: TheyDiColors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: TheyDiColors.divider),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TheyDiColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.flag_outlined,
                      color: Colors.red, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Report ${widget.otherName}',
                    style: TheyDiTextStyles.headlineMedium),
              ]),
              const SizedBox(height: 6),
              Text('Select a reason for reporting',
                  style: TheyDiTextStyles.bodySmall
                      .copyWith(color: TheyDiColors.textSecondary)),
              const SizedBox(height: 16),
              ..._kReportReasons.map((reason) => GestureDetector(
                    onTap: () => setModalState(() => selectedReason = reason),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: selectedReason == reason
                            ? Colors.red.withValues(alpha: 0.1)
                            : TheyDiColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedReason == reason
                              ? Colors.red.withValues(alpha: 0.5)
                              : TheyDiColors.divider,
                        ),
                      ),
                      child: Row(children: [
                        Icon(
                          selectedReason == reason
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 18,
                          color: selectedReason == reason
                              ? Colors.red
                              : TheyDiColors.textMuted,
                        ),
                        const SizedBox(width: 12),
                        Text(reason,
                            style: TheyDiTextStyles.bodySmall.copyWith(
                              color: selectedReason == reason
                                  ? Colors.red
                                  : TheyDiColors.textSecondary,
                            )),
                      ]),
                    ),
                  )),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selectedReason != null
                        ? Colors.red
                        : TheyDiColors.divider,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: selectedReason == null
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            await _submitReport(selectedReason!);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Submit Report',
                        style: TheyDiTextStyles.labelMedium
                            .copyWith(color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitReport(String reason) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;
    await FirebaseFirestore.instance.collection('reports').add({
      'reportedUid': widget.otherUid,
      'reportedName': widget.otherName,
      'reporterUid': myUid,
      'reason': reason,
      'type': 'user',
      'source': 'dm_chat',
      'chatId': _chatId,
      'createdAt': Timestamp.now(),
      'status': 'pending',
    });

    if (mounted) {
      _showSnack(
        'Report submitted. Thank you for helping keep TheyDi safe.',
        Colors.green,
      );
    }
  }

  Future<bool> _confirmDialog({
    required String title,
    required String body,
    required String confirm,
    Color confirmColor = Colors.red,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TheyDiColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: TheyDiTextStyles.headlineMedium),
        content: Text(
          body,
          style: TheyDiTextStyles.bodyMedium
              .copyWith(color: TheyDiColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TheyDiTextStyles.labelMedium
                  .copyWith(color: TheyDiColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirm,
              style: TheyDiTextStyles.labelMedium.copyWith(color: confirmColor),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnack(String msg, Color color,
      {Duration duration = const Duration(seconds: 3)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: duration,
    ));
  }

  void _showMediaSheet() {
    setState(() => _showEmojiPicker = false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
            color: TheyDiColors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: TheyDiColors.divider)),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: TheyDiColors.divider,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Share Media', style: TheyDiTextStyles.headlineMedium),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _MediaOption(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                color: TheyDiColors.primary,
                onTap: () {
                  Navigator.pop(ctx);
                  _showSnack('Camera coming soon 🚀', TheyDiColors.primary);
                }),
            _MediaOption(
                icon: Icons.videocam_outlined,
                label: 'Video',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(ctx);
                  _showSnack('Video coming soon 🚀', TheyDiColors.primary);
                }),
            _MediaOption(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(ctx);
                  _showSnack('Gallery coming soon 🚀', TheyDiColors.primary);
                }),
          ]),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  void _toggleEmojiPicker() {
    setState(() => _showEmojiPicker = !_showEmojiPicker);
    if (_showEmojiPicker) FocusScope.of(context).unfocus();
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  bool _isSameDay(Timestamp? a, Timestamp? b) {
    if (a == null || b == null) return false;
    final da = a.toDate();
    final db = b.toDate();
    return da.year == db.year && da.month == db.month && da.day == db.day;
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final initial =
        widget.otherName.isNotEmpty ? widget.otherName[0].toUpperCase() : '?';
    final hasText = _messageController.text.trim().isNotEmpty;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [TheyDiColors.cardLight, TheyDiColors.surface],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter)),
        child: SafeArea(
            child: Column(children: [
          // ── App Bar ──
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            decoration: BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: TheyDiColors.divider))),
            child: Row(children: [
              IconButton(
                  icon: const Icon(Icons.arrow_back, color: TheyDiColors.textPrimary),
                  onPressed: () => context.pop()),
              const SizedBox(width: 4),
              Expanded(
                  child: GestureDetector(
                      onTap: _openFriendInfo,
                      child: Row(children: [
                        Stack(children: [
                          Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                  gradient: TheyDiColors.gradientPrimary,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Center(
                                  child: Text(initial,
                                      style: TheyDiTextStyles.labelLarge
                                          .copyWith(color: Colors.white)))),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(widget.otherUid)
                                  .snapshots(),
                              builder: (ctx, snap) {
                                final isOnline = (snap.data?.data() as Map<
                                        String, dynamic>?)?['isOnline'] ==
                                    true;
                                return Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                        color: isOnline
                                            ? Colors.green
                                            : Colors.grey,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: const Color(0xFF0D0D14),
                                            width: 2)));
                              },
                            ),
                          ),
                        ]),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(widget.otherName,
                                  style: TheyDiTextStyles.labelLarge,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              StreamBuilder<DocumentSnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(widget.otherUid)
                                    .snapshots(),
                                builder: (ctx, snap) {
                                  final data = snap.data?.data()
                                      as Map<String, dynamic>?;
                                  final isOnline = data?['isOnline'] == true;
                                  final lastSeen =
                                      data?['lastSeen'] as Timestamp?;
                                  String label;
                                  if (isOnline) {
                                    label = 'Online';
                                  } else if (lastSeen != null) {
                                    final diff = DateTime.now()
                                        .difference(lastSeen.toDate());
                                    if (diff.inMinutes < 5) {
                                      label = 'Last seen just now';
                                    } else if (diff.inHours < 1)
                                      label =
                                          'Last seen ${diff.inMinutes}m ago';
                                    else if (diff.inDays < 1)
                                      label = 'Last seen ${diff.inHours}h ago';
                                    else
                                      label = 'Last seen ${diff.inDays}d ago';
                                  } else {
                                    label = 'Tap for info';
                                  }
                                  return Text(label,
                                      style: TheyDiTextStyles.caption.copyWith(
                                          color: isOnline
                                              ? Colors.green
                                              : TheyDiColors.textSecondary));
                                },
                              ),
                            ])),
                      ]))),
              _ChatMenuButton(
                muted: _notificationsMuted,
                onSelected: (value) {
                  switch (value) {
                    case 'viewProfile':
                      _openUserProfile();
                      break;
                    case 'mute':
                      _toggleMuteNotifications();
                      break;
                    case 'delete':
                      _deleteChat();
                      break;
                    case 'report':
                      _reportUser();
                      break;
                    case 'block':
                      _blockUser();
                      break;
                  }
                },
              ),
            ]),
          ),

          // ── Messages ──
          Expanded(
              child: _chatLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: TheyDiColors.primary))
                  : GestureDetector(
                      onTap: () => setState(() => _showEmojiPicker = false),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('chats')
                            .doc(_chatId)
                            .collection('messages')
                            .orderBy('timestamp')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator(
                                    color: TheyDiColors.primary));
                          }
                          var docs = snapshot.data?.docs ?? [];
                          if (_clearedAt != null) {
                            docs = docs.where((d) {
                              final ts = (d.data()
                                      as Map<String, dynamic>)['timestamp']
                                  as Timestamp?;
                              return ts != null &&
                                  ts.toDate().isAfter(_clearedAt!);
                            }).toList();
                          }
                          if (docs.isEmpty) {
                            return Center(
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                  const Text('👋',
                                      style: TextStyle(fontSize: 40)),
                                  const SizedBox(height: 12),
                                  Text('Say hello to ${widget.otherName}!',
                                      style: TheyDiTextStyles.bodyMedium
                                          .copyWith(
                                              color:
                                                  TheyDiColors.textSecondary)),
                                ]));
                          }
                          WidgetsBinding.instance
                              .addPostFrameCallback((_) => _scrollToBottom());
                          for (final doc in docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            if (data['senderId'] != myUid &&
                                data['seen'] != true) {
                              doc.reference.update({
                                'seen': true,
                                'readBy': FieldValue.arrayUnion([myUid])
                              });
                            }
                          }
                          return ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final data =
                                  docs[index].data() as Map<String, dynamic>;
                              final isMine = data['senderId'] == myUid;
                              final msgType = data['type'] ?? 'text';
                              final timestamp = data['timestamp'] as Timestamp?;
                              final seen = data['seen'] ?? false;
                              final timeLabel = timestamp != null
                                  ? DateFormat('h:mm a')
                                      .format(timestamp.toDate())
                                  : '';
                              final showDate = index == 0 ||
                                  !_isSameDay(
                                    (docs[index - 1].data() as Map<String,
                                        dynamic>)['timestamp'] as Timestamp?,
                                    timestamp,
                                  );
                              return Column(children: [
                                if (showDate && timestamp != null)
                                  _DateSeparator(date: timestamp.toDate()),
                                if (msgType == 'voice')
                                  _VoiceBubble(
                                    audioUrl: data['audioUrl'] ?? '',
                                    durationSecs:
                                        (data['duration'] as num?)?.toInt() ??
                                            0,
                                    isMine: isMine,
                                    timeLabel: timeLabel,
                                    seen: seen,
                                  )
                                else
                                  _DmBubble(
                                      text: data['text'] ?? '',
                                      isMine: isMine,
                                      timeLabel: timeLabel,
                                      seen: seen),
                              ]);
                            },
                          );
                        },
                      ),
                    )),

          // ── Upload indicator ──
          if (_isUploading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: TheyDiColors.card,
              child: Row(children: [
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: TheyDiColors.primary)),
                const SizedBox(width: 10),
                Text('Sending voice message...',
                    style: TheyDiTextStyles.caption
                        .copyWith(color: TheyDiColors.textSecondary)),
              ]),
            ),

          // ── Emoji Picker ──
          if (_showEmojiPicker)
            Container(
                height: 220,
                color: TheyDiColors.card,
                child: Column(children: [
                  Container(height: 1, color: TheyDiColors.divider),
                  Expanded(
                      child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 8,
                            childAspectRatio: 1,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4),
                    itemCount: _kEmojis.length,
                    itemBuilder: (ctx, i) => GestureDetector(
                      onTap: () {
                        final pos = _messageController.selection.base.offset;
                        final text = _messageController.text;
                        final newText = pos < 0
                            ? text + _kEmojis[i]
                            : text.substring(0, pos) +
                                _kEmojis[i] +
                                text.substring(pos);
                        _messageController.value = TextEditingValue(
                            text: newText,
                            selection: TextSelection.collapsed(
                                offset: pos < 0
                                    ? newText.length
                                    : pos + _kEmojis[i].length));
                      },
                      child: Center(
                          child: Text(_kEmojis[i],
                              style: const TextStyle(fontSize: 22))),
                    ),
                  )),
                ])),

          // ── Input Bar ──
          Container(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
            decoration: BoxDecoration(
                color: TheyDiColors.dark,
                border: Border(top: BorderSide(color: TheyDiColors.divider))),
            child:
                _isRecording ? _buildRecordingBar() : _buildNormalBar(hasText),
          ),
        ])),
      ),
    );
  }

  // ── Recording bar ──────────────────────────────────────────────────────────
  Widget _buildRecordingBar() {
    final isCancelling = _dragOffset > _cancelThreshold * 0.5;
    return GestureDetector(
      onHorizontalDragUpdate: (d) =>
          setState(() => _dragOffset = math.max(0, _dragOffset - d.delta.dx)),
      onHorizontalDragEnd: (_) {
        if (_dragOffset >= _cancelThreshold) {
          _cancelRecording();
        } else {
          setState(() => _dragOffset = 0);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
            color: isCancelling
                ? Colors.red.withValues(alpha: 0.12)
                : TheyDiColors.card,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
                color: isCancelling
                    ? Colors.red.withValues(alpha: 0.5)
                    : Colors.red.withValues(alpha: 0.4))),
        child: Row(children: [
          _PulsingMic(),
          const SizedBox(width: 10),
          Text(_fmt(_recordSeconds),
              style: TheyDiTextStyles.labelMedium.copyWith(color: Colors.red)),
          const Spacer(),
          AnimatedOpacity(
              opacity: isCancelling ? 0 : 1,
              duration: const Duration(milliseconds: 150),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chevron_left,
                    size: 16, color: TheyDiColors.textMuted),
                Text('Slide to cancel',
                    style: TheyDiTextStyles.caption
                        .copyWith(color: TheyDiColors.textMuted)),
              ])),
          if (isCancelling)
            Text('Release to cancel',
                style: TheyDiTextStyles.caption
                    .copyWith(color: Colors.red, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          GestureDetector(
            onTapUp: (_) => _stopAndSendRecording(),
            child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.red.withValues(alpha: 0.45),
                          blurRadius: 12,
                          spreadRadius: 2)
                    ]),
                child: const Icon(Icons.mic, color: Colors.white, size: 22)),
          ),
        ]),
      ),
    );
  }

  // ── Normal input bar ───────────────────────────────────────────────────────
  Widget _buildNormalBar(bool hasText) {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      GestureDetector(
          onTap: _showMediaSheet,
          child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(bottom: 3),
              decoration: BoxDecoration(
                  color: TheyDiColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: TheyDiColors.divider)),
              child: const Icon(Icons.camera_alt_outlined,
                  color: TheyDiColors.textSecondary, size: 18))),
      const SizedBox(width: 8),
      Expanded(
          child: Container(
        decoration: BoxDecoration(
            color: TheyDiColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: TheyDiColors.divider)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
              child: TextField(
            controller: _messageController,
            style: TheyDiTextStyles.bodyMedium,
            maxLines: 4,
            minLines: 1,
            textInputAction: TextInputAction.send,
            onTap: () => setState(() => _showEmojiPicker = false),
            onSubmitted: (_) => _sendMessage(),
            decoration: InputDecoration(
                hintText: 'Message ${widget.otherName}...',
                hintStyle: TheyDiTextStyles.bodySmall
                    .copyWith(color: TheyDiColors.textMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(16, 10, 4, 10)),
          )),
          GestureDetector(
              onTap: _toggleEmojiPicker,
              child: Padding(
                  padding: const EdgeInsets.only(right: 10, bottom: 10),
                  child: Text(_showEmojiPicker ? '⌨️' : '😊',
                      style: const TextStyle(fontSize: 20)))),
        ]),
      )),
      const SizedBox(width: 8),
      hasText
          ? GestureDetector(
              onTap: _sendMessage,
              child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      gradient: TheyDiColors.gradientPrimary,
                      shape: BoxShape.circle),
                  child: const Icon(Icons.send, color: Colors.white, size: 20)))
          : GestureDetector(
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopAndSendRecording(),
              child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: TheyDiColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: TheyDiColors.divider)),
                  child: const Icon(Icons.mic_none,
                      color: TheyDiColors.textSecondary, size: 20))),
    ]);
  }
}

// ── Pulsing mic ───────────────────────────────────────────────────────────────
class _ChatMenuButton extends StatelessWidget {
  final bool muted;
  final ValueChanged<String> onSelected;

  const _ChatMenuButton({
    required this.muted,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      color: TheyDiColors.cardLight,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (context) => [
        _item(
          value: 'viewProfile',
          icon: Icons.person_outline,
          label: 'View Profile',
        ),
        _item(
          value: 'mute',
          icon: muted
              ? Icons.notifications_active_outlined
              : Icons.notifications_off_outlined,
          label: muted ? 'Unmute Notifications' : 'Mute Notifications',
        ),
        _item(
          value: 'delete',
          icon: Icons.delete_outline,
          label: 'Delete Chat',
          color: Colors.red,
        ),
        const PopupMenuDivider(height: 8),
        _item(
          value: 'report',
          icon: Icons.flag_outlined,
          label: 'Report User',
          color: Colors.amber,
        ),
        _item(
          value: 'block',
          icon: Icons.block_outlined,
          label: 'Block User',
          color: Colors.red,
        ),
      ],
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: TheyDiColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: TheyDiColors.divider),
        ),
        child: const Icon(
          Icons.more_vert,
          color: TheyDiColors.textSecondary,
          size: 22,
        ),
      ),
    );
  }

  PopupMenuItem<String> _item({
    required String value,
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final itemColor = color ?? TheyDiColors.textSecondary;
    return PopupMenuItem<String>(
      value: value,
      child: Row(children: [
        Icon(icon, size: 18, color: itemColor),
        const SizedBox(width: 10),
        Text(
          label,
          style: TheyDiTextStyles.bodyMedium.copyWith(
            color: color ?? TheyDiColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ]),
    );
  }
}

class _PulsingMic extends StatefulWidget {
  @override
  State<_PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<_PulsingMic>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.6, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withValues(alpha: _anim.value * 0.25)),
          child: Center(
              child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Colors.red),
                  child:
                      const Icon(Icons.mic, color: Colors.white, size: 12)))));
}

// ── Voice Bubble ──────────────────────────────────────────────────────────────
class _VoiceBubble extends StatefulWidget {
  final String audioUrl;
  final int durationSecs;
  final bool isMine;
  final String timeLabel;
  final bool seen;
  const _VoiceBubble(
      {required this.audioUrl,
      required this.durationSecs,
      required this.isMine,
      required this.timeLabel,
      required this.seen});
  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  bool _isPlaying = false;
  double _progress = 0;
  int _currentSec = 0;
  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;
  @override
  void initState() {
    super.initState();
    _stateSub = _sharedPlayer.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      if (s == ap.PlayerState.completed || s == ap.PlayerState.stopped) {
        setState(() {
          _isPlaying = false;
          _progress = 0;
          _currentSec = 0;
        });
      }
    });
    _posSub = _sharedPlayer.onPositionChanged.listen((pos) {
      if (!mounted || !_isPlaying) return;
      final total = widget.durationSecs * 1000;
      setState(() {
        _progress =
            total > 0 ? (pos.inMilliseconds / total).clamp(0.0, 1.0) : 0;
        _currentSec = pos.inSeconds;
      });
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _sharedPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      await _sharedPlayer.stop();
      await _sharedPlayer.play(ap.UrlSource(widget.audioUrl));
      setState(() => _isPlaying = true);
    }
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    final displaySecs = _isPlaying
        ? math.max(0, widget.durationSecs - _currentSec)
        : widget.durationSecs;
    return Padding(
        padding: EdgeInsets.only(
            top: 3,
            bottom: 3,
            left: widget.isMine ? 60 : 0,
            right: widget.isMine ? 0 : 60),
        child: Align(
            alignment:
                widget.isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
              padding: const EdgeInsets.fromLTRB(10, 10, 12, 8),
              decoration: BoxDecoration(
                  color: widget.isMine
                      ? TheyDiColors.primary.withValues(alpha: 0.2)
                      : TheyDiColors.card,
                  borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(widget.isMine ? 16 : 4),
                      bottomRight: Radius.circular(widget.isMine ? 4 : 16)),
                  border: Border.all(
                      color: widget.isMine
                          ? TheyDiColors.primary.withValues(alpha: 0.3)
                          : TheyDiColors.divider)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      GestureDetector(
                          onTap: _togglePlay,
                          child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                  gradient: TheyDiColors.gradientPrimary,
                                  shape: BoxShape.circle),
                              child: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 20))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            _WaveformBars(
                                progress: _progress, isMine: widget.isMine),
                            const SizedBox(height: 4),
                            Text(_fmt(displaySecs),
                                style: TheyDiTextStyles.caption.copyWith(
                                    color: TheyDiColors.textMuted,
                                    fontSize: 10)),
                          ])),
                    ]),
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text(widget.timeLabel,
                          style: TheyDiTextStyles.caption.copyWith(
                              color: TheyDiColors.textMuted, fontSize: 10)),
                      if (widget.isMine) ...[
                        const SizedBox(width: 4),
                        _ReadReceipt(seen: widget.seen)
                      ],
                    ]),
                  ]),
            )));
  }
}

// ── Waveform bars ─────────────────────────────────────────────────────────────
class _WaveformBars extends StatelessWidget {
  final double progress;
  final bool isMine;
  const _WaveformBars({required this.progress, required this.isMine});
  static const _h = [
    6.0,
    10.0,
    14.0,
    8.0,
    16.0,
    10.0,
    6.0,
    12.0,
    8.0,
    14.0,
    10.0,
    6.0,
    12.0,
    16.0,
    8.0,
    10.0,
    6.0,
    14.0,
    10.0,
    8.0,
    16.0,
    6.0,
    12.0,
    10.0,
    8.0,
    14.0,
    6.0,
    10.0,
    12.0,
    8.0
  ];
  @override
  Widget build(BuildContext context) {
    final played = (_h.length * progress).round();
    return SizedBox(
        height: 20,
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(
                _h.length,
                (i) => Container(
                    width: 3,
                    height: _h[i],
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                        color: i < played
                            ? TheyDiColors.primary
                            : (isMine
                                ? Colors.white.withValues(alpha: 0.3)
                                : TheyDiColors.textMuted
                                    .withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(2))))));
  }
}

// ── Shared helper widgets ─────────────────────────────────────────────────────
class _MediaOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MediaOption(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.3))),
            child: Icon(icon, color: color, size: 28)),
        const SizedBox(height: 8),
        Text(label,
            style: TheyDiTextStyles.caption
                .copyWith(color: TheyDiColors.textSecondary)),
      ]));
}

class _DmBubble extends StatelessWidget {
  final String text;
  final bool isMine;
  final String timeLabel;
  final bool seen;
  const _DmBubble(
      {required this.text,
      required this.isMine,
      required this.timeLabel,
      required this.seen});
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(
          top: 3, bottom: 3, left: isMine ? 60 : 0, right: isMine ? 0 : 60),
      child: Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: isMine
                    ? TheyDiColors.primary.withValues(alpha: 0.2)
                    : TheyDiColors.card,
                borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMine ? 16 : 4),
                    bottomRight: Radius.circular(isMine ? 4 : 16)),
                border: Border.all(
                    color: isMine
                        ? TheyDiColors.primary.withValues(alpha: 0.3)
                        : TheyDiColors.divider)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(text,
                  style: TheyDiTextStyles.bodySmall.copyWith(
                      color: isMine ? Colors.white : TheyDiColors.textSecondary,
                      height: 1.4)),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(timeLabel,
                    style: TheyDiTextStyles.caption
                        .copyWith(color: TheyDiColors.textMuted, fontSize: 10)),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  _ReadReceipt(seen: seen)
                ],
              ]),
            ]),
          )));
}

class _ReadReceipt extends StatelessWidget {
  final bool seen;
  const _ReadReceipt({required this.seen});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check,
            size: 11, color: seen ? Colors.blue : TheyDiColors.textMuted),
        const SizedBox(width: 1),
        Icon(Icons.check,
            size: 11, color: seen ? Colors.blue : TheyDiColors.textMuted),
      ]);
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      label = 'Today';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      label = 'Yesterday';
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                    color: TheyDiColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TheyDiColors.divider)),
                child: Text(label,
                    style: TheyDiTextStyles.caption
                        .copyWith(color: TheyDiColors.textMuted)))));
  }
}
