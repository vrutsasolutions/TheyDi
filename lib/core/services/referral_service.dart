import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../router/app_routes.dart';
import '../router/root_navigator.dart';

class ReferralCodeValidation {
  final bool valid;
  final String? referrerUid;
  final String? referrerName;
  final String? error;

  const ReferralCodeValidation({
    required this.valid,
    this.referrerUid,
    this.referrerName,
    this.error,
  });

  factory ReferralCodeValidation.fromMap(Map<Object?, Object?> data) {
    return ReferralCodeValidation(
      valid: data['valid'] == true,
      referrerUid: data['referrerUid'] as String?,
      referrerName: data['referrerName'] as String?,
      error: data['error'] as String?,
    );
  }
}

class ReferralService {
  ReferralService._();

  static final ReferralService instance = ReferralService._();

  static const String inviteBaseUrl = 'https://theydi-cefdf.web.app/invite';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.theydi.app';
  static const String appStoreUrl = 'https://apps.apple.com/app/idXXXXXXXXX';

  static const _pendingReferralKey = 'pending_referral_code';
  static const _allowedHosts = {'theydi.app', 'theydi-cefdf.web.app'};
  static const _codePattern = r'^[A-Z0-9]{6,12}$';

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-south1');
  StreamSubscription<Uri>? _linkSub;
  bool _initialized = false;

  String inviteLink(String referralCode) => '$inviteBaseUrl/$referralCode';

  Future<void> initializeDeepLinks() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    final appLinks = AppLinks();
    try {
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) await handleUri(initialUri, navigate: true);
    } catch (e) {
      debugPrint('[Referral] Initial deep link failed: $e');
    }

    _linkSub = appLinks.uriLinkStream.listen(
      (uri) => handleUri(uri, navigate: true),
      onError: (Object error) => debugPrint('[Referral] Link stream error: $error'),
    );
  }

  Future<void> disposeDeepLinks() async {
    await _linkSub?.cancel();
    _linkSub = null;
    _initialized = false;
  }

  Future<bool> handleUri(Uri uri, {bool navigate = false}) async {
    final code = extractReferralCode(uri);
    if (code == null) return false;

    await savePendingReferralCode(code);
    if (navigate) {
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        GoRouter.of(context).go('${AppRoutes.invite}/$code');
      }
    }
    return true;
  }

  String? extractReferralCode(Uri uri) {
    if (!_allowedHosts.contains(uri.host.toLowerCase())) return null;
    if (uri.pathSegments.length != 2 || uri.pathSegments.first != 'invite') {
      return null;
    }
    final code = normalizeReferralCode(uri.pathSegments[1]);
    return isReferralCodeFormatValid(code) ? code : null;
  }

  String normalizeReferralCode(String code) => code.trim().toUpperCase();

  bool isReferralCodeFormatValid(String code) {
    return RegExp(_codePattern).hasMatch(code);
  }

  Future<void> savePendingReferralCode(String code) async {
    final normalized = normalizeReferralCode(code);
    if (!isReferralCodeFormatValid(normalized)) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingReferralKey, normalized);
  }

  Future<String?> getPendingReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_pendingReferralKey);
    if (code == null) return null;
    final normalized = normalizeReferralCode(code);
    return isReferralCodeFormatValid(normalized) ? normalized : null;
  }

  Future<void> clearPendingReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingReferralKey);
  }

  Future<String> ensureReferralCode() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('User must be signed in');

    final callable = _functions.httpsCallable('ensureReferralCode');
    final result = await callable.call();
    return (result.data as Map<Object?, Object?>)['referralCode'] as String;
  }

  Future<ReferralCodeValidation> validateReferralCode(String code) async {
    final normalized = normalizeReferralCode(code);
    if (!isReferralCodeFormatValid(normalized)) {
      return const ReferralCodeValidation(
        valid: false,
        error: 'This invite link is invalid.',
      );
    }

    final callable = _functions.httpsCallable('validateReferralCode');
    final result = await callable.call({'referralCode': normalized});
    return ReferralCodeValidation.fromMap(result.data as Map<Object?, Object?>);
  }

  Future<void> applyPendingReferral() async {
    final code = await getPendingReferralCode();
    if (code == null) return;

    final callable = _functions.httpsCallable('attributeReferral');
    final result = await callable.call({'referralCode': code});
    final data = result.data as Map<Object?, Object?>;
    if (data['success'] == true ||
        data['alreadyAttributed'] == true ||
        data['notNewSignup'] == true) {
      await clearPendingReferralCode();
    }
  }

  Future<void> copyInviteLink(BuildContext context, String referralCode) async {
    await Clipboard.setData(ClipboardData(text: inviteLink(referralCode)));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite link copied')),
    );
  }

  Future<void> shareInvite(String referralCode) async {
    final message = Uri.encodeComponent(
      'Join me on TheyDi: ${inviteLink(referralCode)}',
    );
    final uri = Uri.parse('https://wa.me/?text=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> openStore() async {
    final url = defaultTargetPlatform == TargetPlatform.iOS
        ? appStoreUrl
        : playStoreUrl;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
