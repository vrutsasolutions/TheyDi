import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/services/cloudflare_upload.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/signup_progress_bar.dart';
import '../models/signup_data.dart';
import '../../../core/utils/picker_theme_helper.dart';

const _kInterests = [
  'Music',
  'Tech',
  'Sports',
  'Art',
  'Food',
  'Travel',
  'Gaming',
  'Fitness',
  'Movies',
  'Books',
  'Photography',
  'Dance',
  'Startups',
  'Comedy',
  'Networking',
  'Wellness',
];

const _kGenderOptions = [
  {'label': 'Male', 'icon': Icons.male},
  {'label': 'Female', 'icon': Icons.female},
  {'label': 'Other', 'icon': Icons.transgender},
  {'label': 'Prefer not to say', 'icon': Icons.person_outline},
];

// ── Username validation states ──
enum _UsernameState { idle, checking, available, taken, invalid }

// ── Username regex: letters, numbers, underscore, dot — 3–30 chars ──
// Allows uppercase input (we lowercase before saving + Firestore check)
final _kUsernameRegex = RegExp(r'^[a-zA-Z0-9_.]{3,30}$');

class SignupStep3Screen extends StatefulWidget {
  final SignupData signupData;
  const SignupStep3Screen({super.key, required this.signupData});

  @override
  State<SignupStep3Screen> createState() => _SignupStep3ScreenState();
}

class _SignupStep3ScreenState extends State<SignupStep3Screen> {
  final _formKey = GlobalKey<FormState>();

  // ── Single combined field ──
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;

  final Set<String> _selectedInterests = {};
  DateTime? _dateOfBirth;
  String _selectedGender = '';

  // ── Username availability state ──
  _UsernameState _usernameState = _UsernameState.idle;
  String _usernameFeedback = '';
  Timer? _debounce;

  // ── Profile image state ──
  Uint8List? _imageBytes;
  String? _uploadedImageUrl;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill from existing data — prefer username, fall back to displayName
    final prefill = widget.signupData.username.isNotEmpty
        ? widget.signupData.username
        : widget.signupData.displayName;
    _usernameController = TextEditingController(text: prefill);
    _bioController = TextEditingController(text: widget.signupData.bio);
    _selectedInterests.addAll(widget.signupData.interests);
    _dateOfBirth = widget.signupData.dateOfBirth;
    _selectedGender = widget.signupData.gender;

