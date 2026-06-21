import 'dart:async';
import 'dart:io' show File;
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../models/circle_model.dart';
import '../models/message_model.dart';
import '../../../core/utils/platform_helper.dart';

const _kEmojis = [
  '😀','😂','😍','😎','🥳','😢','😡','🤔','👋','👍','👏','🙏',
  '❤️','🔥','🎉','✅','💯','😅','🤣','😊','😇','🥰','😘','😜',
  '😴','🤗','🤩','😬','🙄','😏','😒','😔','😤','😭','😱','😳',
  '🤯','🤪','🥺','😋','🤤','🤑','🤫','🤭','🧐','🥴','😷','🤧',
  '👌','✌️','🤞','🤙','💪','🙌','👀','💀','🎊','🌟','💫','⚡',
];

final _circleSharedPlayer = ap.AudioPlayer();

class CircleChatScreen extends ConsumerStatefulWidget {
  final CircleModel circle;
  const CircleChatScreen({super.key, required this.circle});

  @override
  ConsumerState<CircleChatScreen> createState() => _CircleChatScreenState();
}

class _CircleChatScreenState extends ConsumerState<CircleChatScreen>
    with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  late CircleModel _circle;
  bool _isMember = true;
  bool _showEmojiPicker = false;
  bool _showAttachmentMenu = false;
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
    _circle = widget.circle;
    _messageController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addObserver(this);
    _loadClearedAt();
    FirebaseFirestore.instance
        .collection('circles').doc(_circle.id).snapshots()
        .listen((doc) {
      if (!mounted) return;
      if (!doc.exists) { setState(() => _isMember = false); return; }
      final updated = CircleModel.fromFirestore(doc);
      final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      setState(() {
        _circle = updated;
        _isMember = updated.memberUids.contains(myUid);
      });
    });
  }

  Future<void> _loadClearedAt() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('circles').doc(_circle.id)
        .collection('clearedBy').doc(myUid).get();
    if (doc.exists) {
      final ts = doc.data()?['clearedAt'] as Timestamp?;
      if (ts != null && mounted) setState(() => _clearedAt = ts.toDate());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _markAllSeen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recorder.dispose();
    _recordTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markAllSeen() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;
    final msgs = await FirebaseFirestore.instance
        .collection('circles').doc(_circle.id).collection('messages')
        .where('senderUid', isNotEqualTo: myUid).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in msgs.docs) {
      final seenBy = List<String>.from(doc.data()['seenBy'] ?? []);
      final readBy = List<String>.from(doc.data()['readBy'] ?? []);
      bool needsUpdate = false;
      if (!seenBy.contains(myUid)) { seenBy.add(myUid); needsUpdate = true; }
      if (!readBy.contains(myUid)) { readBy.add(myUid); needsUpdate = true; }
      if (needsUpdate) {
        batch.update(doc.reference, {'seenBy': seenBy, 'readBy': readBy});
      }
    }
    await batch.commit();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending || !_isMember) return;
    setState(() { _isSending = true; _showEmojiPicker = false; _showAttachmentMenu = false; });
    _messageController.clear();
    try {
      final user = FirebaseAuth.instance.currentUser!;
      String senderName = user.displayName ?? user.email!.split('@').first;
      try {
        final d = await FirebaseFirestore.instance
            .collection('users').doc(user.uid).get();
        if (d.exists) senderName = d.data()?['displayName'] ?? senderName;
      } catch (_) {}
      final message = MessageModel(
        id: '', circleId: _circle.id,
        senderUid: user.uid, senderName: senderName,
        text: text, createdAt: DateTime.now(),
        readBy: [user.uid], seenBy: [user.uid],
      );
      await FirebaseFirestore.instance
          .collection('circles').doc(_circle.id).collection('messages')
          .add(message.toFirestoreMap());
      await FirebaseFirestore.instance
          .collection('circles').doc(_circle.id).update({
        'lastMessage': text, 'lastMessageSender': senderName,
        'lastMessageAt': Timestamp.now(),
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) _showSnack('Failed: $e', Colors.red);
    }
    if (mounted) setState(() => _isSending = false);
  }

  // ── Voice ──────────────────────────────────────────────────────────────────
  Future<bool> _requestMicPermission() async {
    if (kIsWeb) {
      // The record package handles browser mic permission automatically
      return await _recorder.hasPermission();
    }
    final status = await Permission.microphone.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(context: context, builder: (ctx) => AlertDialog(
        backgroundColor: TheyDiColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Microphone Access', style: TheyDiTextStyles.headlineMedium),
        content: Text('Microphone access is required to send voice messages.',
            style: TheyDiTextStyles.bodySmall.copyWith(color: TheyDiColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () { Navigator.pop(ctx); openAppSettings(); },
              child: Text('Open Settings', style: TextStyle(color: TheyDiColors.primary))),
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
          path: '', // web doesn't use file path
        );
      } else {
        final tmpDir = await getTempDirPath();
        final path =
            '$tmpDir/voice_circle_${DateTime.now().millisecondsSinceEpoch}.aac';
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
        HapticFeedback.mediumImpact();
      }
      setState(() {
        _isRecording = true; _recordSeconds = 0; _dragOffset = 0;
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
      // stop() returns the file path on mobile, or a blob URL on web
      final path = await _recorder.stop();
      if (!kIsWeb) HapticFeedback.lightImpact();
      setState(() {
        _isRecording = false; _recordSeconds = 0; _dragOffset = 0;
      });
      if (duration < 1) return;
      if (path == null || path.isEmpty) {
        if (mounted) _showSnack('Recording failed — no audio captured', Colors.red);
        return;
      }
      await _uploadAndSendVoice(path, duration);
    } catch (e) {
      setState(() { _isRecording = false; _recordSeconds = 0; });
      if (mounted) _showSnack('Recording failed: $e', Colors.red);
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    try { await _recorder.stop(); } catch (_) {}
    if (!kIsWeb) HapticFeedback.heavyImpact();
    setState(() { _isRecording = false; _recordSeconds = 0; _dragOffset = 0; });
    if (mounted) {
      _showSnack('Recording cancelled', Colors.grey.shade700,
        duration: const Duration(seconds: 2));
    }
  }

  Future<void> _uploadAndSendVoice(String filePath, int durationSecs) async {
    setState(() => _isUploading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      String senderName = user.displayName ?? 'Me';
      try {
        final d = await FirebaseFirestore.instance
            .collection('users').doc(user.uid).get();
        if (d.exists) senderName = d.data()?['displayName'] ?? senderName;
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
        if (mounted) _showSnack('Audio capture failed — please try again', Colors.red);
        setState(() => _isUploading = false);
        return;
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('voice_messages')
          .child('circles')
          .child(_circle.id)
          .child(fileName);

      final contentType = kIsWeb ? 'audio/webm' : 'audio/aac';
      final snapshot = await storageRef.putData(
        Uint8List.fromList(bytes),
        SettableMetadata(contentType: contentType),
      );
      final audioUrl = await snapshot.ref.getDownloadURL();

      final now = DateTime.now();
      await FirebaseFirestore.instance
          .collection('circles').doc(_circle.id)
          .collection('messages').add({
        'senderUid': user.uid,
        'senderName': senderName,
        'type': 'voice',
        'audioUrl': audioUrl,
        'duration': durationSecs,
        'text': '🎤 Voice message',
        'circleId': _circle.id,
        'createdAt': Timestamp.fromDate(now),
        'readBy': [user.uid],
        'seenBy': [user.uid],
      });
      await FirebaseFirestore.instance
          .collection('circles').doc(_circle.id).update({
        'lastMessage': '🎤 Voice message',
        'lastMessageSender': senderName,
        'lastMessageAt': Timestamp.fromDate(now),
      });
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
              child: const Text('Retry', style: TextStyle(
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.bold)),
            ),
          ]),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 6),
        ));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _openInfo() => context.push(AppRoutes.circleInfo, extra: _circle);

  void _showSnack(String msg, Color color,
      {Duration duration = const Duration(seconds: 3)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16), duration: duration,
    ));
  }

  // ── Media Attachment Logic ────────────────────────────────────────────────
  Future<void> _handleMediaAction(String action) async {
    setState(() { _showEmojiPicker = false; _showAttachmentMenu = false; });
    final picker = ImagePicker();
    XFile? file;
    String type = 'image';
    String? fileName;

    try {
      if (action == 'camera') {
        file = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      } else if (action == 'video') {
        file = await picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(minutes: 5));
        type = 'video';
      } else if (action == 'gallery') {
        file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      } else if (action == 'document') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'zip'],
          withData: kIsWeb,
        );
        if (result != null && result.files.isNotEmpty) {
          final pickedFile = result.files.single;
          String? path = pickedFile.path;
          
          if (kIsWeb && pickedFile.bytes != null && path == null) {
            // On web, path is null. We create a blob URL from bytes for compatibility with preview and storage.
            path = XFile.fromData(pickedFile.bytes!).path;
          }
          
          if (path != null) {
            type = 'file';
            fileName = pickedFile.name;
            _confirmAndSendMedia(path, type, fileName!);
          }
        }
        return;
      }

      if (file != null) {
        _confirmAndSendMedia(file.path, type, file.name);
      }
    } catch (e) {
      _showSnack('Error picking media: $e', Colors.red);
    }
  }

  Future<void> _confirmAndSendMedia(String path, String type, String fileName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TheyDiColors.card,
        title: Text('Send $type?', style: TheyDiTextStyles.headlineMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type == 'image')
              kIsWeb
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(path, height: 200, fit: BoxFit.cover))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(path), height: 200, fit: BoxFit.cover),
                    )
            else
              Icon(type == 'video' ? Icons.videocam : Icons.description, size: 48, color: TheyDiColors.primary),
            const SizedBox(height: 12),
            Text(fileName, style: TheyDiTextStyles.bodySmall, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Send', style: TextStyle(color: TheyDiColors.primary))),
        ],
      ),
    );

    if (confirmed == true) {
      _uploadAndSendMedia(path, type, fileName);
    }
  }

  Future<void> _uploadAndSendMedia(String filePath, String type, String fileName) async {
    setState(() => _isUploading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final List<int> bytes;
      final String ext;

      if (kIsWeb) {
        bytes = await getBlobBytes(filePath);
        ext = fileName.contains('.') ? fileName.split('.').last : (type == 'image' ? 'jpg' : type == 'video' ? 'mp4' : 'bin');
      } else {
        bytes = await getFileBytes(filePath);
        ext = filePath.split('.').last;
      }

      final storagePath = 'media/circles/${_circle.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);
      
      await storageRef.putData(Uint8List.fromList(bytes));
      final url = await storageRef.getDownloadURL();

      final senderName = user.displayName ?? 'User';
      final msgText = type == 'image' ? '📷 Photo' : type == 'video' ? '🎥 Video' : '📄 $fileName';

      await FirebaseFirestore.instance
          .collection('circles').doc(_circle.id)
          .collection('messages').add({
        'senderUid': user.uid,
        'senderName': senderName,
        'type': type,
        'mediaUrl': url,
        'fileName': fileName,
        'text': msgText,
        'circleId': _circle.id,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [user.uid],
        'seenBy': [user.uid],
      });

      await FirebaseFirestore.instance.collection('circles').doc(_circle.id).update({
        'lastMessage': msgText,
        'lastMessageSender': senderName,
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
      _scrollToBottom();
    } catch (e) {
      _showSnack('Upload failed: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _toggleEmojiPicker() {
    setState(() => _showEmojiPicker = !_showEmojiPicker);
    if (_showEmojiPicker) FocusScope.of(context).unfocus();
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final hasText = _messageController.text.trim().isNotEmpty;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(
            colors: [TheyDiColors.cardLight, TheyDiColors.surface],
            begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: SafeArea(child: Column(children: [

          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: TheyDiColors.divider))),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: TheyDiColors.textPrimary),
                  onPressed: () => context.pop()),
              const SizedBox(width: 4),
              Expanded(child: GestureDetector(onTap: _openInfo, child: Row(children: [
                Container(width: 40, height: 40,
                    decoration: BoxDecoration(gradient: TheyDiColors.gradientPrimary,
                        borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text(
                        _circle.name.isNotEmpty
                            ? _circle.name[0].toUpperCase() : '?',
                        style: TheyDiTextStyles.labelLarge
                            .copyWith(color: Colors.white)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_circle.name, style: TheyDiTextStyles.labelLarge,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${_circle.memberUids.length} members · Tap for info',
                      style: TheyDiTextStyles.caption
                          .copyWith(color: TheyDiColors.textSecondary)),
                ])),
              ]))),
              IconButton(icon: Icon(Icons.info_outline,
                  color: TheyDiColors.textSecondary, size: 22), onPressed: _openInfo),
            ]),
          ),

          Expanded(child: GestureDetector(
            onTap: () => setState(() { _showEmojiPicker = false; _showAttachmentMenu = false; }),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('circles').doc(_circle.id)
                  .collection('messages').orderBy('createdAt').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: TheyDiColors.primary));
                }
                var docs = snapshot.data?.docs ?? [];
                if (_clearedAt != null) {
                  docs = docs.where((d) {
                    final ts = (d.data() as Map<String, dynamic>)['createdAt']
                        as Timestamp?;
                    return ts != null && ts.toDate().isAfter(_clearedAt!);
                  }).toList();
                }
                if (docs.isEmpty) {
                  return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('💬', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    Text('Start the conversation in ${_circle.name}!',
                        style: TheyDiTextStyles.bodyMedium
                            .copyWith(color: TheyDiColors.textSecondary),
                        textAlign: TextAlign.center),
                  ]));
                }
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMine = data['senderUid'] == myUid;
                    final msgType = data['type'] ?? 'text';
                    final senderName = data['senderName'] ?? '';
                    final createdAt = data['createdAt'] as Timestamp?;
                    final seenBy = List<String>.from(data['seenBy'] ?? []);
                    final seen = seenBy.length > 1;
                    final timeLabel = createdAt != null
                        ? DateFormat('h:mm a').format(createdAt.toDate())
                        : '';
                    final prevCreatedAt = index > 0
                        ? ((docs[index - 1].data()
                            as Map<String, dynamic>)['createdAt']
                            as Timestamp?)?.toDate()
                        : null;
                    final showDate = index == 0 ||
                        !_isSameDay(prevCreatedAt, createdAt?.toDate());
                    return Column(children: [
                      if (showDate && createdAt != null)
                        _DateSeparator(date: createdAt.toDate()),
                      if (msgType == 'voice')
                        _CircleVoiceBubble(
                          audioUrl: data['audioUrl'] ?? '',
                          durationSecs:
                              (data['duration'] as num?)?.toInt() ?? 0,
                          isMine: isMine,
                          senderName: senderName,
                          timeLabel: timeLabel,
                          seen: seen,
                        )
                      else
                        _CircleBubble(
                            text: data['text'] ?? '',
                            isMine: isMine,
                            senderName: senderName,
                            timeLabel: timeLabel,
                            seen: seen),
                    ]);
                  },
                );
              },
            ),
          )),

          if (_isUploading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: TheyDiColors.card,
              child: Row(children: [
                const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: TheyDiColors.primary)),
                const SizedBox(width: 10),
                Text('Sending voice message...',
                    style: TheyDiTextStyles.caption
                        .copyWith(color: TheyDiColors.textSecondary)),
              ]),
            ),

          if (_showEmojiPicker)
            Container(height: 220, color: TheyDiColors.card, child: Column(children: [
              Container(height: 1, color: TheyDiColors.divider),
              Expanded(child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8, childAspectRatio: 1,
                    crossAxisSpacing: 4, mainAxisSpacing: 4),
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
                  child: Center(child: Text(_kEmojis[i],
                      style: const TextStyle(fontSize: 22))),
                ),
              )),
            ])),

          if (_showAttachmentMenu && !_isRecording && _isMember)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _buildAttachmentMenu(),
            ),

          if (!_isMember)
            Container(padding: const EdgeInsets.all(16), color: TheyDiColors.card,
              child: Text('You are no longer a member of this circle',
                  style: TheyDiTextStyles.bodySmall
                      .copyWith(color: TheyDiColors.textMuted),
                  textAlign: TextAlign.center))
          else
            Container(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
              decoration: BoxDecoration(color: TheyDiColors.dark,
                  border: Border(top: BorderSide(color: TheyDiColors.divider))),
              child: _isRecording
                  ? _buildRecordingBar()
                  : _buildNormalBar(hasText),
            ),
        ])),
      ),
    );
  }

  Widget _buildAttachmentMenu() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TheyDiColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _MediaOption(icon: Icons.camera_alt, label: 'Camera', color: Colors.blue, 
              onTap: () => _handleMediaAction('camera')),
          _MediaOption(icon: Icons.videocam, label: 'Video', color: Colors.red, 
              onTap: () => _handleMediaAction('video')),
          _MediaOption(icon: Icons.photo_library, label: 'Gallery', color: Colors.purple, 
              onTap: () => _handleMediaAction('gallery')),
          _MediaOption(icon: Icons.description, label: 'Document', color: Colors.orange, 
              onTap: () => _handleMediaAction('document')),
        ],
      ),
    );
  }

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
        height: 54, padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isCancelling
              ? Colors.red.withOpacity(0.12) : TheyDiColors.card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: isCancelling
              ? Colors.red.withOpacity(0.5)
              : Colors.red.withOpacity(0.4))),
        child: Row(children: [
          _PulsingMic(),
          const SizedBox(width: 10),
          Text(_fmt(_recordSeconds),
              style: TheyDiTextStyles.labelMedium.copyWith(color: Colors.red)),
          const Spacer(),
          AnimatedOpacity(opacity: isCancelling ? 0 : 1,
              duration: const Duration(milliseconds: 150),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chevron_left, size: 16, color: TheyDiColors.textMuted),
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
            child: Container(width: 44, height: 44,
                decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                        color: Colors.red.withOpacity(0.45),
                        blurRadius: 12, spreadRadius: 2)]),
                child: const Icon(Icons.mic, color: Colors.white, size: 22)),
          ),
        ]),
      ),
    );
  }

  Widget _buildNormalBar(bool hasText) {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _AttachmentIcon(
        icon: _showAttachmentMenu ? Icons.close : Icons.add, 
        onTap: () => setState(() {
          _showAttachmentMenu = !_showAttachmentMenu;
          _showEmojiPicker = false;
        }),
      ),
      const SizedBox(width: 10),
      Expanded(child: Container(
        decoration: BoxDecoration(color: TheyDiColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: TheyDiColors.divider)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: TextField(
            controller: _messageController, style: TheyDiTextStyles.bodyMedium,
            maxLines: 4, minLines: 1, textInputAction: TextInputAction.send,
            onTap: () => setState(() => _showEmojiPicker = false),
            onSubmitted: (_) => _sendMessage(),
            decoration: InputDecoration(
              hintText: 'Message ${_circle.name}...',
              hintStyle: TheyDiTextStyles.bodySmall.copyWith(color: TheyDiColors.textMuted),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(16, 10, 4, 10)),
          )),
          GestureDetector(onTap: _toggleEmojiPicker,
            child: Padding(padding: const EdgeInsets.only(right: 12, bottom: 10),
              child: Text(_showEmojiPicker ? '⌨️' : '😊',
                  style: const TextStyle(fontSize: 20)))),
        ]),
      )),
      const SizedBox(width: 8),
      hasText
          ? GestureDetector(onTap: _sendMessage,
              child: Container(width: 44, height: 44,
                  decoration: BoxDecoration(gradient: TheyDiColors.gradientPrimary,
                      shape: BoxShape.circle),
                  child: const Icon(Icons.send, color: Colors.white, size: 20)))
          : GestureDetector(
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopAndSendRecording(),
              child: Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: TheyDiColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: TheyDiColors.divider)),
                  child: const Icon(Icons.mic_none,
                      color: TheyDiColors.textSecondary, size: 20))),
    ]);
  }
}

