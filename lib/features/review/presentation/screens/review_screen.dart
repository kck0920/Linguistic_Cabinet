import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/review_card.dart';
import '../../data/repositories/review_repository.dart';
import '../../../words/data/models/word.dart';
import '../../../words/presentation/screens/word_list_screen.dart';
import '../../../../core/theme/cabinet_colors.dart';
import '../../../../core/theme/cabinet_theme.dart';
import '../../../../shared/widgets/cabinet_widgets.dart';
import 'flashcard_screen.dart';
import '../../../../home/home_dashboard_screen.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) => ReviewRepository());

final dueReviewCardsProvider = FutureProvider<List<ReviewCard>>((ref) async {
  final repo = ref.watch(reviewRepositoryProvider);
  return repo.getDueReviewCards();
});

final reviewStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(reviewRepositoryProvider);
  return repo.getReviewStats();
});

final hasReviewedTodayProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(reviewRepositoryProvider);
  return repo.hasReviewedToday();
});

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureReviewCards();
    });
  }

  Future<void> _ensureReviewCards() async {
    final repo = ref.read(reviewRepositoryProvider);
    final createdCount = await repo.ensureReviewCardsExist();
    if (createdCount > 0) {
      ref.invalidate(dueReviewCardsProvider);
      ref.invalidate(reviewStatsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(cabinetThemeModeProvider);
    final colors = CabinetColors.fromMode(themeMode);
    final theme = CabinetTheme(colors);

    final dueCardsAsync = ref.watch(dueReviewCardsProvider);
    final statsAsync = ref.watch(reviewStatsProvider);
    final hasReviewedTodayAsync = ref.watch(hasReviewedTodayProvider);

    return CabinetPaperScaffold(
      colors: colors,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CabinetSectionHead(
              eyebrow: 'Section 03 · Reading Room',
              title: 'Today\'s Review',
              subtitle: 'Spaced Repetition Flashcards',
              colors: colors,
            ),
            const SizedBox(height: 24),

            // Reading Room Stats Summary
            _buildStatsCard(context, statsAsync, colors, theme),
            const SizedBox(height: 24),

            // Main Review CTA Box
            dueCardsAsync.when(
              data: (cards) {
                if (cards.isEmpty) {
                  return hasReviewedTodayAsync.when(
                    data: (hasReviewed) => _buildEmptyState(context, hasReviewed, colors, theme),
                    loading: () => Center(child: CircularProgressIndicator(color: colors.accent)),
                    error: (_, __) => _buildEmptyState(context, false, colors, theme),
                  );
                }

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CabinetPaperCard(
                      colors: colors,
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CabinetStamp(
                                text: 'READY FOR REVIEW',
                                color: colors.accent,
                                fontSize: 11,
                              ),
                              Text('${cards.length} CARDS DUE', style: theme.catalogNo),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '오늘 복습할 카드가 ${cards.length}개 남아있습니다.',
                            style: theme.wordTitle.copyWith(fontSize: 22),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '카드를 뒤집으며 아는 단어(Known)와 모르는 단어(Again)를 구분해보세요.',
                            style: theme.handNote.copyWith(fontSize: 18, color: colors.ink3),
                          ),
                          const SizedBox(height: 24),
                          CabinetBrutalButton(
                            text: '3D 플립 복습 시작하기',
                            icon: Icons.play_arrow,
                            fullWidth: true,
                            onPressed: () {
                              _startReview(context, cards);
                            },
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: -8,
                      left: 20,
                      child: CabinetTape(color: colors.tapeYellow, rotateDegrees: -4),
                    ),
                  ],
                );
              },
              loading: () => Center(child: CircularProgressIndicator(color: colors.accent)),
              error: (err, stack) => Center(child: Text('오류 발생: $err', style: theme.bodySans)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(
    BuildContext context,
    AsyncValue<Map<String, dynamic>> statsAsync,
    CabinetColors colors,
    CabinetTheme theme,
  ) {
    return CabinetPaperCard(
      colors: colors,
      padding: const EdgeInsets.all(20),
      child: statsAsync.when(
        data: (stats) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total Words', '${stats['totalWords']}', colors, theme),
              _buildStatItem('Due Today', '${stats['dueForReview']}', colors, theme, isAccent: true),
              _buildStatItem('Accuracy', '${stats['accuracy']}%', colors, theme),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: colors.accent)),
        error: (err, stack) => Text('오류: $err', style: theme.bodySans),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    CabinetColors colors,
    CabinetTheme theme, {
    bool isAccent = false,
  }) {
    return Column(
      children: [
        Text(label.toUpperCase(), style: theme.labelMono.copyWith(fontSize: 9)),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.displaySerif.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: isAccent ? colors.accent : colors.ink,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool hasReviewedToday,
    CabinetColors colors,
    CabinetTheme theme,
  ) {
    return CabinetPaperCard(
      colors: colors,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            CabinetStamp(
              text: hasReviewedToday ? 'REVIEW COMPLETED' : 'NO DUE CARDS',
              color: colors.accent3,
              fontSize: 14,
            ),
            const SizedBox(height: 16),
            Text(
              hasReviewedToday ? '오늘의 복습을 모두 완료했습니다!' : '현재 복습할 카드가 없습니다.',
              style: theme.wordTitle.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 8),
            Text(
              hasReviewedToday ? '훌륭합니다! 내일 다시 방문해 주세요.' : '새 단어를 컬렉션에 추가하거나 나중에 다시 확인해 보세요.',
              textAlign: TextAlign.center,
              style: theme.handNote.copyWith(fontSize: 18, color: colors.ink3),
            ),
          ],
        ),
      ),
    );
  }

  void _startReview(BuildContext context, List<ReviewCard> cards) async {
    final wordRepo = ref.read(wordRepositoryProvider);
    final words = <Word>[];
    for (final card in cards) {
      final word = await wordRepo.getWordById(card.wordId);
      if (word != null) {
        words.add(word);
      }
    }

    if (words.isNotEmpty && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FlashcardScreen(words: words),
        ),
      ).then((_) {
        ref.invalidate(dueReviewCardsProvider);
        ref.invalidate(reviewStatsProvider);
        ref.invalidate(streakDataProvider);
      });
    }
  }
}
