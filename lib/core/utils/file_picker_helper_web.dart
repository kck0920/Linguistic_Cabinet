import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<String?> pickJsonFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
    withData: true,
  );
  if (result != null && result.files.isNotEmpty) {
    final file = result.files.first;
    if (file.bytes != null) {
      return utf8.decode(file.bytes!);
    }
  }
  return null;
}

Future<Uint8List?> pickZipFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['zip'],
    withData: true,
  );
  if (result != null && result.files.isNotEmpty) {
    final file = result.files.first;
    if (file.bytes != null) {
      return file.bytes!;
    }
  }
  return null;
}
