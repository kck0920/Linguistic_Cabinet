import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../words/data/models/word.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../review/presentation/screens/review_screen.dart';

class MeaningQuizScreen extends ConsumerStatefulWidget {
  final List<Word> words;

  const MeaningQuizScreen({super.key, required this.words});

  @override
  ConsumerState<MeaningQuizScreen> createState() => _MeaningQuizScreenState();
}

class _MeaningQuizScreenState extends ConsumerState<MeaningQuizScreen> {
  int _currentIndex = 0;
  int _correctCount = 0;
  int? _selectedAnswer;
  bool _answered = false;
  late List<Word> _quizWords;
  List<String> _currentOptions = [];
  DateTime? _questionStartTime;

  @override
  void initState() {
    super.initState();
    _quizWords = List.from(widget.words)..shuffle();
    if (_quizWords.length > 10) {
      _quizWords = _quizWords.sublist(0, 10);
    }
    _generateOptions();
    _questionStartTime = DateTime.now();
  }

  void _generateOptions() {
    if (_quizWords.isEmpty) return;
    
    final correctAnswer = _quizWords[_currentIndex].korean;
    final allKoreanWords = widget.words.map((w) => w.korean).toList();
    allKoreanWords.remove(correctAnswer);
    allKoreanWords.shuffle();
    
    final options = [correctAnswer];
    options.addAll(allKoreanWords.take(3));
    options.shuffle();
    
    _currentOptions = options;
  }

  void _selectAnswer(int index) {
    if (_answered) return;
    
    setState(() {
      _selectedAnswer = index;
      _answered = true;
    });

    final isCorrect = _currentOptions[index] == _quizWords[_currentIndex].korean;
    if (isCorrect) {
      _correctCount++;
    }

    _recordAnswer(isCorrect);

    Future.delayed(const Duration(seconds: 1), () {
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
      studyMethod: 'meaning_quiz',
      durationMs: durationMs,
    );
  }

  void _nextQuestion() {
    if (_currentIndex < _quizWords.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _answered = false;
        _generateOptions();
        _questionStartTime = DateTime.now();
      });
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
                _selectedAnswer = null;
                _answered = false;
                _quizWords.shuffle();
                _generateOptions();
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
    final word = _quizWords[_currentIndex];
    final options = _currentOptions;

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
                      word.english,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            ...List.generate(4, (index) {
              final option = options[index];
              final isSelected = _selectedAnswer == index;
              final isCorrectOption = option == word.korean;
              
              Color? backgroundColor;
              if (_answered) {
                if (isCorrectOption) {
                  backgroundColor = AppColors.correctAnswer.withValues(alpha: 0.2);
                } else if (isSelected && !isCorrectOption) {
                  backgroundColor = AppColors.wrongAnswer.withValues(alpha: 0.2);
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton(
                  onPressed: () => _selectAnswer(index),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: backgroundColor,
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.centerLeft,
                  ),
                  child: Text(
                    option,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
