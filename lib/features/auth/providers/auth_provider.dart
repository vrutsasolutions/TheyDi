import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/user_service.dart';
import '../../../core/services/notification_service.dart';

// ── Firebase Auth Instance ──
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

// ── Auth State Stream ──
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

// ── Auth Notifier ──
class AuthNotifier extends AsyncNotifier<User?> {
  static const _keepSignedInKey = 'keep_me_signed_in';
  FirebaseAuth get _auth => ref.read(firebaseAuthProvider);

  @override
  Future<User?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final keepSignedIn = prefs.getBool(_keepSignedInKey) ?? true;

    if (!keepSignedIn && _auth.currentUser != null) {
      await NotificationService.setOnlineStatus(false);
      await _auth.signOut();
      return null;
    }

    // start listening to auth state changes and update state
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keepSignedInKey, keepMeSignedIn);

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(displayName);

      // Save to Firestore
      if (credential.user != null) {
        await userService.createUserProfile(
          uid: credential.user!.uid,
          name: displayName,
          email: email,
          phone: phone,
        );
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keepSignedInKey, keepMeSignedIn);

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
        // WEB: Sign in with a popup
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        // ANDROID / IOS: Use GoogleSignIn plugin
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepSignedInKey, false);
    await NotificationService.setOnlineStatus(false);
    await _auth.signOut();
  }
}

// ── Providers ──
final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, User?>(AuthNotifier.new);
