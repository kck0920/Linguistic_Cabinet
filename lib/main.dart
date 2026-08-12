import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'app.dart';
import 'shared/services/database_service.dart';
import 'core/utils/platform_helper.dart';

import 'shared/services/google_auth_service.dart';
import 'shared/services/google_drive_sync_service.dart';
import 'shared/services/google_token_refresh.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    if (!kIsWeb && isDesktop) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    
    // Initialize database
    await DatabaseService.database;

    // Restore Google Auth Session silently
    debugPrint('[MAIN] Attempting signInSilently at app startup...');
    final restoredUser = await GoogleAuthService().signInSilently();
    debugPrint('[MAIN] Silent sign in result: ${restoredUser?.email}');

    // 리다이렉트 재인증 복귀 처리: URL fragment(#access_token=...)에서 토큰을
    // 회수해 저장 세션에 반영한다 (연결 상태는 그대로 유지).
    final redirectToken = await GoogleTokenRefresher.consumeRedirectResult();
    if (redirectToken != null) {
      debugPrint('[MAIN] Consumed redirect reauth token, persisting session...');
      await GoogleAuthService()
          .persistAccessToken(redirectToken.accessToken, redirectToken.expiresAt);
    }
  } catch (e, stack) {
    debugPrint("CRITICAL DATABASE ERROR: $e");
    debugPrint('$stack');
  }
  
  runApp(
    const ProviderScope(
      child: VocaTreeApp(),
    ),
  );

  // 리다이렉트 재인증으로 이동하기 전에 보류됐던 동기화를 자동 재개한다.
  unawaited(GoogleDriveSyncService().resumePendingSyncIfNeeded());
}
