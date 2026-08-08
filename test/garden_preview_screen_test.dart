import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:linguistic_cabinet/dev/garden_preview_screen.dart';
import 'package:linguistic_cabinet/shared/widgets/cabinet_widgets.dart';

void main() {
  group('GardenPreviewScreen', () {
    testWidgets('레벨 0~20 전체 카드가 예외 없이 렌더링된다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: GardenPreviewScreen()),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 레벨별 라벨이 모두 표시된다 (0 / 20 포함).
      // 미리보기 라벨은 'LVL n / 20 · n words' 형식 (정원 카드 헤더와 구분).
      // 단어 수는 레벨 중간값: LVL 0 = (0+5)~/2 = 2, LVL 20 = 2000 (최대 캡).
      expect(find.textContaining('LVL 0 / 20 · 2 words'), findsOneWidget);
      expect(find.textContaining('LVL 20 / 20 · 2000 words'), findsOneWidget);

      // 레벨 카드 21개(0~20) + 개화 시연 카드 1개 = 22개
      final gardens = find.byType(CabinetWordGarden);
      expect(gardens, findsNWidgets(CabinetWordGarden.maxGardenLevel + 2));

      // 개화 시연 버튼이 보인다
      expect(find.textContaining('개화 재생'), findsOneWidget);

      // 스크롤 끝까지 이동하며 화면 하단 카드도 예외 없이 페인팅되는지 확인
      await tester.scrollUntilVisible(
        find.textContaining('LVL 20 / 20 · 2000 words'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('개화 시연 버튼으로 레벨업이 예외 없이 재생된다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: GardenPreviewScreen()),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.scrollUntilVisible(
        find.textContaining('개화 재생'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.textContaining('개화 재생'));
      await tester.pump();
      // 개화 애니메이션 프레임 진행
      for (var t = 0; t < 2000; t += 250) {
        await tester.pump(const Duration(milliseconds: 250));
        expect(tester.takeException(), isNull,
            reason: '개화 시연 t=$t 중 예외');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('테마 칩 전환 시 화면이 예외 없이 다시 그려진다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: GardenPreviewScreen()),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 테마 칩 5개가 표시된다
      for (final label in ['SEPIA', 'FOREST', 'LAVENDER', 'SUNSET', 'MONO']) {
        expect(find.text(label), findsOneWidget);
      }

      // 다른 테마로 전환
      await tester.tap(find.text('SUNSET'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('MONO'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('개발용 게이트 상수 정의', (tester) async {
      // kGardenPreviewEnabled는 컴파일 타임 상수이며 테스트(디버그)에서 true
      expect(kGardenPreviewEnabled, isTrue);
    });
  });
}