class _AttachmentIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AttachmentIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap,
      child: Container(width: 38, height: 38,
          margin: const EdgeInsets.only(bottom: 3),
          decoration: BoxDecoration(color: TheyDiColors.card, shape: BoxShape.circle,
              border: Border.all(color: TheyDiColors.divider)),
          child: Icon(icon, color: TheyDiColors.textSecondary, size: 18)));
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────────
class _PulsingMic extends StatefulWidget {
  @override State<_PulsingMic> createState() => _PulsingMicState();
}
class _PulsingMicState extends State<_PulsingMic>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl; late Animation<double> _anim;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.6, end: 1.0).animate(_ctrl);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _anim,
    builder: (_, __) => Container(width: 32, height: 32,
      decoration: BoxDecoration(shape: BoxShape.circle,
          color: Colors.red.withOpacity(_anim.value * 0.25)),
      child: Center(child: Container(width: 20, height: 20,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
          child: const Icon(Icons.mic, color: Colors.white, size: 12)))));
}

class _CircleVoiceBubble extends StatefulWidget {
  final String audioUrl; final int durationSecs;
  final bool isMine; final String senderName;
  final String timeLabel; final bool seen;
  const _CircleVoiceBubble({required this.audioUrl, required this.durationSecs,
      required this.isMine, required this.senderName,
      required this.timeLabel, required this.seen});
  @override State<_CircleVoiceBubble> createState() =>
      _CircleVoiceBubbleState();
}
class _CircleVoiceBubbleState extends State<_CircleVoiceBubble> {
  bool _isPlaying = false; double _progress = 0; int _currentSec = 0;
  StreamSubscription? _posSub; StreamSubscription? _stateSub;
  @override void initState() {
    super.initState();
    _stateSub = _circleSharedPlayer.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      if (s == ap.PlayerState.completed || s == ap.PlayerState.stopped) {
        setState(() { _isPlaying = false; _progress = 0; _currentSec = 0; });
      }
    });
    _posSub = _circleSharedPlayer.onPositionChanged.listen((pos) {
      if (!mounted || !_isPlaying) return;
      final total = widget.durationSecs * 1000;
      setState(() {
        _progress = total > 0
            ? (pos.inMilliseconds / total).clamp(0.0, 1.0) : 0;
        _currentSec = pos.inSeconds;
      });
    });
  }
  @override void dispose() { _posSub?.cancel(); _stateSub?.cancel(); super.dispose(); }
  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _circleSharedPlayer.pause(); setState(() => _isPlaying = false);
    } else {
      await _circleSharedPlayer.stop();
      await _circleSharedPlayer.play(ap.UrlSource(widget.audioUrl));
      setState(() => _isPlaying = true);
    }
  }
  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  @override Widget build(BuildContext context) {
    final displaySecs = _isPlaying
        ? math.max(0, widget.durationSecs - _currentSec)
        : widget.durationSecs;
    return Padding(
      padding: EdgeInsets.only(top: 3, bottom: 3,
          left: widget.isMine ? 60 : 0, right: widget.isMine ? 0 : 60),
      child: Align(
        alignment: widget.isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: widget.isMine
              ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!widget.isMine)
              Padding(padding: const EdgeInsets.only(left: 4, bottom: 3),
                  child: Text(widget.senderName,
                      style: TheyDiTextStyles.caption.copyWith(
                          color: TheyDiColors.primary,
                          fontWeight: FontWeight.w600))),
            Container(
              constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
              padding: const EdgeInsets.fromLTRB(10, 10, 12, 8),
              decoration: BoxDecoration(
                color: widget.isMine ? Colors.white : Colors.white,
                borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(widget.isMine ? 16 : 4),
                    bottomRight: Radius.circular(widget.isMine ? 4 : 16)),
                border: Border.all(color: widget.isMine
                    ? const Color(0xFFE0E0E0)
                    : const Color(0xFFD0D5DD))), // Specific received border color
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  GestureDetector(onTap: _togglePlay,
                    child: Container(width: 38, height: 38,
                        decoration: BoxDecoration(gradient: TheyDiColors.gradientPrimary,
                            shape: BoxShape.circle),
                        child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white, size: 20))),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _WaveformBars(progress: _progress, isMine: widget.isMine),
                    const SizedBox(height: 4),
                    Text(_fmt(displaySecs), style: TheyDiTextStyles.caption.copyWith(
                        color: widget.isMine ? Colors.black : const Color(0xFF6B7280),
                        fontSize: 10)),
                  ])),
                ]),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(widget.timeLabel, style: TheyDiTextStyles.caption.copyWith(
                      color: widget.isMine ? Colors.black54 : const Color(0xFF6B7280),
                      fontSize: 10)),
                  if (widget.isMine) ...[
                    const SizedBox(width: 4), _ReadReceipt(seen: widget.seen)],
                ]),
              ]),
            ),
          ],
        ),
      ));
  }
}

