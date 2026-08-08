import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:linguistic_cabinet/core/theme/cabinet_colors.dart';
import 'package:linguistic_cabinet/features/achievements/data/achievement_service.dart';
import 'package:linguistic_cabinet/features/achievements/presentation/master_garden_certificate_screen.dart';
import 'package:linguistic_cabinet/features/review/data/repositories/review_repository.dart';
import 'package:linguistic_cabinet/features/review/presentation/screens/review_screen.dart';
import 'package:linguistic_cabinet/features/words/data/models/word.dart';
import 'package:linguistic_cabinet/features/words/presentation/screens/word_list_screen.dart';
import 'package:linguistic_cabinet/shared/widgets/cabinet_widgets.dart';

/// settings 맵 기반 가짜 리포 (master_badge_test와 동일 패턴)
class FakeSettingsRepository extends ReviewRepository {
  final Map<String, String> settings = {};

  @override
  Future<String?> getSetting(String key) async => settings[key];

  @override
  Future<void> setSetting(String key, String value) async {
    settings[key] = value;
  }
}

Future<void> _pumpCertificate(
  WidgetTester tester, {
  String? badgeDate,
}) async {
  final fakeRepo = FakeSettingsRepository();
  final words = [
    Word(id: '1', english: 'apple', korean: '사과', difficulty: 1),
    Word(id: '2', english: 'banana', korean: '바나나', difficulty: 4),
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reviewRepositoryProvider.overrideWithValue(fakeRepo),
        masterGardenBadgeProvider
            .overrideWith((ref) async => badgeDate),
        certificateStatsProvider.overrideWith(
          (ref) async => {'totalReviews': 42, 'currentStreak': 7},
        ),
        wordListProvider.overrideWith((ref) async => words),
      ],
      child: MaterialApp(
        home: const MasterGardenCertificateScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('MasterGardenCertificateScreen 렌더링', () {
    testWidgets('해금 상태: 제목·달성 날짜·통계·ACHIEVED 스탬프가 보인다', (tester) async {
      await _pumpCertificate(tester, badgeDate: '2026-08-07');

      expect(find.text('Certificate of Achievement'), findsOneWidget);
      expect(find.text('MASTER GARDENER'), findsOneWidget);
      expect(find.text('ACHIEVED'), findsOneWidget);
      // 달성 날짜 (handNote 서식: 2026.08.07)
      expect(find.text('2026.08.07'), findsOneWidget);
      // 통계: 수집 2 / 숙지 1 / 스트릭 7 / 복습 42
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('7 DAYS'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
      // 달성 조건 ✓ 칩 (가이드와 동일 스타일)
      expect(find.byIcon(Icons.check), findsNWidgets(2));
      expect(find.text('2,000단어 모으기'), findsOneWidget);
      expect(find.text('레벨 20 만개 달성'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('미해금 상태: 잠금 뱃지·진행 링·진행 텍스트가 보인다', (tester) async {
      await _pumpCertificate(tester, badgeDate: null);

      expect(find.text('Certificate of Achievement'), findsOneWidget);
      // 직인 원: 트로피 실루엣 + 우하단 잠금 뱃지 (lock_outline 1개)
      expect(find.byType(CabinetLockBadge), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events), findsOneWidget); // 실루엣 트로피
      // 진행 링 + 진행 텍스트 (words 2개 → 0%)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('2 / 2,000단어 · 0%'), findsOneWidget);
      expect(find.textContaining('2,000개를 모아'), findsOneWidget);
      expect(find.text('ACHIEVED'), findsNothing);
      expect(find.text('——————'), findsOneWidget); // 날짜 미기재
      // 미해금: 달성 ✓ 칩 없음
      expect(find.byIcon(Icons.check), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('미해금 상태: 단어 1,500개면 진행 링 75% 텍스트가 보인다', (tester) async {
      final fakeRepo = FakeSettingsRepository();
      final words = List.generate(
        1500,
        (i) => Word(
          id: '$i',
          english: 'word$i',
          korean: '단어$i',
          difficulty: 1,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewRepositoryProvider.overrideWithValue(fakeRepo),
            masterGardenBadgeProvider.overrideWith((ref) async => null),
            certificateStatsProvider.overrideWith(
              (ref) async => {'totalReviews': 42, 'currentStreak': 7},
            ),
            wordListProvider.overrideWith((ref) async => words),
          ],
          child: MaterialApp(
            home: const MasterGardenCertificateScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1,500 / 2,000단어 · 75%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('CabinetBadgeCard 진입점', () {
    testWidgets('onTap 콜백이 정상 호출된다', (tester) async {
      final colors = CabinetColors.fromMode(CabinetThemeMode.sepia);
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CabinetBadgeCard(
                achievedDate: null,
                colors: colors,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(CabinetBadgeCard));
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
