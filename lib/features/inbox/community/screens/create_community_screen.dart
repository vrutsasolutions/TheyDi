import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_error_utils.dart';
import '../../../../core/services/notification_service.dart';

/// Creates a new Community. Anyone can create one (unlike Circles, which
/// are locked to the creator of the experience they're attached to) — so
/// there's no experience/host context needed here, just the community's
/// own details.
class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  static const _categories = [
    'Tech',
    'Design',
    'Business',
    'AI',
    'Startups',
    'Music',
    'Food',
    'Fitness',
    'Gaming',
    'Art',
  ];
  String? _selectedCategory;
  bool _requiresApproval = false;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a category for your community')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isCreating = true);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final creatorName =
          (userDoc.data()?['displayName'] as String?) ?? 'Member';

      final communityRef =
          await FirebaseFirestore.instance.collection('communities').add({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'creatorUid': user.uid,
        'creatorName': creatorName,
        // Creator auto-joins their own community.
        'memberUids': [user.uid],
        'memberNames': [creatorName],
        'createdAt': Timestamp.now(),
        'coverImageUrl': null,
        'requiresApproval': _requiresApproval,
      });

      // Notify everyone else that a new community exists. MVP scope per
      // current requirements — everyone gets notified, not just
      // interest-matched users. See notifyNewCommunityCreated's doc
      // comment for how to narrow this later.
      try {
        final usersSnap =
            await FirebaseFirestore.instance.collection('users').get();
        final notifyUids = usersSnap.docs
            .map((d) => d.id)
            .where((uid) => uid != user.uid)
            .toList();
        await NotificationService.notifyNewCommunityCreated(
          notifyUids: notifyUids,
          communityId: communityRef.id,
          communityName: _nameController.text.trim(),
          category: _selectedCategory!,
          creatorName: creatorName,
        );
      } catch (_) {
        // Don't block community creation on notification fan-out failing.
      }

      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      AppErrorUtils.showErrorSnackBar(context, e);
      return;
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: TheyDiColors.textPrimary),
                      onPressed:
                          _isCreating ? null : () => context.pop(),
                    ),
                    const SizedBox(width: 4),
                    Text('New Community',
                        style: TheyDiTextStyles.displayMedium),
                  ],
                ),
              ).animate().fade(duration: 300.ms),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      Text('Anyone can create a community',
                          style: TheyDiTextStyles.bodySmall
                              .copyWith(color: TheyDiColors.textSecondary)),
                      const SizedBox(height: 20),
                      _label('Community Name *'),
                      TextFormField(
                        controller: _nameController,
                        style: TheyDiTextStyles.bodyMedium,
                        decoration: const InputDecoration(
                            hintText: 'e.g. Chennai Tech Circle'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      _label('Description'),
                      TextFormField(
                        controller: _descriptionController,
                        style: TheyDiTextStyles.bodyMedium,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            hintText:
                                'What is this community about, and who should join?'),
                      ),
                      const SizedBox(height: 18),
                      _label('Category *'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categories.map((cat) {
                          final isSelected = cat == _selectedCategory;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedCategory = cat),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? TheyDiColors.gradientPrimary
                                    : null,
                                color: isSelected ? null : TheyDiColors.card,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.transparent
                                      : TheyDiColors.divider,
                                ),
                              ),
                              child: Text(cat,
                                  style: TheyDiTextStyles.labelMedium.copyWith(
                                      color: isSelected
                                          ? Colors.white
                                          : TheyDiColors.textSecondary)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              TheyDiColors.card,
                              TheyDiColors.primary.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color:
                                  TheyDiColors.primary.withValues(alpha: 0.15)),
                          boxShadow: [
                            BoxShadow(
                              color: TheyDiColors.primary.withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text('Require approval to join',
                                      style: TheyDiTextStyles.labelMedium),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Off: anyone can join instantly. On: you approve each request.',
                                    style: TheyDiTextStyles.caption.copyWith(
                                        color: TheyDiColors.textSecondary,
                                        height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _requiresApproval,
                              onChanged: (v) =>
                                  setState(() => _requiresApproval = v),
                              activeColor: TheyDiColors.primary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: TheyDiColors.gradientPrimary,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    TheyDiColors.primary.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isCreating ? null : _create,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _isCreating
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.4),
                                  )
                                : Text('Create Community',
                                    style: TheyDiTextStyles.labelLarge
                                        .copyWith(color: Colors.white)),
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

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: TheyDiTextStyles.labelLarge.copyWith(
                color: TheyDiColors.textSecondary,
                fontWeight: FontWeight.w600)),
      );
}