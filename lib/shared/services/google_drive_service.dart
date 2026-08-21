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
  ///
  /// [interactive] == true면 토큰 만료 시 사용자 제스처 기반 팝업/리다이렉트
  /// 재인증까지 허용한다 (모바일 웹 1시간 만료 시나리오 대응).
  Future<T?> _withAuthRetry<T>(
    Future<T?> Function(drive.DriveApi api) action, {
    bool interactive = false,
  }) async {
    var client = await _authService.getAuthenticatedClient(interactive: interactive);
    if (client == null) {
      debugPrint('GoogleDriveService: No authenticated client.');
      return null;
    }
    try {
      return await action(drive.DriveApi(client));
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 401) {
        debugPrint('GoogleDriveService: Auth error (401), re-authenticating...');
        final newClient = await _authService.reauthenticate(interactive: interactive);
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
  Future<DriveFileMetadata?> getRemoteDatabaseMetadata({bool interactive = false}) async {
    try {
      return await _withAuthRetry<DriveFileMetadata>(
        (driveApi) async {
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
      },
        interactive: interactive,
      );
    } catch (e) {
      debugPrint('GoogleDriveService getRemoteDatabaseMetadata Error: $e');
      return null;
    }
  }

  /// 구글 드라이브에서 `vocatree.db` 파일 바이트 다운로드
  ///
  /// [knownMetadata]를 전달하면 내부 메타데이터 조회를 생략한다
  /// (동기화 흐름에서 이미 조회한 결과 재사용 — Drive 호출/재인증 중복 방지).
  Future<List<int>?> downloadDatabase({
    bool interactive = false,
    DriveFileMetadata? knownMetadata,
  }) async {
    try {
      return await _withAuthRetry<List<int>>(
        (driveApi) async {
        final metadata =
            knownMetadata ?? await getRemoteDatabaseMetadata(interactive: interactive);
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
      },
        interactive: interactive,
      );
    } catch (e) {
      debugPrint('GoogleDriveService downloadDatabase Error: $e');
      return null;
    }
  }

  /// 구글 드라이브로 `vocatree.db` 파일 바이너리 업로드
  ///
  /// [knownMetadata]를 전달하면 내부 메타데이터 조회를 생략한다
  /// (동기화 흐름에서 이미 조회한 결과 재사용 — Drive 호출/재인증 중복 방지).
  Future<DriveFileMetadata?> uploadDatabase(
    List<int> bytes, {
    bool interactive = false,
    DriveFileMetadata? knownMetadata,
  }) async {
    try {
      return await _withAuthRetry<DriveFileMetadata>(
        (driveApi) async {
        final existingFile =
            knownMetadata ?? await getRemoteDatabaseMetadata(interactive: interactive);
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
      },
        interactive: interactive,
      );
    } catch (e) {
      debugPrint('GoogleDriveService uploadDatabase Error: $e');
      return null;
    }
  }
}
