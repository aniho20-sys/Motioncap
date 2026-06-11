import 'dart:async';

import 'package:flutter/material.dart';

import '../cv/angle_calculator.dart';
import '../cv/camera_pose_source.dart';
import '../cv/pose_source.dart';
import '../data/session_storage.dart';
import '../models/compensation.dart';
import '../models/joint_rom.dart';
import '../models/pose_landmark.dart';
import '../models/session_recording.dart';
import '../theme/tokens.dart';
import '../widgets/angle_tag.dart';
import '../widgets/live_drawer.dart';
import '../widgets/live_hud.dart';
import '../widgets/range_arc.dart';
import '../widgets/record_button.dart';
import '../widgets/skeleton_overlay.dart';

/// Screen 02 — Live即時評估 (DESIGN SPEC.md §4).
///
/// Covers 版面 (camera feed + skeleton overlay + HUD + drawer shell) and
/// the "metrics後" pass per §9: live joint-angle tags, alignment
/// compensation detection, hip-flexion AROM tracking, the measured-joint
/// list, and session recording (start/stop + local save pending Firestore).
class LiveScreen extends StatefulWidget {
  LiveScreen({super.key, PoseSource? poseSource, SessionStorage? sessionStorage})
      : poseSource = poseSource ?? CameraPoseSource(),
        sessionStorage = sessionStorage ?? const LocalSessionStorage();

  final PoseSource poseSource;
  final SessionStorage sessionStorage;

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

  bool _recording = false;
  SessionRecording? _session;
  final _stopwatch = Stopwatch();
  Timer? _elapsedTimer;
  Set<String> _activeCompensationLabels = {};
  Duration _lastSampledAt = Duration.zero;

  /// Minimum gap between recorded frame samples — keeps the saved JSON a
  /// manageable size without losing meaningful detail.
  static const _sampleInterval = Duration(milliseconds: 100);

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
      if (_recording) _recordSample();
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

  /// Samples the current angles into [_session] — DESIGN SPEC.md §4
  /// 功能需求 "連同時間戳記嘅角度數據" — and logs newly-triggered
  /// compensation alerts as [CompensationEvent]s.
  void _recordSample() {
    final session = _session!;
    final elapsed = _stopwatch.elapsed;
    if (elapsed - _lastSampledAt >= _sampleInterval) {
      session.addFrame(elapsed, _angles);
      _lastSampledAt = elapsed;
    }

    final alerts = detectCompensation(_angles);
    final activeLabels = <String>{};
    for (final alert in alerts) {
      activeLabels.add(alert.label);
      if (!_activeCompensationLabels.contains(alert.label)) {
        session.addCompensationEvent(elapsed, alert);
      }
    }
    _activeCompensationLabels = activeLabels;
  }

  void _toggleRecording() {
    if (_recording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  void _startRecording() {
    _hipFlexionTracker.reset();
    _activeCompensationLabels = {};
    _lastSampledAt = Duration.zero;
    _stopwatch
      ..reset()
      ..start();
    _session = SessionRecording(startedAt: DateTime.now());
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    setState(() => _recording = true);
  }

  Future<void> _stopRecording() async {
    _stopwatch.stop();
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    final session = _session;
    setState(() {
      _recording = false;
      _session = null;
    });
    if (session == null) return;

    session.hipFlexionAromDeg = _hipFlexionTracker.arom;
    final path = await widget.sessionStorage.save(session);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已儲存 Session：$path')),
    );
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
    _elapsedTimer?.cancel();
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
                recording: _recording,
                elapsed: _stopwatch.elapsed,
                poseLockState: _poseLockState,
                visibleLandmarkCount: _frame.visibleCount,
              ),
            ),
          ),
          if (_initialized)
            Positioned(
              right: 16,
              bottom: MediaQuery.of(context).size.height *
                      LiveDrawer.collapsedSize +
                  16,
              child: RecordButton(
                recording: _recording,
                onPressed: _toggleRecording,
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
