import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/cloudflare_upload.dart';
import '../../../shared/screens/image_cropper_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _ageController = TextEditingController();

  String _selectedCity = 'Chennai';
  String _selectedGender = '';
  final Set<String> _selectedInterests = {};

  String _existingPhotoUrl = '';
  XFile? _pickedImageFile;
  Uint8List? _pickedImageBytes;
  bool _isLoading = true;
  bool _isSaving = false;

  static const List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  static const List<String> _cities = [
    'Mumbai',
    'Delhi',
    'Bangalore',
    'Hyderabad',
    'Chennai',
    'Kolkata',
    'Pune',
    'Ahmedabad',
    'Jaipur',
    'Lucknow',
    'Surat',
    'Kochi',
    'Chandigarh',
    'Indore',
    'Coimbatore',
    'Goa',
    'Vizag',
    'Nagpur',
    'Bhopal',
    'Thiruvananthapuram',
  ];

  static const List<Map<String, String>> _interestOptions = [
    {'label': 'Music', 'emoji': '🎵'},
    {'label': 'Tech', 'emoji': '💻'},
    {'label': 'Sports', 'emoji': '⚽'},
    {'label': 'Art', 'emoji': '🎨'},
    {'label': 'Food', 'emoji': '🍕'},
    {'label': 'Travel', 'emoji': '✈️'},
    {'label': 'Gaming', 'emoji': '🎮'},
    {'label': 'Fitness', 'emoji': '💪'},
    {'label': 'Movies', 'emoji': '🎬'},
    {'label': 'Books', 'emoji': '📚'},
    {'label': 'Photography', 'emoji': '📷'},
    {'label': 'Dance', 'emoji': '💃'},
    {'label': 'Startups', 'emoji': '🚀'},
    {'label': 'Comedy', 'emoji': '😂'},
    {'label': 'Networking', 'emoji': '🤝'},
    {'label': 'Wellness', 'emoji': '🧘'},
  ];

  // ── Light theme constants ──────────────────────────────────────────────────
  static const Color _fillColor = Color(0xFFF3F4F6); // TieInColors.inputFill
  static const Color _borderColor = Color(0xFFE5E7EB); // TieInColors.divider
  static const Color _textColor = Color(0xFF000000);
  static const Color _hintColor = Color(0xFF9CA3AF);
  static const Color _labelColor = Color(0xFF4B5563);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        _displayNameController.text = data['displayName'] ?? '';
        _bioController.text = data['bio'] ?? '';

        final age = data['age'];
        if (age != null) _ageController.text = age.toString();

        final gender = data['gender'] as String? ?? '';
        if (_genderOptions.contains(gender)) _selectedGender = gender;

        final city = data['city'] as String? ?? '';
        if (city.isNotEmpty && _cities.contains(city)) _selectedCity = city;

        _existingPhotoUrl = (data['profileImageUrl'] as String?) ??
            (data['photoUrl'] as String?) ??
            '';

        final interests = List<String>.from(data['interests'] ?? []);
        _selectedInterests.addAll(interests);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load profile: $e'),
              backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      final initialBytes = await picked.readAsBytes();
      if (!mounted) return;
      final croppedBytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (context) => ImageCropperScreen(
            imageBytes: initialBytes,
            aspectRatio: 1.0,
            title: 'Crop Profile Photo',
          ),
        ),
      );

      if (croppedBytes != null && mounted) {
        setState(() {
          _pickedImageFile = picked;
          _pickedImageBytes = croppedBytes;
        });
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: _borderColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined,
                color: TheyDiColors.primary),
            title:
                Text('Choose from Gallery', style: TheyDiTextStyles.bodyMedium),
            onTap: () {
              Navigator.pop(ctx);
              _pickImage();
            },
          ),
          if (_existingPhotoUrl.isNotEmpty || _pickedImageFile != null)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text('Remove Photo',
                  style:
                      TheyDiTextStyles.bodyMedium.copyWith(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _pickedImageFile = null;
                  _pickedImageBytes = null;
                  _existingPhotoUrl = '';
                });
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<String?> _uploadImage(Uint8List bytes) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final imageUrl = await CloudflareUpload.uploadBytes(
        bytes,
        '$uid.jpg',
      );

      return imageUrl;
    } catch (e) {
      print('Profile image upload error: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      String photoUrl = _existingPhotoUrl;
      if (_pickedImageBytes != null) {
        final uploaded = await _uploadImage(_pickedImageBytes!);
        if (uploaded != null) photoUrl = uploaded;
      }

      final ageText = _ageController.text.trim();
      final age = ageText.isNotEmpty ? int.tryParse(ageText) : null;

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'displayName': _displayNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'city': _selectedCity,
        'interests': _selectedInterests.toList(),
        'photoUrl': photoUrl,
        'profileImageUrl': photoUrl,
        'gender': _selectedGender,
        if (age != null) 'age': age,
      });

      await FirebaseAuth.instance.currentUser!
          .updateDisplayName(_displayNameController.text.trim());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Profile updated! ✅'), backgroundColor: Colors.green),
      );
      context.pop();
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to save: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildAvatar(String initial) {
    ImageProvider? imageProvider;
    if (_pickedImageBytes != null) {
      imageProvider = MemoryImage(_pickedImageBytes!);
    } else if (_existingPhotoUrl.isNotEmpty) {
      imageProvider = NetworkImage(_existingPhotoUrl);
    }

    return GestureDetector(
      onTap: _showImageSourceSheet,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            gradient:
                imageProvider == null ? TheyDiColors.gradientPrimary : null,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
                color: TheyDiColors.primary.withValues(alpha: 0.4), width: 2),
            image: imageProvider != null
                ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                : null,
          ),
          child: imageProvider == null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Center(
                    child: Text(initial,
                        style: TheyDiTextStyles.displayLarge
                            .copyWith(fontSize: 40, color: Colors.white)),
                  ),
                )
              : null,
        ),
        Positioned(
          bottom: -2,
          right: -2,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: TheyDiColors.gradientPrimary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
          ),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = _displayNameController.text.isNotEmpty
        ? _displayNameController.text[0].toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text('Edit Profile',
            style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: TheyDiColors.primary))
          : Form(
              key: _formKey,
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                children: [
                  // ── Profile Photo ──
                  Center(child: _buildAvatar(initial)),
                  const SizedBox(height: 6),
                  Center(
                    child: Text('Upload a valid user image',
                        style: TheyDiTextStyles.caption
                            .copyWith(color: TheyDiColors.textMuted),
                        textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 24),

                  // ── Display Name ──
                  _buildLabel('Display Name'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _displayNameController,
                    style: const TextStyle(color: _textColor, fontSize: 14),
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Name is required'
                        : null,
                    onChanged: (_) => setState(() {}),
                    decoration: _inputDecoration('What should we call you?'),
                  ),
                  const SizedBox(height: 20),

                  // ── Bio ──
                  _buildLabel('Bio'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _bioController,
                    style: const TextStyle(color: _textColor, fontSize: 14),
                    maxLines: 3,
                    maxLength: 150,
                    decoration: _inputDecoration('A short intro about yourself')
                        .copyWith(
                      counterStyle:
                          const TextStyle(color: _hintColor, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Age & Gender ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Age'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _ageController,
                              style: const TextStyle(
                                  color: _textColor, fontSize: 14),
                              keyboardType: TextInputType.number,
                              validator: (val) {
                                if (val != null && val.isNotEmpty) {
                                  final n = int.tryParse(val);
                                  if (n == null || n < 13 || n > 100) {
                                    return 'Enter valid age';
                                  }
                                }
                                return null;
                              },
                              decoration: _inputDecoration('e.g. 23'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Gender'),
                            const SizedBox(height: 6),
                            // ── FIXED: light dropdown ──
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: _fillColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _borderColor),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedGender.isEmpty
                                      ? null
                                      : _selectedGender,
                                  hint: const Text('Select',
                                      style: TextStyle(
                                          color: _hintColor, fontSize: 14)),
                                  isExpanded: true,
                                  dropdownColor: Colors.white,
                                  style: const TextStyle(
                                      color: _textColor, fontSize: 14),
                                  icon: const Icon(Icons.keyboard_arrow_down,
                                      color: _hintColor),
                                  items: _genderOptions
                                      .map((g) => DropdownMenuItem(
                                          value: g,
                                          child: Text(g,
                                              style: const TextStyle(
                                                  color: _textColor))))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedGender = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── City ──
                  _buildLabel('City'),
                  const SizedBox(height: 6),
                  // ── FIXED: light dropdown ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _fillColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCity,
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        style: const TextStyle(color: _textColor, fontSize: 14),
                        icon: const Icon(Icons.keyboard_arrow_down,
                            color: _hintColor),
                        items: _cities
                            .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c,
                                    style: const TextStyle(color: _textColor))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCity = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Interests ──
                  _buildLabel('Interests'),
                  const SizedBox(height: 4),
                  const Text('Tap to select or deselect',
                      style: TextStyle(color: _hintColor, fontSize: 12)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _interestOptions.map((interest) {
                      final label = interest['label']!;
                      final emoji = interest['emoji']!;
                      final isSelected = _selectedInterests.contains(label);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedInterests.remove(label);
                            } else {
                              _selectedInterests.add(label);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            // ── FIXED: light unselected, emerald selected ──
                            color: isSelected
                                ? TheyDiColors.primary.withValues(alpha: 0.12)
                                : _fillColor,
                            border: Border.all(
                              color: isSelected
                                  ? TheyDiColors.primary
                                  : _borderColor,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            '$emoji $label',
                            style: TextStyle(
                              color: isSelected
                                  ? TheyDiColors.primary
                                  : _labelColor,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),

                  // ── Save Button ──
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            TheyDiColors.primary,
                            TheyDiColors.secondary,
                          ],
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text('Save Changes',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: const TextStyle(
            color: _labelColor, fontSize: 14, fontWeight: FontWeight.w600));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _hintColor, fontSize: 14),
      filled: true,
      fillColor: _fillColor, // ← light grey fill
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TheyDiColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