class _WaveformBars extends StatelessWidget {
  final double progress; final bool isMine;
  const _WaveformBars({required this.progress, required this.isMine});
  static const _h = [6.0,10.0,14.0,8.0,16.0,10.0,6.0,12.0,8.0,14.0,
    10.0,6.0,12.0,16.0,8.0,10.0,6.0,14.0,10.0,8.0,16.0,6.0,12.0,10.0,
    8.0,14.0,6.0,10.0,12.0,8.0];
  @override Widget build(BuildContext context) {
    final played = (_h.length * progress).round();
    return SizedBox(height: 20, child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(_h.length, (i) => Container(
        width: 3, height: _h[i], margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: i < played 
              ? (isMine ? Colors.white : TheyDiColors.primary) // Played bars are white for sent, primary for received
              : (isMine ? Colors.white.withOpacity(0.3)
                  : Colors.grey.shade400), // Unplayed bars are light grey for received
          borderRadius: BorderRadius.circular(2))))));
  }
}

class _CircleBubble extends StatelessWidget {
  final String text, senderName, timeLabel; final bool isMine, seen;
  const _CircleBubble({required this.text, required this.isMine,
      required this.senderName, required this.timeLabel, required this.seen});
  @override Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: 3, bottom: 3,
        left: isMine ? 60 : 0, right: isMine ? 0 : 60),
    child: Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMine)
            Padding(padding: const EdgeInsets.only(left: 4, bottom: 3),
                child: Text(senderName, style: TheyDiTextStyles.caption.copyWith(
                    color: TheyDiColors.primary, fontWeight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMine ? Colors.white : Colors.white,
              borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16)),
              border: Border.all(color: isMine
                  ? const Color(0xFFE0E0E0)
                  : const Color(0xFFD0D5DD))), // Specific received border color
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(text, style: TheyDiTextStyles.bodySmall.copyWith(
                  color: isMine ? Colors.black : const Color(0xFF111827),
                  height: 1.4)),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(timeLabel, style: TheyDiTextStyles.caption.copyWith(
                    color: isMine ? Colors.black54 : const Color(0xFF6B7280),
                    fontSize: 10)),
                if (isMine) ...[
                  const SizedBox(width: 4), _ReadReceipt(seen: seen)],
              ]),
            ]),
          ),
        ],
      )));
}

