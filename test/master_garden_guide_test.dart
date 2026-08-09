import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:linguistic_cabinet/features/achievements/data/achievement_service.dart';
import 'package:linguistic_cabinet/features/achievements/data/anniversary_service.dart';
import 'package:linguistic_cabinet/features/achievements/presentation/achievement_collection_screen.dart';
import 'package:linguistic_cabinet/features/achievements/presentation/master_garden_certificate_screen.dart';
import 'package:linguistic_cabinet/features/achievements/presentation/master_garden_guide_screen.dart';
import 'package:linguistic_cabinet/features/review/data/repositories/review_repository.dart';
import 'package:linguistic_cabinet/features/review/presentation/screens/review_screen.dart';
import 'package:linguistic_cabinet/features/words/data/models/word.dart';
import 'package:linguistic_cabinet/features/words/data/repositories/word_repository.dart';
import 'package:linguistic_cabinet/features/words/presentation/screens/word_form_screen.dart';
import 'package:linguistic_cabinet/features/words/presentation/screens/word_list_screen.dart';
import 'package:linguistic_cabinet/shared/widgets/cabinet_widgets.dart';

/// settings 맵 기반 가짜 리포.
class FakeSettingsRepository extends ReviewRepository {
  final Map<String, String> settings = {};

  @override
  Future<String?> getSetting(String key) async => settings[key];

  @override
  Future<void> setSetting(String key, String value) async {
    settings[key] = value;
  }

  @override
  Future<Map<String, String>> getSettings(List<String> keys) async => {
        for (final k in keys)
          if (settings[k] != null) k: settings[k]!,
      };

  @override
  Future<Map<String, dynamic>> getReviewStats() async => {
        'totalWords': 0,
        'dueForReview': 0,
        'totalReviews': 0,
        'accuracy': 0,
      };

  @override
  Future<int> getMasteredCount() async => 0;

  @override
  Future<int> getCurrentStreakDays() async => 0;

  @override
  Future<Map<int, int>> getMonthlyStudyDayCounts() async => {};
}

/// 메모리 기반 가짜 단어 리포 — 단어 추가 후 invalidate가 새 목록을 읽는지 검증.
class MutableWordRepository extends WordRepository {
  final List<Word> db = [];

  @override
  Future<List<Word>> getAllWords() async => List.of(db);

  @override
  Future<void> insertWord(Word word) async {
    db.add(word);
  }
}

