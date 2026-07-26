import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../words/data/models/word.dart';
import '../../../words/presentation/screens/word_list_screen.dart';
import '../../../../core/theme/cabinet_colors.dart';
import '../../../../core/theme/cabinet_theme.dart';
import '../../../../shared/widgets/cabinet_widgets.dart';
import 'meaning_quiz_screen.dart';
import 'fill_blank_quiz_screen.dart';
import 'meaning_typing_screen.dart';
import 'spelling_typing_screen.dart';

final quizWordsProvider = FutureProvider<List<Word>>((ref) async {
  final repo = ref.watch(wordRepositoryProvider);
  final words = await repo.getAllWords();
  if (words.length < 4) return [];
  final list = List<Word>.from(words)..shuffle();
  return list.take(10).toList();
});

class QuizScreen extends ConsumerWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(cabinetThemeModeProvider);
    final colors = CabinetColors.fromMode(themeMode);
    final theme = CabinetTheme(colors);

    final wordsAsync = ref.watch(quizWordsProvider);

    return CabinetPaperScaffold(
      colors: colors,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CabinetSectionHead(
              eyebrow: 'Section 04 · Examination',
              title: 'Knowledge Quiz',
              subtitle: '4 Examination Modes Available',
              colors: colors,
            ),
            const SizedBox(height: 24),

            wordsAsync.when(
              data: (words) {
                if (words.isEmpty) {
                  return _buildEmptyState(colors, theme);
                }
                return _buildExamGrid(context, words, colors, theme);
              },
              loading: () => Center(child: CircularProgressIndicator(color: colors.accent)),
              error: (err, stack) => Center(child: Text('오류: $err', style: theme.bodySans)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(CabinetColors colors, CabinetTheme theme) {
    return CabinetPaperCard(
      colors: colors,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            CabinetStamp(text: 'MINIMUM 4 WORDS REQUIRED', color: colors.accent),
            const SizedBox(height: 16),
            Text(
              '퀴즈를 시작하려면 최소 4개 이상의 단어가 필요합니다.',
              style: theme.wordTitle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              '컬렉션에 새 단어를 먼저 추가해 보세요!',
              style: theme.handNote.copyWith(fontSize: 18, color: colors.ink3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamGrid(
    BuildContext context,
    List<Word> words,
    CabinetColors colors,
    CabinetTheme theme,
  ) {
    final examOptions = [
      {
        'examNo': 'EXAM · 01',
        'title': '뜻 맞추기',
        'sub': 'Meaning Multiple Choice',
        'desc': '단어를 보고 4가지 선택지 중 올바른 뜻을 골라보세요.',
        'tapeColor': colors.tapeYellow,
        'onStart': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MeaningQuizScreen(words: words)),
          );
        },
      },
      {
        'examNo': 'EXAM · 02',
        'title': '빈칸 채우기',
        'sub': 'Fill in the Blank',
        'desc': '예문의 마스킹 빈칸에 들어갈 알맞은 단어를 선택하세요.',
        'tapeColor': colors.tapePink,
        'onStart': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FillBlankQuizScreen(words: words)),
          );
        },
      },
      {
        'examNo': 'EXAM · 03',
        'title': '뜻 타이핑',
        'sub': 'Meaning Typing Exam',
        'desc': '단어를 보고 한국어 뜻을 주관식으로 직접 입력하세요.',
        'tapeColor': colors.tapeBlue,
        'onStart': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MeaningTypingScreen(words: words)),
          );
        },
      },
      {
        'examNo': 'EXAM · 04',
        'title': '철자 타이핑',
        'sub': 'Spelling Typing Exam',
        'desc': '뜻을 보고 알맞은 영어 철자를 주관식으로 입력하세요.',
        'tapeColor': colors.tapeGreen,
        'onStart': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SpellingTypingScreen(words: words)),
          );
        },
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 750 ? 2 : 1;
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.6,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: examOptions.length,
          itemBuilder: (context, index) {
            final exam = examOptions[index];
            return Stack(
              clipBehavior: Clip.none,
              children: [
                CabinetPaperCard(
                  colors: colors,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(exam['examNo'] as String, style: theme.catalogNo),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.paper3,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text('10 QUESTIONS', style: theme.labelMono.copyWith(fontSize: 8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        exam['title'] as String,
                        style: theme.wordTitle.copyWith(fontSize: 22),
                      ),
                      Text(
                        exam['sub'] as String,
                        style: theme.labelMono.copyWith(color: colors.ink3, fontSize: 10),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        exam['desc'] as String,
                        style: theme.handNote.copyWith(fontSize: 16),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: CabinetBrutalButton(
                          text: '시험 시작 (START)',
                          icon: Icons.play_arrow,
                          onPressed: exam['onStart'] as VoidCallback,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: -6,
                  left: 18,
                  child: CabinetTape(
                    color: exam['tapeColor'] as Color,
                    rotateDegrees: (index % 2 == 0) ? -5 : 4,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
