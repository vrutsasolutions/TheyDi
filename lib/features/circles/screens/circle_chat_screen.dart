import 'dart:async';
import 'dart:io' show File;
import 'dart:math' as math;

import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import '../../../core/utils/video_thumbnail_helper.dart';
import '../../../core/utils/image_picker_helper.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../models/circle_model.dart';
import '../models/message_model.dart';
import '../../../core/services/cloudflare_upload.dart';
import '../../../core/utils/platform_helper.dart';
import 'package:video_player/video_player.dart';
import '../../../core/services/encryption_service.dart';
import '../../../shared/widgets/decrypted_text.dart';

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

final _circleSharedPlayer = ap.AudioPlayer();

class CircleChatScreen extends ConsumerStatefulWidget {
  final CircleModel circle;
  const CircleChatScreen({super.key, required this.circle});

  @override
  ConsumerState<CircleChatScreen> createState() => _CircleChatScreenState();
}

class _CircleChatScreenState extends ConsumerState<CircleChatScreen>
    with WidgetsBindingObserver {
  late final Stream<QuerySnapshot> _messagesStream;
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

  // Cache generated preview thumbnails per file path so re-opening the
  // confirmation dialog (e.g. after cropping) doesn't regenerate them.
  final Map<String, Uint8List?> _previewThumbCache = {};

  @override
  void initState() {
    super.initState();
    _circle = widget.circle;
    _messageController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addObserver(this);
    _loadClearedAt();
    _messagesStream = FirebaseFirestore.instance // BUILD ONCE
        .collection('circles')
        .doc(_circle.id)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();

    FirebaseFirestore.instance
        .collection('circles')
        .doc(_circle.id)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      if (!doc.exists) {
        setState(() => _isMember = false);
        return;
      }
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
        .collection('circles')
        .doc(_circle.id)
        .collection('clearedBy')
        .doc(myUid)
        .get();
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
        .collection('circles')
        .doc(_circle.id)
        .collection('messages')
        .where('senderUid', isNotEqualTo: myUid)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in msgs.docs) {
      final seenBy = List<String>.from(doc.data()['seenBy'] ?? []);
      final readBy = List<String>.from(doc.data()['readBy'] ?? []);
      bool needsUpdate = false;
      if (!seenBy.contains(myUid)) {
        seenBy.add(myUid);
        needsUpdate = true;
      }
      if (!readBy.contains(myUid)) {
        readBy.add(myUid);
        needsUpdate = true;
      }
      if (needsUpdate) {
        batch.update(doc.reference, {'seenBy': seenBy, 'readBy': readBy});
      }
    }
    await batch.commit();
  }

  Future<void> _handleSelectedMedia(XFile file) async {
    try {
      final path = file.name.toLowerCase();
      final mediaType = path.endsWith('.mp4') ||
              path.endsWith('.mov') ||
              path.endsWith('.avi')
          ? 'video'
          : 'image';

      if (mediaType == 'video') {
        final withinLimit = await _isVideoWithinDurationLimit(file);
        if (!withinLimit) {
          _showSnack('Maximum video sending limit is 2 minutes', Colors.red);
          return;
        }
      }

      final bytes = await file.readAsBytes();
      final url = await CloudflareUpload.uploadBytes(bytes, file.name);

      // Generate + upload a thumbnail exactly like any other file — no paid
// service involved. Best-effort: if it fails for any reason, the video
// still sends fine, it just falls back to a placeholder icon in the bubble.
      String? thumbnailUrl;
      if (mediaType == 'video') {
        final thumbBytes = await VideoThumbnailHelper.generate(file.path);
        if (thumbBytes != null) {
          thumbnailUrl = await CloudflareUpload.uploadBytes(
            thumbBytes,
            'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        }
      }

      if (url == null) {
        _showSnack('Upload failed', Colors.red);
        return;
      }

      await _sendMessage(mediaUrl: url, mediaType: mediaType);
    } catch (e) {
      _showSnack('Failed: $e', Colors.red);
    }
  }

  Future<void> _sendMessage({
    String? mediaUrl,
    String? mediaType, // "image" | "video"
  }) async {
    final text = _messageController.text.trim();

    if ((text.isEmpty && mediaUrl == null) || _isSending || !_isMember) return;

    setState(() {
      _isSending = true;
      _showEmojiPicker = false;
    });

    _messageController.clear();

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final encryptedText = await EncryptionService.encrypt(text, _circle.id);
      String senderName = user.displayName ?? user.email!.split('@').first;

      try {
        final d = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (d.exists) {
          senderName = d.data()?['displayName'] ?? senderName;
        }
      } catch (_) {}

      final message = MessageModel(
        id: '',
        circleId: _circle.id,
        senderUid: user.uid,
        senderName: senderName,
        text: encryptedText,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        createdAt: DateTime.now(),
        readBy: [user.uid],
        seenBy: [user.uid],
      );

      await FirebaseFirestore.instance
          .collection('circles')
          .doc(_circle.id)
          .collection('messages')
          .add(message.toFirestoreMap());

      await FirebaseFirestore.instance
          .collection('circles')
          .doc(_circle.id)
          .update({
        'lastMessage': mediaType == "image"
            ? '📷 Photo'
            : mediaType == "video"
                ? '🎥 Video'
                : encryptedText,
        'lastMessageSender': senderName,
        'lastMessageAt': Timestamp.now(),
      });

      _scrollToBottom();
    } catch (e) {
      if (mounted) _showSnack('Failed: $e', Colors.red);
    }

    if (mounted) {
      setState(() => _isSending = false);
    }
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
      // stop() returns the file path on mobile, or a blob URL on web
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
    setState(() => _isUploading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      String senderName = user.displayName ?? 'Me';
      try {
        final d = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
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
        if (mounted) {
          _showSnack('Audio capture failed — please try again', Colors.red);
        }
        setState(() => _isUploading = false);
        return;
      }

      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final audioUrl = await CloudflareUpload.uploadBytes(bytes, fileName);

      if (audioUrl == null) {
        if (mounted) {
          _showSnack('Audio upload failed. Please try again.', Colors.red);
        }
        setState(() => _isUploading = false);
        return;
      }

      final now = DateTime.now();
      await FirebaseFirestore.instance
          .collection('circles')
          .doc(_circle.id)
          .collection('messages')
          .add({
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
          .collection('circles')
          .doc(_circle.id)
          .update({
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

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _openInfo() => context.push(AppRoutes.circleInfo, extra: _circle);

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

  // ── Media Attachment Logic ────────────────────────────────────────────────
  Future<void> _handleMediaAction(String action) async {
    setState(() {
      _showEmojiPicker = false;
      _showAttachmentMenu = false;
    });
    final picker = ImagePicker();
    XFile? file;
    String type = 'image';
    String? fileName;

    try {
      if (action == 'camera') {
        file = await picker.pickImage(
          source: ImageSource.camera,
        );
      } else if (action == 'video') {
        file = await picker.pickVideo(
            source: ImageSource.camera,
            maxDuration: const Duration(minutes: 2));
        type = 'video';
      } else if (action == 'gallery') {
        final XFile? picked = await picker.pickMedia();
        if (picked != null) {
          final lower = picked.name.toLowerCase();
          type = lower.endsWith('.mp4') ||
                  lower.endsWith('.mov') ||
                  lower.endsWith('.avi') ||
                  lower.endsWith('.mkv') ||
                  lower.endsWith('.webm')
              ? 'video'
              : 'image';
          file = picked;
        }
      } else if (action == 'document') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: [
            'pdf',
            'doc',
            'docx',
            'xls',
            'xlsx',
            'ppt',
            'pptx',
            'txt',
            'zip',
          ],
          withData: kIsWeb,
        );

        if (result != null && result.files.isNotEmpty) {
          final pickedFile = result.files.single;

          type = 'file';

          if (kIsWeb) {
            if (pickedFile.bytes == null) {
              _showSnack('Unable to read file.', Colors.red);
              return;
            }

            final xFile = XFile.fromData(
              pickedFile.bytes!,
              name: pickedFile.name,
              mimeType: pickedFile.extension,
            );

            _confirmAndSendMedia(xFile, type);
          } else {
            final xFile = XFile(
              pickedFile.path!,
              name: pickedFile.name,
            );

            _confirmAndSendMedia(xFile, type);
          }
        }

        return;
      }

      if (file != null) {
        if (type == 'video') {
          final withinLimit = await _isVideoWithinDurationLimit(file);
          if (!withinLimit) {
            _showSnack('Maximum video sending limit is 2 minutes', Colors.red);
            return;
          }
        }
        _confirmAndSendMedia(file, type);
      }
    } catch (e) {
      _showSnack('Error picking media: $e', Colors.red);
    }
  }

  /// Generates (and caches) a JPEG preview thumbnail for a video file so the
  /// "Send video?" confirmation dialog can show an actual frame instead of a
  /// static camera icon. Safe to call unconditionally — VideoThumbnailHelper
  /// already returns null on failure/unsupported platforms rather than
  /// throwing, so this never blocks the send flow.
  Future<Uint8List?> _getPreviewThumb(String path) async {
    if (_previewThumbCache.containsKey(path)) {
      return _previewThumbCache[path];
    }
    final bytes = await VideoThumbnailHelper.generate(path);
    _previewThumbCache[path] = bytes;
    return bytes;
  }

  Future<void> _confirmAndSendMedia(
    XFile file,
    String type,
  ) async {
    XFile workingFile = file;

    if (type == 'image') {
      final cropped = await ImagePickerHelper.cropImage(workingFile);
      if (cropped == null) return; // shouldn't happen, but guard anyway
      workingFile = cropped;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: TheyDiColors.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            type == 'image'
                ? 'Send photo?'
                : type == 'video'
                    ? 'Send video?'
                    : 'Send file?',
            style: TheyDiTextStyles.headlineMedium,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (type == 'image')
                SizedBox(
                  width:
                      260, // finite width — Image's width: double.infinity is what
                  // breaks AlertDialog's internal IntrinsicWidth pass on web
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: kIsWeb
                        ? Image.network(workingFile.path,
                            height: 220, fit: BoxFit.cover)
                        : Image.file(File(workingFile.path),
                            height: 220, fit: BoxFit.cover),
                  ),
                )
              else if (type == 'video')
                SizedBox(
                  width: 260,
                  child: FutureBuilder<Uint8List?>(
                    future: _getPreviewThumb(workingFile.path),
                    builder: (context, snapshot) {
                      final thumbBytes = snapshot.data;
                      final loading =
                          snapshot.connectionState != ConnectionState.done;
                      return Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: TheyDiColors.dark,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: loading
                            ? const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: TheyDiColors.primary,
                                  ),
                                ),
                              )
                            : thumbBytes != null
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.memory(thumbBytes,
                                          fit: BoxFit.cover),
                                      Container(
                                        color: Colors.black
                                            .withValues(alpha: 0.15),
                                      ),
                                      const Center(
                                        child: Icon(
                                          Icons.play_circle_fill,
                                          color: Colors.white,
                                          size: 44,
                                        ),
                                      ),
                                    ],
                                  )
                                : Icon(
                                    Icons.videocam_rounded,
                                    size: 48,
                                    color: TheyDiColors.primary,
                                  ),
                      );
                    },
                  ),
                )
              else
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: TheyDiColors.dark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.description,
                    size: 48,
                    color: TheyDiColors.primary,
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                workingFile.name,
                style: TheyDiTextStyles.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Send',
                style: TextStyle(
                    color: TheyDiColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _uploadAndSendMedia(workingFile, type);
    }
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
                onTap: () async {
                  Navigator.pop(ctx);

                  final XFile? image = await ImagePicker().pickImage(
                    source: ImageSource.camera,
                    imageQuality: 80,
                  );

                  if (image != null) {
                    _handleSelectedMedia(image);
                  }
                }),
            _MediaOption(
                icon: Icons.videocam_outlined,
                label: 'Video',
                color: Colors.red,
                onTap: () async {
                  Navigator.pop(ctx);

                  final XFile? video = await ImagePicker().pickVideo(
                    source: ImageSource.gallery,
                  );

                  if (video != null) {
                    _handleSelectedMedia(video);
                  }
                }),
            _MediaOption(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                color: Colors.green,
                onTap: () async {
                  Navigator.pop(ctx);

                  final ImagePicker picker = ImagePicker();
                  final XFile? image = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 80,
                  );

                  if (image != null) {
                    _handleSelectedMedia(image);
                  }
                }),
          ]),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Future<void> _uploadAndSendMedia(
    XFile file,
    String type,
  ) async {
    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;

      // Read original file bytes
      final bytes = await file.readAsBytes();

      final url = await CloudflareUpload.uploadBytes(
        bytes,
        file.name,
      );

      // Generate + upload a thumbnail exactly like any other file — no paid
// service involved. Best-effort: if it fails for any reason, the video
// still sends fine, it just falls back to a placeholder icon in the bubble.
      String? thumbnailUrl;
      if (type == 'video') {
        final thumbBytes = await _getPreviewThumb(file.path);
        if (thumbBytes != null) {
          thumbnailUrl = await CloudflareUpload.uploadBytes(
            thumbBytes,
            'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        }
      }

      if (url == null) {
        throw Exception('Cloudflare upload failed');
      }

      final senderName = user.displayName ?? 'User';

      final msgText = type == 'image'
          ? '📷 Photo'
          : type == 'video'
              ? '🎥 Video'
              : '📄 ${file.name}';

      await FirebaseFirestore.instance
          .collection('circles')
          .doc(_circle.id)
          .collection('messages')
          .add({
        'senderUid': user.uid,
        'senderName': senderName,
        'type': type,
        'mediaUrl': url,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        'fileName': file.name,
        'text': msgText,
        'circleId': _circle.id,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [user.uid],
        'seenBy': [user.uid],
      });

      await FirebaseFirestore.instance
          .collection('circles')
          .doc(_circle.id)
          .update({
        'lastMessage': msgText,
        'lastMessageSender': senderName,
        'lastMessageAt': FieldValue.serverTimestamp(),
      });

      _scrollToBottom();
    } catch (e) {
      _showSnack('Upload failed: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
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

  static const int _kMaxVideoDurationSeconds = 120; // 2 minutes

  Future<bool> _isVideoWithinDurationLimit(XFile file) async {
    VideoPlayerController? controller;
    try {
      controller = kIsWeb
          ? VideoPlayerController.networkUrl(Uri.parse(file.path))
          : VideoPlayerController.file(File(file.path));
      await controller.initialize();
      final duration = controller.value.duration;
      return duration.inSeconds <= _kMaxVideoDurationSeconds;
    } catch (e) {
      // If we can't read duration, don't block a legitimate upload.
      return true;
    } finally {
      await controller?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
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
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            decoration: BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: TheyDiColors.divider))),
            child: Row(children: [
              IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: TheyDiColors.textPrimary),
                  onPressed: () => context.pop()),
              const SizedBox(width: 4),
              Expanded(
                  child: GestureDetector(
                      onTap: _openInfo,
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: _circle.profileImageUrl != null &&
                                    _circle.profileImageUrl!.isNotEmpty
                                ? DecorationImage(
                                    image:
                                        NetworkImage(_circle.profileImageUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            gradient: (_circle.profileImageUrl == null ||
                                    _circle.profileImageUrl!.isEmpty)
                                ? TheyDiColors.gradientPrimary
                                : null,
                          ),
                          child: (_circle.profileImageUrl == null ||
                                  _circle.profileImageUrl!.isEmpty)
                              ? Center(
                                  child: Text(
                                    _circle.name.isNotEmpty
                                        ? _circle.name[0].toUpperCase()
                                        : '?',
                                    style: TheyDiTextStyles.labelLarge
                                        .copyWith(color: Colors.white),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(_circle.name,
                                  style: TheyDiTextStyles.labelLarge,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(
                                  '${_circle.memberUids.length} members · Tap for info',
                                  style: TheyDiTextStyles.caption.copyWith(
                                      color: TheyDiColors.textSecondary)),
                            ])),
                      ]))),
              IconButton(
                  icon: Icon(Icons.info_outline,
                      color: TheyDiColors.textSecondary, size: 22),
                  onPressed: _openInfo),
            ]),
          ),
          Expanded(
              child: GestureDetector(
            onTap: () => setState(() => _showEmojiPicker = false),
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: TheyDiColors.primary));
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
                  return Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMine = data['senderUid'] == myUid;
                    final mediaUrl = data['mediaUrl'];
                    final msgType = data['mediaType'] ?? data['type'] ?? 'text';
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
                                as Timestamp?)
                            ?.toDate()
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
                      else if (msgType == 'image')
                        _CircleImageBubble(
                          imageUrl: mediaUrl ?? '',
                          isMine: isMine,
                          senderName: senderName,
                          timeLabel: timeLabel,
                          seen: seen,
                        )
                      else if (msgType == 'video')
                        _CircleVideoBubble(
                          thumbnailUrl: data['thumbnailUrl'],
                          videoUrl: mediaUrl ?? '',
                          isMine: isMine,
                          senderName: senderName,
                          timeLabel: timeLabel,
                          seen: seen,
                        )
                      else if (msgType == 'file')
                        _CircleDocumentBubble(
                          fileUrl: mediaUrl ?? '',
                          fileName: data['fileName'] ?? 'Document',
                          isMine: isMine,
                          senderName: senderName,
                          timeLabel: timeLabel,
                          seen: seen,
                        )
                      else if (msgType == 'event_share')
                        _CircleEventShareBubble(
                          eventId: data['eventId'] ?? '',
                          eventName: data['eventName'] ?? '',
                          eventLink: data['eventLink'],
                          isMine: isMine,
                          senderName: senderName,
                          timeLabel: timeLabel,
                          seen: seen,
                        )
                      else if (msgType == 'circle_invite')
                        _CircleInviteBubble(
                          circleId: data['circleId'] ?? '',
                          circleName: data['circleName'] ?? '',
                          circleLink: data['circleLink'],
                          isMine: isMine,
                          senderName: senderName,
                          timeLabel: timeLabel,
                          seen: seen,
                        )
                      else if (msgType == 'profile_share') // ADD THIS BLOCK
                        _CircleProfileShareBubble(
                          profileUserId: data['userId'] ?? '',
                          profileUserName: data['userName'] ?? '',
                          profilePhotoUrl: data['userPhoto'] ?? '',
                          isMine: isMine,
                          senderName: senderName,
                          timeLabel: timeLabel,
                          seen: seen,
                        )
                      else
                        _CircleBubble(
                          text: data['text'] ?? '',
                          chatId: _circle.id, // NEW
                          isMine: isMine,
                          senderName: senderName,
                          timeLabel: timeLabel,
                          seen: seen,
                        ),
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
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: TheyDiColors.primary)),
                const SizedBox(width: 10),
                Text('Uploading media...',
                    style: TheyDiTextStyles.caption
                        .copyWith(color: TheyDiColors.textSecondary)),
              ]),
            ),
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
          if (!_isMember)
            Container(
              padding: const EdgeInsets.all(16),
              color: TheyDiColors.card,
              child: Text(
                'You are no longer a member of this circle',
                style: TheyDiTextStyles.bodySmall.copyWith(
                  color: TheyDiColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            if (_showAttachmentMenu && !_isRecording)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _buildAttachmentMenu(),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
              decoration: BoxDecoration(
                color: TheyDiColors.dark,
                border: Border(
                  top: BorderSide(
                    color: TheyDiColors.divider,
                  ),
                ),
              ),
              child: _isRecording
                  ? _buildRecordingBar()
                  : _buildNormalBar(hasText),
            ),
          ],
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
          _MediaOption(
              icon: Icons.camera_alt,
              label: 'Camera',
              color: Colors.blue,
              onTap: () => _handleMediaAction('camera')),
          _MediaOption(
              icon: Icons.videocam,
              label: 'Video',
              color: Colors.red,
              onTap: () => _handleMediaAction('video')),
          _MediaOption(
              icon: Icons.photo_library,
              label: 'Gallery',
              color: Colors.purple,
              onTap: () => _handleMediaAction('gallery')),
          _MediaOption(
              icon: Icons.description,
              label: 'Document',
              color: Colors.orange,
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

  Widget _buildNormalBar(bool hasText) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Attachment Button
        GestureDetector(
          onTap: () {
            setState(() {
              _showAttachmentMenu = !_showAttachmentMenu;
              _showEmojiPicker = false;
            });
          },
          child: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(bottom: 3),
            decoration: BoxDecoration(
              color: TheyDiColors.card,
              shape: BoxShape.circle,
              border: Border.all(
                color: TheyDiColors.divider,
              ),
            ),
            child: Icon(
              _showAttachmentMenu ? Icons.close : Icons.add,
              color: TheyDiColors.textSecondary,
              size: 20,
            ),
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: TheyDiColors.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: TheyDiColors.divider,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TheyDiTextStyles.bodyMedium,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onTap: () => setState(() {
                      _showEmojiPicker = false;
                    }),
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Message ${_circle.name}...',
                      hintStyle: TheyDiTextStyles.bodySmall.copyWith(
                        color: TheyDiColors.textMuted,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _toggleEmojiPicker,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10, bottom: 10),
                    child: Text(
                      _showEmojiPicker ? '⌨️' : '😊',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        hasText
            ? GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: TheyDiColors.gradientPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              )
            : MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _startRecording,
                  onLongPressStart: (_) => _startRecording(),
                  onLongPressEnd: (_) => _stopAndSendRecording(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: TheyDiColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: TheyDiColors.divider,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: TheyDiColors.primary.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.mic_none,
                      color: TheyDiColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}

class _AttachmentIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AttachmentIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.only(bottom: 3),
            decoration: BoxDecoration(
                color: TheyDiColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: TheyDiColors.divider)),
            child: Icon(icon, color: TheyDiColors.textSecondary, size: 18)));
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────────
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

