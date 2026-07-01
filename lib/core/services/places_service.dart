import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class PlacesService {
  PlacesService._();

  static final PlacesService instance = PlacesService._();

  String get apiKey {
    if (kIsWeb) {
      return dotenv.env['GOOGLE_MAPS_WEB_API_KEY'] ?? '';
    }

    if (Platform.isAndroid) {
      return dotenv.env['GOOGLE_MAPS_ANDROID_API_KEY'] ?? '';
    }

    if (Platform.isIOS) {
      return dotenv.env['GOOGLE_MAPS_IOS_API_KEY'] ?? '';
    }

    throw UnsupportedError('Unsupported platform');
  }

  /// Autocomplete using Places API (New)
  Future<List<dynamic>> autocomplete(String input) async {
    final response = await http.post(
      Uri.parse('https://places.googleapis.com/v1/places:autocomplete'),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask':
            'suggestions.placePrediction.placeId,suggestions.placePrediction.text',
      },
      body: jsonEncode({
        "input": input,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }

    final json = jsonDecode(response.body);

    return json['suggestions'] ?? [];
  }

  /// Get place details
  Future<Map<String, dynamic>> getPlaceDetails(String placeId) async {
    final response = await http.get(
      Uri.parse('https://places.googleapis.com/v1/places/$placeId'),
      headers: {
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'displayName,formattedAddress,location',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }

    return jsonDecode(response.body);
  }
}
