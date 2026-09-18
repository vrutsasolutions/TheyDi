import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/event_constants.dart';
import '../../../../core/utils/app_error_utils.dart';

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
  String _vibe = 'Social'; // Social | Professional
  String _city = '';
  final Set<String> _selectedInterests = {};
  bool _requiresApproval = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _prefillCity();
  }

  Future<void> _prefillCity() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final city = (doc.data()?['city'] as String?) ?? '';
    if (mounted && city.isNotEmpty) setState(() => _city = city);
  }

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
        SnackBar(
          content: const Text('Please select a category'),
          backgroundColor: TheyDiColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
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

      await FirebaseFirestore.instance.collection('communities').add({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'vibe': _vibe,
        'city': _city.trim(),
        'interests': _selectedInterests.toList(),
        'creatorUid': user.uid,
        'creatorName': creatorName,
        'memberUids': [user.uid],
        'memberNames': [creatorName],
        'createdAt': Timestamp.now(),
        'coverImageUrl': null,
        'requiresApproval': _requiresApproval,
      });

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
                      // ── Category: Social / Professional ──
                      _label('Category *'),
                      const SizedBox(height: 8),
                      Row(
                        children: ['Social', 'Professional'].map((v) {
                          final isSel = _vibe == v;
                          final isLast = v == 'Professional';
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: isLast ? 0 : 10),
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _vibe = v;
                                  _selectedInterests.clear();
                                  _selectedCategory = null;
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  height: 46,
                                  decoration: BoxDecoration(
                                    gradient: isSel ? TheyDiColors.gradientPrimary : null,
                                    color: isSel ? null : TheyDiColors.card,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: isSel ? Colors.transparent : TheyDiColors.divider),
                                  ),
                                  child: Center(
                                    child: Text(v,
                                        style: TheyDiTextStyles.labelMedium.copyWith(
                                            color: isSel ? Colors.white : TheyDiColors.textSecondary,
                                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w400)),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),

                      // ── City / Location ──
                      _label('City / Location'),
                      TextFormField(
                        initialValue: _city,
                        style: TheyDiTextStyles.bodyMedium,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Mumbai, Chennai',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        onChanged: (v) => setState(() => _city = v),
                      ),
                      const SizedBox(height: 18),

                      // ── Interests ──
                      _label('Interests (select multiple)'),
                      const SizedBox(height: 8),
                      Builder(builder: (context) {
                        final interests = _vibe == 'Social'
                            ? EventConstants.socialCategories
                            : EventConstants.professionalCategories;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: interests.map((interest) {
                            final isSel = _selectedInterests.contains(interest);
                            return GestureDetector(
                              onTap: () => setState(() {
                                if (isSel) {
                                  _selectedInterests.remove(interest);
                                } else {
                                  _selectedInterests.add(interest);
                                  // Auto-set category from first interest
                                  _selectedCategory ??= interest;
                                }
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  gradient: isSel ? TheyDiColors.gradientPrimary : null,
                                  color: isSel ? null : TheyDiColors.card,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: isSel
                                          ? Colors.transparent
                                          : TheyDiColors.divider),
                                ),
                                child: Text(interest,
                                    style: TheyDiTextStyles.labelMedium.copyWith(
                                        color: isSel
                                            ? Colors.white
                                            : TheyDiColors.textSecondary)),
                              ),
                            );
                          }).toList(),
                        );
                      }),
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