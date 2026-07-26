import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/word.dart';
import '../../data/repositories/word_repository.dart';
import '../../../../core/theme/cabinet_colors.dart';
import '../../../../core/theme/cabinet_theme.dart';
import '../../../../shared/widgets/cabinet_widgets.dart';
import 'word_form_screen.dart';

final wordRepositoryProvider = Provider<WordRepository>((ref) => WordRepository());

final wordListProvider = FutureProvider<List<Word>>((ref) async {
  final repo = ref.watch(wordRepositoryProvider);
  return repo.getAllWords();
});

final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedTagFilterProvider = StateProvider<String>((ref) => 'all');
final sortOrderProvider = StateProvider<String>((ref) => 'recent'); // recent, alpha, mastery

final filteredWordsProvider = FutureProvider<List<Word>>((ref) async {
  final repo = ref.watch(wordRepositoryProvider);
  final query = ref.watch(searchQueryProvider);
  final tagFilter = ref.watch(selectedTagFilterProvider);
  final sortOrder = ref.watch(sortOrderProvider);

  List<Word> words;
  if (query.isEmpty) {
    words = await repo.getAllWords();
  } else {
    words = await repo.searchWords(query);
  }

  // Filter by tag
  if (tagFilter != 'all') {
    words = words.where((w) => w.tags.any((t) => t.toLowerCase() == tagFilter.toLowerCase())).toList();
  }

  // Sort
  if (sortOrder == 'alpha') {
    words.sort((a, b) => a.english.toLowerCase().compareTo(b.english.toLowerCase()));
  } else if (sortOrder == 'mastery') {
    words.sort((a, b) => a.difficulty.compareTo(b.difficulty));
  } else {
    // recent
    words.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  return words;
});

class WordListScreen extends ConsumerWidget {
  const WordListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(cabinetThemeModeProvider);
    final colors = CabinetColors.fromMode(themeMode);
    final theme = CabinetTheme(colors);

    final wordsAsync = ref.watch(filteredWordsProvider);
    final selectedTag = ref.watch(selectedTagFilterProvider);
    final selectedSort = ref.watch(sortOrderProvider);

    return CabinetPaperScaffold(
      colors: colors,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Head (Responsive)
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                if (isMobile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CabinetSectionHead(
                        eyebrow: 'Section 02 · Cabinet',
                        title: 'The Collection',
                        subtitle: wordsAsync.value != null ? '${wordsAsync.value!.length} CARDS CATALOGED' : null,
                        colors: colors,
                      ),
                      const SizedBox(height: 12),
                      CabinetBrutalButton(
                        text: '새 단어 수집',
                        icon: Icons.add,
                        fullWidth: true,
                        onPressed: () {
                          _openWordForm(context, ref, null);
                        },
                      ),
                    ],
                  );
                } else {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: CabinetSectionHead(
                          eyebrow: 'Section 02 · Cabinet',
                          title: 'The Collection',
                          subtitle: wordsAsync.value != null ? '${wordsAsync.value!.length} CARDS CATALOGED' : null,
                          colors: colors,
                        ),
                      ),
                      const SizedBox(width: 12),
                      CabinetBrutalButton(
                        text: '새 단어 수집',
                        icon: Icons.add,
                        onPressed: () {
                          _openWordForm(context, ref, null);
                        },
                      ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 18),

            // Search & Filter Bar
            CabinetPaperCard(
              colors: colors,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                children: [
                  // Search TextField
                  TextField(
                    onChanged: (val) => ref.read(searchQueryProvider.notifier).state = val,
                    style: theme.bodySans,
                    decoration: InputDecoration(
                      hintText: '단어, 뜻, 장소, 메모 검색...',
                      hintStyle: theme.labelMono.copyWith(color: colors.ink3),
                      prefixIcon: Icon(Icons.search, color: colors.ink3, size: 20),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                  const Divider(height: 12),

                  // Tag & Sort Pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text('TAGS: ', style: theme.labelMono.copyWith(fontSize: 9)),
                        const SizedBox(width: 4),
                        _buildPill('ALL', selectedTag == 'all', colors, theme, () {
                          ref.read(selectedTagFilterProvider.notifier).state = 'all';
                        }),
                        const SizedBox(width: 4),
                        _buildPill('GENERAL', selectedTag == 'general', colors, theme, () {
                          ref.read(selectedTagFilterProvider.notifier).state = 'general';
                        }),
                        const SizedBox(width: 4),
                        _buildPill('TOEIC', selectedTag == 'toeic', colors, theme, () {
                          ref.read(selectedTagFilterProvider.notifier).state = 'toeic';
                        }),
                        const SizedBox(width: 16),
                        Text('SORT: ', style: theme.labelMono.copyWith(fontSize: 9)),
                        const SizedBox(width: 4),
                        _buildPill('RECENT', selectedSort == 'recent', colors, theme, () {
                          ref.read(sortOrderProvider.notifier).state = 'recent';
                        }),
                        const SizedBox(width: 4),
                        _buildPill('A-Z', selectedSort == 'alpha', colors, theme, () {
                          ref.read(sortOrderProvider.notifier).state = 'alpha';
                        }),
                        const SizedBox(width: 4),
                        _buildPill('MASTERY', selectedSort == 'mastery', colors, theme, () {
                          ref.read(sortOrderProvider.notifier).state = 'mastery';
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Card Grid
            Expanded(
              child: wordsAsync.when(
                data: (words) {
                  if (words.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CabinetStamp(
                            text: 'CABINET EMPTY',
                            color: colors.ink3,
                            fontSize: 16,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '수집된 단어 카드가 없습니다.\n새 단어 수집 버튼을 눌러 단어를 추가해 보세요!',
                            textAlign: TextAlign.center,
                            style: theme.handNote.copyWith(fontSize: 20, color: colors.ink3),
                          ),
                        ],
                      ),
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 900
                          ? 4
                          : (constraints.maxWidth > 600 ? 3 : 2);

                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.15,
                        ),
                        itemCount: words.length,
                        itemBuilder: (context, index) {
                          final word = words[index];
                          final catNo = 'CAB · #${(index + 1).toString().padLeft(4, '0')}';
                          final tilt = ((index % 7) - 3) * 0.15;

                          return CabinetCatalogCard(
                            catalogNo: catNo,
                            english: word.english,
                            ipa: word.pronunciation,
                            korean: word.korean,
                            tag: word.tags.isNotEmpty ? word.tags.first : 'GENERAL',
                            mastery: 5 - (word.difficulty - 1).clamp(0, 5),
                            colors: colors,
                            rotateDegrees: tilt,
                            onTap: () {
                              _showWordDetailModal(context, ref, word, catNo, colors, theme);
                            },
                          );
                        },
                      );
                    },
                  );
                },
                loading: () => Center(
                  child: CircularProgressIndicator(color: colors.accent),
                ),
                error: (err, stack) => Center(
                  child: Text('오류 발생: $err', style: theme.bodySans),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPill(
    String label,
    bool isSelected,
    CabinetColors colors,
    CabinetTheme theme,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? colors.accent : colors.paper3,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? colors.accent : colors.inkLineStrong,
          ),
        ),
        child: Text(
          label,
          style: theme.labelMono.copyWith(
            fontSize: 9,
            color: isSelected ? colors.paper : colors.ink,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  /// Detail Modal: "The Moment Collected"
  void _showWordDetailModal(
    BuildContext context,
    WidgetRef ref,
    Word word,
    String catalogNo,
    CabinetColors colors,
    CabinetTheme theme,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CabinetPaperCard(
                  colors: colors,
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(catalogNo, style: theme.catalogNo),
                          IconButton(
                            icon: Icon(Icons.close, color: colors.ink),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(word.english, style: theme.wordBig),
                      if (word.pronunciation != null) ...[
                        const SizedBox(height: 4),
                        Text(word.pronunciation!, style: theme.labelMono.copyWith(color: colors.ink3)),
                      ],
                      const SizedBox(height: 16),
                      Text(word.korean, style: theme.meaningSerif.copyWith(fontSize: 22)),
                      if (word.exampleSentence != null && word.exampleSentence!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          '"${word.exampleSentence}"',
                          style: theme.meaningSerif.copyWith(fontSize: 16, color: colors.ink2),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // "The Moment Collected" Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.paper3,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: colors.accent, width: 1.0),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                CabinetStamp(
                                  text: 'COLLECTED MOMENT',
                                  color: colors.accent,
                                  fontSize: 10,
                                ),
                                Text(
                                  word.createdAt.toString().substring(0, 10),
                                  style: theme.catalogNo,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (word.memo != null && word.memo!.isNotEmpty)
                              Text(
                                '"${word.memo}"',
                                style: theme.handNote.copyWith(fontSize: 18),
                              )
                            else
                              Text(
                                '저장된 특별한 순간 메모가 없습니다.',
                                style: theme.handNote.copyWith(fontSize: 16, color: colors.ink4),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: Icon(Icons.delete_outline, color: colors.accent),
                            label: Text('삭제', style: theme.bodySans.copyWith(color: colors.accent)),
                            onPressed: () async {
                              final repo = ref.read(wordRepositoryProvider);
                              await repo.deleteWord(word.id);
                              ref.invalidate(filteredWordsProvider);
                              ref.invalidate(wordListProvider);
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                          const SizedBox(width: 12),
                          CabinetBrutalButton(
                            text: '편집',
                            icon: Icons.edit,
                            onPressed: () {
                              Navigator.pop(context);
                              _openWordForm(context, ref, word);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: -8,
                  left: 20,
                  child: CabinetTape(color: colors.tapeYellow, rotateDegrees: -6),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openWordForm(BuildContext context, WidgetRef ref, Word? word) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WordFormScreen(word: word),
      ),
    ).then((_) {
      ref.invalidate(filteredWordsProvider);
      ref.invalidate(wordListProvider);
    });
  }
}
