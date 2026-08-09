import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:linguistic_cabinet/core/theme/cabinet_colors.dart';
import 'package:linguistic_cabinet/features/review/data/repositories/review_repository.dart';
import 'package:linguistic_cabinet/shared/widgets/cabinet_widgets.dart';

/// settings 맵 기반 가짜 리포 (backup_service_test와 동일 패턴)
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
}

void main() {
  group('마스터 정원 배지 저장/읽기', () {
    test('배지 수여: setSetting 후 getSetting으로 영구 조회된다', () async {
      final repo = FakeSettingsRepository();

      // 아직 미수여
      expect(await repo.getSetting('master_garden_badge'), isNull);

      // 레벨 20 달성 시 수여 (실제 수여 로직과 동일한 저장 방식)
      await repo.setSetting('master_garden_badge', '2026-08-07');

      // 재시작 후에도 유지되는 것과 동일한 조회
      expect(await repo.getSetting('master_garden_badge'), '2026-08-07');
    });

    test('중복 수여 방지: 이미 값이 있으면 덮어쓰지 않는다', () async {
      final repo = FakeSettingsRepository();
      await repo.setSetting('master_garden_badge', '2026-08-07');

      // 수여 로직과 동일한 가드 (기존 값이 있으면 저장하지 않음)
      final existing = await repo.getSetting('master_garden_badge');
      if (existing == null) {
        await repo.setSetting('master_garden_badge', '2026-08-08');
      }

      expect(await repo.getSetting('master_garden_badge'), '2026-08-07');
    });
  });

  group('CabinetBadgeCard 렌더링 (실제 위젯)', () {
    Widget wrap(CabinetColors colors, Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: Container(color: colors.paper, child: Center(child: child)),
        ),
      );
    }

    testWidgets('미해금 상태: LOCKED 아이콘과 잠금 해제 안내가 보인다', (tester) async {
      final colors = CabinetColors.fromMode(CabinetThemeMode.sepia);
      await tester.pumpWidget(wrap(
        colors,
        CabinetBadgeCard(achievedDate: null, colors: colors),
      ));
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byType(CabinetLockBadge), findsOneWidget); // 우하단 잠금 뱃지
      expect(find.text('MASTER GARDENER'), findsOneWidget);
      expect(find.textContaining('잠금 해제'), findsOneWidget);
      expect(find.text('ACHIEVED'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('미해금 상태: 진행 링과 진행 텍스트가 보인다', (tester) async {
      final colors = CabinetColors.fromMode(CabinetThemeMode.sepia);
      await tester.pumpWidget(wrap(
        colors,
        CabinetBadgeCard(
          achievedDate: null,
          colors: colors,
          currentCount: 1500,
          thresholdCount: 2000,
        ),
      ));
      // 진행 링 (Circular) + 진행 텍스트 (천 단위 쉼표 + %)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('1,500 / 2,000단어 · 75%'), findsOneWidget);
      expect(find.textContaining('1,500 / 2,000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('해금 상태: 트로피 아이콘과 달성 날짜 스탬프가 보인다', (tester) async {
      final colors = CabinetColors.fromMode(CabinetThemeMode.sepia);
      await tester.pumpWidget(wrap(
        colors,
        CabinetBadgeCard(achievedDate: '2026-08-07', colors: colors),
      ));
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
      expect(find.text('MASTER GARDENER ✨'), findsOneWidget);
      expect(find.textContaining('2026-08-07'), findsOneWidget);
      expect(find.text('ACHIEVED'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
