import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'cloudflare_upload.dart';
import 'notification_service.dart';
import '../../features/auth/screens/face_verification_screen.dart';

class FaceVerificationService {
  FaceVerificationService._();

  static final _firestore = FirebaseFirestore.instance;
  static const String _adminUid = 'pMgZijNBerTdhH1ZdVWfsfY6Jbw2';

  // ── Upload photo to Cloudflare ────────────────────────────────────────────
  static Future<String?> uploadPhoto({
    required String userId,
    required Uint8List bytes,
    required String suffix, // '' for selfie, '_id' for ID doc
  }) async {
    try {
      final fileName = 'face_selfies/$userId$suffix.jpg';
      return await CloudflareUpload.uploadBytes(bytes, fileName);
    } catch (e) {
      debugPrint('[FaceVerificationService] uploadPhoto error: $e');
      return null;
    }
  }

  // ── Submit for manual review ──────────────────────────────────────────────
  static Future<bool> submitVerificationRequest({
    required String userId,
    required String userName,
    required String selfieUrl,
    required String secondSelfieUrl,
  }) async {
    try {
      await _firestore.collection('verificationRequests').doc(userId).set({
        'userId': userId,
        'userName': userName,
        'selfieUrl': selfieUrl,
        'liveSelfieUrl': selfieUrl,
        'secondSelfieUrl': secondSelfieUrl,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,
        'reviewedBy': null,
        'rejectionReason': null,
      }).timeout(const Duration(seconds: 10));

      await _firestore.collection('users').doc(userId).update({
        'faceVerified': false,
        'isVerified': false,
        'verificationStatus': 'pending',
        'selfieUrl': selfieUrl,
        'secondSelfieUrl': secondSelfieUrl,
        'verificationRequestedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 10));

      await NotificationService.send(
        toUid: userId,
        title: '🔍 Verification Under Review',
        body:
            'We\'ve received your documents. Our team will review and notify you shortly.',
        type: 'verification',
      ).timeout(const Duration(seconds: 10));

      await NotificationService.send(
        toUid: _adminUid,
        title: '📋 New Verification Request',
        body: '$userName has submitted documents for verification.',
        type: 'admin_verification',
        fromUid: userId,
      ).timeout(const Duration(seconds: 10));

      return true;
    } catch (e) {
      debugPrint('[FaceVerificationService] submitVerificationRequest FAILED: $e');
      return false;
    }
  }

  // ── Approve verification (admin) ──────────────────────────────────────────
  static Future<bool> approveVerification({
    required String userId,
    required String userName,
  }) async {
    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid;

      await _firestore.collection('verificationRequests').doc(userId).update({
        'status': 'verified',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': adminUid,
      });

      await _firestore.collection('users').doc(userId).update({
        'faceVerified': true,
        'isVerified': true,
        'verificationStatus': 'verified',
        'trustScore': 90,
        'faceVerifiedAt': FieldValue.serverTimestamp(),
        'verificationReviewedAt': FieldValue.serverTimestamp(),
      });

      await NotificationService.send(
        toUid: userId,
        title: '✅ Verification Approved!',
        body: 'Congratulations $userName! Your profile is now verified.',
        type: 'verification',
      );

      return true;
    } catch (e) {
      debugPrint('[FaceVerificationService] approveVerification error: $e');
      return false;
    }
  }

  // ── Reject verification (admin) ───────────────────────────────────────────
  static Future<bool> rejectVerification({
    required String userId,
    required String userName,
    required String reason,
  }) async {
    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid;

      await _firestore.collection('verificationRequests').doc(userId).update({
        'status': 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': adminUid,
        'rejectionReason': reason,
      });

      await _firestore.collection('users').doc(userId).update({
        'faceVerified': false,
        'isVerified': false,
        'verificationStatus': 'rejected',
        'rejectionReason': reason,
        'verificationReviewedAt': FieldValue.serverTimestamp(),
      });

      await NotificationService.send(
        toUid: userId,
        title: '❌ Verification Rejected',
        body: 'Reason: $reason. Please resubmit with clear photos.',
        type: 'verification',
      );

      return true;
    } catch (e) {
      debugPrint('[FaceVerificationService] rejectVerification error: $e');
      return false;
    }
  }

  // ── Check if user is verified ─────────────────────────────────────────────
  static Future<bool> isUserVerified(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return (doc.data()?['faceVerified'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── Check current user verified ───────────────────────────────────────────
  static Future<bool> isCurrentUserVerified() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    return isUserVerified(uid);
  }

  // ── Remove verification ───────────────────────────────────────────────────
  static Future<bool> removeVerification(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'faceVerified': false,
        'isVerified': false,
        'verificationStatus': 'none',
        'trustScore': 50,
        'selfieUrl': '',
        'secondSelfieUrl': '',
        'faceVerifiedAt': null,
      });

      await _firestore.collection('verificationRequests').doc(userId).delete();

      await CloudflareUpload.deleteFile('face_selfies/$userId.jpg');
      await CloudflareUpload.deleteFile('face_selfies/${userId}_2.jpg');

      return true;
    } catch (e) {
      debugPrint('[FaceVerificationService] removeVerification error: $e');
      return false;
    }
  }

  // ── Payment gate ──────────────────────────────────────────────────────────
  static Future<bool> checkVerifiedBeforePayment(BuildContext context) async {
    final verified = await isCurrentUserVerified();
    if (verified) return true;

    if (!context.mounted) return false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _VerificationRequiredSheet(),
    );

    if (result == true && context.mounted) {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => FaceVerificationScreen(
            userId: uid,
            onComplete: () {},
          ),
        ),
      );
    }
    return false;
  }

  static void dispose() {}
}

// ── Verification Required Bottom Sheet ───────────────────────────────────────
class _VerificationRequiredSheet extends StatelessWidget {
  const _VerificationRequiredSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_outlined,
                color: Color(0xFF10B981), size: 36),
          ),
          const SizedBox(height: 16),
          const Text('Verification Required',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827))),
          const SizedBox(height: 8),
          const Text(
            'To make payments on TheyDi, your account needs to be verified.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF34D399)],
                ),
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Verify Now',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
          ),
        ],
      ),
    );
  }
}