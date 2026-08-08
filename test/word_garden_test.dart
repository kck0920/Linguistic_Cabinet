import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:linguistic_cabinet/core/theme/cabinet_colors.dart';
import 'package:linguistic_cabinet/shared/widgets/cabinet_widgets.dart';

void main() {
  group('CabinetWordGarden.levelForWordCount', () {
    test('레벨 0 (단어 없음 ~ 4개)', () {
      expect(CabinetWordGarden.levelForWordCount(0), 0);
      expect(CabinetWordGarden.levelForWordCount(4), 0);
    });

    test('임계값 공식 5 * n^2 경계', () {
      expect(CabinetWordGarden.levelForWordCount(5), 1); // 5*1^2
      expect(CabinetWordGarden.levelForWordCount(19), 1);
      expect(CabinetWordGarden.levelForWordCount(20), 2); // 5*2^2
      expect(CabinetWordGarden.levelForWordCount(45), 3); // 5*3^2
      expect(CabinetWordGarden.levelForWordCount(80), 4); // 5*4^2
      expect(CabinetWordGarden.levelForWordCount(500), 10); // 5*10^2
      expect(CabinetWordGarden.levelForWordCount(1000), 14); // 980<=1000<1125
      expect(CabinetWordGarden.levelForWordCount(1805), 19); // 5*19^2
      expect(CabinetWordGarden.levelForWordCount(100), 4); // 80<=100<125
    });

    test('최종 레벨 20은 2,000단어, 그 이상은 클램프', () {
      expect(CabinetWordGarden.levelForWordCount(2000), 20);
      expect(CabinetWordGarden.levelForWordCount(2500), 20);
      expect(CabinetWordGarden.levelForWordCount(10000), 20);
    });

    test('thresholdForLevel 역계산 일관성', () {
      expect(CabinetWordGarden.thresholdForLevel(0), 0);
      expect(CabinetWordGarden.thresholdForLevel(1), 5);
      expect(CabinetWordGarden.thresholdForLevel(10), 500);
      expect(CabinetWordGarden.thresholdForLevel(19), 1805);
      expect(CabinetWordGarden.thresholdForLevel(20), 2000);
    });
  });

  group('CabinetWordGarden 꽃/봉오리 배치', () {
    test('bloomAt 임계값이 위→아래 순차 개화하도록 단조 증가한다', () {
      final blooms = CabinetWordGarden.bloomAtProgress;
      expect(blooms.length, CabinetWordGarden.flowerLayout.length,
          reason: '꽃 위치마다 개화 임계값이 하나씩 있어야 한다');
      for (var i = 1; i < blooms.length; i++) {
        expect(blooms[i], greaterThan(blooms[i - 1]),
            reason: '아래로 갈수록 더 나중에 핀다 (단조 증가)');
      }
      expect(blooms.first, greaterThanOrEqualTo(0.4),
          reason: '첫 꽃은 중반 이후에 핀다');
      expect(blooms.last, lessThanOrEqualTo(1.0));
    });

    test('꽃 위치가 줄기 상단~중·하단(0~1)에 분포하고 좌우 대칭 범위 내다', () {
      final layout = CabinetWordGarden.flowerLayout;
      // 줄기 상단부터 중·하단까지 고르게 퍼져 있어야 한다
      expect(layout.first.$1, lessThan(0.1), reason: '상단 꽃이 있어야');
      expect(layout.last.$1, greaterThan(0.75),
          reason: '중·하단 꽃이 있어야');
      // 좌우 오프셋이 캔버스 반폭(75) 안쪽
      for (final (fracY, xOff, _) in layout) {
        expect(fracY, inInclusiveRange(0.0, 1.0));
        expect(xOff.abs(), lessThan(75.0));
      }
    });
  });

  group('CabinetWordGarden 화분 성장 지오메트리', () {
    test('레벨이 오르면 화분이 위로 자라고 더 넓어진다', () {
      final small = CabinetWordGarden.potGeometryForLevel(0);
      final mid = CabinetWordGarden.potGeometryForLevel(10);
      final large = CabinetWordGarden.potGeometryForLevel(20);

      // 화분 높이·폭이 점점 커진다
      expect(large.topWidth, greaterThan(mid.topWidth));
      expect(mid.topWidth, greaterThan(small.topWidth));
      expect(large.bottomWidth, greaterThan(small.bottomWidth));
      expect(large.height, greaterThan(mid.height));
      expect(mid.height, greaterThan(small.height));

      // 화분 위쪽(y)이 점점 올라간다 (바닥 고정, 위로 성장)
      expect(large.potTop, lessThan(mid.potTop));
      expect(mid.potTop, lessThan(small.potTop));

      // 캔버스(150) 밖으로 나가지 않는다
      expect(large.potTop, greaterThanOrEqualTo(0));
      expect(large.potTop + large.height, lessThanOrEqualTo(150));
      expect(large.topWidth, lessThanOrEqualTo(75));
    });

    test('성장 연출(potScale<1)에서 화분 상단이 식물 시작점을 따라간다', () {
      final full = CabinetWordGarden.potGeometryForLevel(10); // 스케일 1.0
      final growing = CabinetWordGarden.potGeometryForLevel(10, potScale: 0.82);

      // 스케일 중엔 화분이 작다 (상단 y가 더 아래)
      expect(growing.potTop, greaterThan(full.potTop));
      expect(growing.height, lessThan(full.height));
      expect(growing.topWidth, lessThan(full.topWidth));

      // 바닥은 항상 고정 (캔버스 150 기준)
      expect(full.potTop + full.height,
          closeTo(growing.potTop + growing.height, 0.001));
      expect(full.potTop + full.height, closeTo(142, 0.001));
    });
  });

  group('CabinetWordGarden 렌더링', () {
    testWidgets('경계 레벨에서 예외 없이 그려진다', (tester) async {
      final colors = CabinetColors.fromMode(CabinetThemeMode.sepia);

      for (final count in [0, 4, 5, 45, 500, 1805, 2000, 2500]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: CabinetWordGarden(
                  colors: colors,
                  totalCount: count,
                  masteredCount: 2,
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull,
            reason: 'totalCount=$count 렌더링 중 예외');
      }
    });

    testWidgets('식물 CustomPaint가 0이 아닌 크기로 렌더링된다 (화분/식물 표시)',
        (tester) async {
      final colors = CabinetColors.fromMode(CabinetThemeMode.sepia);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CabinetWordGarden(colors: colors, totalCount: 0),
            ),
          ),
        ),
      );

      final plantPaint = find.byWidgetPredicate(
        (w) =>
            w is CustomPaint &&
            w.painter != null &&
            w.painter!.runtimeType.toString().contains('PlantPainter'),
      );
      expect(plantPaint, findsOneWidget);

      final size = tester.getSize(plantPaint);
      expect(size.width, greaterThan(0),
          reason: '식물 캔버스 너비가 0이면 화분/식물이 그려지지 않는다');
      expect(size.height, greaterThan(0),
          reason: '식물 캔버스 높이가 0이면 화분/식물이 그려지지 않는다');
      expect(tester.takeException(), isNull);
    });
  });

  group('CabinetWordGarden 레벨업 축하', () {
    Future<ValueNotifier<int>> pumpGarden(WidgetTester tester, int count) async {
      final colors = CabinetColors.fromMode(CabinetThemeMode.sepia);
      final notifier = ValueNotifier<int>(count);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder<int>(
                valueListenable: notifier,
                builder: (context, value, _) => CabinetWordGarden(
                  colors: colors,
                  totalCount: value,
                  masteredCount: 0,
                ),
              ),
            ),
          ),
        ),
      );
      return notifier;
    }

    testWidgets('첫 빌드는 축하 스탬프가 없다 (기준선)', (tester) async {
      await pumpGarden(tester, 5); // 처음부터 레벨 1이어도 축하 없음
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('SPROUTED!'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('레벨 0→1 상승 시 SPROUTED! 스탬프 표시 후 사라짐', (tester) async {
      final notifier = await pumpGarden(tester, 4); // 레벨 0

      notifier.value = 5; // 레벨 0 → 1
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('SPROUTED!'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1500)); // 애니메이션 완료
      expect(find.text('SPROUTED!'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('레벨 상승이 없으면 축하 표시 안 함', (tester) async {
      final notifier = await pumpGarden(tester, 10); // 레벨 1

      notifier.value = 11; // 여전히 레벨 1
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('LEVEL UP'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('마일스톤 레벨 4→5 상승 시 BLOOMED! 스탬프', (tester) async {
      final notifier = await pumpGarden(tester, 124); // 레벨 4

      notifier.value = 125; // 레벨 4 → 5 (마일스톤)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('BLOOMED!'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text('BLOOMED!'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('CabinetWordGarden 개화 애니메이션', () {
    testWidgets('레벨업 시 개화 애니메이션이 예외 없이 재생된다', (tester) async {
      final colors = CabinetColors.fromMode(CabinetThemeMode.sepia);
      final notifier = ValueNotifier<int>(4); // 레벨 0
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder<int>(
                valueListenable: notifier,
                builder: (context, value, _) => CabinetWordGarden(
                  colors: colors,
                  totalCount: value,
                ),
              ),
            ),
          ),
        ),
      );

      // 레벨 10 → tier 0,1이 새로 핀다 (bloomAt 0.50, 0.58)
      notifier.value = 500;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      // 애니메이션 진행 중 프레임별 렌더링
      for (var t = 0; t <= 2000; t += 200) {
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull,
            reason: '개화 애니메이션 프레임 t=$t 중 예외');
      }

      // 애니메이션 종료 후 안정 상태
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });

    testWidgets('첫 빌드는 개화 애니메이션이 없다 (기준선)', (tester) async {
      final colors = CabinetColors.fromMode(CabinetThemeMode.sepia);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CabinetWordGarden(
                colors: colors,
                totalCount: 2000, // 이미 만개 상태로 시작
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('만개 스페셜: 레벨 19→20에서 화분 성장+동시 개화+꽃가루가 예외 없이 재생된다',
        (tester) async {
      final colors = CabinetColors.fromMode(CabinetThemeMode.sepia);
      final notifier = ValueNotifier<int>(1805); // 레벨 19
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder<int>(
                valueListenable: notifier,
                builder: (context, value, _) => CabinetWordGarden(
                  colors: colors,
                  totalCount: value,
                ),
              ),
            ),
          ),
        ),
      );

      notifier.value = 2000; // 레벨 19 → 20 (만개)
      await tester.pump();

      // 만개 스페셜 시퀀스 프레임별 렌더링 (화분 성장 + 동시 개화 + 꽃가루)
      for (var t = 0; t <= 2000; t += 150) {
        await tester.pump(const Duration(milliseconds: 150));
        expect(tester.takeException(), isNull,
            reason: '만개 스페셜 프레임 t=$t 중 예외');
      }
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });
  });

  group('CabinetWordGarden.onLevelUp 콜백', () {
    testWidgets('레벨 상승 시에만 새 레벨로 호출된다', (tester) async {
      final colors = CabinetColors.fromMode(CabinetThemeMode.sepia);
      final notifier = ValueNotifier<int>(4); // 레벨 0
      final levels = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder<int>(
                valueListenable: notifier,
                builder: (context, value, _) => CabinetWordGarden(
                  colors: colors,
                  totalCount: value,
                  onLevelUp: levels.add,
                ),
              ),
            ),
          ),
        ),
      );

      notifier.value = 5; // 0 → 1
      await tester.pump();
      expect(levels, [1]);

      notifier.value = 10; // 같은 레벨 1 → 콜백 없음
      await tester.pump();
      expect(levels, [1]);

      notifier.value = 20; // 1 → 2
      await tester.pump();
      expect(levels, [1, 2]);
      expect(tester.takeException(), isNull);
    });
  });

  group('CabinetConfettiOverlay', () {
    testWidgets('재생 중 예외 없고 완료 시 onFinished 호출', (tester) async {
      final colors = CabinetColors.fromMode(CabinetThemeMode.sepia);
      var finished = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const SizedBox.expand(),
                CabinetConfettiOverlay(
                  colors: colors,
                  big: true,
                  onFinished: () => finished = true,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 1200)); // 재생 중
      expect(tester.takeException(), isNull);
      expect(finished, isFalse);

      await tester.pump(const Duration(milliseconds: 1200)); // 완료
      expect(finished, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('플래시 모드: 반짝이는 프레임에도 예외 없이 그려진다', (tester) async {
      final colors = CabinetColors.fromMode(CabinetThemeMode.sepia);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const SizedBox.expand(),
                CabinetConfettiOverlay(
                  colors: colors,
                  big: true,
                  flash: true,
                ),
              ],
            ),
          ),
        ),
      );

      // 반짝임 구간(0~0.35초)과 이후 페이드아웃 구간을 프레임별 검증
      for (var t = 0; t < 2200; t += 100) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull,
            reason: '플래시 프레임 t=$t 중 예외');
      }
      expect(tester.takeException(), isNull);
    });
  });
}
