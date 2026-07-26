import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../words/data/models/word.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../review/presentation/screens/review_screen.dart';

class MeaningTypingScreen extends ConsumerStatefulWidget {
  final List<Word> words;

  const MeaningTypingScreen({super.key, required this.words});

  @override
  ConsumerState<MeaningTypingScreen> createState() => _MeaningTypingScreenState();
}

class _MeaningTypingScreenState extends ConsumerState<MeaningTypingScreen> {
  int _currentIndex = 0;
  int _correctCount = 0;
  String _userInput = '';
  bool _answered = false;
  bool _showHint = false;
  late List<Word> _quizWords;
  final TextEditingController _controller = TextEditingController();
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _quizWords = List.from(widget.words)..shuffle();
    if (_quizWords.length > 10) {
      _quizWords = _quizWords.sublist(0, 10);
    }
    _stopwatch.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    _stopwatch.stop();
    super.dispose();
  }

  bool _checkPartialMatch(String input, String target) {
    final normalizedInput = input.trim().toLowerCase();
    final normalizedTarget = target.trim().toLowerCase();

    if (normalizedInput.isEmpty) return false;

    // 정확히 일치
    if (normalizedInput == normalizedTarget) return true;

    // 부분 일치: 입력이 대상에 포함되거나, 대상이 입력에 포함
    if (normalizedTarget.contains(normalizedInput) ||
        normalizedInput.contains(normalizedTarget)) {
      return true;
    }

    // 콤마/슬래시로 분리된 뜻 중 하나라도 일치
    final alternatives = normalizedTarget
        .split(RegExp(r'[,/;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    for (final alt in alternatives) {
      if (normalizedInput == alt ||
          alt.contains(normalizedInput) ||
          normalizedInput.contains(alt)) {
        return true;
      }
    }

    return false;
  }

  void _checkAnswer() {
    if (_answered || _userInput.trim().isEmpty) return;

    setState(() {
      _answered = true;
    });

    final isCorrect = _checkPartialMatch(
      _userInput,
      _quizWords[_currentIndex].korean,
    );

    if (isCorrect) {
      _correctCount++;
    }

    _recordAnswer(isCorrect);

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _nextQuestion();
      }
    });
  }

  Future<void> _recordAnswer(bool isCorrect) async {
    final repo = ref.read(reviewRepositoryProvider);
    await repo.logReview(
      wordId: _quizWords[_currentIndex].id,
      isCorrect: isCorrect,
      studyMethod: 'meaning_typing',
    );
  }

  void _nextQuestion() {
    if (_currentIndex < _quizWords.length - 1) {
      setState(() {
        _currentIndex++;
        _userInput = '';
        _answered = false;
        _showHint = false;
      });
      _controller.clear();
    } else {
      _showResult();
    }
  }

  void _showResult() {
    _stopwatch.stop();
    final elapsed = _stopwatch.elapsed;
    final accuracy = (_correctCount / _quizWords.length * 100).round();
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('뜻 타이핑 완료!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              accuracy >= 80 ? Icons.celebration : Icons.sentiment_dissatisfied,
              size: 64,
              color: accuracy >= 80 ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              '정답: $_correctCount / ${_quizWords.length}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '정답률: $accuracy%',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: accuracy >= 80 ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '소요 시간: $minutes분 $seconds초',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
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
                _currentIndex = 0;
                _correctCount = 0;
                _userInput = '';
                _answered = false;
                _showHint = false;
                _quizWords.shuffle();
              });
              _controller.clear();
              _stopwatch.reset();
              _stopwatch.start();
            },
            child: const Text('다시 하기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final word = _quizWords[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('뜻 타이핑'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_currentIndex + 1} / ${_quizWords.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      word.english,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (word.pronunciation != null && word.pronunciation!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        word.pronunciation!,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                    if (_showHint && !_answered) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${word.korean[0]}...',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.amber[800],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: '한국어 뜻을 입력하세요',
                hintText: '정답을 입력하세요',
              ),
              onChanged: (value) {
                _userInput = value;
              },
              onSubmitted: (_) => _checkAnswer(),
              enabled: !_answered,
              autofocus: true,
            ),
            const SizedBox(height: 12),

            if (!_answered) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _showHint = !_showHint;
                        });
                      },
                      child: Text(_showHint ? '힌트 숨기기' : '힌트 보기'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _checkAnswer,
                      child: const Text('확인'),
                    ),
                  ),
                ],
              ),
            ],

            if (_answered) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _checkPartialMatch(_userInput, word.korean)
                      ? AppColors.correctAnswer.withValues(alpha: 0.2)
                      : AppColors.wrongAnswer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _checkPartialMatch(_userInput, word.korean)
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: _checkPartialMatch(_userInput, word.korean)
                              ? AppColors.correctAnswer
                              : AppColors.wrongAnswer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _checkPartialMatch(_userInput, word.korean)
                              ? '정답입니다!'
                              : '오답입니다',
                          style: TextStyle(
                            color: _checkPartialMatch(_userInput, word.korean)
                                ? AppColors.correctAnswer
                                : AppColors.wrongAnswer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (!_checkPartialMatch(_userInput, word.korean)) ...[
                      const SizedBox(height: 8),
                      Text(
                        '정답: ${word.korean}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
