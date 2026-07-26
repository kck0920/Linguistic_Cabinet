import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../words/data/models/word.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../review/presentation/screens/review_screen.dart';

class SpellingTypingScreen extends ConsumerStatefulWidget {
  final List<Word> words;

  const SpellingTypingScreen({super.key, required this.words});

  @override
  ConsumerState<SpellingTypingScreen> createState() => _SpellingTypingScreenState();
}

class _SpellingTypingScreenState extends ConsumerState<SpellingTypingScreen> {
  int _currentIndex = 0;
  int _correctCount = 0;
  String _userInput = '';
  bool _answered = false;
  int _tolerance = 1;
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

  int _levenshteinDistance(String a, String b) {
    a = a.toLowerCase();
    b = b.toLowerCase();
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<List<int>> matrix = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => 0),
    );

    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        int cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[a.length][b.length];
  }

  bool _isWithinTolerance(String input, String target) {
    final normalizedInput = input.trim().toLowerCase();
    final normalizedTarget = target.trim().toLowerCase();

    if (normalizedInput.isEmpty) return false;
    if (normalizedInput == normalizedTarget) return true;

    final distance = _levenshteinDistance(normalizedInput, normalizedTarget);
    return distance <= _tolerance;
  }

  void _checkAnswer() {
    if (_answered || _userInput.trim().isEmpty) return;

    setState(() {
      _answered = true;
    });

    final isCorrect = _isWithinTolerance(
      _userInput,
      _quizWords[_currentIndex].english,
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
      studyMethod: 'spelling_typing',
    );
  }

  void _nextQuestion() {
    if (_currentIndex < _quizWords.length - 1) {
      setState(() {
        _currentIndex++;
        _userInput = '';
        _answered = false;
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
        title: const Text('철자 타이핑 완료!'),
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

  String _getMaskedExample(String sentence, String word) {
    if (sentence.isEmpty || word.isEmpty) return sentence;
    final regex = RegExp(r'\b' + RegExp.escape(word) + r'\w*', caseSensitive: false);
    return sentence.replaceAllMapped(regex, (match) {
      final matchedText = match.group(0)!;
      return matchedText.split('').map((char) {
        if (RegExp(r'[a-zA-Z0-9]').hasMatch(char)) {
          return '_';
        }
        return char;
      }).join('');
    });
  }

  @override
  Widget build(BuildContext context) {
    final word = _quizWords[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('철자 타이핑'),
        actions: [
          PopupMenuButton<int>(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tune),
                const SizedBox(width: 4),
                Text(
                  '허용: $_tolerance',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            onSelected: (value) {
              setState(() {
                _tolerance = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 0,
                child: Text('정확히 일치 (허용 없음)'),
              ),
              const PopupMenuItem(
                value: 1,
                child: Text('1글자 오탈 허용'),
              ),
              const PopupMenuItem(
                value: 2,
                child: Text('2글자 오탈 허용'),
              ),
              const PopupMenuItem(
                value: 3,
                child: Text('3글자 오탈 허용'),
              ),
            ],
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
                      word.korean,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (word.exampleSentence != null && word.exampleSentence!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _answered
                            ? word.exampleSentence!
                            : _getMaskedExample(word.exampleSentence!, word.english),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
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
                labelText: '영어 단어를 입력하세요',
                hintText: '정답을 입력하세요',
              ),
              onChanged: (value) {
                _userInput = value;
              },
              onSubmitted: (_) => _checkAnswer(),
              enabled: !_answered,
              autofocus: true,
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _answered ? null : _checkAnswer,
              child: const Text('확인'),
            ),

            if (_answered) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isWithinTolerance(_userInput, word.english)
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
                          _isWithinTolerance(_userInput, word.english)
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: _isWithinTolerance(_userInput, word.english)
                              ? AppColors.correctAnswer
                              : AppColors.wrongAnswer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isWithinTolerance(_userInput, word.english)
                              ? '정답입니다!'
                              : '오답입니다',
                          style: TextStyle(
                            color: _isWithinTolerance(_userInput, word.english)
                                ? AppColors.correctAnswer
                                : AppColors.wrongAnswer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (!_isWithinTolerance(_userInput, word.english)) ...[
                      const SizedBox(height: 8),
                      Text(
                        '정답: ${word.english}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_userInput.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '입력: $_userInput (편집거리: ${_levenshteinDistance(_userInput, word.english)})',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
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
