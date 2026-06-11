import 'dart:async';

import 'package:flutter/material.dart';

import '../cv/camera_pose_source.dart';
import '../cv/pose_source.dart';
import '../models/pose_landmark.dart';
import '../theme/tokens.dart';
import '../widgets/live_drawer.dart';
import '../widgets/live_hud.dart';
import '../widgets/range_arc.dart';
import '../widgets/skeleton_overlay.dart';

/// Screen 02 — Live即時評估 (DESIGN SPEC.md §4).
///
/// This first pass covers 版面 (camera feed + skeleton overlay + HUD +
/// drawer shell) per §9 "camera+骨架先" — live angle/metric calculation,
/// compensation detection and the expanded joint list follow in a later
/// pass ("metrics後").
class LiveScreen extends StatefulWidget {
  LiveScreen({super.key, PoseSource? poseSource})
      : poseSource = poseSource ?? CameraPoseSource();

  final PoseSource poseSource;

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final _drawerController = DraggableScrollableController();
  StreamSubscription<PoseFrame>? _subscription;

  PoseFrame _frame = const PoseFrame();
  bool _initialized = false;
  bool _hasAutoExpanded = false;
  int _framesSincePoseSeen = 0;

  /// landmark≥28 — DESIGN SPEC.md §4 功能需求.
  static const _fullBodyLandmarkThreshold = 28;

  /// Frames of partial detection tolerated before showing "RE-ACQUIRING" —
  /// avoids flicker on momentary single-frame dropouts.
  static const _poseLostFrameThreshold = 10;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await widget.poseSource.initialize();
    if (!mounted) return;
    setState(() => _initialized = true);
    _subscription = widget.poseSource.frames.listen(_onFrame);
  }

  void _onFrame(PoseFrame frame) {
    if (!mounted) return;
    setState(() {
      _frame = frame;
      if (frame.visibleCount >= _fullBodyLandmarkThreshold) {
        _framesSincePoseSeen = 0;
        if (!_hasAutoExpanded) {
          _hasAutoExpanded = true;
          if (_drawerController.isAttached) {
            _drawerController.animateTo(
              LiveDrawer.peekSize,
              duration: AppDurations.value,
              curve: Curves.easeOutBack,
            );
          }
        }
      } else {
        _framesSincePoseSeen++;
      }
    });
  }

  PoseLockState get _poseLockState {
    if (_frame.visibleCount >= _fullBodyLandmarkThreshold) {
      return PoseLockState.locked;
    }
    if (_framesSincePoseSeen <= _poseLostFrameThreshold) {
      return PoseLockState.locked;
    }
    return PoseLockState.reacquiring;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _drawerController.dispose();
    widget.poseSource.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          widget.poseSource.buildPreview(context) ??
              const ColoredBox(color: AppColors.ink),
          if (_initialized) SkeletonOverlay(frame: _frame),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LiveHud(
                recording: false,
                elapsed: Duration.zero,
                poseLockState: _poseLockState,
                visibleLandmarkCount: _frame.visibleCount,
              ),
            ),
          ),
          LiveDrawer(
            controller: _drawerController,
            peekBuilder: _buildPeek,
            expandedBuilder: _buildExpanded,
          ),
        ],
      ),
    );
  }

  /// Peek state — Range Arc + 2×2 metrics grid (DESIGN SPEC.md §4 版面).
  ///
  /// Values are placeholders until live angle/metric calculation lands in
  /// the "metrics後" pass.
  Widget _buildPeek(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const RangeArc(arom: 0, prom: 0, normative: 0, label: '', size: 96),
        const SizedBox(width: 20),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 16,
            childAspectRatio: 2.0,
            children: const [
              LiveMetricCell(value: '--', unit: '°', label: 'AROM / PROM'),
              LiveMetricCell(
                value: '--',
                unit: '°',
                label: 'Passive Deficit',
                valueColor: AppColors.deficit,
              ),
              LiveMetricCell(
                value: '--',
                unit: '%',
                label: 'Smoothness',
                valueColor: AppColors.good,
              ),
              LiveMetricCell(
                value: '--',
                label: '代償 Compensation',
                valueColor: AppColors.warn,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Expanded state — list of joints measured this session
  /// (DESIGN SPEC.md §4 功能需求). Empty until rep/joint tracking lands.
  Widget _buildExpanded(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        '未有已測關節 · No joints measured yet',
        style: AppText.body(size: 13, color: AppColors.muted),
      ),
    );
  }
}
