import 'dart:typed_data';

Future<void> saveJsonFile(String jsonString, String fileName) async {
  throw UnsupportedError('Cannot save file on this platform.');
}

Future<void> saveZipFile(Uint8List bytes, String fileName) async {
  throw UnsupportedError('Cannot save file on this platform.');
}
