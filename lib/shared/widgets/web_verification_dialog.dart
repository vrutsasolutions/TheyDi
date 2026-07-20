import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class WebVerificationDialog {
  /// Returns true if on web (should block) false if on mobile (should proceed)
  static bool isWeb(BuildContext context) => kIsWeb;

  /// Show download app dialog on web
  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: TheyDiColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              gradient: TheyDiColors.gradientPrimary,
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.phone_android, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 20),
          Text('Download TheyDi App',
              style: TheyDiTextStyles.headlineMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            'Face verification is only available on the TheyDi mobile app.\n\nDownload the app to get verified and unlock all features.',
            style: TheyDiTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Play Store button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.android, color: Colors.white),
              label: const Text('Get it on Play Store',
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF01875F),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Continue on web',
                style: TheyDiTextStyles.caption
                    .copyWith(color: TheyDiColors.textMuted)),
          ),
        ]),
      ),
    );
  }
}
