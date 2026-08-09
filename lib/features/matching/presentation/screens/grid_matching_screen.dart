import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../words/data/models/word.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../review/presentation/screens/review_screen.dart';
import '../../../achievements/data/achievement_evaluator.dart';

class GridMatchingScreen extends ConsumerStatefulWidget {
  final List<Word> words;

  const GridMatchingScreen({super.key, required this.words});

  @override
  ConsumerState<GridMatchingScreen> createState() => _GridMatchingScreenState();
}

class _GridMatchingScreenState extends ConsumerState<GridMatchingScreen> {
  late List<_GridItem> _items;
  _GridItem? _firstSelected;
  int _matchedCount = 0;
  int _totalPairs = 6;
  late int _crossAxisCount;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  void _initializeGame() {
    final selectedWords = List.from(widget.words)..shuffle();
    final pairCount = selectedWords.length.clamp(3, 6);
    final gameWords = selectedWords.take(pairCount).toList();
    _totalPairs = pairCount;

    _items = [];
    for (final word in gameWords) {
      _items.add(_GridItem(
        id: word.id,
        content: word.english,
        type: _ItemType.word,
        isSelected: false,
        isMatched: false,
      ));
      _items.add(_GridItem(
        id: word.id,
        content: word.korean,
        type: _ItemType.meaning,
        isSelected: false,
        isMatched: false,
      ));
    }
    _items.shuffle();

    final itemCount = _items.length;
    if (itemCount <= 8) {
      _crossAxisCount = 4;
    } else if (itemCount <= 12) {
      _crossAxisCount = 3;
    } else {
      _crossAxisCount = 4;
    }

    _matchedCount = 0;
    _firstSelected = null;
  }

  void _onItemTap(_GridItem item) {
    if (item.isMatched) return;
    if (_firstSelected == item) return;

    setState(() {
      if (_firstSelected == null) {
        _firstSelected = item;
        item.isSelected = true;
      } else {
        if (_firstSelected!.id == item.id && _firstSelected!.type != item.type) {
          _firstSelected!.isMatched = true;
          _firstSelected!.isSelected = false;
          item.isMatched = true;
          _matchedCount++;

          if (_matchedCount == _totalPairs) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                _showCompletionDialog();
              }
            });
          }
        } else {
          _firstSelected!.isSelected = false;
        }
        _firstSelected = null;
      }
    });
  }

  /// 매칭 완료 시 각 매칭 쌍 단어를 복습 로그로 기록하고 복습 일정에 반영한다.
  /// (같은 단어는 word/meaning 타일 2장이므로 중복 없이 1회만 기록)
  /// 퀴즈와 동일하게 logReview + processReviewResult(일정 갱신)를 함께 호출한다.
  Future<void> _logMatchedWords() async {
    final repo = ref.read(reviewRepositoryProvider);
    final loggedIds = <String>{};
    for (final item in _items) {
      if (!item.isMatched) continue;
      if (!loggedIds.add(item.id)) continue;
      await repo.logReview(
        wordId: item.id,
        isCorrect: true,
        studyMethod: 'grid_matching',
      );
      await repo.processReviewResult(
        wordId: item.id,
        isCorrect: true,
      );
    }
    // 기록 직후 업적을 즉시 평가한다 (재시작 없이 해금/토스트, fire-and-forget).
    unawaited(ref.read(achievementEvaluatorProvider).evaluateNow());
  }

  Future<void> _showCompletionDialog() async {
    // 로깅 실패가 완료 다이얼로그를 막지 않도록 격리한다.
    try {
      await _logMatchedWords();
    } catch (_) {}
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('매칭 완료!'),
        content: const Text('모든 쌍을 찾았습니다!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('확인'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _initializeGame();
              });
            },
            child: const Text('다시 하기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('그리드 매칭 ($_matchedCount/$_totalPairs)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '같은 뜻의 영어 단어와 한국어를 순서대로 탭하세요',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _crossAxisCount,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  return _buildGridItem(_items[index]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _initializeGame();
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시작'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridItem(_GridItem item) {
    Color backgroundColor;
    Color borderColor;

    if (item.isMatched) {
      backgroundColor = AppColors.matchedCard.withValues(alpha: 0.3);
      borderColor = AppColors.matchedCard;
    } else if (item.isSelected) {
      backgroundColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.2);
      borderColor = Theme.of(context).colorScheme.primary;
    } else {
      backgroundColor = Theme.of(context).colorScheme.surface;
      borderColor = Theme.of(context).colorScheme.outline;
    }

    return GestureDetector(
      onTap: () => _onItemTap(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: item.isSelected ? 3 : 1,
          ),
        ),
        child: Center(
          child: item.isMatched
              ? Icon(
                  Icons.check_circle,
                  color: AppColors.matchedCard,
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.type == _ItemType.word
                          ? Icons.language
                          : Icons.translate,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.content,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

enum _ItemType { word, meaning }

class _GridItem {
  final String id;
  final String content;
  final _ItemType type;
  bool isSelected;
  bool isMatched;

  _GridItem({
    required this.id,
    required this.content,
    required this.type,
    this.isSelected = false,
    this.isMatched = false,
  });
}
