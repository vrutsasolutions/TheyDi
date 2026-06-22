// ─────────────────────────────────────────────────────────────────────────────
// CHANGES vs original circle_info_screen.dart
//
//  1. Added import for circle_share_sheet.dart
//  2. In build() → AppBar Row: added Share button after Edit (visible to
//     both Admin and Members, per spec)
//  3. Added _shareAnimating bool + _buildShareButton() for pulse animation
//  4. All existing logic (edit, save, delete, leave, report, block) unchanged
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/cloudflare_upload.dart';
import '../../../shared/screens/image_cropper_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/event_circle_service.dart';
import '../models/circle_model.dart';
import '../../../core/router/app_routes.dart';

// ── NEW import ──
import '../widgets/circle_share_sheet.dart';


const _kCircleReportReasons = [
  'Spam or unwanted content',
  'Harassment or bullying',
  'Hate speech or discrimination',
  'Inappropriate or adult content',
  'Scam or fraud',
  'Other',
];

class CircleInfoScreen extends StatefulWidget {
  final CircleModel circle;
  const CircleInfoScreen({super.key, required this.circle});

  @override
  State<CircleInfoScreen> createState() => _CircleInfoScreenState();
}

class _CircleInfoScreenState extends State<CircleInfoScreen> {
  late CircleModel _circle;
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _isHost = false;
  bool _editing = false;
  bool _saving = false;

