import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cabinet_colors.dart';
import '../../core/theme/cabinet_theme.dart';
import '../../shared/widgets/cabinet_widgets.dart';
import '../../features/words/data/models/word.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../features/words/presentation/screens/word_form_screen.dart';
import '../../features/words/presentation/screens/word_list_screen.dart';
import '../home_screen.dart';

/// 대시보드 "오늘의 단어" 카드 — 3D 플립(앞: 영어/뒤: 뜻)과 마스킹 테이프 연출.
/// 단어가 없으면 추가 유도 빈 상태를 보여준다.
class DashboardWordOfDayCard extends ConsumerStatefulWidget {
  const DashboardWordOfDayCard({super.key, required this.word});

  final Word? word;

  @override
  ConsumerState<DashboardWordOfDayCard> createState() =>
      _DashboardWordOfDayCardState();
}

class _DashboardWordOfDayCardState extends ConsumerState<DashboardWordOfDayCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(cabinetThemeModeProvider);
    final colors = CabinetColors.fromMode(themeMode);
    final theme = CabinetTheme(colors);
    final word = widget.word;

    if (word == null) {
      return CabinetPaperCard(
        colors: colors,
        child: SizedBox(
          height: 220,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'No words collected yet.\nTap or click below to start your cabinet!',
                  textAlign: TextAlign.center,
                  style: theme.handNote.copyWith(
                    fontSize: 18,
                    color: colors.ink3,
                  ),
                ),
                const SizedBox(height: 14),
                CabinetBrutalButton(
                  text: '단어 추가하기 (Add Word)',
                  icon: Icons.add,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WordFormScreen(),
                      ),
                    ).then((_) {
                      ref.invalidate(wordListProvider);
                      ref.invalidate(filteredWordsProvider);
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Card Body with 3D Flip
        GestureDetector(
          onTap: _toggleFlip,
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
                    ? _buildFront(word, colors, theme)
                    : Transform(
                        transform: Matrix4.identity()..rotateY(math.pi),
                        alignment: Alignment.center,
                        child: _buildBack(word, colors, theme),
                      ),
              );
            },
          ),
        ),

        // Tape on top left
        Positioned(
          top: -8,
          left: 16,
          child: CabinetTape(color: colors.tapeYellow, rotateDegrees: -8),
        ),
        // Tape on top right
        Positioned(
          top: -6,
          right: 24,
          child: CabinetTape(color: colors.tapePink, rotateDegrees: 5),
        ),
      ],
    );
  }

  Widget _buildFront(Word word, CabinetColors colors, CabinetTheme theme) {
    return CabinetPaperCard(
      colors: colors,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CAB · TODAY\'S WORD', style: theme.labelMono),
              Text(
                'TAP TO FLIP ↺',
                style: theme.labelMono.copyWith(color: colors.accent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(word.english, style: theme.wordHuge.copyWith(color: colors.ink)),
          if (word.pronunciation != null && word.pronunciation!.isNotEmpty) ...[
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  word.pronunciation!,
                  style: theme.labelMono.copyWith(
                    color: colors.ink3,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text('뜻을 떠올려보세요 →', style: theme.handNote.copyWith(fontSize: 20)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#0001 · ${word.tags.isNotEmpty ? word.tags.first.toUpperCase() : 'GENERAL'}',
                style: theme.catalogNo,
              ),
              CabinetBrutalButton(
                text: '오늘 복습',
                icon: Icons.play_arrow,
                onPressed: () {
                  ref.read(currentTabIndexProvider.notifier).state =
                      2; // Move to Review
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBack(Word word, CabinetColors colors, CabinetTheme theme) {
    return CabinetPaperCard(
      colors: colors,
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 380),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('MEANING & CONTEXT', style: theme.labelMono),
                  Text(
                    'TAP TO FLIP ↺',
                    style: theme.labelMono.copyWith(color: colors.accent),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(right: 12, top: 2, bottom: 2),
                child: Text(
                  word.korean,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.meaningSerif.copyWith(
                    fontSize: 22,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (word.exampleSentence != null &&
                  word.exampleSentence!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '"${word.exampleSentence}"',
                  style: theme.meaningSerif.copyWith(
                    fontSize: 15,
                    color: colors.ink2,
                  ),
                ),
              ],
              if (word.memo != null && word.memo!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.paper3,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: colors.inkLineStrong, width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Moment Note:',
                        style: theme.labelMono.copyWith(
                          fontSize: 10,
                          color: colors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      MarkdownBody(
                        data: word.memo!,
                        styleSheet: theme.buildMarkdownStyle(
                          fontSize: 17,
                          textColor: colors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: CabinetBrutalButton(
                  text: '복습 완료',
                  icon: Icons.check,
                  onPressed: _toggleFlip,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
