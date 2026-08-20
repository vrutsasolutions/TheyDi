import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// Encrypts/decrypts chat message text with AES-256-GCM.
///
/// Key model (v1 — symmetric, NOT full E2EE):
///   - One key per chat, derived via HKDF from a fixed app-wide secret + chatId.
///   - Anyone with the app secret (i.e. anyone who decompiles the app) can
///     derive any chat's key. This is NOT protection against a malicious
///     client/attacker with the APK — it IS protection against:
///       * a Firestore data dump / breach showing plaintext messages
///       * a backend engineer or admin console casually reading chats
///       * data-at-rest compliance requirements
///   - True E2EE (where even a compromised app secret can't decrypt past
///     messages) requires per-device asymmetric key exchange (ECDH) and is
///     a separate, larger project — see TODO at bottom.
class EncryptionService {
  // TODO(security): move this out of source control before shipping.
  // Options, in order of preference:
  //   1. --dart-define=CHAT_ENC_SECRET=xxxx at build time, read via
  //      String.fromEnvironment('CHAT_ENC_SECRET')
  //   2. Fetched once at app start from a backend endpoint (still not true
  //      E2EE, but at least isn't baked into the binary)
  // A hardcoded string here is a placeholder ONLY.
  static const String _masterSecret = String.fromEnvironment(
    'CHAT_ENC_SECRET',
    defaultValue: 'REPLACE_WITH_A_LONG_RANDOM_SECRET_BEFORE_SHIPPING',
  );

  /// True once a real secret has been supplied via --dart-define(-from-file).
  /// False means the placeholder default is in use — safe for a first local
  /// smoke test, but every build that leaves this false is encrypting with
  /// a secret anyone can read straight out of this source file.
  static bool get isConfigured =>
      _masterSecret != 'REPLACE_WITH_A_LONG_RANDOM_SECRET_BEFORE_SHIPPING';

  static final AesGcm _algorithm = AesGcm.with256bits();

  // Cache derived keys per chatId so we're not re-running HKDF on every
  // message — HKDF itself is cheap, but no reason to redo it per-bubble.
  static final Map<String, SecretKey> _keyCache = {};

  static Future<SecretKey> _keyForChat(String chatId) async {
    final cached = _keyCache[chatId];
    if (cached != null) return cached;

    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final key = await hkdf.deriveKey(
      secretKey: SecretKey(utf8.encode(_masterSecret)),
      nonce: utf8.encode('theydi-chat-salt-v1'), // fixed salt, fine for HKDF
      info: utf8.encode('chat:$chatId'),
    );
    _keyCache[chatId] = key;
    return key;
  }

  /// Marker prefix so we can tell "this is our ciphertext format" apart from
  /// legacy plaintext messages already sitting in Firestore.
  static const String _prefix = 'enc1:';

  /// Encrypts [plaintext] for [chatId]. Returns a single string safe to
  /// store directly in the `text` field.
  static Future<String> encrypt(String plaintext, String chatId) async {
    if (plaintext.isEmpty) return plaintext;

    final key = await _keyForChat(chatId);
    final nonce = _algorithm.newNonce();
    final secretBox = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );

    final payload = <String, String>{
      'n': base64Encode(secretBox.nonce),
      'c': base64Encode(secretBox.cipherText),
      'm': base64Encode(secretBox.mac.bytes),
    };
    return '$_prefix${base64Encode(utf8.encode(jsonEncode(payload)))}';
  }

  /// Decrypts a string previously produced by [encrypt]. If [ciphertext]
  /// doesn't start with our marker prefix, it's treated as legacy plaintext
  /// and returned as-is (so old chat history doesn't break).
  static Future<String> decrypt(String ciphertext, String chatId) async {
    if (ciphertext.isEmpty) return ciphertext;
    if (!ciphertext.startsWith(_prefix)) {
      return ciphertext; // legacy / already-plaintext message
    }

    try {
      final raw = utf8.decode(base64Decode(ciphertext.substring(_prefix.length)));
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final key = await _keyForChat(chatId);

      final secretBox = SecretBox(
        base64Decode(payload['c'] as String),
        nonce: base64Decode(payload['n'] as String),
        mac: Mac(base64Decode(payload['m'] as String)),
      );

      final clear = await _algorithm.decrypt(secretBox, secretKey: key);
      return utf8.decode(clear);
    } catch (_) {
      return '⚠️ Unable to decrypt message';
    }
  }

  /// Call this once (e.g. on logout or when leaving a chat you don't expect
  /// to revisit soon) if you want to bound memory use of the key cache.
  static void clearCacheForChat(String chatId) => _keyCache.remove(chatId);
}

// TODO(next iteration — real E2EE):
//   1. Each device generates an X25519 keypair on first login, stores the
//      private key in secure storage (flutter_secure_storage / Keychain /
//      Keystore) and publishes the public key to Firestore under
//      users/{uid}/publicKey.
//   2. Per-chat AES key is generated randomly (not derived from a shared
//      secret), then encrypted separately to each participant's public key
//      via ECDH and stored in chats/{chatId}/keys/{uid}.
//   3. Backend/Firestore never sees the AES key or plaintext — only
//      per-recipient encrypted key blobs and ciphertext messages.
//   4. Add forward secrecy via key rotation (Signal-style ratchet) if you
//      need messages-before-compromise to stay safe after a device is
//      compromised. This is the part that actually takes days, not hours.