Future<void> _pumpGuide(WidgetTester tester, {int wordCount = 0}) async {
  final words = List.generate(
    wordCount,
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
        reviewRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        wordListProvider.overrideWith((ref) async => words),
      ],
      child: const MaterialApp(
        home: MasterGardenGuideScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('MasterGardenGuideScreen 렌더링', () {
    testWidgets('해금 조건·진행도·잠금 배지가 보인다', (tester) async {
      await _pumpGuide(tester, wordCount: 1500);

      expect(find.text('BADGE GUIDE'), findsOneWidget);
      expect(find.text('MASTER GARDENER'), findsOneWidget);
      expect(find.text('아직 잠겨 있어요'), findsOneWidget);
      // 해금 조건 카드 (미해금: 일반 아이콘, 체크 없음)
      expect(find.text('단어 수집'), findsOneWidget);
      expect(find.text('2,000단어 모으기'), findsOneWidget);
      expect(find.text('정원 레벨'), findsOneWidget);
      expect(find.text('레벨 20 만개 달성'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.text('달성 완료'), findsNothing);
      // 진행도 (1500 / 2000 · 75%)
      expect(find.text('1,500 / 2,000단어'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.textContaining('500단어를 더 모으면 해금됩니다'), findsOneWidget);
      // 잠금 스타일: 실루엣 트로피 + 잠금 뱃지
      expect(find.byType(CabinetLockBadge), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
      // CTA
      expect(find.text('단어 모으러 가기'), findsOneWidget);
      expect(find.text('수료증 미리보기'), findsOneWidget);
      expect(find.text('업적 컬렉션 보기'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('수료증 미리보기를 탭하면 수료증 화면이 열린다', (tester) async {
      await _pumpGuide(tester, wordCount: 1500);

      // CTA가 화면 아래에 있어 스크롤 후 탭
      await tester.ensureVisible(find.text('수료증 미리보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('수료증 미리보기'));
      await tester.pumpAndSettle();

      expect(
        find.byType(MasterGardenCertificateScreen),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('조건 충족 상태(2,000단어)면 완료 안내가 보인다', (tester) async {
      await _pumpGuide(tester, wordCount: 2000);

      expect(find.text('2,000 / 2,000단어'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(
        find.textContaining('조건을 모두 충족했어요'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('MasterGardenGuideScreen 즉시 갱신', () {
    testWidgets('해금 상태 진입 시 confetti가 한 번 재생된 뒤 사라진다',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewRepositoryProvider.overrideWithValue(
              FakeSettingsRepository(),
            ),
            wordListProvider.overrideWith((ref) async => []),
            masterGardenBadgeProvider.overrideWith((ref) async => '2026-08-08'),
          ],
          child: const MaterialApp(home: MasterGardenGuideScreen()),
        ),
      );
      // 1) 미래 완료 → 해금 감지(포스트프레임) → confetti 오버레이 표시
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CabinetConfettiOverlay), findsOneWidget);

      // 2) 애니메이션 완료(2.2s) 후 onFinished → 오버레이 제거
      await tester.pumpAndSettle();
      expect(find.byType(CabinetConfettiOverlay), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('배지 해금 상태면 해금 UI와 수료증 CTA가 보인다', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewRepositoryProvider.overrideWithValue(
              FakeSettingsRepository(),
            ),
            wordListProvider.overrideWith((ref) async => []),
            masterGardenBadgeProvider.overrideWith((ref) async => '2026-08-08'),
          ],
          child: const MaterialApp(home: MasterGardenGuideScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('해금 완료! 🎉'), findsOneWidget);
      expect(find.text('수료증 보러 가기'), findsOneWidget);
      expect(find.text('단어 모으러 가기'), findsNothing);
      expect(find.text('수료증 미리보기'), findsNothing);
      expect(find.text('ACHIEVED'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
      expect(find.byType(CabinetLockBadge), findsNothing);
      // 조건 카드가 '달성 ✓' 스타일로 전환된다: ✓ 원 2개 + 칩 내부 체크 2개
      expect(find.byIcon(Icons.check), findsNWidgets(4));
      // 값 우측에 '달성 완료' 보조 배지가 붙는다
      expect(find.text('달성 완료'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('수료증 미리보기에서 돌아오면 배지 해금 상태로 즉시 갱신된다',
        (tester) async {
      final settingsRepo = FakeSettingsRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewRepositoryProvider.overrideWithValue(settingsRepo),
            wordListProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(home: MasterGardenGuideScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('아직 잠겨 있어요'), findsOneWidget);

      // 수료증 미리보기 → 수료증 화면 열림
      await tester.ensureVisible(find.text('수료증 미리보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('수료증 미리보기'));
      await tester.pumpAndSettle();
      expect(find.byType(MasterGardenCertificateScreen), findsOneWidget);

      // 수료증이 열린 동안 배지가 해금됐다고 가정 (컬렉션 자가수여 시나리오)
      settingsRepo.settings[AnniversaryService.badgeKey] = '2026-08-08';

      // 뒤로 → CTA의 invalidate → 배지 재조회 → 즉시 해금 UI 갱신
      Navigator.of(
        tester.element(find.byType(MasterGardenCertificateScreen)),
      ).pop();
      await tester.pumpAndSettle();

      expect(find.byType(MasterGardenCertificateScreen), findsNothing);
      expect(find.text('해금 완료! 🎉'), findsOneWidget);
      expect(find.text('수료증 보러 가기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('업적 컬렉션에서 돌아오면 배지 해금 상태로 즉시 갱신된다',
        (tester) async {
      final settingsRepo = FakeSettingsRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewRepositoryProvider.overrideWithValue(settingsRepo),
            wordListProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(home: MasterGardenGuideScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('아직 잠겨 있어요'), findsOneWidget);

      // 업적 컬렉션 → 컬렉션 화면 열림 (자가평가 실행, 통계 0 → 수여 없음)
      await tester.ensureVisible(find.text('업적 컬렉션 보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('업적 컬렉션 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(AchievementCollectionScreen), findsOneWidget);

      // 컬렉션의 자가수여로 배지가 해금됐다고 가정
      settingsRepo.settings[AnniversaryService.badgeKey] = '2026-08-08';

      // 뒤로 → CTA의 invalidate → 배지 재조회 → 즉시 해금 UI 갱신
      Navigator.of(
        tester.element(find.byType(AchievementCollectionScreen)),
      ).pop();
      await tester.pumpAndSettle();

      expect(find.byType(AchievementCollectionScreen), findsNothing);
      expect(find.text('해금 완료! 🎉'), findsOneWidget);
      expect(find.text('수료증 보러 가기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('단어 추가 후 안내 화면으로 복귀하면 진행도가 즉시 갱신된다',
        (tester) async {
      final repo = MutableWordRepository();
      repo.db.addAll(List.generate(
        1500,
        (i) => Word(
          id: 'w$i',
          english: 'word$i',
          korean: '단어$i',
          difficulty: 1,
        ),
      ));

      // wordListProvider를 직접 오버라이드하지 않고 리포를 오버라이드해
      // invalidate → 재조회 → 새 목록 반영 흐름을 실제처럼 검증한다.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewRepositoryProvider.overrideWithValue(
              FakeSettingsRepository(),
            ),
            wordRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(home: MasterGardenGuideScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // 초기 진행도: 1500 / 2000 · 75%
      expect(find.text('1,500 / 2,000단어'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);

      // CTA 탭 → 단어 추가 화면 열림
      await tester.ensureVisible(find.text('단어 모으러 가기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('단어 모으러 가기'));
      await tester.pumpAndSettle();
      expect(find.byType(WordFormScreen), findsOneWidget);

      // 단어 1개 추가 (저장 시나리오 모사)
      await repo.insertWord(
        Word(english: 'new', korean: '새 단어', difficulty: 1),
      );

      // 뒤로 → CTA의 .then(invalidate) → 재조회 → 즉시 갱신
      Navigator.of(tester.element(find.byType(WordFormScreen))).pop();
      await tester.pumpAndSettle();

      expect(find.byType(WordFormScreen), findsNothing);
      expect(find.text('1,501 / 2,000단어'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget); // 1501/2000 = 75.05 → 75
      expect(
        find.textContaining('499단어를 더 모으면 해금됩니다'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
