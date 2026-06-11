import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/pose_landmark.dart';
import '../theme/tokens.dart';

/// Pose-detection status shown in the right-hand HUD chip — DESIGN SPEC.md
/// §4 驗收標準: 弱光環境pose lost時HUD chip轉黃「RE-ACQUIRING」.
enum PoseLockState { locked, reacquiring }

/// Top HUD — DESIGN SPEC.md §4 版面: 左 `REC 00:42`（紅點閃爍），
/// 右 `POSE LOCKED · 31/33`（綠點，數字=偵測到嘅landmark數）.
class LiveHud extends StatelessWidget {
  const LiveHud({
    super.key,
    required this.recording,
    required this.elapsed,
    required this.poseLockState,
    required this.visibleLandmarkCount,
  });

  final bool recording;
  final Duration elapsed;
  final PoseLockState poseLockState;
  final int visibleLandmarkCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (recording) _RecChip(elapsed: elapsed) else const SizedBox.shrink(),
        _PoseLockChip(state: poseLockState, count: visibleLandmarkCount),
      ],
    );
  }
}

class _RecChip extends StatefulWidget {
  const _RecChip({required this.elapsed});

  final Duration elapsed;

  @override
  State<_RecChip> createState() => _RecChipState();
}

class _RecChipState extends State<_RecChip> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = widget.elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = widget.elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return _HudChip(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 1, end: .25).animate(_controller),
            child: const _Dot(color: AppColors.deficit),
          ),
          const SizedBox(width: 6),
          Text('REC $minutes:$seconds', style: AppText.data(size: 11)),
        ],
      ),
    );
  }
}

class _PoseLockChip extends StatelessWidget {
  const _PoseLockChip({required this.state, required this.count});

  final PoseLockState state;
  final int count;

  @override
  Widget build(BuildContext context) {
    final locked = state == PoseLockState.locked;
    final color = locked ? AppColors.good : AppColors.warn;
    final label = locked
        ? 'POSE LOCKED · $count/${PoseLandmarkIndex.total}'
        : 'RE-ACQUIRING';

    return _HudChip(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: color),
          const SizedBox(width: 6),
          Text(label, style: AppText.data(size: 11)),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            // rgba(0,0,0,.45)
            color: const Color(0x73000000),
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
          child: child,
        ),
      ),
    );
  }
}
