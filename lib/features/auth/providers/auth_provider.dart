import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/services/user_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/referral_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

class AuthNotifier extends AsyncNotifier<User?> {
  static const _keepSignedInKey = 'keep_me_signed_in';
  static const _secureStorage = FlutterSecureStorage();
  FirebaseAuth get _auth => ref.read(firebaseAuthProvider);

  @override
  Future<User?> build() async {
    final keepSignedInStr = await _secureStorage.read(key: _keepSignedInKey);
    final keepSignedIn = keepSignedInStr != 'false';

    if (!keepSignedIn && _auth.currentUser != null) {
      await NotificationService.setOnlineStatus(false);
      await _auth.signOut();
      return null;
    }

    _auth.authStateChanges().listen((user) {
      state = AsyncData(user);
    });
    return _auth.currentUser;
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    required String phone,
    bool keepMeSignedIn = true,
  }) async {
    state = const AsyncLoading();
    try {
      await _secureStorage.write(
        key: _keepSignedInKey,
        value: keepMeSignedIn.toString(),
      );

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(displayName);

      if (credential.user != null) {
        await userService.createUserProfile(
          uid: credential.user!.uid,
          name: displayName,
          email: email,
          phone: phone,
        );
        try {
          await ReferralService.instance.ensureReferralCode();
          await ReferralService.instance.applyPendingReferral();
        } catch (e) {
          // The backend user-create trigger also creates referral codes.
          // Do not fail a completed auth/profile signup for referral sync.
        }
      }
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
    bool keepMeSignedIn = true,
  }) async {
    state = const AsyncLoading();
    try {
      await _secureStorage.write(
        key: _keepSignedInKey,
        value: keepMeSignedIn.toString(),
      );

      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    try {
      final UserCredential userCredential;

      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        await GoogleSignIn.instance.initialize(
          serverClientId:
              '703233514575-mgfa7e8q2qpusf9pqu275rhqt8s8bi65.apps.googleusercontent.com',
        );
        final GoogleSignInAccount googleUser =
            await GoogleSignIn.instance.authenticate();
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      final User? user = userCredential.user;

      if (user != null) {
        final profile = await userService.getUserProfile(user.uid);
        if (profile == null) {
          await userService.createUserProfile(
            uid: user.uid,
            name: user.displayName ?? 'Google User',
            email: user.email ?? '',
            phone: user.phoneNumber ?? '',
          );
          try {
            await ReferralService.instance.ensureReferralCode();
            await ReferralService.instance.applyPendingReferral();
          } catch (e) {
            // Keep Google sign-in intact if referral sync is temporarily down.
          }
        }
      }

      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> login({
    required String email,
    required String password,
    bool keepMeSignedIn = true,
  }) async {
    await signInWithEmail(
      email: email,
      password: password,
      keepMeSignedIn: keepMeSignedIn,
    );
  }

  Future<void> signOut() async {
    await _secureStorage.write(key: _keepSignedInKey, value: 'false');
    await NotificationService.setOnlineStatus(false);
    await _auth.signOut();
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, User?>(AuthNotifier.new);
