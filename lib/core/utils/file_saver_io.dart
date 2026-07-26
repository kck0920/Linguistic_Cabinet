import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveJsonFile(String jsonString, String fileName) async {
  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    final outputFilePath = await FilePicker.platform.saveFile(
      dialogTitle: '백업 파일 저장 위치를 선택하세요',
      fileName: fileName,
    );
    if (outputFilePath != null) {
      final file = File(outputFilePath);
      await file.writeAsString(jsonString);
    }
  } else {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(jsonString);
    await Share.shareXFiles([XFile(file.path)], text: 'VocaTree 백업');
  }
}

Future<void> saveZipFile(Uint8List bytes, String fileName) async {
  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    final outputFilePath = await FilePicker.platform.saveFile(
      dialogTitle: '백업 파일 저장 위치를 선택하세요',
      fileName: fileName,
    );
    if (outputFilePath != null) {
      final file = File(outputFilePath);
      await file.writeAsBytes(bytes);
    }
  } else {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'VocaTree 백업');
  }
}
