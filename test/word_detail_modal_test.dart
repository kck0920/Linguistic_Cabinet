import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguistic_cabinet/features/words/data/models/word.dart';
import 'package:linguistic_cabinet/features/words/data/repositories/word_repository.dart';
import 'package:linguistic_cabinet/features/words/presentation/screens/word_list_screen.dart';
import 'package:linguistic_cabinet/shared/widgets/cabinet_surfaces.dart';
import 'helpers.dart';

class FakeWordRepository extends WordRepository {
  final List<Word> words;
  FakeWordRepository(this.words);

  @override
  Future<List<Word>> getAllWords() async => words;

  @override
  Future<List<Word>> searchWords(String query) async => words;

  @override
  Future<List<Word>> getWordsByTag(String tag) async => words;
}

void main() {
  final testWord = Word(
    id: 'test-1',
    english: 'such',
    korean: '그토록, 너무나',
    pronunciation: '/sʌtʃ/',
    difficulty: 3,
    createdAt: DateTime.now(),
  );

  testWidgets('단어 상세 모달 너비 - 대형 데스크탑(1400px)에서 최대 960px로 확장된다', (WidgetTester tester) async {
    ignoreTestFontOverflow();
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = FakeWordRepository([testWord]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wordRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: WordListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 단어 카드 탭하여 모달 열기
    await tester.tap(find.byType(CabinetCatalogCard));
    await tester.pumpAndSettle();

    // 모달 내 CabinetPaperCard 너비 확인 (최대 960px)
    final paperCards = tester.widgetList<CabinetPaperCard>(find.byType(CabinetPaperCard));
    // 모달 내부의 카드는 width 속성이 설정되어 있음
    final modalCard = paperCards.firstWhere((c) => c.width != null);
    expect(modalCard.width, equals(960.0));
  });

  testWidgets('단어 상세 모달 너비 - 중간 데스크탑(1000px)에서 75% 너비(750px)로 계산된다', (WidgetTester tester) async {
    ignoreTestFontOverflow();
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = FakeWordRepository([testWord]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wordRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: WordListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 단어 카드 탭하여 모달 열기
    await tester.tap(find.byType(CabinetCatalogCard));
    await tester.pumpAndSettle();

    final paperCards = tester.widgetList<CabinetPaperCard>(find.byType(CabinetPaperCard));
    final modalCard = paperCards.firstWhere((c) => c.width != null);
    expect(modalCard.width, equals(750.0));
  });

  testWidgets('단어 상세 모달 너비 - 모바일(400px)에서 여백을 제외한 368px로 제약된다', (WidgetTester tester) async {
    ignoreTestFontOverflow();
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = FakeWordRepository([testWord]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wordRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: WordListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 단어 카드 탭하여 모달 열기
    await tester.tap(find.byType(CabinetCatalogCard));
    await tester.pumpAndSettle();

    final paperCards = tester.widgetList<CabinetPaperCard>(find.byType(CabinetPaperCard));
    final modalCard = paperCards.firstWhere((c) => c.width != null);
    expect(modalCard.width, equals(368.0));
  });
}
