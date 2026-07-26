import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'app.dart';
import 'shared/services/database_service.dart';
import 'core/utils/platform_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    if (!kIsWeb && isDesktop) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    
    // Initialize database
    await DatabaseService.database;
  } catch (e, stack) {
    print("CRITICAL DATABASE ERROR: $e");
    print(stack);
  }
  
  runApp(
    const ProviderScope(
      child: VocaTreeApp(),
    ),
  );
}
