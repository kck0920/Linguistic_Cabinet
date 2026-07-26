import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<void> saveJsonFile(String jsonString, String fileName) async {
  final bytes = utf8.encode(jsonString).toJS;
  final parts = <web.BlobPart>[bytes].toJS;
  final blob = web.Blob(parts, web.BlobPropertyBag(type: 'application/json'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  anchor.click();
  web.URL.revokeObjectURL(url);
}

Future<void> saveZipFile(Uint8List bytes, String fileName) async {
  final jsBytes = bytes.toJS;
  final parts = <web.BlobPart>[jsBytes].toJS;
  final blob = web.Blob(parts, web.BlobPropertyBag(type: 'application/zip'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  anchor.click();
  web.URL.revokeObjectURL(url);
}