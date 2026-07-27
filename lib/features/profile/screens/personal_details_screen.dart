import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/constants/bank_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_error_utils.dart';
// import 'package:flutter_windowmanager/flutter_windowmanager.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _legalNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _confirmAccountNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  final _bankNameController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  // bool _confirmed = false;
  String? _autoFilledBankName;




  @override
void initState() {
  super.initState();

  // FlutterWindowManager.addFlags(
  //   FlutterWindowManager.FLAG_SECURE,
  // );

  _loadProfile();
}

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      _legalNameController.text =
          (data['name'] as String?)?.trim().isNotEmpty == true
              ? data['name'] as String
              : (data['displayName'] as String?) ?? user?.displayName ?? '';
      _emailController.text = (data['email'] as String?) ?? user?.email ?? '';
      _mobileController.text = (data['mobile'] as String?) ??
          (data['phone'] as String?) ??
          (data['phoneNumber'] as String?) ??
          user?.phoneNumber ??
          '';
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load profile: $e'),
          backgroundColor: TheyDiColors.error,
        ),
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
  //    FlutterWindowManager.clearFlags(
  //   FlutterWindowManager.FLAG_SECURE,
  // );
    _legalNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _accountHolderController.dispose();
    _accountNumberController.dispose();
    _confirmAccountNumberController.dispose();
    _ifscController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  void _onIfscChanged(String value) {
    final normalized = value.toUpperCase();
    if (_ifscController.text != normalized) {
      _ifscController.value = _ifscController.value.copyWith(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }

    final prefix = normalized.length >= 4 ? normalized.substring(0, 4) : '';
    final bankName = BankConstants.bankNamesByIfscPrefix[prefix];
    if (bankName == null) return;

    final currentBankName = _bankNameController.text.trim();
    if (currentBankName.isEmpty || currentBankName == _autoFilledBankName) {
      _bankNameController.text = bankName;
      _autoFilledBankName = bankName;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _legalNameController.text.trim(),
        'email': _emailController.text.trim(),
        'mobile': _mobileController.text.trim(),
      }, SetOptions(merge: true));

      // Save temporary bank details
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('tempBankDetails')
          .set({
        'accountHolderName': _accountHolderController.text.trim(),
        'accountNumber': _accountNumberController.text.trim(),
        'ifscCode': _ifscController.text.trim().toUpperCase(),
        'bankName': _bankNameController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Trigger Cloud Function
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('setupHostCashfreeBeneficiary');
      await callable.call({
        'payoutMethod': 'bank',
        'name': _accountHolderController.text.trim(),
        'ifsc': _ifscController.text.trim().toUpperCase(),
        'accountNumber': _accountNumberController.text.trim(),
        'email': _emailController.text.trim(),
        'mobile': _mobileController.text.trim(),
        'legalName': _legalNameController.text.trim(),
      });

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppErrorUtils.showErrorSnackBar(context, e);
    }
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? _validateEmail(String? value) {
    final required = _required(value);
    if (required != null) return required;
    final email = value!.trim();
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    return valid ? null : 'Enter a valid email';
  }

  String? _validateMobile(String? value) {
    final required = _required(value);
    if (required != null) return required;
    final digits = value!.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 && digits.length <= 15
        ? null
        : 'Enter a valid mobile number';
  }

  String? _validateIfsc(String? value) {
    final required = _required(value);
    if (required != null) return required;
    final valid =
        RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(value!.trim().toUpperCase());
    return valid ? null : 'Enter a valid IFSC code';
  }

  String? _validateConfirmAccountNumber(String? value) {
    final required = _required(value);
    if (required != null) return required;
    if (value!.trim() != _accountNumberController.text.trim()) {
      return 'Account numbers do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personal Details')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: TheyDiColors.primary),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                children: [
                  Text('Complete Payout Setup',
                      style: TheyDiTextStyles.displaySmall),
                  const SizedBox(height: 28),
                  _buildSectionTitle('Personal Details'),
                  const SizedBox(height: 16),
                  _buildField(
                    label: 'Full Legal Name *',
                    controller: _legalNameController,
                    textInputAction: TextInputAction.next,
                    validator: _required,
                  ),
                  _buildField(
                    label: 'Email *',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: _validateEmail,
                  ),
                  _buildField(
                    label: 'Mobile Number *',
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: _validateMobile,
                  ),
                  const SizedBox(height: 12),
                  _buildSectionTitle('Bank Details'),
                  const SizedBox(height: 16),
                  _buildField(
                    label: 'Account Holder Name *',
                    controller: _accountHolderController,
                    textInputAction: TextInputAction.next,
                    validator: _required,
                  ),
                  _buildField(
                    label: 'Bank Account Number *',
                    controller: _accountNumberController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: _required,
                  ),
                  _buildField(
                    label: 'Confirm Account Number *',
                    controller: _confirmAccountNumberController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: _validateConfirmAccountNumber,
                  ),
                  _buildField(
                    label: 'IFSC Code *',
                    controller: _ifscController,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    onChanged: _onIfscChanged,
                    validator: _validateIfsc,
                  ),
                  _buildField(
                    label:
                        'Bank Name (auto-filled if possible, otherwise editable)',
                    controller: _bankNameController,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 8),
                  // CheckboxListTile(
                  //   value: _confirmed,
                  //   onChanged: _isSaving
                  //       ? null
                  //       : (value) =>
                  //           setState(() => _confirmed = value ?? false),
                  //   controlAffinity: ListTileControlAffinity.leading,
                  //   contentPadding: EdgeInsets.zero,
                  //   activeColor: TheyDiColors.primary,
                  //   title: Text(
                  //     'I confirm this bank account belongs to me. Accepting terms & policy.',
                  //     style: TheyDiTextStyles.bodySmall.copyWith(
                  //       color: TheyDiColors.textSecondary,
                  //     ),
                  //   ),
                  // ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
  borderRadius: BorderRadius.circular(16),
  gradient: TheyDiColors.gradientPrimary,
),
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Save & Continue',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(text, style: TheyDiTextStyles.headlineSmall);
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TheyDiTextStyles.labelLarge.copyWith(
              color: TheyDiColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
            validator: validator,
            onChanged: onChanged,
            style: TheyDiTextStyles.bodyMedium,
            decoration: const InputDecoration(),
          ),
        ],
      ),
    );
  }
}
