import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../words/data/models/word.dart';
import '../../../../core/theme/app_colors.dart';

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
            _showCompletionDialog();
          }
        } else {
          _firstSelected!.isSelected = false;
        }
        _firstSelected = null;
      }
    });
  }

  void _showCompletionDialog() {
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
