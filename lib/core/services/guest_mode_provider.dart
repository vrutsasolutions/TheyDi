// lib/core/services/guest_mode_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True only after someone taps "Continue as Guest" on the web login
/// screen. Never set on the native app build (the app never shows that
/// button — see login_screen.dart's kIsWeb check). Not persisted to
/// storage on purpose: a fresh page load / new tab starts as a normal
/// logged-out visitor, and guest status simply expires with the session.
///
/// Built on Notifier (same modern API auth_provider.dart already uses)
/// instead of the legacy StateProvider, which this project's Riverpod
/// version doesn't export. Read/write usage is identical either way:
/// ref.watch(isGuestModeProvider) and
/// ref.read(isGuestModeProvider.notifier).state = true both still work.
class GuestModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
}

final isGuestModeProvider =
    NotifierProvider<GuestModeNotifier, bool>(GuestModeNotifier.new);