import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../words/data/models/word.dart';
import '../../../../core/theme/cabinet_colors.dart';
import '../../../../core/theme/cabinet_theme.dart';
import '../../../../shared/widgets/cabinet_widgets.dart';
import 'review_screen.dart';

class FlashcardScreen extends ConsumerStatefulWidget {
  final List<Word> words;

  const FlashcardScreen({super.key, required this.words});

  @override
  ConsumerState<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends ConsumerState<FlashcardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  int _currentIndex = 0;
  bool _isFlipped = false;
  String? _lastStamp; // 'KNOWN' or 'AGAIN'
  FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _handleAnswer(bool known) async {
    setState(() {
      _lastStamp = known ? 'KNOWN' : 'AGAIN';
    });

    final repo = ref.read(reviewRepositoryProvider);
    final word = widget.words[_currentIndex];
    final quality = known ? 4 : 1;
    await repo.logReview(
      wordId: word.id,
      isCorrect: known,
      studyMethod: 'flashcard',
    );
    await repo.updateReviewCardWithSM2(wordId: word.id, quality: quality);

    await Future.delayed(const Duration(milliseconds: 400));

    if (_currentIndex < widget.words.length - 1) {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
        _lastStamp = null;
      });
      _flipController.reset();
    } else {
      _showDoneDialog();
    }
  }

  void _showDoneDialog() {
    final themeMode = ref.read(cabinetThemeModeProvider);
    final colors = CabinetColors.fromMode(themeMode);
    final theme = CabinetTheme(colors);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.paper2,
          title: Text('복습 완료!', style: theme.wordTitle),
          content: Text('오늘의 모든 복습 카드를 완료하셨습니다!', style: theme.handNote.copyWith(fontSize: 18)),
          actions: [
            CabinetBrutalButton(
              text: '홈으로 돌아가기',
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(cabinetThemeModeProvider);
    final colors = CabinetColors.fromMode(themeMode);
    final theme = CabinetTheme(colors);

    final word = widget.words[_currentIndex];

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.space) {
            _toggleFlip();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _handleAnswer(false);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _handleAnswer(true);
          }
        }
      },
      child: CabinetPaperScaffold(
        colors: colors,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: colors.ink),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'REVIEW · ${_currentIndex + 1} / ${widget.words.length}',
            style: theme.labelMono.copyWith(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // Segmented Progress Bar
              Row(
                children: List.generate(widget.words.length, (index) {
                  final isDone = index < _currentIndex;
                  final isCurrent = index == _currentIndex;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: isDone
                            ? colors.accent3
                            : (isCurrent ? colors.accent : colors.inkLine),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Main Flashcard Container
              Expanded(
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: _toggleFlip,
                        onHorizontalDragEnd: (details) {
                          if (details.primaryVelocity != null) {
                            if (details.primaryVelocity! > 100) {
                              _handleAnswer(true); // Swipe Right -> Known
                            } else if (details.primaryVelocity! < -100) {
                              _handleAnswer(false); // Swipe Left -> Again
                            }
                          }
                        },
                        child: AnimatedBuilder(
                          animation: _flipController,
                          builder: (context, child) {
                            final angle = _flipController.value * math.pi;
                            final isFront = angle < math.pi / 2;
                            return Transform(
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001)
                                ..rotateY(angle),
                              alignment: Alignment.center,
                              child: isFront
                                  ? _buildFrontCard(word, colors, theme)
                                  : Transform(
                                      transform: Matrix4.identity()..rotateY(math.pi),
                                      alignment: Alignment.center,
                                      child: _buildBackCard(word, colors, theme),
                                    ),
                            );
                          },
                        ),
                      ),

                      // Stamp Overlay on Action
                      if (_lastStamp != null)
                        Positioned.fill(
                          child: Center(
                            child: CabinetStamp(
                              text: _lastStamp!,
                              color: _lastStamp == 'KNOWN' ? colors.accent3 : colors.accent,
                              fontSize: 32,
                              rotateDegrees: _lastStamp == 'KNOWN' ? 12 : -12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Control Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: CabinetBrutalButton(
                      text: '다시 (Again)',
                      icon: Icons.refresh,
                      bg: colors.paper2,
                      textColor: colors.accent,
                      onPressed: () => _handleAnswer(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CabinetBrutalButton(
                    text: '뒤집기 (Space)',
                    icon: Icons.flip,
                    onPressed: _toggleFlip,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CabinetBrutalButton(
                      text: '알았다 (Known)',
                      icon: Icons.check,
                      bg: colors.accent3,
                      textColor: colors.paper,
                      onPressed: () => _handleAnswer(true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFrontCard(Word word, CabinetColors colors, CabinetTheme theme) {
    return CabinetPaperCard(
      colors: colors,
      width: 540,
      height: 380,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('READING CARD · FRONT', style: theme.labelMono),
          const Spacer(),
          Text(word.english, style: theme.wordHuge),
          if (word.pronunciation != null) ...[
            const SizedBox(height: 8),
            Text(word.pronunciation!, style: theme.labelMono.copyWith(fontSize: 14)),
          ],
          const Spacer(),
          Text('뜻이 떠오르나요? Tap to flip ↺', style: theme.handNote.copyWith(fontSize: 20)),
        ],
      ),
    );
  }

  Widget _buildBackCard(Word word, CabinetColors colors, CabinetTheme theme) {
    return CabinetPaperCard(
      colors: colors,
      width: 540,
      height: 380,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('READING CARD · BACK', style: theme.labelMono),
          const Spacer(),
          Text(word.korean, style: theme.meaningSerif.copyWith(fontSize: 28, fontWeight: FontWeight.w600)),
          if (word.exampleSentence != null && word.exampleSentence!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '"${word.exampleSentence}"',
              textAlign: TextAlign.center,
              style: theme.meaningSerif.copyWith(fontSize: 16, color: colors.ink2),
            ),
          ],
          if (word.memo != null && word.memo!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Moment: ${word.memo}',
              style: theme.handNote.copyWith(fontSize: 18),
            ),
          ],
          const Spacer(),
        ],
      ),
    );
  }
}
