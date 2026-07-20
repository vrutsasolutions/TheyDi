import 'dart:convert';
import 'package:http/http.dart' as http;

class CloudflareUpload {
  static const String workerUrl =
      'https://r2-upload-service.theydi-app.workers.dev/';

  static Future<String?> uploadBytes(
    List<int> bytes,
    String fileName,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(workerUrl),
      );

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
        return data['url'];
      }

      print(responseBody);
      return null;
    } catch (e) {
      print(e);
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
        },
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('[CloudflareUpload] deleteFile error: $e');
      return false;
    }
  }
}