  // ── NEW: share button animation state ──
  bool _shareAnimating = false;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _circle = widget.circle;
    _isHost = _myUid == _circle.creatorUid;
    _nameController.text = _circle.name;
    _descController.text = _circle.description;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final doc = await FirebaseFirestore.instance
        .collection('circles')
        .doc(_circle.id)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        _circle = CircleModel.fromFirestore(doc);
        _isHost = _myUid == _circle.creatorUid;
      });
    }
  }

  Future<void> _saveEdits() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);

    await FirebaseFirestore.instance
        .collection('circles')
        .doc(_circle.id)
        .update({
      'name': _nameController.text.trim(),
      'description': _descController.text.trim(),
    });

    await _refresh();
    if (mounted)
      setState(() {
        _editing = false;
        _saving = false;
      });
  }

  Future<void> _pickGroupPhoto() async {
    final picker = ImagePicker();

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );

    if (picked == null) return;

    try {
      final initialBytes = await picked.readAsBytes();

      if (!mounted) return;
      final bytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (context) => ImageCropperScreen(
            imageBytes: initialBytes,
            aspectRatio: 1.0,
            title: 'Crop Group Photo',
          ),
        ),
      );

      if (bytes == null) return;

      final url = await CloudflareUpload.uploadBytes(
        bytes,
        '${_circle.id}.jpg',
      );

      if (url == null) {
        throw Exception('Cloudflare upload failed');
      }

      await FirebaseFirestore.instance
          .collection('circles')
          .doc(_circle.id)
          .update({'profileImageUrl': url});

      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeMember(String uid, String name) async {
    final confirmed = await _confirmDialog(
      title: 'Remove $name?',
      body: 'They will be removed from this circle and notified.',
      confirm: 'Remove',
      confirmColor: Colors.red,
    );
    if (!confirmed) return;

    await EventCircleService.removeMemberFromCircle(
        circleId: _circle.id, userUid: uid, userName: name);
    await _refresh();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name removed'), backgroundColor: Colors.grey),
      );
    }
  }

  Future<void> _leaveGroup() async {
    final myName = _circle.memberMap[_myUid] ?? 'You';
    final confirmed = await _confirmDialog(
      title: 'Leave Circle?',
      body: 'Are you sure you want to leave "${_circle.name}"?',
      confirm: 'Leave',
      confirmColor: Colors.red,
    );
    if (!confirmed) return;

    await EventCircleService.removeMemberFromCircle(
        circleId: _circle.id, userUid: _myUid, userName: myName);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You left the circle'), backgroundColor: Colors.grey),
      );
      context.pop();
      context.pop();
    }
  }

  Future<void> _deleteGroup() async {
    final confirmed = await _confirmDialog(
      title: 'Delete Circle?',
      body:
          'This will permanently delete "${_circle.name}" and all its messages.',
      confirm: 'Delete',
      confirmColor: Colors.red,
    );
    if (!confirmed) return;

    final messages = await FirebaseFirestore.instance
        .collection('circles')
        .doc(_circle.id)
        .collection('messages')
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    await FirebaseFirestore.instance
        .collection('circles')
        .doc(_circle.id)
        .delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Circle deleted'), backgroundColor: Colors.red),
      );
      context.pop();
      context.pop();
    }
  }

  Future<void> _clearChat() async {
    final confirmed = await _confirmDialog(
      title: 'Clear Chat?',
      body:
          'This clears all messages from your view only. Other members will still see the conversation.',
      confirm: 'Clear',
      confirmColor: Colors.orange,
    );
    if (!confirmed) return;

    await FirebaseFirestore.instance
        .collection('circles')
        .doc(_circle.id)
        .collection('clearedBy')
        .doc(_myUid)
        .set({'clearedAt': Timestamp.now()});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat cleared from your view'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _reportCircle() async {
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
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.flag_outlined,
                        color: Colors.red, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Report "${_circle.name}"',
                        style: TheyDiTextStyles.headlineMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Select a reason for reporting',
                  style: TheyDiTextStyles.bodySmall
                      .copyWith(color: TheyDiColors.textSecondary)),
              const SizedBox(height: 16),
              ..._kCircleReportReasons.map((reason) => GestureDetector(
                    onTap: () => setModalState(() => selectedReason = reason),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: selectedReason == reason
                            ? Colors.red.withOpacity(0.1)
                            : TheyDiColors.dark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedReason == reason
                              ? Colors.red.withOpacity(0.5)
                              : TheyDiColors.divider,
                        ),
                      ),
                      child: Row(
                        children: [
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
                          Expanded(
                            child: Text(reason,
                                style: TheyDiTextStyles.bodySmall.copyWith(
                                    color: selectedReason == reason
                                        ? Colors.red
                                        : TheyDiColors.textSecondary)),
                          ),
                        ],
                      ),
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
                            await _submitCircleReport(selectedReason!);
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

  Future<void> _submitCircleReport(String reason) async {
    await FirebaseFirestore.instance.collection('reports').add({
      'reportedCircleId': _circle.id,
      'reportedCircleName': _circle.name,
      'reporterUid': _myUid,
      'reason': reason,
      'type': 'circle',
      'createdAt': Timestamp.now(),
      'status': 'pending',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Report submitted. Thank you for helping keep TieIn safe.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _blockCircle() async {
    final confirmed = await _confirmDialog(
      title: 'Block Circle?',
      body:
          'You will leave "${_circle.name}" and it will be hidden from you. This cannot be undone.',
      confirm: 'Block',
      confirmColor: Colors.red,
    );
    if (!confirmed) return;

    final myName = _circle.memberMap[_myUid] ?? 'User';
    await EventCircleService.removeMemberFromCircle(
        circleId: _circle.id, userUid: _myUid, userName: myName);

    await FirebaseFirestore.instance.collection('users').doc(_myUid).update({
      'blockedCircleIds': FieldValue.arrayUnion([_circle.id]),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${_circle.name}" blocked'),
          backgroundColor: Colors.red,
        ),
      );
      context.pop();
      context.pop();
    }
  }

  void _showAddMembersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: TheyDiColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _AddMembersSheet(
        circle: _circle,
        onMembersAdded: () async => _refresh(),
      ),
    );
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
        content: Text(body,
            style: TheyDiTextStyles.bodyMedium
                .copyWith(color: TheyDiColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TheyDiTextStyles.labelMedium
                    .copyWith(color: TheyDiColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirm,
                style:
                    TheyDiTextStyles.labelMedium.copyWith(color: confirmColor)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── NEW: animated share button ──────────────────────────────────────────────
  Widget _buildShareButton() {
    return GestureDetector(
      onTap: () async {
        setState(() => _shareAnimating = true);
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) setState(() => _shareAnimating = false);
        if (mounted) showCircleShareSheet(context, circle: _circle);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: TheyDiColors.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: TheyDiColors.primary.withOpacity(0.35), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.share_outlined, size: 14, color: TheyDiColors.primary),
            const SizedBox(width: 5),
            Text('Share',
                style: TheyDiTextStyles.caption.copyWith(
                    color: TheyDiColors.primary, fontWeight: FontWeight.w600)),
          ],
        ),
      )
          .animate(target: _shareAnimating ? 1 : 0)
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.12, 1.12),
            duration: 150.ms,
            curve: Curves.easeOut,
          )
          .then()
          .scale(
            begin: const Offset(1.12, 1.12),
            end: const Offset(1, 1),
            duration: 150.ms,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final members = _circle.memberMap;
    final uniqueCount = members.length;
    final initial = _circle.initials;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [TheyDiColors.cardLight, TheyDiColors.surface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── App Bar ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: TheyDiColors.textPrimary),
                      onPressed: () => context.pop(),
                    ),
                    Text('Circle Info', style: TheyDiTextStyles.displayMedium),
                    const Spacer(),

                    // ── NEW: Share button (all members) ──
                    _buildShareButton(),
                    const SizedBox(width: 8),

                    // Edit / Save button (host only)
                    if (_isHost)
                      GestureDetector(
                        onTap: () {
                          if (_editing) {
                            _saveEdits();
                          } else {
                            setState(() => _editing = true);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: TheyDiColors.gradientPrimary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text(_editing ? 'Save' : 'Edit',
                                  style: TheyDiTextStyles.caption.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                        ),
                      ),

                    // Cancel editing button
                    if (_editing)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _editing = false;
                            _nameController.text = _circle.name;
                            _descController.text = _circle.description;
                          });
                        },
                      ),
                  ],
                ),
              ).animate().fade(duration: 300.ms),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ── Group Avatar ──
                    Center(
                      child: GestureDetector(
                        onTap: _isHost ? _pickGroupPhoto : null,
                        child: Stack(
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                gradient: TheyDiColors.gradientPrimary,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                    color: TheyDiColors.primary
                                        .withOpacity(0.4),
                                    width: 2),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(26),
                                child: _circle.profileImageUrl != null &&
                                        _circle.profileImageUrl!.isNotEmpty
                                    ? Image.network(_circle.profileImageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Center(
                                            child: Text(initial,
                                                style: TheyDiTextStyles.displayLarge
                                                    .copyWith(
                                                        fontSize: 40,
                                                        color: Colors.white))))
                                    : Center(
                                        child: Text(initial,
                                            style: TheyDiTextStyles.displayLarge
                                                .copyWith(
                                                    fontSize: 40,
                                                    color: Colors.white))),
                              ),
                            ),
                            if (_isHost)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    gradient: TheyDiColors.gradientPrimary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: const Color(0xFF0D0D14),
                                        width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt,
                                      size: 14, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                        .animate()
                        .scale(duration: 400.ms, curve: Curves.elasticOut),

                    const SizedBox(height: 16),

                    // ── Group Name ──
                    _editing
                        ? TextField(
                            controller: _nameController,
                            style: TheyDiTextStyles.displayMedium
                                .copyWith(fontSize: 20),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: TheyDiColors.card,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: TheyDiColors.divider)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: TheyDiColors.primary)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                          )
                        : Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_circle.name,
                                    style: TheyDiTextStyles.displayMedium),
                                if (_circle.isEventCircle) ...[
                                  const SizedBox(width: 8),
                                  Container(
<<<<<<< HEAD
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.orange.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
=======
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3), 
                                    decoration: BoxDecoration(
                                      color: Colors.orange
                                          .withOpacity(0.15),
                                      borderRadius:
                                          BorderRadius.circular(8),
>>>>>>> d9f7621 (Updated Explore filters and chat attachment UI)
                                    ),
                                    child: Text('Event',
                                        style: TheyDiTextStyles.caption
                                            .copyWith(
                                                color: Colors.orange,
                                                fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ],
                            ),
                          ),

                    const SizedBox(height: 8),

                    // ── Description ──
                    _editing
                        ? TextField(
                            controller: _descController,
                            style: TheyDiTextStyles.bodySmall,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: 'Add a description...',
                              hintStyle: TheyDiTextStyles.bodySmall
                                  .copyWith(color: TheyDiColors.textMuted),
                              filled: true,
                              fillColor: TheyDiColors.card,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: TheyDiColors.divider)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: TheyDiColors.primary)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                          )
                        : Center(
                            child: Text(
                              _circle.description.isNotEmpty
                                  ? _circle.description
                                  : 'No description',
                              style: TheyDiTextStyles.bodySmall
                                  .copyWith(color: TheyDiColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ),

                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                          '$uniqueCount member${uniqueCount == 1 ? '' : 's'}',
                          style: TheyDiTextStyles.caption
                              .copyWith(color: TheyDiColors.textMuted)),
                    ),

                    const SizedBox(height: 28),

                    // ── Members Section ──
                    Row(
                      children: [
                        Text('Members',
                            style: TheyDiTextStyles.labelLarge
                                .copyWith(color: TheyDiColors.textSecondary)),
                        const Spacer(),
                        if (_isHost)
                          GestureDetector(
                            onTap: _showAddMembersSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: TheyDiColors.gradientPrimary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person_add_outlined,
                                      size: 14, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text('Add',
                                      style: TheyDiTextStyles.caption.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    ...members.entries.map((entry) {
                      final uid = entry.key;
                      final name = entry.value;
                      final isCreator = uid == _circle.creatorUid;
                      final isMe = uid == _myUid;

<<<<<<< HEAD
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: TheyDiColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: TheyDiColors.divider),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: TheyDiColors.gradientPrimary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: TheyDiTextStyles.labelLarge
                                      .copyWith(color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Row(
                                children: [
                                  Text(name,
                                      style: TheyDiTextStyles.labelMedium),
                                  if (isMe) ...[
                                    const SizedBox(width: 6),
                                    Text('(You)',
                                        style: TheyDiTextStyles.caption
                                            .copyWith(
                                                color: TheyDiColors.textMuted)),
=======
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          context.push(
                            AppRoutes.userProfile,
                            extra: {'uid': uid, 'requestId': null},
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: TheyDiColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: TheyDiColors.divider),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: TheyDiColors.gradientPrimary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: TheyDiTextStyles.labelLarge
                                        .copyWith(color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(name,
                                        style: TheyDiTextStyles
                                            .labelMedium),
                                    if (isMe) ...[
                                      const SizedBox(width: 6),
                                      Text('(You)',
                                          style: TheyDiTextStyles
                                              .caption
                                              .copyWith(
                                                  color: TheyDiColors
                                                      .textMuted)),
                                    ],
                                    const SizedBox(width: 6),
                                    _OnlineDot(uid: uid),
>>>>>>> d9f7621 (Updated Explore filters and chat attachment UI)
                                  ],
                                ),
                              ),
<<<<<<< HEAD
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isCreator
                                    ? TheyDiColors.primary
                                        .withValues(alpha: 0.15)
                                    : Colors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isCreator ? 'Admin' : 'Member',
                                style: TheyDiTextStyles.caption.copyWith(
=======
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
>>>>>>> d9f7621 (Updated Explore filters and chat attachment UI)
                                  color: isCreator
                                      ? TheyDiColors.primary
                                          .withOpacity(0.15)
                                      : Colors.green
                                          .withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
<<<<<<< HEAD
                              ),
                            ),
                            if (_isHost && !isMe && !isCreator) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _removeMember(uid, name),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.remove_circle_outline,
                                      size: 16, color: Colors.red),
=======
                                child: Text(
                                  isCreator ? 'Admin' : 'Member',
                                  style: TheyDiTextStyles.caption.copyWith(
                                    color: isCreator
                                        ? TheyDiColors.primary
                                        : Colors.green,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
>>>>>>> d9f7621 (Updated Explore filters and chat attachment UI)
                                ),
                              ),
                              if (_isHost && !isMe && !isCreator) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _removeMember(uid, name),
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.red
                                          .withOpacity(0.12),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                        Icons.remove_circle_outline,
                                        size: 16,
                                        color: Colors.red),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 28),

                    // ── Leave / Delete ──
                    if (!_isHost)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _leaveGroup,
                          icon: const Icon(Icons.exit_to_app,
                              color: Colors.orange, size: 18),
                          label: const Text('Leave Circle',
                              style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.orange),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),

                    if (_isHost) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _deleteGroup,
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 18),
                          label: const Text('Delete Circle',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    _CircleActionTile(
                      icon: Icons.cleaning_services_outlined,
                      label: 'Clear Chat',
                      subtitle: 'Remove messages from your view only',
                      color: Colors.orange,
                      onTap: _clearChat,
                    ),
                    const SizedBox(height: 8),

                    _CircleActionTile(
                      icon: Icons.flag_outlined,
                      label: 'Report Circle',
                      subtitle: 'Report inappropriate content or behavior',
                      color: Colors.amber,
                      onTap: _reportCircle,
                    ),
                    const SizedBox(height: 8),

                    _CircleActionTile(
                      icon: Icons.block_outlined,
                      label: 'Block Circle',
                      subtitle: 'Leave and hide this circle permanently',
                      color: Colors.red,
                      onTap: _blockCircle,
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Circle Action Tile ────────────────────────────────────────────────────────
class _CircleActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _CircleActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          TheyDiTextStyles.labelMedium.copyWith(color: color)),
                  Text(subtitle,
                      style: TheyDiTextStyles.caption
                          .copyWith(color: TheyDiColors.textMuted)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14, color: color.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}

// ── Online Dot ────────────────────────────────────────────────────────────────
class _OnlineDot extends StatelessWidget {
  final String uid;
  const _OnlineDot({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final isOnline =
            (snap.data?.data() as Map<String, dynamic>?)?['isOnline'] == true;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOnline ? Colors.greenAccent : Colors.grey[600],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════
// ADD MEMBERS SHEET (unchanged)
// ══════════════════════════════════════
class _AddMembersSheet extends StatefulWidget {
  final CircleModel circle;
  final VoidCallback onMembersAdded;

  const _AddMembersSheet({required this.circle, required this.onMembersAdded});

  @override
  State<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends State<_AddMembersSheet> {
  final _searchController = TextEditingController();
  List<Map<String, String>> _allCandidates = [];
  List<Map<String, String>> _filtered = [];
  final Set<String> _selectedUids = {};
  bool _loading = true;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCandidates() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final currentMemberUids = widget.circle.memberUids.toSet();
    final friendsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('friends')
        .get();

    final candidates = <Map<String, String>>[];
    for (final doc in friendsSnap.docs) {
      if (!currentMemberUids.contains(doc.id)) {
        final data = doc.data();
        candidates.add({
          'uid': doc.id,
          'name': data['displayName'] ?? 'User',
          'username': data['username'] ?? '',
          'city': data['city'] ?? '',
        });
      }
    }

    if (mounted) {
      setState(() {
        _allCandidates = candidates;
        _filtered = candidates;
        _loading = false;
      });
    }
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? _allCandidates
          : _allCandidates.where((c) {
              return (c['name'] ?? '').toLowerCase().contains(q) ||
                  (c['username'] ?? '').toLowerCase().contains(q);
            }).toList();
    });
  }

  Future<void> _addSelected() async {
    if (_selectedUids.isEmpty) return;
    setState(() => _adding = true);

    final myName = FirebaseAuth.instance.currentUser?.displayName ?? 'Someone';

    for (final uid in _selectedUids) {
      final candidate = _allCandidates.firstWhere((c) => c['uid'] == uid,
          orElse: () => {'uid': uid, 'name': 'Member', 'username': ''});

      await EventCircleService.addMemberToCircle(
        circleId: widget.circle.id,
        userUid: uid,
        userName: candidate['name'] ?? 'Member',
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add({
        'title': 'Added to circle 👥',
        'body': '$myName added you to "${widget.circle.name}"',
        'type': 'social',
        'isRead': false,
        'createdAt': Timestamp.now(),
      });
    }

    widget.onMembersAdded();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: TheyDiColors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Text('Add Members', style: TheyDiTextStyles.headlineMedium),
                const Spacer(),
                if (_selectedUids.isNotEmpty)
                  GestureDetector(
                    onTap: _adding ? null : _addSelected,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: TheyDiColors.gradientPrimary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _adding
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text('Add (${_selectedUids.length})',
                              style: TheyDiTextStyles.labelMedium
                                  .copyWith(color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Container(
              decoration: BoxDecoration(
                color: TheyDiColors.dark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TheyDiColors.divider),
              ),
              child: TextField(
                controller: _searchController,
                style: TheyDiTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Search by name or username...',
                  hintStyle: TheyDiTextStyles.bodySmall
                      .copyWith(color: TheyDiColors.textMuted),
                  prefixIcon: Icon(Icons.search,
                      color: TheyDiColors.textMuted, size: 20),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: TheyDiColors.primary))
                : _filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _searchController.text.isEmpty
                                ? 'No friends available to add'
                                : 'No users found',
                            style: TheyDiTextStyles.bodySmall
                                .copyWith(color: TheyDiColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: _filtered.map((candidate) {
                          final isSelected =
                              _selectedUids.contains(candidate['uid']);
                          final name = candidate['name'] ?? 'User';
                          final username = candidate['username'] ?? '';
                          final city = candidate['city'] ?? '';

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedUids.remove(candidate['uid']);
                                } else {
                                  _selectedUids.add(candidate['uid']!);
                                }
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? TheyDiColors.primary
                                        .withOpacity(0.12)
                                    : TheyDiColors.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? TheyDiColors.primary
                                      : TheyDiColors.divider,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: TheyDiColors.gradientPrimary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : '?',
                                        style: TheyDiTextStyles.labelLarge
                                            .copyWith(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(name,
                                            style:
                                                TheyDiTextStyles.labelMedium),
                                        if (city.isNotEmpty ||
                                            username.isNotEmpty)
                                          Text(
                                              city.isNotEmpty ? city : username,
                                              style: TheyDiTextStyles.caption),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: TheyDiColors.primary),
                                      child: const Icon(Icons.check,
                                          size: 14, color: Colors.white),
                                    )
                                  else
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: TheyDiColors.divider)),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
