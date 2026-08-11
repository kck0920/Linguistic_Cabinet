import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'app.dart';
import 'shared/services/database_service.dart';
import 'core/utils/platform_helper.dart';

import 'shared/services/google_auth_service.dart';

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
    await GoogleAuthService().signInSilently();
  } catch (e, stack) {
    debugPrint("CRITICAL DATABASE ERROR: $e");
    debugPrint('$stack');
  }
  
  runApp(
    const ProviderScope(
      child: VocaTreeApp(),
    ),
  );
}
