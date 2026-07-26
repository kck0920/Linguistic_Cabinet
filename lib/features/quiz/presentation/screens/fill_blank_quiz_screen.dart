import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../words/data/models/word.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../review/presentation/screens/review_screen.dart';

class FillBlankQuizScreen extends ConsumerStatefulWidget {
  final List<Word> words;

  const FillBlankQuizScreen({super.key, required this.words});

  @override
  ConsumerState<FillBlankQuizScreen> createState() => _FillBlankQuizScreenState();
}

class _FillBlankQuizScreenState extends ConsumerState<FillBlankQuizScreen> {
  int _currentIndex = 0;
  int _correctCount = 0;
  String _userInput = '';
  bool _answered = false;
  late List<Word> _quizWords;
  final TextEditingController _controller = TextEditingController();
  DateTime? _questionStartTime;

  @override
  void initState() {
    super.initState();
    _quizWords = List.from(widget.words)..shuffle();
    if (_quizWords.length > 10) {
      _quizWords = _quizWords.sublist(0, 10);
    }
    _questionStartTime = DateTime.now();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _checkAnswer() {
    if (_answered || _userInput.trim().isEmpty) return;

    setState(() {
      _answered = true;
    });

    final isCorrect = _userInput.trim().toLowerCase() == 
        _quizWords[_currentIndex].english.toLowerCase();
    
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
    final durationMs = _questionStartTime != null
        ? DateTime.now().difference(_questionStartTime!).inMilliseconds
        : null;
    await repo.logReview(
      wordId: _quizWords[_currentIndex].id,
      isCorrect: isCorrect,
      studyMethod: 'fill_blank',
      durationMs: durationMs,
    );
  }

  void _nextQuestion() {
    if (_currentIndex < _quizWords.length - 1) {
      setState(() {
        _currentIndex++;
        _userInput = '';
        _answered = false;
        _questionStartTime = DateTime.now();
      });
      _controller.clear();
    } else {
      _showResult();
    }
  }

  void _showResult() {
    final accuracy = (_correctCount / _quizWords.length * 100).round();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('퀴즈 완료!'),
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
    final hasExampleSentence = word.exampleSentence != null && word.exampleSentence!.isNotEmpty;
    final sentence = hasExampleSentence
        ? word.exampleSentence!
        : 'The word "${word.english}" is ___';
    final blankSentence = _getMaskedExample(sentence, word.english);

    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentIndex + 1} / ${_quizWords.length}'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '정답: $_correctCount',
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
                      word.korean,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _answered ? sentence : blankSentence,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: '영어 단어 입력',
                hintText: '정답을 입력하세요',
              ),
              onChanged: (value) {
                _userInput = value;
              },
              onSubmitted: (_) => _checkAnswer(),
              enabled: !_answered,
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
                  color: _userInput.trim().toLowerCase() == word.english.toLowerCase()
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
                          _userInput.trim().toLowerCase() == word.english.toLowerCase()
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: _userInput.trim().toLowerCase() == word.english.toLowerCase()
                              ? AppColors.correctAnswer
                              : AppColors.wrongAnswer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _userInput.trim().toLowerCase() == word.english.toLowerCase()
                              ? '정답입니다!'
                              : '오답입니다',
                          style: TextStyle(
                            color: _userInput.trim().toLowerCase() == word.english.toLowerCase()
                                ? AppColors.correctAnswer
                                : AppColors.wrongAnswer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (_userInput.trim().toLowerCase() != word.english.toLowerCase()) ...[
                      const SizedBox(height: 8),
                      Text(
                        '정답: ${word.english}',
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
