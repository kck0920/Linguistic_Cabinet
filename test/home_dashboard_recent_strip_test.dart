import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:linguistic_cabinet/features/words/data/models/word.dart';
import 'package:linguistic_cabinet/home/widgets/dashboard_recent_strip.dart';
import 'helpers.dart';

void main() {
  testWidgets('DashboardRecentStrip displays 4 most recently created words with correct catalog numbers', (tester) async {
    ignoreTestFontOverflow();

    final baseTime = DateTime(2025, 1, 1);
    final words = [
      Word(id: 'w1', english: 'apple', korean: '사과', createdAt: baseTime.add(const Duration(days: 1))),
      Word(id: 'w2', english: 'banana', korean: '바나나', createdAt: baseTime.add(const Duration(days: 2))),
      Word(id: 'w3', english: 'cherry', korean: '체리', createdAt: baseTime.add(const Duration(days: 3))),
      Word(id: 'w4', english: 'date', korean: '대추', createdAt: baseTime.add(const Duration(days: 4))),
      Word(id: 'w5', english: 'elderberry', korean: '엘더베리', createdAt: baseTime.add(const Duration(days: 5))),
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DashboardRecentStrip(words: words),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 섹션 헤더 표시 확인
    expect(find.text('RECENTLY COLLECTED'), findsOneWidget);

    // 최신 4개 단어(elderberry, date, cherry, banana)가 화면에 있어야 함
    expect(find.text('elderberry'), findsOneWidget);
    expect(find.text('date'), findsOneWidget);
    expect(find.text('cherry'), findsOneWidget);
    expect(find.text('banana'), findsOneWidget);

    // 가장 먼저 등록된 apple은 표시되지 않아야 함
    expect(find.text('apple'), findsNothing);

    // 각 카드의 카탈로그 번호 확인:
    // elderberry는 5번째 등록 단어이므로 #0005
    expect(find.text('CAB · #0005'), findsOneWidget);
    // date는 4번째 등록 단어이므로 #0004
    expect(find.text('CAB · #0004'), findsOneWidget);
    // cherry는 3번째 등록 단어이므로 #0003
    expect(find.text('CAB · #0003'), findsOneWidget);
    // banana는 2번째 등록 단어이므로 #0002
    expect(find.text('CAB · #0002'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('DashboardRecentStrip handles empty list gracefully', (tester) async {
    ignoreTestFontOverflow();

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DashboardRecentStrip(words: []),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RECENTLY COLLECTED'), findsOneWidget);
    expect(find.text('No recent cards.'), findsOneWidget);
  });
}
