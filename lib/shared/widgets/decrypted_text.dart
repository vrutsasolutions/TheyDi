import 'package:flutter/material.dart';
import '../../core/services/encryption_service.dart';

/// Drop-in replacement for a `Text(data['text'])` call when the stored text
/// is encrypted. Decrypts asynchronously and rebuilds once resolved.
///
/// Usage (was):
///   Text(data['text'] ?? '', style: ...)
///
/// Usage (now):
///   DecryptedText(
///     cipherText: data['text'] ?? '',
///     chatId: chatId,
///     style: ...,
///   )
class DecryptedText extends StatelessWidget {
  final String cipherText;
  final String chatId;
  final TextStyle? style;
  final TextAlign? textAlign;

  const DecryptedText({
    super.key,
    required this.cipherText,
    required this.chatId,
    this.style,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      // Note: EncryptionService caches the derived key per chat, so this
      // future resolves fast after the first message in a chat — it's not
      // re-deriving the key every bubble.
      future: EncryptionService.decrypt(cipherText, chatId),
      builder: (context, snapshot) {
        final text = snapshot.data ?? '';
        return Text(text, style: style, textAlign: textAlign);
      },
    );
  }
}