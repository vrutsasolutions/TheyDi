// Web implementation — uses JS interop to call theydiScanQrImage()
// defined in web/index.html (BarcodeDetector API + ZXing fallback).

import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

@JS('theydiScanQrImage')
external JSPromise<JSString?> _theydiScanQrImage(JSUint8Array bytes);

Future<String?> decodeQrFromImageBytes(List<int> bytes) async {
  try {
    final uint8 = Uint8List.fromList(bytes);
    final jsBytes = uint8.toJS;
    final result = await _theydiScanQrImage(jsBytes).toDart;
    if (result == null) return null;
    final str = result.toDart;
    return str.isEmpty ? null : str;
  } catch (_) {
    return null;
  }
}