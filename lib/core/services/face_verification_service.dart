import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../router/app_routes.dart';
import 'cloudflare_upload.dart';
import 'notification_service.dart';
import 'package:go_router/go_router.dart';

class FaceVerificationService {
  FaceVerificationService._();

  static final _firestore = FirebaseFirestore.instance;

  // ── Admin UID ─────────────────────────────────────────
  static const String _adminUid = 'pMgZijNBerTdhH1ZdVWfsfY6Jbw2';

  static final _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableLandmarks: true,
      enableContours: false,
      enableTracking: false,
      enableClassification: true,
      minFaceSize: 0.15,
    ),
  );

  // ── Extract face measurements ─────────────────────────
  static Future<Map<String, double>?> extractFaceMeasurements(
    File imageFile,
  ) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final faces = await _detector.processImage(inputImage);
      if (faces.isEmpty) return null;

      final face = faces.first;
      final box = face.boundingBox;

      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];
      final nose = face.landmarks[FaceLandmarkType.noseBase];
      final mouthL = face.landmarks[FaceLandmarkType.leftMouth];
      final mouthR = face.landmarks[FaceLandmarkType.rightMouth];

      if (leftEye == null || rightEye == null || nose == null) return null;

      final faceW = box.width;
      final faceH = box.height;

      final eyeDistance = _distance(
            leftEye.position.x,
            leftEye.position.y,
            rightEye.position.x,
            rightEye.position.y,
          ) /
          faceW;

      final noseToEyeL = _distance(
            nose.position.x,
            nose.position.y,
            leftEye.position.x,
            leftEye.position.y,
          ) /
          faceH;

      final noseToEyeR = _distance(
            nose.position.x,
            nose.position.y,
            rightEye.position.x,
            rightEye.position.y,
          ) /
          faceH;

      final mouthWidth = (mouthL != null && mouthR != null)
          ? _distance(
                mouthL.position.x,
                mouthL.position.y,
                mouthR.position.x,
                mouthR.position.y,
              ) /
              faceW
          : 0.0;

      return {
        'eyeDistance': eyeDistance,
        'noseToEyeL': noseToEyeL,
        'noseToEyeR': noseToEyeR,
        'mouthWidth': mouthWidth,
        'eulerY': face.headEulerAngleY ?? 0,
        'eulerZ': face.headEulerAngleZ ?? 0,
        'leftEyeOpen': face.leftEyeOpenProbability ?? 1.0,
        'rightEyeOpen': face.rightEyeOpenProbability ?? 1.0,
      };
    } catch (e) {
      print('[FaceVerificationService] extractFaceMeasurements error: $e');
      return null;
    }
  }

  // ── Detect blink ──────────────────────────────────────
  static Future<bool> detectBlink(File frameFile) async {
    try {
      final faces = await _detector.processImage(
        InputImage.fromFile(frameFile),
      );
      if (faces.isEmpty) return false;
      final l = faces.first.leftEyeOpenProbability ?? 1.0;
      final r = faces.first.rightEyeOpenProbability ?? 1.0;
      return l < 0.3 && r < 0.3;
    } catch (_) {
      return false;
    }
  }

  // ── Detect head turn ──────────────────────────────────
  static Future<String?> detectHeadTurn(File frameFile) async {
    try {
      final faces = await _detector.processImage(
        InputImage.fromFile(frameFile),
      );
      if (faces.isEmpty) return null;
      final eulerY = faces.first.headEulerAngleY ?? 0;
      if (eulerY > 20) return 'left';
      if (eulerY < -20) return 'right';
      return 'center';
    } catch (_) {
      return null;
    }
  }

  // ── Upload selfie to Cloudflare ───────────────────────
  static Future<String?> uploadSelfie({
    required String userId,
    required File selfieFile,
    String suffix = '',
  }) async {
    try {
      final bytes = await selfieFile.readAsBytes();
      final fileName = 'face_selfies/$userId$suffix.jpg';
      return await CloudflareUpload.uploadBytes(bytes, fileName);
    } catch (e) {
      print('[FaceVerificationService] uploadSelfie error: $e');
      return null;
    }
  }

  // ── Submit verification request for manual review ─────
  static Future<bool> submitVerificationRequest({
    required String userId,
    required String userName,
    required String selfieUrl,
    required String liveSelfieUrl,
  }) async {
    try {
      // 1. Save request to verificationRequests collection
      await _firestore.collection('verificationRequests').doc(userId).set({
        'userId': userId,
        'userName': userName,
        'selfieUrl': selfieUrl,
        'liveSelfieUrl': liveSelfieUrl,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,
        'reviewedBy': null,
        'rejectionReason': null,
      });

      // 2. Update user doc
      await _firestore.collection('users').doc(userId).update({
        'faceVerified': false,
        'isVerified': false,
        'verificationStatus': 'pending',
        'selfieUrl': selfieUrl,
        'liveSelfieUrl': liveSelfieUrl,
        'verificationRequestedAt': FieldValue.serverTimestamp(),
      });

      // 3. Notify user — under review
      await NotificationService.send(
        toUid: userId,
        title: '🔍 Verification Under Review',
        body:
            'We\'ve received your request. Our team will review it shortly and notify you once done.',
        type: 'verification',
      );

      // 4. Notify admin — new request
      await NotificationService.send(
        toUid: _adminUid,
        title: '📋 New Verification Request',
        body: '$userName has submitted a face verification request.',
        type: 'admin_verification',
        fromUid: userId,
      );

      return true;
    } catch (e) {
      print('[FaceVerificationService] submitVerificationRequest error: $e');
      return false;
    }
  }

  // ── Admin: Approve verification ───────────────────────
  static Future<bool> approveVerification({
    required String userId,
    required String userName,
  }) async {
    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid;

      // 1. Update verificationRequests
      await _firestore.collection('verificationRequests').doc(userId).update({
        'status': 'verified',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': adminUid,
      });

      // 2. Update user doc
      await _firestore.collection('users').doc(userId).update({
        'faceVerified': true,
        'isVerified': true,
        'verificationStatus': 'verified',
        'trustScore': 90,
        'faceVerifiedAt': FieldValue.serverTimestamp(),
        'verificationReviewedAt': FieldValue.serverTimestamp(),
      });

      // 3. Notify user — approved
      await NotificationService.send(
        toUid: userId,
        title: '✅ Verification Approved!',
        body:
            'Congratulations $userName! Your profile is now verified. You can now make payments.',
        type: 'verification',
      );

      return true;
    } catch (e) {
      print('[FaceVerificationService] approveVerification error: $e');
      return false;
    }
  }

  // ── Admin: Reject verification ────────────────────────
  static Future<bool> rejectVerification({
    required String userId,
    required String userName,
    required String reason,
  }) async {
    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid;

      // 1. Update verificationRequests
      await _firestore.collection('verificationRequests').doc(userId).update({
        'status': 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': adminUid,
        'rejectionReason': reason,
      });

      // 2. Update user doc
      await _firestore.collection('users').doc(userId).update({
        'faceVerified': false,
        'isVerified': false,
        'verificationStatus': 'rejected',
        'rejectionReason': reason,
        'verificationReviewedAt': FieldValue.serverTimestamp(),
      });

      // 3. Notify user — rejected
      await NotificationService.send(
        toUid: userId,
        title: '❌ Verification Rejected',
        body:
            'Your verification was not approved. Reason: $reason. You can try again.',
        type: 'verification',
      );

      return true;
    } catch (e) {
      print('[FaceVerificationService] rejectVerification error: $e');
      return false;
    }
  }

  // ── Check if user is verified ─────────────────────────
  static Future<bool> isUserVerified(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return (doc.data()?['faceVerified'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── Check current user verified ───────────────────────
  static Future<bool> isCurrentUserVerified() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    return isUserVerified(uid);
  }

  // ── Payment gate ──────────────────────────────────────
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
      await context.push(AppRoutes.faceVerification, extra: {'userId': uid});
    }
    return false;
  }

  // ── Helper ────────────────────────────────────────────
  static double _distance(num x1, num y1, num x2, num y2) {
    return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
  }

  static void dispose() => _detector.close();
}

// ── Verification Required Bottom Sheet ───────────────────
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
            child: const Icon(
              Icons.shield_outlined,
              color: Color(0xFF10B981),
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Face Verification Required',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'To make payments on TheyDi, your account needs to be face verified.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
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
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Verify Now',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}