import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../models/circle_model.dart';

class CreateCircleScreen extends StatefulWidget {
  const CreateCircleScreen({super.key});

  @override
  State<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends State<CreateCircleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _usernameController = TextEditingController();

  final List<Map<String, String>> _invitedMembers = [];
  List<Map<String, String>> _friends = [];
  bool _isCreating = false;
  bool _loadingFriends = true;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  // ── Load friends from Firestore ──
  Future<void> _loadFriends() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('friends')
          .get();

      final friends = snap.docs.map<Map<String, String>>((d) {
        final data = d.data();
        return {
          'uid': d.id,
          'name': (data['displayName'] as String?) ?? 'User',
          'username': '',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _friends = friends;
          _loadingFriends = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFriends = false);
    }
  }

  // ── Toggle friend selection ──
  void _toggleFriend(Map<String, String> friend) {
    final alreadyAdded =
        _invitedMembers.any((m) => m['uid'] == friend['uid']);
    setState(() {
      if (alreadyAdded) {
        _invitedMembers.removeWhere((m) => m['uid'] == friend['uid']);
      } else {
        _invitedMembers.add(friend);
      }
    });
  }

  // ── Search by username (fallback) ──
  Future<void> _searchAndAddByUsername() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty || username.contains(' ')) {
      setState(() => _searchError = 'Enter a valid username');
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser!;
    final currentUserName = currentUser.displayName ?? currentUser.email!.split('@').first;
    if (username == currentUserName) {
      setState(() => _searchError = 'You\'ll be added automatically');
      return;
    }

    if (_invitedMembers.any((m) => m['username'] == username)) {
      setState(() => _searchError = 'Already added');
      return;
    }

    setState(() => _searchError = null);

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() => _searchError = 'No user found with this username');
        return;
      }

      final userData = query.docs.first.data();
      final uid = query.docs.first.id;
      final name = userData['displayName'] ?? username;

      if (_invitedMembers.any((m) => m['uid'] == uid)) {
        setState(() => _searchError = 'Already added');
        return;
      }

      setState(() {
        _invitedMembers.add({'uid': uid, 'name': name, 'username': username});
        _usernameController.clear();
        _searchError = null;
      });
    } catch (e) {
      setState(() => _searchError = 'Search failed: $e');
    }
  }

  Future<void> _createCircle() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isCreating = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;

      String creatorName =
          user.displayName ?? user.email!.split('@').first;
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          creatorName = userDoc.data()?['displayName'] ?? creatorName;
        }
      } catch (_) {}

      final memberUids = [
        user.uid,
        ..._invitedMembers.map((m) => m['uid']!),
      ];
      final memberNames = [
        creatorName,
        ..._invitedMembers.map((m) => m['name']!),
      ];

      final circleRef = await FirebaseFirestore.instance
          .collection('circles')
          .add({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'creatorUid': user.uid,
        'creatorName': creatorName,
        'memberUids': memberUids,
        'memberNames': memberNames,
        'lastMessage': null,
        'lastMessageSender': null,
        'lastMessageAt': null,
        'createdAt': Timestamp.now(),
        'type': 'custom',
        'eventId': null,
      });

      // Notify invited members
      for (final member in _invitedMembers) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(member['uid'])
            .collection('notifications')
            .add({
          'title': 'Added to a circle 👥',
          'body':
              '$creatorName added you to "${_nameController.text.trim()}"',
          'type': 'social',
          'isRead': false,
          'createdAt': Timestamp.now(),
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Circle created! 🎉'),
            backgroundColor: Colors.green),
      );

      // Navigate to the new circle's chat
      final circleDoc = await circleRef.get();
      final circle = CircleModel.fromFirestore(circleDoc);
      if (mounted) {
        context.pop();
        context.push(AppRoutes.circleChat, extra: circle);
      }
    } catch (e) {
      setState(() => _isCreating = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to create: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
              // ── App Bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: TheyDiColors.textPrimary),
                      onPressed: _isCreating ? null : () => context.pop(),
                    ),
                    const SizedBox(width: 4),
                    Text('Create Circle',
                        style: TheyDiTextStyles.displayMedium),
                  ],
                ),
              ).animate().fade(duration: 300.ms),

              const SizedBox(height: 16),

              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      // ── Circle Name ──
                      Text('Circle name',
                              style: TheyDiTextStyles.labelMedium)
                          .animate(delay: 100.ms)
                          .fade(duration: 300.ms),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        style: TheyDiTextStyles.bodyMedium,
                        validator: (val) =>
                            (val == null || val.trim().isEmpty)
                                ? 'Name is required'
                                : null,
                        decoration:
                            _inputDecoration('e.g. Weekend Explorers'),
                      ).animate(delay: 120.ms).fade(duration: 300.ms),

                      const SizedBox(height: 20),

                      // ── Description ──
                      Text('Description (optional)',
                              style: TheyDiTextStyles.labelMedium)
                          .animate(delay: 150.ms)
                          .fade(duration: 300.ms),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descriptionController,
                        style: TheyDiTextStyles.bodyMedium,
                        maxLines: 2,
                        maxLength: 100,
                        decoration:
                            _inputDecoration('What\'s this circle about?')
                                .copyWith(
                          counterStyle:
                              TextStyle(color: TheyDiColors.textMuted),
                        ),
                      ).animate(delay: 170.ms).fade(duration: 300.ms),

                      const SizedBox(height: 24),

                      // ── Add from Friends ──
                      Row(
                        children: [
                          Text('Add from Friends',
                              style: TheyDiTextStyles.labelMedium),
                          const Spacer(),
                          if (_invitedMembers.isNotEmpty)
                            Text(
                              '${_invitedMembers.length} selected',
                              style: TheyDiTextStyles.caption.copyWith(
                                  color: TheyDiColors.primary),
                            ),
                        ],
                      ).animate(delay: 200.ms).fade(duration: 300.ms),
                      const SizedBox(height: 4),
                      Text(
                        'Select friends to add to this circle',
                        style: TheyDiTextStyles.caption
                            .copyWith(color: TheyDiColors.textMuted),
                      ).animate(delay: 210.ms).fade(duration: 300.ms),
                      const SizedBox(height: 12),

                      // ── Friends List ──
                      _loadingFriends
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                    color: TheyDiColors.primary),
                              ),
                            )
                          : _friends.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: TheyDiColors.card,
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: TheyDiColors.divider),
                                  ),
                                  child: Text(
                                    'No friends yet. Connect with people at events!',
                                    style: TheyDiTextStyles.caption.copyWith(
                                        color: TheyDiColors.textSecondary),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : Column(
                                  children: _friends.map((friend) {
                                    final isSelected = _invitedMembers
                                        .any((m) => m['uid'] == friend['uid']);
                                    final initial = friend['name']!.isNotEmpty
                                        ? friend['name']![0].toUpperCase()
                                        : '?';
                                    return GestureDetector(
                                      onTap: () => _toggleFriend(friend),
                                      child: Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? TheyDiColors.primary
                                                  .withValues(alpha: 0.12)
                                              : TheyDiColors.card,
                                          borderRadius:
                                              BorderRadius.circular(12),
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
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                gradient: TheyDiColors
                                                    .gradientPrimary,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Center(
                                                child: Text(initial,
                                                    style: TheyDiTextStyles
                                                        .labelLarge
                                                        .copyWith(
                                                            color:
                                                                Colors.white)),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(friend['name']!,
                                                  style: TheyDiTextStyles
                                                      .labelMedium),
                                            ),
                                            if (isSelected)
                                              Container(
                                                width: 24,
                                                height: 24,
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: TheyDiColors.primary,
                                                ),
                                                child: const Icon(Icons.check,
                                                    size: 14,
                                                    color: Colors.white),
                                              )
                                            else
                                              Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                      color: TheyDiColors
                                                          .divider),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),

                      const SizedBox(height: 20),

                            // ── Search by username (fallback) ──
                            Text('Or add by username',
                              style: TheyDiTextStyles.labelMedium)
                          .animate(delay: 230.ms)
                          .fade(duration: 300.ms),
                      const SizedBox(height: 4),
                      Text(
                        'For users not in your friends list',
                        style: TheyDiTextStyles.caption
                            .copyWith(color: TheyDiColors.textMuted),
                      ).animate(delay: 240.ms).fade(duration: 300.ms),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _usernameController,
                              style: TheyDiTextStyles.bodyMedium,
                              keyboardType: TextInputType.text,
                              decoration:
                                  _inputDecoration('friend_username'),
                              onSubmitted: (_) => _searchAndAddByUsername(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _searchAndAddByUsername,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: TheyDiColors.gradientPrimary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.search,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ).animate(delay: 250.ms).fade(duration: 300.ms),

                      if (_searchError != null) ...[
                        const SizedBox(height: 6),
                        Text(_searchError!,
                            style: TheyDiTextStyles.caption
                                .copyWith(color: TheyDiColors.error)),
                      ],

                      const SizedBox(height: 32),

                      // ── Create Button ──
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: _isCreating
                                ? Colors.grey[800]
                                : TheyDiColors.primary,
                          ),
                          child: ElevatedButton(
                            onPressed: _isCreating ? null : _createCircle,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isCreating
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Text('Create Circle',
                                    style: TheyDiTextStyles.labelLarge
                                        .copyWith(
                                            color: Colors.white, fontSize: 16)),
                          ),
                        ),
                      ).animate(delay: 300.ms).fade(duration: 300.ms),

                      const SizedBox(height: 40),
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          TheyDiTextStyles.bodySmall.copyWith(color: TheyDiColors.textMuted),
      filled: true,
      fillColor: TheyDiColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: TheyDiColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TheyDiColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