class _ReadReceipt extends StatelessWidget {
  final bool seen; const _ReadReceipt({required this.seen});

  @override
  Widget build(BuildContext context) {
    // UI-only change: adjust tick icon color + tighten spacing between the two checks.
    // Replace the existing tick rendering below (keep sizes/positions unchanged).
    // Map tick colors per existing message model semantics:
    // - single grey tick: sent/offline/not delivered (seen==false AND message not read)
    // - double grey ticks: delivered but not seen
    // - double blue ticks: seen
    // NOTE: This widget currently only receives `seen` boolean, so we preserve existing
    // behavior: when `seen` is true we show blue ticks; otherwise show grey ticks.
    final tickColor = seen ? Colors.blue : Colors.grey;
    return SizedBox(
      width: 15,
      height: 11,
      child: Stack(children: [
        Icon(Icons.check, size: 11, color: tickColor),
        Positioned(left: 3, child: Icon(Icons.check, size: 11, color: tickColor)),
      ]),
    );
  }
}


class _DateSeparator extends StatelessWidget {
  final DateTime date; const _DateSeparator({required this.date});
  @override Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;
    if (date.year == now.year && date.month == now.month &&
        date.day == now.day) {
      label = 'Today';
    } else if (date.year == now.year && date.month == now.month &&
        date.day == now.day - 1) {
      label = 'Yesterday';
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }
    return Padding(padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(color: TheyDiColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: TheyDiColors.divider)),
        child: Text(label, style: TheyDiTextStyles.caption
            .copyWith(color: TheyDiColors.textMuted)))));
  }
}

class _MediaOption extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  final VoidCallback onTap;
  const _MediaOption({required this.icon, required this.label,
      required this.color, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 64, height: 64,
          decoration: BoxDecoration(color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3))),
          child: Icon(icon, color: color, size: 28)),
      const SizedBox(height: 8),
      Text(label, style: TheyDiTextStyles.caption
          .copyWith(color: TheyDiColors.textSecondary)),
    ]));
}
