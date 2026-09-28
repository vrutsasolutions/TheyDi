import 'package:flutter/material.dart';

/// Opens an Instagram-style full-screen image preview as a dialog/overlay.
///
/// Usage:
///   showImagePreview(context, imageUrl: 'https://...', fallbackLabel: 'K');
///
/// - Works on Web and mobile (no new dependencies).
/// - Tapping anywhere outside the image, or the ✕ button, dismisses it.
/// - Fallback initial letter shown when [imageUrl] is null/empty.
/// - Uses Hero animation if [heroTag] is provided.
void showImagePreview(
  BuildContext context, {
  required String? imageUrl,
  String fallbackLabel = '?',
  String? heroTag,
}) {
  if (imageUrl == null || imageUrl.isEmpty) return; // nothing to show
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _ImagePreviewDialog(
      imageUrl: imageUrl,
      fallbackLabel: fallbackLabel,
      heroTag: heroTag,
    ),
  );
}

class _ImagePreviewDialog extends StatelessWidget {
  final String imageUrl;
  final String fallbackLabel;
  final String? heroTag;

  const _ImagePreviewDialog({
    required this.imageUrl,
    required this.fallbackLabel,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Cap the preview size: full screen on mobile, 480px on wide desktop.
    final previewSize = screenWidth < 600 ? screenWidth * 0.88 : 480.0;

    final imageWidget = Container(
      width: previewSize,
      height: previewSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF34D399)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Text(
              fallbackLabel.isNotEmpty ? fallbackLabel[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 80,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            );
          },
        ),
      ),
    );

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Dismiss on background tap.
            Positioned.fill(child: Container(color: Colors.transparent)),

            // The image — wrapped in GestureDetector to swallow taps so
            // they don't propagate to the background dismisser.
            GestureDetector(
              onTap: () {}, // absorb tap, keep dialog open
              child: heroTag != null
                  ? Hero(tag: heroTag!, child: imageWidget)
                  : imageWidget,
            ),

            // Close button — top-right corner.
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}