class _CircleVoiceBubble extends StatefulWidget {
  final String audioUrl;
  final int durationSecs;
  final bool isMine;
  final String senderName;
  final String timeLabel;
  final bool seen;
  const _CircleVoiceBubble(
      {required this.audioUrl,
      required this.durationSecs,
      required this.isMine,
      required this.senderName,
      required this.timeLabel,
      required this.seen});
  @override
  State<_CircleVoiceBubble> createState() => _CircleVoiceBubbleState();
}

/// Full-screen image preview with pinch-to-zoom, hero animation, and quick
/// actions (share / open in browser). Shared look & feel with the DM screen.
class _ImagePreviewScreen extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  const _ImagePreviewScreen({required this.imageUrl, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.4),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser, color: Colors.white),
            tooltip: 'Open original',
            onPressed: () {
              if (imageUrl.isNotEmpty) {
                launchUrl(Uri.parse(imageUrl),
                    mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                final total = progress.expectedTotalBytes;
                final loaded = progress.cumulativeBytesLoaded;
                return Center(
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: TheyDiColors.primary,
                      value: total != null ? loaded / total : null,
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image, color: Colors.white54, size: 64),
                  SizedBox(height: 8),
                  Text('Could not load image',
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleImageBubble extends StatelessWidget {
  final String imageUrl;
  final bool isMine;
  final String senderName;
  final String timeLabel;
  final bool seen;

  const _CircleImageBubble({
    required this.imageUrl,
    required this.isMine,
    required this.senderName,
    required this.timeLabel,
    required this.seen,
  });

  @override
  Widget build(BuildContext context) {
    final heroTag = 'circle_image_${imageUrl}_$timeLabel';
    return Padding(
      padding: EdgeInsets.only(
        top: 3,
        bottom: 3,
        left: isMine ? 60 : 0,
        right: isMine ? 0 : 60,
      ),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMine)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 3),
                  child: Text(senderName,
                      style: TheyDiTextStyles.caption.copyWith(
                          color: TheyDiColors.primary,
                          fontWeight: FontWeight.w600)),
                ),
              GestureDetector(
                onTap: () {
                  if (imageUrl.isEmpty) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _ImagePreviewScreen(
                          imageUrl: imageUrl, heroTag: heroTag),
                      fullscreenDialog: true,
                    ),
                  );
                },
                child: Hero(
                  tag: heroTag,
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMine ? 16 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 16),
                    ),
                    child: Stack(
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: 150,
                            maxHeight: 260,
                          ),
                          child: imageUrl.isEmpty
                              ? _ImagePlaceholder()
                              : Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    final total = progress.expectedTotalBytes;
                                    final loaded =
                                        progress.cumulativeBytesLoaded;
                                    return Container(
                                      height: 200,
                                      color: TheyDiColors.card,
                                      child: Center(
                                        child: SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: TheyDiColors.primary,
                                            value: total != null
                                                ? loaded / total
                                                : null,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) =>
                                      _ImagePlaceholder(isError: true),
                                ),
                        ),
                        // Bottom gradient scrim so the timestamp/receipt are
                        // legible over bright photos.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(10, 18, 8, 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0),
                                  Colors.black.withValues(alpha: 0.55),
                                ],
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(timeLabel,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500)),
                                if (isMine) ...[
                                  const SizedBox(width: 4),
                                  _ReadReceipt(seen: seen, light: true),
                                ],
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.zoom_out_map,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final bool isError;
  const _ImagePlaceholder({this.isError = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      color: TheyDiColors.card,
      alignment: Alignment.center,
      child: Icon(
        isError ? Icons.broken_image_outlined : Icons.image_outlined,
        color: TheyDiColors.textMuted,
        size: 36,
      ),
    );
  }
}

