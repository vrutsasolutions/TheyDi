import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

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
  static JSObject? _autocompleteService;
  static JSObject? _placesService;
  static JSObject? _sessionToken;
  static JSObject? _placesNamespace;

  static bool get isAvailable {
    try {
      final google = globalContext.getProperty('google'.toJS);
      if (google == null) return false;
      final maps = (google as JSObject).getProperty('maps'.toJS);
      if (maps == null) return false;
      final places = (maps as JSObject).getProperty('places'.toJS);
      return places != null;
    } catch (_) {
      return false;
    }
  }

  static void _ensureInit() {
    if (_autocompleteService != null && _placesService != null) return;

    final google = globalContext.getProperty('google'.toJS) as JSObject;
    final maps = google.getProperty('maps'.toJS) as JSObject;
    _placesNamespace = maps.getProperty('places'.toJS) as JSObject;

    final autocompleteCtor =
        _placesNamespace!.getProperty('AutocompleteService'.toJS) as JSFunction;
    _autocompleteService = autocompleteCtor.callAsConstructor();

    final placesServiceCtor =
        _placesNamespace!.getProperty('PlacesService'.toJS) as JSFunction;

    final document = globalContext.getProperty('document'.toJS) as JSObject;
    final dummyDiv = document.callMethod('createElement'.toJS, 'div'.toJS);
    _placesService = placesServiceCtor.callAsConstructor(dummyDiv);

    _newSessionToken();
  }

  static void _newSessionToken() {
    final sessionTokenCtor = _placesNamespace!
        .getProperty('AutocompleteSessionToken'.toJS) as JSFunction;
    _sessionToken = sessionTokenCtor.callAsConstructor();
  }

  static Future<List<WebPlacePrediction>> getPredictions(
    String input, {
    String? city,
  }) async {
    if (!isAvailable || input.trim().length < 3) return [];
    _ensureInit();

    final completer = Completer<List<WebPlacePrediction>>();

    final request = JSObject()
      ..setProperty('input'.toJS, (city != null ? '$input, $city' : input).toJS)
      ..setProperty(
          'componentRestrictions'.toJS,
          (JSObject()..setProperty('country'.toJS, 'in'.toJS)))
      ..setProperty('sessionToken'.toJS, _sessionToken);

    void callback(JSAny? predictions, JSAny? status) {
      try {
        final statusStr = (status as JSString?)?.toDart;
        if (statusStr != 'OK' || predictions == null) {
          if (!completer.isCompleted) completer.complete([]);
          return;
        }
        final arr = predictions as JSArray;
        final list = arr.toDart;
        final result = list.map((item) {
          final obj = item as JSObject;
          final placeId = (obj.getProperty('place_id'.toJS) as JSString).toDart;
          final description =
              (obj.getProperty('description'.toJS) as JSString).toDart;
          return WebPlacePrediction(placeId: placeId, description: description);
        }).toList();
        if (!completer.isCompleted) completer.complete(result);
      } catch (_) {
        if (!completer.isCompleted) completer.complete([]);
      }
    }

    _autocompleteService!.callMethod(
      'getPlacePredictions'.toJS,
      request,
      callback.toJS,
    );

    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => [],
    );
  }

  static Future<WebPlaceResult?> getPlaceDetails(String placeId) async {
    if (!isAvailable) return null;
    _ensureInit();

    final completer = Completer<WebPlaceResult?>();

    final fields = JSArray<JSString>();
    fields.setProperty(0.toJS, 'geometry'.toJS);
    fields.setProperty(1.toJS, 'formatted_address'.toJS);

    final request = JSObject()
      ..setProperty('placeId'.toJS, placeId.toJS)
      ..setProperty('fields'.toJS, fields)
      ..setProperty('sessionToken'.toJS, _sessionToken);

    void callback(JSAny? place, JSAny? status) {
      try {
        final statusStr = (status as JSString?)?.toDart;
        if (statusStr != 'OK' || place == null) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }
        final obj = place as JSObject;
        final geometry = obj.getProperty('geometry'.toJS) as JSObject;
        final location = geometry.getProperty('location'.toJS) as JSObject;
        final lat = (location.callMethod('lat'.toJS) as JSNumber).toDartDouble;
        final lng = (location.callMethod('lng'.toJS) as JSNumber).toDartDouble;
        final formattedAddress =
            (obj.getProperty('formatted_address'.toJS) as JSString?)?.toDart ?? '';

        if (!completer.isCompleted) {
          completer.complete(WebPlaceResult(
            lat: lat,
            lng: lng,
            formattedAddress: formattedAddress,
          ));
        }
      } catch (_) {
        if (!completer.isCompleted) completer.complete(null);
      }
    }

    _placesService!.callMethod(
      'getDetails'.toJS,
      request,
      callback.toJS,
    );

    final result = await completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => null,
    );

    _newSessionToken();
    return result;
  }
}