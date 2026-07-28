import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:linguistic_cabinet/app.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // Test that the app widget tree can be built without crashing
  testWidgets('App widget tree builds correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: VocaTreeApp()),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  // Test theme is configured correctly
  testWidgets('App has correct theme', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: VocaTreeApp()),
    );

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme, isNotNull);
  });
}