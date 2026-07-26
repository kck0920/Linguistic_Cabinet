import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../words/data/models/word.dart';
import '../../../../core/theme/app_colors.dart';

class WordMatchingScreen extends ConsumerStatefulWidget {
  final List<Word> words;

  const WordMatchingScreen({super.key, required this.words});

  @override
  ConsumerState<WordMatchingScreen> createState() => _WordMatchingScreenState();
}

class _WordMatchingScreenState extends ConsumerState<WordMatchingScreen>
    with SingleTickerProviderStateMixin {
  late List<_MatchingCard> _cards;
  int? _firstSelectedIndex;
  int? _secondSelectedIndex;
  bool _isProcessing = false;
  int _matchedPairs = 0;
  int _totalPairs = 4;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );
    _initializeGame();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _initializeGame() {
    final selectedWords = List.from(widget.words)..shuffle();
    // 단어 수에 따라 카드 수 자동 조절
    int pairCount;
    if (selectedWords.length >= 16) {
      pairCount = 8;
    } else if (selectedWords.length >= 8) {
      pairCount = 6;
    } else {
      pairCount = 4;
    }
    final gameWords = selectedWords.take(pairCount).toList();
    _totalPairs = pairCount;

    _cards = [];
    for (final word in gameWords) {
      _cards.add(_MatchingCard(
        id: word.id,
        content: word.english,
        type: _CardType.word,
        word: word,
        isRevealed: false,
        isMatched: false,
      ));
      _cards.add(_MatchingCard(
        id: word.id,
        content: word.korean,
        type: _CardType.meaning,
        word: word,
        isRevealed: false,
        isMatched: false,
      ));
    }
    _cards.shuffle();
    _matchedPairs = 0;
    _firstSelectedIndex = null;
    _secondSelectedIndex = null;
  }

  void _onCardTap(int index) {
    if (_isProcessing) return;
    if (_cards[index].isMatched) return;
    if (_cards[index].isRevealed) return;
    if (index == _firstSelectedIndex) return;

    setState(() {
      _cards[index].isRevealed = true;

      if (_firstSelectedIndex == null) {
        _firstSelectedIndex = index;
      } else {
        _secondSelectedIndex = index;
        _isProcessing = true;
        _checkMatch();
      }
    });
  }

  void _checkMatch() {
    final firstCard = _cards[_firstSelectedIndex!];
    final secondCard = _cards[_secondSelectedIndex!];

    if (firstCard.id == secondCard.id && firstCard.type != secondCard.type) {
      // Match found
      setState(() {
        firstCard.isMatched = true;
        secondCard.isMatched = true;
        _matchedPairs++;
      });

      _firstSelectedIndex = null;
      _secondSelectedIndex = null;
      _isProcessing = false;

      if (_matchedPairs == _totalPairs) {
        _showCompletionDialog();
      }
    } else {
      // No match - shake and hide
      _shakeController.forward(from: 0).then((_) {
        setState(() {
          firstCard.isRevealed = false;
          secondCard.isRevealed = false;
          _firstSelectedIndex = null;
          _secondSelectedIndex = null;
          _isProcessing = false;
        });
      });
    }
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
        title: Text('매칭 게임 ($_matchedPairs/$_totalPairs)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Game Board
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 360,
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _cards.length,
                    itemBuilder: (context, index) {
                      return _buildCard(index);
                    },
                  ),
                ),
              ),
            ),
            
            // Reset Button
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

  Widget _buildCard(int index) {
    final card = _cards[index];
    final isSelected = index == _firstSelectedIndex || index == _secondSelectedIndex;

    return GestureDetector(
      onTap: () => _onCardTap(index),
      child: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(
              card.isMatched
                  ? 0
                  : isSelected
                      ? _shakeAnimation.value * 5 * (index % 2 == 0 ? 1 : -1)
                      : 0,
              0,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: card.isMatched
                    ? AppColors.matchedCard.withValues(alpha: 0.3)
                    : card.isRevealed
                        ? Theme.of(context).colorScheme.surface
                        : Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: card.isMatched
                      ? AppColors.matchedCard
                      : isSelected
                          ? Theme.of(context).colorScheme.secondary
                          : Theme.of(context).colorScheme.primary,
                  width: isSelected ? 3 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: card.isMatched
                    ? Icon(
                        Icons.check_circle,
                        color: AppColors.matchedCard,
                        size: 48,
                      )
                    : card.isRevealed
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                card.type == _CardType.word
                                    ? Icons.language
                                    : Icons.translate,
                                color: Theme.of(context).colorScheme.primary,
                                size: 24,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                card.content,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        : Icon(
                            Icons.question_mark,
                            color: Colors.white,
                            size: 48,
                          ),
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _CardType { word, meaning }

class _MatchingCard {
  final String id;
  final String content;
  final _CardType type;
  final Word word;
  bool isRevealed;
  bool isMatched;

  _MatchingCard({
    required this.id,
    required this.content,
    required this.type,
    required this.word,
    this.isRevealed = false,
    this.isMatched = false,
  });
}