    // Run check on pre-filled value if present
    if (prefill.isNotEmpty) _onUsernameChanged(prefill);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Profile image picker ───────────────────────────────────────────────────
  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: TheyDiColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: TheyDiColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text('Profile Photo', style: TheyDiTextStyles.headlineMedium),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                      color: TheyDiColors.inputFill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: TheyDiColors.divider)),
                  child: Column(children: [
                    const Icon(Icons.camera_alt_outlined,
                        color: TheyDiColors.primary, size: 28),
                    const SizedBox(height: 8),
                    Text('Camera', style: TheyDiTextStyles.labelMedium),
                  ]),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                      color: TheyDiColors.inputFill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: TheyDiColors.divider)),
                  child: Column(children: [
                    const Icon(Icons.photo_library_outlined,
                        color: TheyDiColors.primary, size: 28),
                    const SizedBox(height: 8),
                    Text('Gallery', style: TheyDiTextStyles.labelMedium),
                  ]),
                ),
              )),
            ]),
            if (_uploadedImageUrl != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _imageBytes = null;
                      _uploadedImageUrl = null;
                    });
                  },
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 18),
                  label: Text('Remove Photo',
                      style: TheyDiTextStyles.labelMedium
                          .copyWith(color: Colors.red)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      // Validate size (5MB max)
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        _showSnack('Image too large. Max 5MB.', Colors.red);
        return;
      }

      setState(() {
        _imageBytes = bytes;
        _isUploadingImage = true;
      });

      // Upload to Firebase Storage
      final url = await CloudflareUpload.uploadBytes(
        bytes,
        'signup_temp_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (url == null) {
        throw Exception('Cloudflare upload failed');
      }

      if (mounted) {
        setState(() {
          _uploadedImageUrl = url;
          _isUploadingImage = false;
          // Pre-fill signupData so it persists if user navigates back
          widget.signupData.profileImageUrl = url;
        });
        _showSnack('✅ Profile photo added', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        _showSnack('Upload failed, try again', Colors.red);
      }
    }
  }

  // ── DOB picker (FIXED) ────────────────────────────────────────────────────
  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
      helpText: 'Select your date of birth',
      builder: PickerTheme.wrap, // ← replaces ColorScheme.dark
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  int? get _calculatedAge {
    if (_dateOfBirth == null) return null;
    final now = DateTime.now();
    int years = now.year - _dateOfBirth!.year;
    if (now.month < _dateOfBirth!.month ||
        (now.month == _dateOfBirth!.month && now.day < _dateOfBirth!.day)) {
      years--;
    }
    return years;
  }

  // ── Derive display name from username ──────────────────────────────────────
  // e.g. "sheerap_23" → "Sheerap 23"  |  "john.doe" → "John Doe"
  String _toDisplayName(String username) {
    return username
        .replaceAll(RegExp(r'[_.]'), ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  // ── Live username validation ──────────────────────────────────────────────
  void _onUsernameChanged(String raw) {
    final stored = raw.toLowerCase().trim(); // what goes to Firestore
    _debounce?.cancel();

    if (raw.trim().isEmpty) {
      setState(() {
        _usernameState = _UsernameState.idle;
        _usernameFeedback = '';
      });
      return;
    }

    // Client-side format check
    if (!_kUsernameRegex.hasMatch(raw.trim())) {
      setState(() {
        _usernameState = _UsernameState.invalid;
        _usernameFeedback = 'Only letters, numbers, _ and . (3–30 chars)';
      });
      return;
    }

    setState(() {
      _usernameState = _UsernameState.checking;
      _usernameFeedback = 'Checking availability...';
    });

    // Debounce Firestore check
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('usernames')
            .doc(stored)
            .get();
        if (!mounted) return;
        if (doc.exists) {
          final suggestions = _buildSuggestions(stored);
          setState(() {
            _usernameState = _UsernameState.taken;
            _usernameFeedback =
                'Username taken. Try: ${suggestions.join(', ')}';
          });
        } else {
          setState(() {
            _usernameState = _UsernameState.available;
            _usernameFeedback = '@$stored is available!';
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _usernameState = _UsernameState.available;
            _usernameFeedback = '';
          });
        }
      }
    });
  }

  List<String> _buildSuggestions(String base) {
    final rnd = DateTime.now().millisecond % 900 + 100;
    return ['${base}_$rnd', '$base.official'];
  }

  // ── Continue ───────────────────────────────────────────────────────────────
  void _continue() {
    if (!_formKey.currentState!.validate()) return;

    final raw = _usernameController.text.trim();
    final stored = raw.toLowerCase();

    if (raw.isEmpty) {
      _showSnack('Username is required', Colors.red);
      return;
    }
    if (!_kUsernameRegex.hasMatch(raw)) {
      _showSnack('Only letters, numbers, _ and . (3–30 chars)', Colors.red);
      return;
    }
    if (_usernameState == _UsernameState.taken) {
      _showSnack('Username is taken. Please choose another.', Colors.red);
      return;
    }
    if (_usernameState == _UsernameState.checking) {
      _showSnack('Still checking username… please wait.', Colors.orange);
      return;
    }

    // Save both username (lowercase) and derived display name
    widget.signupData.username = stored;
    widget.signupData.displayName = _toDisplayName(raw);
    widget.signupData.bio = _bioController.text.trim();
    widget.signupData.interests = _selectedInterests.toList();
    widget.signupData.dateOfBirth = _dateOfBirth;
    widget.signupData.gender = _selectedGender;
    if (_uploadedImageUrl != null) {
      widget.signupData.profileImageUrl = _uploadedImageUrl!;
    }

    context.push(AppRoutes.signupStep4, extra: widget.signupData);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Availability feedback widget ───────────────────────────────────────────
  Widget _buildUsernameFeedback() {
    if (_usernameState == _UsernameState.idle) return const SizedBox.shrink();

    if (_usernameState == _UsernameState.checking) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: TheyDiColors.primary),
          ),
          const SizedBox(width: 8),
          Text('Checking availability…',
              style: TheyDiTextStyles.caption
                  .copyWith(color: TheyDiColors.textMuted)),
        ]),
      );
    }

    Color color;
    IconData icon;
    switch (_usernameState) {
      case _UsernameState.available:
        color = Colors.green;
        icon = Icons.check_circle_outline;
      case _UsernameState.taken:
        color = Colors.red;
        icon = Icons.cancel_outlined;
      case _UsernameState.invalid:
        color = Colors.orange;
        icon = Icons.warning_amber_rounded;
      default:
        return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(_usernameFeedback,
              style: TheyDiTextStyles.caption.copyWith(color: color)),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewName = _usernameController.text.trim().isNotEmpty
        ? _toDisplayName(_usernameController.text.trim())
        : '?';
    final previewInitial = previewName.isNotEmpty ? previewName[0] : '?';

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
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      color: TheyDiColors.textPrimary,
                      onPressed: () => context.pop(),
                    ),
                    const Expanded(
                      child: SignupProgressBar(step: 3, totalSteps: 5),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('About you', style: TheyDiTextStyles.displayMedium)
                            .animate()
                            .fade(duration: 400.ms),
                        const SizedBox(height: 6),
                        Text('Step 3 of 5 — Create your @handle',
                                style: TheyDiTextStyles.bodySmall)
                            .animate(delay: 80.ms)
                            .fade(duration: 300.ms),

                        const SizedBox(height: 28),

                        // ── Profile Image Uploader ────────────────────────
                        Center(
                          child: Column(children: [
                            GestureDetector(
                              onTap: _isUploadingImage
                                  ? null
                                  : _showImageSourceSheet,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: _imageBytes == null
                                      ? TheyDiColors.gradientPrimary
                                      : null,
                                  color: _imageBytes != null
                                      ? Colors.transparent
                                      : null,
                                  border: Border.all(
                                    color: _uploadedImageUrl != null
                                        ? TheyDiColors.primary
                                        : TheyDiColors.primary
                                            .withValues(alpha: 0.4),
                                    width: _uploadedImageUrl != null ? 3 : 2,
                                  ),
                                  // Glow when image is set
                                  boxShadow: _uploadedImageUrl != null
                                      ? [
                                          BoxShadow(
                                            color: TheyDiColors.primary
                                                .withValues(alpha: 0.35),
                                            blurRadius: 16,
                                            spreadRadius: 2,
                                          )
                                        ]
                                      : null,
                                ),
                                child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // ── Image or placeholder ──
                                      ClipOval(
                                        child: _isUploadingImage
                                            ? Container(
                                                width: 110,
                                                height: 110,
                                                color: TheyDiColors.card,
                                                child: const Center(
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      CircularProgressIndicator(
                                                          color: TheyDiColors
                                                              .primary,
                                                          strokeWidth: 2.5),
                                                      SizedBox(height: 8),
                                                      Text('Uploading…',
                                                          style: TextStyle(
                                                              color: TheyDiColors
                                                                  .textMuted,
                                                              fontSize: 10)),
                                                    ],
                                                  ),
                                                ),
                                              )
                                            : _imageBytes != null
                                                ? Image.memory(_imageBytes!,
                                                    width: 110,
                                                    height: 110,
                                                    fit: BoxFit.cover)
                                                : Container(
                                                    width: 110,
                                                    height: 110,
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      previewInitial
                                                          .toUpperCase(),
                                                      style: TheyDiTextStyles
                                                          .displayLarge
                                                          .copyWith(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 40),
                                                    ),
                                                  ),
                                      ),

                                      // ── Camera badge (bottom-right) ──
                                      if (!_isUploadingImage)
                                        Positioned(
                                          bottom: 2,
                                          right: 2,
                                          child: Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              gradient:
                                                  TheyDiColors.gradientPrimary,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFF0D0D14),
                                                  width: 2),
                                            ),
                                            child: Icon(
                                              _imageBytes != null
                                                  ? Icons.edit_outlined
                                                  : Icons.camera_alt_outlined,
                                              size: 15,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ]),
                              ),
                            ),
                            const SizedBox(height: 10),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                _usernameController.text.trim().isNotEmpty
                                    ? previewName
                                    : 'Your Name',
                                key: ValueKey(previewName),
                                style: TheyDiTextStyles.labelLarge.copyWith(
                                    color: TheyDiColors.textSecondary),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _imageBytes != null
                                  ? 'Tap to change photo'
                                  : 'Add Photo (Optional)',
                              style: TheyDiTextStyles.caption.copyWith(
                                  color: _imageBytes != null
                                      ? TheyDiColors.primary
                                      : TheyDiColors.textMuted),
                            ),
                          ]),
                        ).animate(delay: 100.ms).fade(duration: 400.ms),

                        const SizedBox(height: 28),

                        // ── USERNAME (single field) ─────────────────────────
                        Row(children: [
                          Text('Username (@handle)',
                              style: TheyDiTextStyles.labelMedium),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  TheyDiColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Instagram style',
                                style: TheyDiTextStyles.caption.copyWith(
                                    color: TheyDiColors.primary, fontSize: 10)),
                          ),
                        ]).animate(delay: 140.ms).fade(duration: 300.ms),

                        const SizedBox(height: 4),
                        Text(
                          'Letters, numbers, _ and . only. This becomes your @handle and display name.',
                          style: TheyDiTextStyles.caption
                              .copyWith(color: TheyDiColors.textMuted),
                        ).animate(delay: 150.ms).fade(duration: 300.ms),

                        const SizedBox(height: 8),

                        TextFormField(
                          controller: _usernameController,
                          style: TheyDiTextStyles.bodyMedium,
                          onChanged: (v) {
                            _onUsernameChanged(v);
                            setState(() {}); // rebuild avatar preview
                          },
                          decoration: InputDecoration(
                            hintText: 'e.g. sheerap_23',
                            prefixIcon: const Icon(Icons.alternate_email),
                            suffixIcon:
                                _usernameState == _UsernameState.available
                                    ? const Icon(Icons.check_circle,
                                        color: Colors.green, size: 20)
                                    : _usernameState == _UsernameState.taken
                                        ? const Icon(Icons.cancel,
                                            color: Colors.red, size: 20)
                                        : null,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Username is required';
                            }
                            if (!_kUsernameRegex.hasMatch(v.trim())) {
                              return 'Only letters, numbers, _ and . (3–30 chars)';
                            }
                            return null;
                          },
                        ).animate(delay: 160.ms).fade(duration: 300.ms),

                        // Availability feedback
                        _buildUsernameFeedback(),

                        // Display name preview pill
                        if (_usernameController.text.trim().isNotEmpty &&
                            _usernameState == _UsernameState.available) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.25)),
                            ),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.badge_outlined,
                                  size: 13, color: Colors.green),
                              const SizedBox(width: 6),
                              Text(
                                'Display name will be "$previewName"',
                                style: TheyDiTextStyles.caption.copyWith(
                                    color: Colors.green, fontSize: 11),
                              ),
                            ]),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // ── Bio ────────────────────────────────────────────
                        Text('Bio (optional)',
                                style: TheyDiTextStyles.labelMedium)
                            .animate(delay: 200.ms)
                            .fade(duration: 300.ms),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _bioController,
                          maxLines: 3,
                          maxLength: 150,
                          style: TheyDiTextStyles.bodyMedium,
                          decoration: const InputDecoration(
                            hintText: 'A short intro about yourself...',
                            alignLabelWithHint: true,
                            counterStyle: TextStyle(
                                color: TheyDiColors.textMuted, fontSize: 11),
                          ),
                        ).animate(delay: 215.ms).fade(duration: 300.ms),

                        const SizedBox(height: 20),

                        // ── Date of Birth ──────────────────────────────────
                        Text('Date of Birth',
                                style: TheyDiTextStyles.labelMedium)
                            .animate(delay: 230.ms)
                            .fade(duration: 300.ms),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickDateOfBirth,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: TheyDiColors.inputFill,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: TheyDiColors.divider),
                            ),
                            child: Row(children: [
                              Icon(Icons.cake_outlined,
                                  size: 18,
                                  color: _dateOfBirth != null
                                      ? TheyDiColors.primary
                                      : TheyDiColors.textMuted),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _dateOfBirth != null
                                      ? '${DateFormat('d MMM yyyy').format(_dateOfBirth!)} ($_calculatedAge years old)'
                                      : 'Select your date of birth',
                                  style: TheyDiTextStyles.bodySmall.copyWith(
                                    color: _dateOfBirth != null
                                        ? TheyDiColors.textPrimary
                                        : TheyDiColors.textMuted,
                                  ),
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down,
                                  size: 18, color: TheyDiColors.textMuted),
                            ]),
                          ),
                        ).animate(delay: 245.ms).fade(duration: 300.ms),

                        const SizedBox(height: 20),

                        // ── Gender ─────────────────────────────────────────
                        Text('Gender', style: TheyDiTextStyles.labelMedium)
                            .animate(delay: 260.ms)
                            .fade(duration: 300.ms),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              _kGenderOptions.asMap().entries.map((entry) {
                            final i = entry.key;
                            final option = entry.value;
                            final label = option['label'] as String;
                            final icon = option['icon'] as IconData;
                            final isSelected = _selectedGender == label;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedGender = label),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? TheyDiColors.gradientPrimary
                                      : null,
                                  color: isSelected ? null : TheyDiColors.card,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.transparent
                                        : TheyDiColors.divider,
                                  ),
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(icon,
                                          size: 16,
                                          color: isSelected
                                              ? Colors.white
                                              : TheyDiColors.textSecondary),
                                      const SizedBox(width: 6),
                                      Text(label,
                                          style: TheyDiTextStyles.labelMedium
                                              .copyWith(
                                            color: isSelected
                                                ? Colors.white
                                                : TheyDiColors.textSecondary,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                          )),
                                    ]),
                              ),
                            )
                                .animate(
                                    delay: Duration(milliseconds: 270 + 40 * i))
                                .fade(duration: 250.ms);
                          }).toList(),
                        ),

                        const SizedBox(height: 24),

                        // ── Interests ──────────────────────────────────────
                        Text('Your Interests',
                                style: TheyDiTextStyles.labelMedium)
                            .animate(delay: 310.ms)
                            .fade(duration: 300.ms),
                        const SizedBox(height: 4),
                        Text('Pick what excites you',
                                style: TheyDiTextStyles.caption)
                            .animate(delay: 320.ms)
                            .fade(duration: 300.ms),
                        const SizedBox(height: 12),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _kInterests.asMap().entries.map((entry) {
                            final i = entry.key;
                            final interest = entry.value;
                            final selected =
                                _selectedInterests.contains(interest);
                            return GestureDetector(
                              onTap: () => setState(() {
                                if (selected) {
                                  _selectedInterests.remove(interest);
                                } else {
                                  _selectedInterests.add(interest);
                                }
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: selected
                                      ? TheyDiColors.gradientPrimary
                                      : null,
                                  color: selected ? null : TheyDiColors.card,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: selected
                                        ? Colors.transparent
                                        : TheyDiColors.divider,
                                  ),
                                ),
                                child: Text(interest,
                                    style:
                                        TheyDiTextStyles.labelMedium.copyWith(
                                      color: selected
                                          ? Colors.white
                                          : TheyDiColors.textSecondary,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    )),
                              ),
                            )
                                .animate(
                                    delay: Duration(milliseconds: 340 + 30 * i))
                                .fade(duration: 250.ms)
                                .scale(
                                    begin: const Offset(0.85, 0.85),
                                    end: const Offset(1, 1));
                          }).toList(),
                        ),

                        const SizedBox(height: 36),

                        GradientButton(
                          label: 'Continue →',
                          onPressed: _continue,
                        ).animate(delay: 500.ms).fade(duration: 300.ms),
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
