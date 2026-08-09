import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:linguistic_cabinet/main.dart' as app;
import 'package:linguistic_cabinet/shared/services/database_service.dart';
import 'package:linguistic_cabinet/features/words/data/models/word.dart';
import 'package:linguistic_cabinet/features/words/data/repositories/word_repository.dart';

/// 통합 테스트: 실제 앱 전체(VocaTreeApp + 실제 SQLite 쿼리)를 구동해
/// 복습 → 홈 탭 복귀 시 LEDGER SUMMARY 통계 갱신 플로우를 검증한다.
///
/// - 실제 파일 DB(vocatree.db)를 건드리지 않도록 인메모리 DB를 사용한다.
/// - 단어를 앱 시작 전에 등록해, 복습 화면 initState의 ensureReviewCards가
///   카드를 자동 생성하도록 한다 (실제 사용자 흐름과 동일).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('복습 완료 후 홈 탭 복귀 시 LEDGER SUMMARY가 즉시 갱신된다',
      (tester) async {
    // ── 1) 실제 파일 DB 대신 인메모리 DB 사용 (main.dart와 동일한 ffi 초기화)
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DatabaseService.setTestDatabaseInMemory();

    // ── 2) 앱 시작 전 단어 2개 등록 (difficulty 3·4 → Known 답변 후 난이도 자동 반영)
    final wordRepo = WordRepository();
    await wordRepo.insertWords([
      Word(english: 'apple', korean: '사과', difficulty: 3),
      Word(english: 'banana', korean: '바나나', difficulty: 4),
    ]);

    // ── 3) 실제 앱 구동 (모바일 크기 화면 + 하단 네비게이션 사용)
    await tester.binding.setSurfaceSize(const Size(500, 900));
    app.main();
    await tester.pumpAndSettle();

    // 홈 대시보드 초기 상태: 단어 2개, 아직 복습 전
    expect(find.text('LEDGER SUMMARY'), findsOneWidget);
    expect(find.text('MASTERED'), findsOneWidget);
    expect(find.text('0 / 2'), findsOneWidget); // 숙달 0개
    expect(find.text('0% 숙달'), findsOneWidget);
    expect(find.text('0 Days'), findsOneWidget); // 스트릭 0

    // ── 4) 복습 탭으로 이동 (하단 네비게이션)
    final bottomNav = find.byType(BottomNavigationBar);
    await tester.tap(find.descendant(of: bottomNav, matching: find.text('복습')));
    await tester.pumpAndSettle();

    // ── 5) 복습 시작 (카드 2장 자동 생성됨)
    final startButton = find.text('3D 플립 복습 시작하기');
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    // ── 6) 두 카드 모두 Known으로 답변 (logReview 2건 + 난이도 반영)
    // CabinetBrutalButton은 버튼 텍스트를 대문자로 표시하므로 (KNOWN)으로 찾는다.
    expect(find.text('REVIEW · 1 / 2'), findsOneWidget);
    await tester.tap(find.text('알았다 (KNOWN)'));
    // _handleAnswer 내부의 400ms 지연을 진행시킨 뒤 다음 카드로 전환
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('REVIEW · 2 / 2'), findsOneWidget);
    await tester.tap(find.text('알았다 (KNOWN)'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    // ── 7) 완료 다이얼로그 → 홈으로 돌아가기
    expect(find.text('복습 완료!'), findsOneWidget);
    await tester.tap(find.text('홈으로 돌아가기'));
    await tester.pumpAndSettle();

    // ── 8) 홈 탭 복귀 → LEDGER SUMMARY 즉시 갱신 검증
    await tester.tap(find.descendant(of: bottomNav, matching: find.text('홈')));
    await tester.pumpAndSettle();

    expect(find.text('LEDGER SUMMARY'), findsOneWidget);
    // Collected = 2 (단어 2개)
    expect(find.text('COLLECTED'), findsOneWidget);
    // Mastered = 1/2 · 50% (apple: 3→2 숙달, banana: 4→3 미숙달)
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('50% 숙달'), findsOneWidget);
    // Streak = 1 Day (오늘 복습 2건)
    expect(find.text('STREAK'), findsOneWidget);
    expect(find.text('1 Day'), findsOneWidget);
    // Reviews = 2 (복습 로그 2건) — COLLECTED(2)와 별개 텍스트 존재 확인
    expect(find.text('REVIEWS'), findsOneWidget);
    expect(find.text('2'), findsNWidgets(2)); // COLLECTED + REVIEWS
    expect(tester.takeException(), isNull);

    // ── 9) 정리: 인메모리 DB 해제 (파일 DB 무영향)
    DatabaseService.clearTestDatabase();
  });
}
