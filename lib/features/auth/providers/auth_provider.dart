import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/user_service.dart';

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
  FirebaseAuth get _auth => ref.read(firebaseAuthProvider);

  @override
  Future<User?> build() async {
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
  }) async {
    state = const AsyncLoading();
    try {
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
  }) async {
    state = const AsyncLoading();
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    await signInWithEmail(email: email, password: password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

// ── Providers ──
final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, User?>(AuthNotifier.new);