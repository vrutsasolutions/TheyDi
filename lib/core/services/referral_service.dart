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

// ── Referral history entry ────────────────────────────────────────────────
class ReferralEntry {
  final String referredUid;
  final String inviteeName;
  final String inviteePhoto;
  final String status;       // "attributed" | "eligible"
  final String gender;
  final DateTime? attributedAt;
  final DateTime? eligibleAt;
  final double? firstBookingAmount;
  final double? calculatedReward;
  final String? milestoneKey;
  final String rewardStatus; // "pending" | "rewarded" | "not_in_milestone"

  const ReferralEntry({
    required this.referredUid,
    required this.inviteeName,
    required this.inviteePhoto,
    required this.status,
    required this.gender,
    required this.rewardStatus,
    this.attributedAt,
    this.eligibleAt,
    this.firstBookingAmount,
    this.calculatedReward,
    this.milestoneKey,
  });

  bool get isEligible => status == 'eligible';
  bool get isWomen => gender == 'female';
  bool get isRewarded => rewardStatus == 'rewarded';

  factory ReferralEntry.fromMap(Map<Object?, Object?> m) => ReferralEntry(
        referredUid: m['referredUid'] as String? ?? '',
        inviteeName: m['inviteeName'] as String? ?? 'Member',
        inviteePhoto: m['inviteePhoto'] as String? ?? '',
        status: m['status'] as String? ?? 'attributed',
        gender: m['gender'] as String? ?? 'unknown',
        rewardStatus: m['rewardStatus'] as String? ?? 'pending',
        attributedAt: m['attributedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['attributedAt'] as int)
            : null,
        eligibleAt: m['eligibleAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['eligibleAt'] as int)
            : null,
        firstBookingAmount:
            (m['firstBookingAmount'] as num?)?.toDouble(),
        calculatedReward:
            (m['calculatedReward'] as num?)?.toDouble(),
        milestoneKey: m['milestoneKey'] as String?,
      );
}

// ── Credit transaction ────────────────────────────────────────────────────
class CreditTransaction {
  final String txId;
  final String type;   // "referral_reward" | "credit_used"
  final double amount; // positive = earned, negative = spent
  final String? milestoneKey;
  final String? bookingId;
  final DateTime createdAt;

  const CreditTransaction({
    required this.txId,
    required this.type,
    required this.amount,
    required this.createdAt,
    this.milestoneKey,
    this.bookingId,
  });

  factory CreditTransaction.fromMap(Map<Object?, Object?> m) =>
      CreditTransaction(
        txId: m['txId'] as String? ?? '',
        type: m['type'] as String? ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
        milestoneKey: m['milestoneKey'] as String?,
        bookingId: m['bookingId'] as String?,
        createdAt: m['createdAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int)
            : DateTime.now(),
      );
}

// ── Referral stats ────────────────────────────────────────────────────────
class ReferralStats {
  final int totalEligible;
  final int womenEligible;
  final double creditBalance;
  final double totalCreditEarned;
  final List<String> rewardedMilestones;
  final String referralCode;
  final List<ReferralEntry> history;
  final List<CreditTransaction> creditHistory;
  // Progress within current batch
  final int normalProgress;
  final int womenProgress;
  final int normalRemainingToNext;
  final int womenRemainingToNext;
  // Config
  final int normalMilestoneSize;
  final double normalMaxReward;
  final int womenMilestoneSize;
  final double womenMaxReward;

  const ReferralStats({
    required this.totalEligible,
    required this.womenEligible,
    required this.creditBalance,
    required this.totalCreditEarned,
    required this.rewardedMilestones,
    required this.referralCode,
    required this.history,
    required this.creditHistory,
    required this.normalProgress,
    required this.womenProgress,
    required this.normalRemainingToNext,
    required this.womenRemainingToNext,
    required this.normalMilestoneSize,
    required this.normalMaxReward,
    required this.womenMilestoneSize,
    required this.womenMaxReward,
  });

  factory ReferralStats.fromMap(Map<Object?, Object?> m) {
    final historyRaw = m['history'] as List<Object?>? ?? [];
    final creditRaw = m['creditHistory'] as List<Object?>? ?? [];
    final normalSize = (m['normalMilestoneSize'] as num?)?.toInt() ?? 5;
    final womenSize = (m['womenMilestoneSize'] as num?)?.toInt() ?? 5;
    final totalEligible = (m['totalEligible'] as num?)?.toInt() ?? 0;
    final womenEligible = (m['womenEligible'] as num?)?.toInt() ?? 0;
    final normalProgress = (m['normalProgress'] as num?)?.toInt() ??
        (totalEligible % normalSize);
    final womenProgress = (m['womenProgress'] as num?)?.toInt() ??
        (womenEligible % womenSize);

    return ReferralStats(
      totalEligible: totalEligible,
      womenEligible: womenEligible,
      creditBalance: (m['creditBalance'] as num?)?.toDouble() ?? 0.0,
      totalCreditEarned:
          (m['totalCreditEarned'] as num?)?.toDouble() ?? 0.0,
      rewardedMilestones:
          (m['rewardedMilestones'] as List<Object?>? ?? [])
              .map((e) => e.toString())
              .toList(),
      referralCode: m['referralCode'] as String? ?? '',
      history: historyRaw
          .whereType<Map<Object?, Object?>>()
          .map(ReferralEntry.fromMap)
          .toList(),
      creditHistory: creditRaw
          .whereType<Map<Object?, Object?>>()
          .map(CreditTransaction.fromMap)
          .toList(),
      normalProgress: normalProgress,
      womenProgress: womenProgress,
      normalRemainingToNext:
          (m['normalRemainingToNext'] as num?)?.toInt() ??
              (normalSize - normalProgress),
      womenRemainingToNext:
          (m['womenRemainingToNext'] as num?)?.toInt() ??
              (womenSize - womenProgress),
      normalMilestoneSize: normalSize,
      normalMaxReward:
          (m['normalMaxReward'] as num?)?.toDouble() ?? 5.0,
      womenMilestoneSize: womenSize,
      womenMaxReward:
          (m['womenMaxReward'] as num?)?.toDouble() ?? 10.0,
    );
  }

  static ReferralStats empty() => const ReferralStats(
        totalEligible: 0,
        womenEligible: 0,
        creditBalance: 0,
        totalCreditEarned: 0,
        rewardedMilestones: [],
        referralCode: '',
        history: [],
        creditHistory: [],
        normalProgress: 0,
        womenProgress: 0,
        normalRemainingToNext: 5,
        womenRemainingToNext: 5,
        normalMilestoneSize: 5,
        normalMaxReward: 5.0,
        womenMilestoneSize: 5,
        womenMaxReward: 10.0,
      );
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

    FirebaseFunctions get _functions =>
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

  /// Fetch this user's referral stats + history + credit balance.
  Future<ReferralStats> getReferralStats() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return ReferralStats.empty();
    try {
      final callable = _functions.httpsCallable('getReferralStats');
      final result = await callable.call();
      return ReferralStats.fromMap(result.data as Map<Object?, Object?>);
    } catch (e) {
      debugPrint('[Referral] getReferralStats error: $e');
      return ReferralStats.empty();
    }
  }

  /// Fetch payment quote including credit balance info.
  Future<Map<String, dynamic>?> getPaymentQuoteWithCredit(
      String eventId) async {
    try {
      final callable =
          _functions.httpsCallable('getPaymentQuoteWithCredit');
      final result = await callable.call({'eventId': eventId});
      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      debugPrint('[Referral] getPaymentQuoteWithCredit error: $e');
      return null;
    }
  }

  /// Create a Razorpay order, optionally deducting Event Credit first.
  /// Returns the raw data map from the Cloud Function.
  Future<Map<String, dynamic>> createOrderWithCredit({
    required String eventId,
    required bool applyCredit,
  }) async {
    final callable = _functions.httpsCallable('createOrderWithCredit');
    final result = await callable.call({
      'eventId': eventId,
      'applyCredit': applyCredit,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }
}