class _CircleInviteBubble extends StatelessWidget {
  final String circleId;
  final String circleName;
  final String? circleLink;
  final bool isMine;
  final String senderName;
  final String timeLabel;
  final bool seen;

  const _CircleInviteBubble({
    required this.circleId,
    required this.circleName,
    this.circleLink,
    required this.isMine,
    required this.senderName,
    required this.timeLabel,
    required this.seen,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isMine
              ? TheyDiColors.primary.withValues(alpha: 0.12)
              : TheyDiColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: TheyDiColors.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  senderName,
                  style: TheyDiTextStyles.labelMedium.copyWith(
                    color: TheyDiColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Row(
              children: [
                const Icon(
                  Icons.groups,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Circle Invite',
                  style: TheyDiTextStyles.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              circleName,
              style: TheyDiTextStyles.titleMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.push('/circle/$circleId');
                },
                icon: const Icon(Icons.group, size: 18),
                label: const Text('View Circle'),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeLabel,
                    style: TheyDiTextStyles.labelSmall,
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      seen ? Icons.done_all : Icons.done,
                      size: 14,
                      color: seen ? Colors.blue : Colors.grey,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleEventShareBubble extends StatelessWidget {
  final String eventId;
  final String eventName;
  final String? eventLink;
  final bool isMine;
  final String senderName;
  final String timeLabel;
  final bool seen;

  const _CircleEventShareBubble({
    required this.eventId,
    required this.eventName,
    this.eventLink,
    required this.isMine,
    required this.senderName,
    required this.timeLabel,
    required this.seen,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isMine
              ? TheyDiColors.primary.withValues(alpha: 0.12)
              : TheyDiColors.card,
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: TheyDiColors.primary.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  senderName,
                  style: TheyDiTextStyles.labelMedium.copyWith(
                    color: TheyDiColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Row(
              children: [
                const Icon(
                  Icons.event,
                  color: TheyDiColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Shared an Event',
                  style: TheyDiTextStyles.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              eventName,
              style: TheyDiTextStyles.titleMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.push('/event/$eventId');
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('View Event'),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                timeLabel,
                style: TheyDiTextStyles.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleProfileShareBubble extends StatelessWidget {
  final String profileUserId;
  final String profileUserName;
  final String profilePhotoUrl;
  final bool isMine;
  final String senderName;
  final String timeLabel;
  final bool seen;

  const _CircleProfileShareBubble({
    required this.profileUserId,
    required this.profileUserName,
    required this.profilePhotoUrl,
    required this.isMine,
    required this.senderName,
    required this.timeLabel,
    required this.seen,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        profileUserName.isNotEmpty ? profileUserName[0].toUpperCase() : '?';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isMine
              ? TheyDiColors.primary.withValues(alpha: 0.12)
              : TheyDiColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: TheyDiColors.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  senderName,
                  style: TheyDiTextStyles.labelMedium.copyWith(
                    color: TheyDiColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Row(children: [
              const Icon(Icons.person_outline,
                  color: TheyDiColors.primary, size: 18),
              const SizedBox(width: 6),
              Text('Shared a Profile', style: TheyDiTextStyles.labelLarge),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: TheyDiColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: profilePhotoUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          profilePhotoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(initial,
                                style: TheyDiTextStyles.labelLarge
                                    .copyWith(color: Colors.white)),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(initial,
                            style: TheyDiTextStyles.labelLarge
                                .copyWith(color: Colors.white)),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  profileUserName,
                  style: TheyDiTextStyles.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: profileUserId.isEmpty
                    ? null
                    : () => context.push(AppRoutes.userProfile, extra: {
                          'uid': profileUserId,
                          'requestId': null,
                        }),
                icon: const Icon(Icons.person, size: 18),
                label: const Text('View Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TheyDiColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(timeLabel, style: TheyDiTextStyles.labelSmall),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    _ReadReceipt(seen: seen),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleVideoBubble extends StatelessWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final bool isMine;
  final String senderName;
  final String timeLabel;
  final bool seen;

  const _CircleVideoBubble({
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.isMine,
    required this.senderName,
    required this.timeLabel,
    required this.seen,
  });

  Widget _buildThumbArea() {
    final url = thumbnailUrl;

    if (url == null || url.isEmpty) {
      return _placeholderBox();
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;

        return Container(
          color: TheyDiColors.card,
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: TheyDiColors.primary,
              ),
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _placeholderBox(),
    );
  }

  Widget _placeholderBox() {
    return Container(
      decoration: BoxDecoration(
        gradient: TheyDiColors.gradientPrimary,
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.videocam_rounded,
        color: Colors.white70,
        size: 34,
      ),
    );
  }

  void _openVideo(BuildContext context) {
    if (videoUrl.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _VideoPlayerScreen(videoUrl: videoUrl),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 3,
        bottom: 3,
        left: isMine ? 60 : 0,
        right: isMine ? 0 : 60,
      ),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 240,
            minWidth: 180,
          ),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMine)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 4,
                    bottom: 3,
                  ),
                  child: Text(
                    senderName,
                    style: TheyDiTextStyles.caption.copyWith(
                      color: TheyDiColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              GestureDetector(
                onTap: () => _openVideo(context),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(
                      isMine ? 16 : 4,
                    ),
                    bottomRight: Radius.circular(
                      isMine ? 4 : 16,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 160,
                        width: double.infinity,
                        child: _buildThumbArea(),
                      ),

                      // Darken slightly so the play icon always pops.
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(
                            alpha: 0.18,
                          ),
                        ),
                      ),

                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(
                            alpha: 0.45,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white70,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),

                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(
                            10,
                            18,
                            8,
                            6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0),
                                Colors.black.withValues(alpha: 0.6),
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.videocam,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Video',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                timeLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (isMine) ...[
                                const SizedBox(width: 4),
                                _ReadReceipt(
                                  seen: seen,
                                  light: true,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen video playback with a proper scrubber, play/pause, elapsed /
/// remaining time, and tap-to-toggle controls that auto-hide while playing.
class _VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  const _VideoPlayerScreen({required this.videoUrl});

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _ready = false;
  bool _controlsVisible = true;
  String? _error;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller.play();
        _controller.addListener(_onTick);
        _scheduleHide();
      }).catchError((e) {
        if (!mounted) return;
        setState(() => _error = 'Could not load video');
      });
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  void _scheduleHide() {
    if (kIsWeb) return;
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    if (kIsWeb) return;
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _togglePlay() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _hideTimer?.cancel();
        // Always keep controls up while paused — otherwise a tap that lands
        // on both the button and the background toggle (can happen with
        // mouse clicks on web) can hide the play button the instant you
        // pause, leaving no way to resume without leaving the screen.
        _controlsVisible = true;
      } else {
        _controller.play();
        _scheduleHide();
      }
    });
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = _ready ? _controller.value.position : Duration.zero;
    final total = _ready ? _controller.value.duration : Duration.zero;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.white)))
          : !_ready
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white))
              : GestureDetector(
                  onTap: _toggleControls,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: VideoPlayer(_controller),
                        ),
                      ),
                      AnimatedOpacity(
                        opacity: _controlsVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: IgnorePointer(
                          ignoring: !_controlsVisible,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap:
                                () {}, // absorb: don't fall through to _toggleControls
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.25),
                              child: Column(
                                children: [
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: _togglePlay,
                                    child: Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.black.withValues(alpha: 0.4),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white70, width: 1.5),
                                      ),
                                      child: Icon(
                                        _controller.value.isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                        color: Colors.white,
                                        size: 38,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 24),
                                    child: Column(
                                      children: [
                                        SliderTheme(
                                          data:
                                              SliderTheme.of(context).copyWith(
                                            trackHeight: 3,
                                            thumbShape:
                                                const RoundSliderThumbShape(
                                                    enabledThumbRadius: 6),
                                            overlayShape:
                                                const RoundSliderOverlayShape(
                                                    overlayRadius: 14),
                                            activeTrackColor:
                                                TheyDiColors.primary,
                                            inactiveTrackColor: Colors.white
                                                .withValues(alpha: 0.3),
                                            thumbColor: TheyDiColors.primary,
                                          ),
                                          child: Slider(
                                            min: 0,
                                            max: total.inMilliseconds > 0
                                                ? total.inMilliseconds
                                                    .toDouble()
                                                : 1,
                                            value: position.inMilliseconds
                                                .clamp(0, total.inMilliseconds)
                                                .toDouble(),
                                            onChangeStart: (_) {
                                              _hideTimer?.cancel();
                                            },
                                            onChanged: (v) {
                                              setState(() {
                                                _controller.seekTo(Duration(
                                                    milliseconds: v.round()));
                                              });
                                            },
                                            onChangeEnd: (_) => _scheduleHide(),
                                          ),
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(_fmtDuration(position),
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12)),
                                            Text(_fmtDuration(total),
                                                style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _CircleDocumentBubble extends StatelessWidget {
  final String fileUrl;
  final String fileName;
  final bool isMine;
  final String senderName;
  final String timeLabel;
  final bool seen;

  const _CircleDocumentBubble({
    required this.fileUrl,
    required this.fileName,
    required this.isMine,
    required this.senderName,
    required this.timeLabel,
    required this.seen,
  });

  Future<void> _openFile(BuildContext context) async {
    final ext =
        fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

    // PDFs: native in-app viewer on mobile, browser tab on web (Chrome renders
    // PDFs natively — instant, no black screen, no Google Docs round trip).
    if (ext == 'pdf') {
      if (kIsWeb) {
        final launched = await launchUrl(
          Uri.parse(fileUrl),
          webOnlyWindowName: '_blank',
        );
        if (!launched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open file')));
        }
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                _PdfViewerScreen(pdfUrl: fileUrl, fileName: fileName),
            fullscreenDialog: true,
          ),
        );
      }
      return;
    }

    // Word / Excel / PowerPoint: hand off to an installed app on mobile;
    // on web there's no native renderer, so fall back to Google's viewer.
    final officeExts = ['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'];
    Uri uri;
    if (kIsWeb && officeExts.contains(ext)) {
      final encoded = Uri.encodeComponent(fileUrl);
      uri = Uri.parse(
          'https://docs.google.com/viewer?url=$encoded&embedded=true');
    } else {
      uri = Uri.parse(fileUrl);
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        webOnlyWindowName: kIsWeb ? '_blank' : null,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not open file')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not open file: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => _openFile(context),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMine ? const Color(0xFFE8F0FE) : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    senderName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              Row(
                children: [
                  const Icon(
                    Icons.insert_drive_file,
                    color: Colors.red,
                    size: 34,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    timeLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      seen ? Icons.done_all : Icons.done,
                      size: 14,
                      color: seen ? Colors.blue : Colors.grey,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String fileName;
  const _PdfViewerScreen({required this.pdfUrl, required this.fileName});

  @override
  State<_PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<_PdfViewerScreen> {
  String? _localPath;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _downloadAndOpen();
  }

  Future<void> _downloadAndOpen() async {
    try {
      final response = await http.get(Uri.parse(widget.pdfUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download (${response.statusCode})');
      }
      final tmpDir = await getTempDirPath();
      final safeName =
          widget.fileName.isNotEmpty ? widget.fileName : 'document.pdf';
      final path = '$tmpDir/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final file = File(path);
      await file.writeAsBytes(response.bodyBytes);
      if (!mounted) return;
      setState(() {
        _localPath = path;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load document';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: TheyDiColors.dark,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.fileName,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.white)))
              : PDFView(
                  filePath: _localPath!,
                  enableSwipe: true,
                  swipeHorizontal: false,
                  autoSpacing: true,
                  pageFling: true,
                  onError: (e) {
                    if (mounted) {
                      setState(() => _error = 'Error rendering PDF');
                    }
                  },
                ),
    );
  }
}

class _CircleVoiceBubbleState extends State<_CircleVoiceBubble> {
  bool _isPlaying = false;
  double _progress = 0;
  int _currentSec = 0;
  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;
  @override
  void initState() {
    super.initState();
    _stateSub = _circleSharedPlayer.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      if (s == ap.PlayerState.completed || s == ap.PlayerState.stopped) {
        setState(() {
          _isPlaying = false;
          _progress = 0;
          _currentSec = 0;
        });
      }
    });
    _posSub = _circleSharedPlayer.onPositionChanged.listen((pos) {
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
      await _circleSharedPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      await _circleSharedPlayer.stop();
      await _circleSharedPlayer.play(ap.UrlSource(widget.audioUrl));
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
          child: Column(
            crossAxisAlignment: widget.isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!widget.isMine)
                Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(widget.senderName,
                        style: TheyDiTextStyles.caption.copyWith(
                            color: TheyDiColors.primary,
                            fontWeight: FontWeight.w600))),
              Container(
                constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
                padding: const EdgeInsets.fromLTRB(10, 10, 12, 8),
                decoration: BoxDecoration(
                    color: TheyDiColors.card,
                    borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(widget.isMine ? 16 : 4),
                        bottomRight: Radius.circular(widget.isMine ? 4 : 16)),
                    border: Border.all(color: const Color(0xFFE0E0E0))),
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
                                      color: Colors.black54, fontSize: 10)),
                            ])),
                      ]),
                      const SizedBox(height: 4),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Text(widget.timeLabel,
                            style: TheyDiTextStyles.caption
                                .copyWith(color: Colors.black54, fontSize: 10)),
                        if (widget.isMine) ...[
                          const SizedBox(width: 4),
                          _ReadReceipt(seen: widget.seen)
                        ],
                      ]),
                    ]),
              ),
            ],
          ),
        ));
  }
}

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
                  : TheyDiColors.textMuted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleBubble extends StatelessWidget {
  final String text, chatId, senderName, timeLabel; // add chatId here
  final bool isMine, seen;
  const _CircleBubble(
      {required this.text,
      required this.chatId, // add here
      required this.isMine,
      required this.senderName,
      required this.timeLabel,
      required this.seen});
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(
          top: 3, bottom: 3, left: isMine ? 60 : 0, right: isMine ? 0 : 60),
      child: Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMine)
                Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(senderName,
                        style: TheyDiTextStyles.caption.copyWith(
                            color: TheyDiColors.primary,
                            fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isMine ? Colors.white : TheyDiColors.card,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMine ? 16 : 4),
                    bottomRight: Radius.circular(isMine ? 4 : 16),
                  ),
                  border: Border.all(
                    color:
                        isMine ? const Color(0xFFE0E0E0) : TheyDiColors.divider,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    DecryptedText(
                      cipherText: text,
                      chatId: chatId,
                      style: TheyDiTextStyles.bodySmall.copyWith(
                        color:
                            isMine ? Colors.black : TheyDiColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeLabel,
                          style: TheyDiTextStyles.caption.copyWith(
                            color: isMine
                                ? Colors.black54
                                : TheyDiColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                        if (isMine) ...[
                          const SizedBox(width: 4),
                          _ReadReceipt(seen: seen),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          )));
}

class _ReadReceipt extends StatelessWidget {
  final bool seen;
  // When `light` is true, the unseen state renders in translucent white
  // instead of grey — used when the receipt sits on top of a photo/video
  // thumbnail where a solid grey tick would be hard to see.
  final bool light;
  const _ReadReceipt({required this.seen, this.light = false});

  @override
  Widget build(BuildContext context) {
    // Map tick colors per existing message model semantics:
    // - single grey tick: sent/offline/not delivered (seen==false AND message not read)
    // - double grey ticks: delivered but not seen
    // - double blue ticks: seen
    final tickColor =
        seen ? Colors.lightBlueAccent : (light ? Colors.white70 : Colors.grey);
    return SizedBox(
      width: 15,
      height: 11,
      child: Stack(children: [
        Icon(Icons.check, size: 11, color: tickColor),
        Positioned(
            left: 3, child: Icon(Icons.check, size: 11, color: tickColor)),
      ]),
    );
  }
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
