import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class WebPlacePrediction {
  final String placeId;
  final String description;
  const WebPlacePrediction({required this.placeId, required this.description});
}

class WebPlaceResult {
  final double lat;
  final double lng;
  final String formattedAddress;
  const WebPlaceResult(
      {required this.lat, required this.lng, required this.formattedAddress});
}

class PlacesWebService {
  static bool get isAvailable => true;

  static String? _sessionToken;

  static String _newSessionToken() {
    final token = DateTime.now().microsecondsSinceEpoch.toString();
    _sessionToken = token;
    return token;
  }

  static Future<List<WebPlacePrediction>> getPredictions(
    String input, {
    String? city,
  }) async {
    var apiKey = const String.fromEnvironment('GOOGLE_MAPS_API_KEY');
    if (apiKey.isEmpty) {
      apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    }
    if (apiKey.isEmpty || input.trim().length < 3) return [];

    _sessionToken ??= _newSessionToken();
    final fullQuery = city != null ? '$input, $city' : input;

    try {
      final encoded = Uri.encodeComponent(fullQuery);
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=$encoded'
        '&components=country:in'
        '&sessiontoken=$_sessionToken'
        '&key=$apiKey',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      if (data['status'] != 'OK') return [];

      final predictions = (data['predictions'] as List)
          .map((p) => WebPlacePrediction(
                placeId: p['place_id'],
                description: p['description'],
              ))
          .toList();

      return predictions;
    } catch (_) {
      return [];
    }
  }

  static Future<WebPlaceResult?> getPlaceDetails(String placeId) async {
    var apiKey = const String.fromEnvironment('GOOGLE_MAPS_API_KEY');
    if (apiKey.isEmpty) {
      apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    }
    if (apiKey.isEmpty) return null;

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=geometry,formatted_address'
        '&sessiontoken=$_sessionToken'
        '&key=$apiKey',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data['status'] != 'OK') return null;

      final result = data['result'];
      final location = result['geometry']['location'];

      return WebPlaceResult(
        lat: (location['lat'] as num).toDouble(),
        lng: (location['lng'] as num).toDouble(),
        formattedAddress: result['formatted_address'] ?? '',
      );
    } catch (_) {
      return null;
    } finally {
      _newSessionToken();
    }
  }
}
