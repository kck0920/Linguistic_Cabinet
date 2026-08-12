import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'google_auth_service.dart';

class DriveFileMetadata {
  final String id;
  final String name;
  final DateTime modifiedTime;
  final int? size;

  DriveFileMetadata({
    required this.id,
    required this.name,
    required this.modifiedTime,
    this.size,
  });
}

class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  static const String _dbFileName = 'vocatree.db';

  final GoogleAuthService _authService = GoogleAuthService();

  /// Drive API 호출을 감싸 인증 실패(401) 시 재인증 후 1회 재시도한다.
  /// 인증 실패·재인증 불가 시 null을 반환한다.
  Future<T?> _withAuthRetry<T>(Future<T?> Function(drive.DriveApi api) action) async {
    var client = await _authService.getAuthenticatedClient();
    if (client == null) {
      debugPrint('GoogleDriveService: No authenticated client.');
      return null;
    }
    try {
      return await action(drive.DriveApi(client));
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 401) {
        debugPrint('GoogleDriveService: Auth error (401), re-authenticating...');
        final newClient = await _authService.reauthenticate();
        if (newClient != null) {
          try {
            return await action(drive.DriveApi(newClient));
          } finally {
            newClient.close();
          }
        }
      } else {
        debugPrint('GoogleDriveService: API error ${e.status}: ${e.message}');
      }
    } catch (e) {
      debugPrint('GoogleDriveService: Error: $e');
    } finally {
      client.close();
    }
    return null;
  }

  /// App Data 폴더에 있는 `vocatree.db` 메타데이터 검색
  Future<DriveFileMetadata?> getRemoteDatabaseMetadata() async {
    try {
      return await _withAuthRetry<DriveFileMetadata>((driveApi) async {
        final fileList = await driveApi.files.list(
          spaces: 'appDataFolder',
          q: "name = '$_dbFileName' and 'appDataFolder' in parents and trashed = false",
          $fields: 'files(id, name, modifiedTime, size)',
        );

        if (fileList.files != null && fileList.files!.isNotEmpty) {
          final file = fileList.files!.first;
          if (file.id != null && file.modifiedTime != null) {
            return DriveFileMetadata(
              id: file.id!,
              name: file.name ?? _dbFileName,
              modifiedTime: file.modifiedTime!.toLocal(),
              size: file.size != null ? int.tryParse(file.size!) : null,
            );
          }
        }
        return null;
      });
    } catch (e) {
      debugPrint('GoogleDriveService getRemoteDatabaseMetadata Error: $e');
      return null;
    }
  }

  /// 구글 드라이브에서 `vocatree.db` 파일 바이트 다운로드
  Future<List<int>?> downloadDatabase() async {
    try {
      return await _withAuthRetry<List<int>>((driveApi) async {
        final metadata = await getRemoteDatabaseMetadata();
        if (metadata == null) return null;

        final dynamic response = await driveApi.files.get(
          metadata.id,
          downloadOptions: drive.DownloadOptions.fullMedia,
        );

        if (response is drive.Media) {
          final List<int> bytes = [];
          await for (final data in response.stream) {
            bytes.addAll(data);
          }
          return bytes;
        }
        return null;
      });
    } catch (e) {
      debugPrint('GoogleDriveService downloadDatabase Error: $e');
      return null;
    }
  }

  /// 구글 드라이브로 `vocatree.db` 파일 바이너리 업로드
  Future<DriveFileMetadata?> uploadDatabase(List<int> bytes) async {
    try {
      return await _withAuthRetry<DriveFileMetadata>((driveApi) async {
        final existingFile = await getRemoteDatabaseMetadata();
        final mediaStream = Stream.value(bytes);
        final media = drive.Media(mediaStream, bytes.length);

        if (existingFile != null) {
          // 기존 파일 업데이트
          final updatedFile = await driveApi.files.update(
            drive.File(),
            existingFile.id,
            uploadMedia: media,
            $fields: 'id, name, modifiedTime, size',
          );
          return DriveFileMetadata(
            id: updatedFile.id!,
            name: updatedFile.name ?? _dbFileName,
            modifiedTime: (updatedFile.modifiedTime ?? DateTime.now()).toLocal(),
            size: bytes.length,
          );
        } else {
          // 새 파일 생성 (appDataFolder 하위)
          final newFile = drive.File()
            ..name = _dbFileName
            ..parents = ['appDataFolder'];

          final createdFile = await driveApi.files.create(
            newFile,
            uploadMedia: media,
            $fields: 'id, name, modifiedTime, size',
          );
          return DriveFileMetadata(
            id: createdFile.id!,
            name: createdFile.name ?? _dbFileName,
            modifiedTime: (createdFile.modifiedTime ?? DateTime.now()).toLocal(),
            size: bytes.length,
          );
        }
      });
    } catch (e) {
      debugPrint('GoogleDriveService uploadDatabase Error: $e');
      return null;
    }
  }
}
