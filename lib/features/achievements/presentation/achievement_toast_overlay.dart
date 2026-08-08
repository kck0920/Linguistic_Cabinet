import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/cabinet_colors.dart';
import '../../../core/theme/cabinet_theme.dart';
import '../../../shared/widgets/cabinet_widgets.dart';
import '../data/achievement_evaluator.dart';
import '../data/models/achievement.dart';

/// 업적 해금 축하 토스트 오버레이.
/// [achievementEvaluatorProvider]의 해금 스트림을 구독해 **어느 탭에서든**
/// (복습·퀴즈 도중 포함) 새로 해금된 업적을 3초 토스트로 표시한다.
/// 홈 화면 body 위에 배치하며, 터치를 가로채지 않도록 IgnorePointer로 감싼다.
class CabinetAchievementToastOverlay extends ConsumerStatefulWidget {
  const CabinetAchievementToastOverlay({super.key});

  @override
  ConsumerState<CabinetAchievementToastOverlay> createState() =>
      _CabinetAchievementToastOverlayState();
}

class _CabinetAchievementToastOverlayState
    extends ConsumerState<CabinetAchievementToastOverlay>
    with TickerProviderStateMixin {
  final List<_ToastEntry> _toasts = [];
  StreamSubscription<List<Achievement>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref
        .read(achievementEvaluatorProvider)
        .awardedStream
        .listen(_onAwarded);
  }

  void _onAwarded(List<Achievement> awarded) {
    if (!mounted) return;
    for (final a in awarded) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3000),
      );
      final toast = _ToastEntry(a, controller);
      _toasts.add(toast);
      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _toasts.remove(toast));
          controller.dispose();
        }
      });
      controller.forward();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    for (final t in _toasts) {
      t.controller.dispose();
    }
    _toasts.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_toasts.isEmpty) return const SizedBox.shrink();
    final themeMode = ref.watch(cabinetThemeModeProvider);
    final colors = CabinetColors.fromMode(themeMode);
    final theme = CabinetTheme(colors);

    return Column(
      children: [
        for (final toast in _toasts) _buildToast(toast, colors, theme),
      ],
    );
  }

  Widget _buildToast(
    _ToastEntry toast,
    CabinetColors colors,
    CabinetTheme theme,
  ) {
    final a = toast.achievement;
    return AnimatedBuilder(
      animation: toast.controller,
      builder: (context, child) {
        final v = toast.controller.value;
        // 등장(0~0.15): 아래로 슬라이드+페이드 / 유지 / 퇴장(0.85~1): 위로 페이드
        final double opacity;
        final double dy;
        if (v < 0.15) {
          opacity = v / 0.15;
          dy = -14 * (1 - v / 0.15);
        } else if (v > 0.85) {
          opacity = (1 - v) / 0.15;
          dy = -14 * ((v - 0.85) / 0.15);
        } else {
          opacity = 1.0;
          dy = 0;
        }
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, dy),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
        decoration: BoxDecoration(
          color: colors.paper2,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: a.color, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: a.color,
              ),
              child: Icon(a.icon, size: 16, color: colors.paper),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ACHIEVEMENT UNLOCKED',
                  style: theme.labelMono.copyWith(
                    fontSize: 8,
                    color: a.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${a.title} 달성!',
                  style: theme.handNote.copyWith(fontSize: 15),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Transform.rotate(
              angle: -0.15,
              child: CabinetStamp(text: 'NEW!', color: a.color, fontSize: 7),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToastEntry {
  final Achievement achievement;
  final AnimationController controller;

  _ToastEntry(this.achievement, this.controller);
}
