// Stub implementation for non-web platforms (mobile/desktop).
// Returns null — mobile uses MobileScannerController.analyzeImage() instead.

Future<String?> decodeQrFromImageBytes(List<int> bytes) async {
  return null;
}