import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../shared/services/database_service.dart';
import '../../shared/services/google_auth_service.dart';
import '../../shared/services/google_drive_service.dart';
import '../../shared/services/google_session_storage.dart';

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
}

class SyncState {
  final SyncStatus status;
  final String? userEmail;
  final DateTime? lastSyncTime;
  final String? errorMessage;

  SyncState({
    required this.status,
    this.userEmail,
    this.lastSyncTime,
    this.errorMessage,
  });

  SyncState copyWith({
    SyncStatus? status,
    String? userEmail,
    DateTime? lastSyncTime,
    String? errorMessage,
  }) {
    return SyncState(
      status: status ?? this.status,
      userEmail: userEmail ?? this.userEmail,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class GoogleDriveSyncService {
  static final GoogleDriveSyncService _instance = GoogleDriveSyncService._internal();
  factory GoogleDriveSyncService() => _instance;
  GoogleDriveSyncService._internal();

  static const String _prefLastSyncKey = 'gdrive_last_sync_timestamp';

  final GoogleAuthService _authService = GoogleAuthService();
  final GoogleDriveService _driveService = GoogleDriveService();

  Timer? _debounceTimer;

  /// 진행 중인 동기화 작업 (중복 실행 방지용)
  Future<bool>? _inFlightSync;

  /// 설정 DB에서 마지막 동기화 타임스탬프 가져오기
  Future<DateTime?> _getLastSyncTime() async {
    try {
      final db = await DatabaseService.database;
      final maps = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [_prefLastSyncKey],
      );
      if (maps.isNotEmpty) {
        final val = maps.first['value'] as String?;
        if (val != null) {
          final millis = int.tryParse(val);
          if (millis != null) {
            return DateTime.fromMillisecondsSinceEpoch(millis);
          }
        }
      }
    } catch (e) {
      debugPrint('GoogleDriveSyncService _getLastSyncTime Error: $e');
    }
    return null;
  }

  /// 설정 DB에 마지막 동기화 타임스탬프 저장하기
  Future<void> _setLastSyncTime(DateTime time) async {
    try {
      final db = await DatabaseService.database;
      await db.insert(
        'settings',
        {
          'key': _prefLastSyncKey,
          'value': time.millisecondsSinceEpoch.toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('GoogleDriveSyncService _setLastSyncTime Error: $e');
    }
  }

  /// 동기화 실행 (수동/자동 공통)
  ///
  /// [interactive] == true면(수동 '지금 동기화' 버튼) 토큰 만료 시 사용자 제스처
  /// 기반 팝업/리다이렉트 재인증까지 허용한다. 자동(debounce) 동기화는 팝업이
  /// 차단되므로 false를 전달한다.
  ///
  /// 이미 진행 중인 동기화가 있으면 새 작업을 시작하지 않고 그 결과를 공유한다
  /// (수동 버튼과 자동 debounce 동기화가 겹쳐 토큰 재발급·업로드가 중복되는 것 방지).
  Future<bool> sync({bool interactive = false}) {
    final inFlight = _inFlightSync;
    if (inFlight != null) return inFlight;
    final future = _doSync(interactive: interactive);
    _inFlightSync = future;
    future.whenComplete(() => _inFlightSync = null);
    return future;
  }

  Future<bool> _doSync({required bool interactive}) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      debugPrint('GoogleDriveSyncService: User not signed in.');
      return false;
    }

    try {
      final remoteMetadata =
          await _driveService.getRemoteDatabaseMetadata(interactive: interactive);
      final lastSyncTime = await _getLastSyncTime() ?? DateTime.fromMillisecondsSinceEpoch(0);

      final localBytes = await DatabaseService.exportDatabaseBytes();
      if (localBytes == null || localBytes.isEmpty) {
        debugPrint('GoogleDriveSyncService: Local DB bytes empty.');
        return false;
      }

      if (remoteMetadata == null) {
        // 원격 DB가 없으면 로컬 DB 업로드
        debugPrint('GoogleDriveSyncService: Remote DB not found. Uploading local DB...');
        final uploaded =
            await _driveService.uploadDatabase(localBytes, interactive: interactive);
        if (uploaded != null) {
          await _setLastSyncTime(uploaded.modifiedTime);
          return true;
        }
      } else {
        // 원격 DB와 로컬 동기화 시각 비교
        final remoteModifiedTime = remoteMetadata.modifiedTime;
        
        // 원격이 로컬 동기화 시점보다 2초 이상 최신이면 다운로드하여 교체
        if (remoteModifiedTime.isAfter(lastSyncTime.add(const Duration(seconds: 2)))) {
          debugPrint('GoogleDriveSyncService: Remote DB is newer. Downloading remote DB...');
          final downloadedBytes =
              await _driveService.downloadDatabase(interactive: interactive);
          if (downloadedBytes != null && downloadedBytes.isNotEmpty) {
            final imported = await DatabaseService.importDatabaseBytes(downloadedBytes);
            if (imported) {
              await _setLastSyncTime(remoteModifiedTime);
              return true;
            }
          }
        } else {
          // 로컬 데이터가 최신이거나 동일하면 업로드
          debugPrint('GoogleDriveSyncService: Local DB is newer/current. Uploading to Drive...');
          final uploaded =
              await _driveService.uploadDatabase(localBytes, interactive: interactive);
          if (uploaded != null) {
            await _setLastSyncTime(uploaded.modifiedTime);
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint('GoogleDriveSyncService sync error: $e');
      return false;
    }
  }

  /// 데이터 변경 후 3.5초 뒤 자동 백그라운드 동기화 스케줄링
  void scheduleDebouncedSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 3500), () async {
      debugPrint('GoogleDriveSyncService: Executing debounced sync...');
      // 타이머 기반 자동 동기화는 사용자 제스처가 아니므로 팝업 재인증을 허용하지 않는다.
      await sync(interactive: false);
    });
  }

  /// 리다이렉트 재인증 복귀 후 보류 중이던 동기화를 자동으로 재개한다.
  /// (토큰은 [GoogleAuthService.persistAccessToken]으로 이미 저장됨)
  ///
  /// 비interactive로 실행한다 — 복귀 시점에는 토큰이 갱신돼 있어 팝업이
  /// 불필요하고, 재인증이 실패로 끝났다면(백 버튼 등) 무한 리다이렉트를 막는다.
  Future<void> resumePendingSyncIfNeeded() async {
    try {
      if (!await GoogleSessionStorage.hasPendingSync()) return;
      await GoogleSessionStorage.setPendingSync(false);
      debugPrint('GoogleDriveSyncService: Resuming pending sync after redirect reauth...');
      await sync(interactive: false);
    } catch (e) {
      debugPrint('GoogleDriveSyncService resumePendingSyncIfNeeded error: $e');
    }
  }
}
