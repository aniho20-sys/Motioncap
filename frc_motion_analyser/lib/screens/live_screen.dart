import 'dart:async';

import 'package:flutter/material.dart';

import '../cv/angle_calculator.dart';
import '../cv/camera_pose_source.dart';
import '../cv/pose_source.dart';
import '../models/compensation.dart';
import '../models/joint_rom.dart';
import '../models/pose_landmark.dart';
import '../theme/tokens.dart';
import '../widgets/angle_tag.dart';
import '../widgets/live_drawer.dart';
import '../widgets/live_hud.dart';
import '../widgets/range_arc.dart';
import '../widgets/skeleton_overlay.dart';

/// Screen 02 — Live即時評估 (DESIGN SPEC.md §4).
///
/// Covers 版面 (camera feed + skeleton overlay + HUD + drawer shell) and
/// the "metrics後" pass per §9: live joint-angle tags, alignment
/// compensation detection, hip-flexion AROM tracking and the measured-joint
/// list.
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
  PoseAngles _angles = PoseAngles.empty;
  final _hipFlexionTracker = HipFlexionTracker();
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
      _angles = computeAngles(frame);
      _hipFlexionTracker.update(avgOf(_angles.hipL, _angles.hipR));
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
          if (_initialized)
            AngleTagOverlay(frame: _frame, angles: _angles),
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
  /// Range Arc tracks 髖屈曲 (hip flexion) AROM — CLAUDE.md MVP優先關節.
  /// PROM (passive ROM) and Smoothness require coach input / multi-frame
  /// history that land in a later pass, so they remain "--" placeholders.
  Widget _buildPeek(BuildContext context) {
    final arom = _hipFlexionTracker.arom;
    final compensationCount = detectCompensation(_angles).length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        RangeArc(
          arom: arom,
          prom: arom,
          normative: NormativeRom.hipFlexion,
          label: 'HIP FLEX',
          size: 96,
        ),
        const SizedBox(width: 20),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 16,
            childAspectRatio: 2.0,
            children: [
              LiveMetricCell(
                value: '${arom.round()}',
                unit: '/--°',
                label: 'AROM / PROM',
              ),
              const LiveMetricCell(
                value: '--',
                unit: '°',
                label: 'Passive Deficit',
                valueColor: AppColors.deficit,
              ),
              const LiveMetricCell(
                value: '--',
                unit: '%',
                label: 'Smoothness',
                valueColor: AppColors.good,
              ),
              LiveMetricCell(
                value: '$compensationCount',
                label: '代償 Compensation',
                valueColor: compensationCount > 0
                    ? AppColors.warn
                    : AppColors.good,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Expanded state — list of joints measured this session
  /// (DESIGN SPEC.md §4 功能需求). Shows the live angle for each tracked
  /// joint once a full body is detected.
  Widget _buildExpanded(BuildContext context) {
    final joints = <(String, double?)>[
      ('L HIP', _angles.hipL),
      ('R HIP', _angles.hipR),
      ('L KNEE', _angles.kneeL),
      ('R KNEE', _angles.kneeR),
      ('L SHOULDER', _angles.shoulderL),
      ('R SHOULDER', _angles.shoulderR),
    ];

    if (joints.every((joint) => joint.$2 == null)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '未有已測關節 · No joints measured yet',
          style: AppText.body(size: 13, color: AppColors.muted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, value) in joints)
          if (value != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: AppText.body(size: 13)),
                  Text(
                    '${value.round()}°',
                    style: AppText.data(size: 14, color: AppColors.orange),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
