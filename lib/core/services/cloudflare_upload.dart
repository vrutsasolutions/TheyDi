import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class CloudflareUpload {
  static const String workerUrl =
      'https://r2-upload-service.theydi-app.workers.dev/';

  static Future<Map<String, String>> _authHeaders() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return token == null ? {} : {'Authorization': 'Bearer $token'};
  }

  /// Uploads bytes to be encrypted and stored server-side. Returns an
  /// opaque file key (NOT a public URL) — the file can only be viewed
  /// via [fetchDecrypted] with an authorized (admin) token.
  static Future<String?> uploadBytes(
    List<int> bytes,
    String fileName,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(workerUrl),
      );
      request.headers.addAll(await _authHeaders());

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        return data['url']; // now a file key, e.g. face_selfies/<uid>.jpg
      }

      print(responseBody);
      return null;
    } catch (e) {
      print(e);
      return null;
    }
  }

  /// Fetches and decrypts an image. Only succeeds for the admin account
  /// (or the file's own owner, per the worker's rules).
  static Future<Uint8List?> fetchDecrypted(String fileKey) async {
    try {
      final uri = Uri.parse(workerUrl).replace(
        queryParameters: {'file': fileKey},
      );
      final response = await http.get(uri, headers: await _authHeaders());
      if (response.statusCode == 200) return response.bodyBytes;
      print('[CloudflareUpload] fetchDecrypted failed: ${response.statusCode}');
      return null;
    } catch (e) {
      print('[CloudflareUpload] fetchDecrypted error: $e');
      return null;
    }
  }

  static Future<bool> deleteFile(String fileName) async {
    try {
      final uri = Uri.parse(
        workerUrl,
      ).replace(
        queryParameters: {'file': fileName},
      );

      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          ...await _authHeaders(),
        },
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('[CloudflareUpload] deleteFile error: $e');
      return false;
    }
  }
}