import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:linguistic_cabinet/features/achievements/presentation/achievement_collection_screen.dart';
import 'package:linguistic_cabinet/features/achievements/presentation/achievement_detail_screen.dart';
import 'package:linguistic_cabinet/features/review/data/repositories/review_repository.dart';
import 'package:linguistic_cabinet/features/review/presentation/screens/review_screen.dart';
import 'package:linguistic_cabinet/shared/widgets/cabinet_widgets.dart';

/// 스파클은 repeat() 애니메이션이라 pumpAndSettle이 타임아웃된다.
/// 프로바이더 해석 + 렌더링에 필요한 고정 pump를 수행한다.
Future<void> pumpCollection(WidgetTester tester) async {
  await tester.pump(); // 프로바이더 시작
  await tester.pump(const Duration(milliseconds: 50)); // Future 완료 + 빌드
  await tester.pump(const Duration(milliseconds: 16)); // 프레임
}

/// settings 맵 기반 가짜 리포.
/// 컬렉션 화면의 자가평가(evaluateAndAward)가 DB를 건드리지 않도록
/// 통계 조회 메서드도 함께 재정의한다.
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

void main() {
  group('AchievementCollectionScreen 렌더링', () {
    testWidgets('해금/미해금 카드가 카테고리 섹션 그리드로 표시된다', (tester) async {
      final repo = FakeSettingsRepository()
        // 첫 단어 업적만 해금
        ..settings['achv_first_word'] = '2026-08-07';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: AchievementCollectionScreen(),
          ),
        ),
      );
      await pumpCollection(tester);

      // 헤더와 진행도 (전체 28개)
      expect(find.text('ACHIEVEMENTS'), findsOneWidget);
      expect(find.text('Achievement Collection'), findsOneWidget);
      expect(find.text('1 / 28'), findsOneWidget);

      // 카테고리 섹션 라벨
      expect(find.text('COLLECTED WORDS · 단어 수집'), findsOneWidget);
      expect(find.text('MASTERED WORDS · 단어 숙달'), findsOneWidget);
      expect(find.text('STREAK · 연속 학습'), findsOneWidget);
      expect(find.text('MONTHLY CHALLENGE · 월간 도전'), findsOneWidget);
      expect(find.text('MASTER · 정원'), findsOneWidget);

      // 해금된 업적: 제목 캡션 + 달성 날짜 (배지 스타일)
      expect(find.text('First Word'), findsOneWidget);
      expect(find.text('2026.08.07'), findsOneWidget);
      expect(find.text('ACHIEVED'), findsNothing); // 스탬프 없음 (배지 색상으로 해금 표시)

      // 새로 추가된 업적도 목록에 있다
      expect(find.text('Mastered 50'), findsOneWidget);
      expect(find.text('Mastered 200'), findsOneWidget);
      expect(find.text('Mastered 500'), findsOneWidget);
      expect(find.text('Streak 10'), findsOneWidget);
      expect(find.text('Streak 100'), findsOneWidget);
      expect(find.text('January Study'), findsOneWidget);
      expect(find.text('December Study'), findsOneWidget);
      expect(find.text('Master Gardener'), findsOneWidget);

      // 진행 상황 라벨 (미수여 배지: 현재/임계값 + 단위)
      expect(find.text('0 / 10일'), findsOneWidget); // 스트릭
      expect(find.text('0 / 20일'), findsWidgets); // 월간 배지들
      expect(find.text('0 / 100단어'), findsOneWidget); // 수집

      // 해금 배지는 진행률 대신 달성 날짜를 표시한다
      expect(find.text('0 / 1단어'), findsNothing); // First Word는 해금됨

      // 배지 렌더링: 상단 진행바(Linear) 1개 + 배지별 진행 링(Circular) 28개
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNWidgets(28));

      // 해금 배지(First Word)에만 스파클이 렌더링된다
      expect(find.byType(CabinetSparkle), findsOneWidget);

      // 미해금 배지(27개)에만 잠금 뱃지가 표시된다
      expect(find.byType(CabinetLockBadge), findsNWidgets(27));
      expect(find.byIcon(Icons.lock_outline), findsNWidgets(27));

      expect(tester.takeException(), isNull);
    });

    testWidgets('배지를 탭하면 상세 화면으로 이동한다', (tester) async {
      final repo = FakeSettingsRepository()
        // 첫 단어 업적만 해금
        ..settings['achv_first_word'] = '2026-08-07';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: AchievementCollectionScreen(),
          ),
        ),
      );
      await pumpCollection(tester);

      // 스트릭 배지 탭 → 상세 화면 (라우트 전환 300ms)
      await tester.tap(find.text('Streak 10'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AchievementDetailScreen), findsOneWidget);
      expect(find.text('BADGE DETAIL'), findsOneWidget);
      // 라우트 아래 컬렉션 화면도 트리에 남으므로 상세 화면으로 스코프 제한
      Finder inDetail(String text) => find.descendant(
            of: find.byType(AchievementDetailScreen),
            matching: find.text(text),
          );
      expect(inDetail('Streak 10'), findsOneWidget); // 제목
      expect(inDetail('10일 연속 학습'), findsOneWidget); // 설명
      expect(inDetail('조건'), findsOneWidget);
      expect(inDetail('10일'), findsOneWidget);
      expect(inDetail('현재 진행'), findsOneWidget);
      expect(inDetail('달성 날짜'), findsOneWidget);
      expect(inDetail('아직 미달성'), findsOneWidget);

      // 미해금 상세에는 스파클이 없다 (컬렉션의 해금 배지 것만)
      expect(
        find.descendant(
          of: find.byType(AchievementDetailScreen),
          matching: find.byType(CabinetSparkle),
        ),
        findsNothing,
      );

      // 미해금 상세 배지에는 잠금 뱃지가 있다
      expect(
        find.descendant(
          of: find.byType(AchievementDetailScreen),
          matching: find.byType(CabinetLockBadge),
        ),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('해금 배지 상세: 달성 날짜가 표시된다', (tester) async {
      final repo = FakeSettingsRepository()
        ..settings['achv_first_word'] = '2026-08-07';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: AchievementCollectionScreen(),
          ),
        ),
      );
      await pumpCollection(tester);

      // 해금 배지 (First Word) 탭 → 상세 화면 (라우트 전환 300ms)
      await tester.tap(find.text('First Word'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AchievementDetailScreen), findsOneWidget);
      Finder inDetail(String text) => find.descendant(
            of: find.byType(AchievementDetailScreen),
            matching: find.text(text),
          );
      expect(inDetail('ACHIEVED'), findsOneWidget); // 스탬프
      expect(inDetail('2026.08.07'), findsOneWidget); // 달성 날짜
      expect(inDetail('달성 완료'), findsOneWidget); // 현재 진행
      expect(inDetail('이 업적을 달성했습니다!'), findsOneWidget);

      // 해금 상세 배지에도 스파클이 렌더링된다
      expect(
        find.descendant(
          of: find.byType(AchievementDetailScreen),
          matching: find.byType(CabinetSparkle),
        ),
        findsOneWidget,
      );

      // 해금 상세 배지에는 잠금 뱃지가 없다
      expect(
        find.descendant(
          of: find.byType(AchievementDetailScreen),
          matching: find.byType(CabinetLockBadge),
        ),
        findsNothing,
      );

      expect(tester.takeException(), isNull);
    });
  });
}
