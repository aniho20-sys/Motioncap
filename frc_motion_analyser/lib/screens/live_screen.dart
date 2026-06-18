import 'dart:async';

import 'package:flutter/material.dart';

import '../cv/angle_calculator.dart';
import '../cv/camera_pose_source.dart';
import '../cv/pose_source.dart';
import '../cv/rep_tracker.dart';
import '../data/session_storage.dart';
import '../models/capture_mode.dart';
import '../models/compensation.dart';
import '../models/joint_rom.dart';
import '../models/pose_landmark.dart';
import '../models/session_recording.dart';
import '../theme/tokens.dart';
import '../widgets/angle_tag.dart';
import '../widgets/capture_mode_bar.dart';
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
  CaptureMode _mode = CaptureMode.hip;
  SquatView _squatView = SquatView.side;
  final _squatTracker = SquatRepTracker();
  final _deadliftTracker = DeadliftRepTracker();
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
      switch (_mode) {
        case CaptureMode.squat:
          _squatTracker.update(
            kneeAvg: avgOf(_angles.kneeL, _angles.kneeR),
            hipKneeDelta: _angles.hipKneeDeltaY,
            backAngle: _angles.trunkLean,
            recording: _recording,
          );
        case CaptureMode.deadlift:
          _deadliftTracker.update(
            hipAvg: avgOf(_angles.hipL, _angles.hipR),
            kneeAvg: avgOf(_angles.kneeL, _angles.kneeR),
            backAngle: _angles.trunkLean,
            recording: _recording,
          );
        case CaptureMode.hip:
        case CaptureMode.shoulder:
        case CaptureMode.full:
          break;
      }
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

  /// Compensation alerts for the current frame, mode-aware — extends
  /// [detectCompensation] with the deadlift tracker's back-angle-vs-neutral
  /// and current-rep knee-travel readings (`null` outside
  /// [CaptureMode.deadlift]) — motion-capture-v2.html `updateAlerts`.
  List<CompensationAlert> _currentAlerts() {
    return detectCompensation(
      _angles,
      mode: _mode,
      squatView: _squatView,
      backAngleDelta: _mode == CaptureMode.deadlift
          ? _deadliftTracker.backAngleDelta(_angles.trunkLean)
          : null,
      kneeTravel: _mode == CaptureMode.deadlift
          ? _deadliftTracker.currentKneeTravel
          : null,
    );
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

    final alerts = _currentAlerts();
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

  /// Switches the active capture mode — motion-capture-v2.html `setMode`.
  /// Resets the relevant rep tracker so stale reps from a previous mode
  /// session don't carry over.
  void _setMode(CaptureMode mode) {
    setState(() {
      _mode = mode;
      switch (mode) {
        case CaptureMode.squat:
          _squatTracker.reset();
        case CaptureMode.deadlift:
          _deadliftTracker.reset();
        case CaptureMode.hip:
        case CaptureMode.shoulder:
        case CaptureMode.full:
          break;
      }
    });
  }

  /// Switches the squat side/front sub-view — motion-capture-v2.html
  /// `setSquatView`.
  void _setSquatView(SquatView view) {
    setState(() => _squatView = view);
  }

  Future<void> _startRecording() async {
    _hipFlexionTracker.reset();
    switch (_mode) {
      case CaptureMode.squat:
        _squatTracker.reset();
      case CaptureMode.deadlift:
        _deadliftTracker.reset();
      case CaptureMode.hip:
      case CaptureMode.shoulder:
      case CaptureMode.full:
        break;
    }
    _activeCompensationLabels = {};
    _lastSampledAt = Duration.zero;
    _stopwatch
      ..reset()
      ..start();
    _session = SessionRecording(startedAt: DateTime.now(), mode: _mode);
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    setState(() => _recording = true);

    // Video recording is best-effort: if the pose source can't support it
    // (e.g. the camera doesn't allow recording alongside the live image
    // stream), the JSON session below still saves without a video.
    try {
      await widget.poseSource.startVideoRecording();
    } catch (_) {
      // Ignored — see comment above.
    }
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

    try {
      session.videoPath = await widget.poseSource.stopVideoRecording();
    } catch (_) {
      // Recording wasn't active/supported — JSON session still saves.
    }
    session.hipFlexionAromDeg = _hipFlexionTracker.arom;
    session.squatReps.addAll(_squatTracker.reps);
    session.deadliftReps.addAll(_deadliftTracker.reps);
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
            AngleTagOverlay(
              frame: _frame,
              angles: _angles,
              mode: _mode,
              squatView: _squatView,
              backAngleDelta: _mode == CaptureMode.deadlift
                  ? _deadliftTracker.backAngleDelta(_angles.trunkLean)
                  : null,
              kneeTravel: _mode == CaptureMode.deadlift
                  ? _deadliftTracker.currentKneeTravel
                  : null,
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LiveHud(
                    recording: _recording,
                    elapsed: _stopwatch.elapsed,
                    poseLockState: _poseLockState,
                    visibleLandmarkCount: _frame.visibleCount,
                  ),
                  const SizedBox(height: 10),
                  CaptureModeBar(mode: _mode, onChanged: _setMode),
                  CameraHintBanner(hint: cameraHint(_mode, _squatView)),
                ],
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
    final compensationCount = _currentAlerts().length;

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
  /// (DESIGN SPEC.md §4 功能需求), filtered to the joints relevant to
  /// [_mode] ([modeJointCards] — motion-capture-v2.html
  /// `MODE_ANGLE_CARDS`), plus the squat/deadlift analysis section for
  /// those modes.
  Widget _buildExpanded(BuildContext context) {
    final joints = <(String, double?)>[
      for (final key in JointKey.values)
        if (modeJointCards[_mode]!.contains(key)) (key.label, key.valueOf(_angles)),
    ];

    final hasJoints = joints.any((joint) => joint.$2 != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hasJoints)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '未有已測關節 · No joints measured yet',
              style: AppText.body(size: 13, color: AppColors.muted),
            ),
          )
        else
          ...[
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
        if (_mode == CaptureMode.squat) _buildSquatSection(),
        if (_mode == CaptureMode.deadlift) _buildDeadliftSection(),
      ],
    );
  }

  /// 深蹲分析 Squat Analysis — view toggle (depth vs knee tracking),
  /// rep counter and rep log — motion-capture-v2.html `#section-squat`.
  Widget _buildSquatSection() {
    final depth = classifySquatDepth(_angles.hipKneeDeltaY);
    final lastRep = _squatTracker.lastRep;
    final valgus = _angles.kneeValgusRatio;
    final valgusWarn =
        valgus != null && valgus < CompensationThresholds.kneeValgusRatio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text('深蹲分析 Squat Analysis', style: AppText.body(size: 13, weight: FontWeight.w600)),
        const SizedBox(height: 10),
        SquatViewToggle(view: _squatView, onChanged: _setSquatView),
        const SizedBox(height: 6),
        if (_squatView == SquatView.side)
          _metricRow('蹲深 Depth', depth.label, warn: depth == SquatDepth.shallow)
        else
          _metricRow(
            '膝關節追蹤 Knee Tracking',
            valgus == null ? '--' : valgus.toStringAsFixed(2),
            warn: valgusWarn,
          ),
        const SizedBox(height: 16),
        Text('深蹲次數 Rep Log', style: AppText.body(size: 13, weight: FontWeight.w600)),
        _metricRow('次數 Reps', '${_squatTracker.repCount}'),
        _metricRow(
          '上一下 Last Rep',
          lastRep == null
              ? '--'
              : '#${lastRep.n} ${lastRep.depth.label} · 膝${_fmt(lastRep.kneeMin)}° · 背${_fmt(lastRep.backAngle)}°',
        ),
        for (final rep in _squatTracker.reps.reversed)
          _repLogItem(
            '第 ${rep.n} 下',
            '${rep.depth.label} · 膝 ${_fmt(rep.kneeMin)}° · 背 ${_fmt(rep.backAngle)}°',
            warn: rep.isWarn,
          ),
      ],
    );
  }

  /// 硬舉分析 Deadlift Analysis — hip hinge / back angle, calibrated
  /// back-angle delta, rep counter, rep log and calibrate button —
  /// motion-capture-v2.html `#section-deadlift`.
  Widget _buildDeadliftSection() {
    final hipAvg = avgOf(_angles.hipL, _angles.hipR);
    final backAngle = _angles.trunkLean;
    final backDelta = _deadliftTracker.backAngleDelta(backAngle);
    final lastRep = _deadliftTracker.lastRep;
    final backWarn =
        backDelta != null && backDelta.abs() > CompensationThresholds.backRounding;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text('硬舉分析 Deadlift Analysis', style: AppText.body(size: 13, weight: FontWeight.w600)),
        const SizedBox(height: 10),
        _metricRow('髖鉸鏈 Hip Hinge', hipAvg == null ? '--' : '${hipAvg.round()}°'),
        _metricRow('背部角度 Back Angle', backAngle == null ? '--' : '${backAngle.round()}°'),
        _metricRow('vs 中立 vs Neutral', backDelta == null ? '--' : '${_fmt(backDelta)}°', warn: backWarn),
        const SizedBox(height: 16),
        Text('硬舉次數 Rep Log', style: AppText.body(size: 13, weight: FontWeight.w600)),
        _metricRow('次數 Reps', '${_deadliftTracker.repCount}'),
        _metricRow(
          '上一下 Last Rep',
          lastRep == null
              ? '--'
              : '#${lastRep.n} 髖${_fmt(lastRep.hipMin)}° · 背Δ${_fmt(lastRep.backDelta)}° · 膝幅${_fmt(lastRep.kneeTravel)}°',
        ),
        for (final rep in _deadliftTracker.reps.reversed)
          _repLogItem(
            '第 ${rep.n} 下',
            '髖${_fmt(rep.hipMin)}° · 背Δ${_fmt(rep.backDelta)}° · 膝幅${_fmt(rep.kneeTravel)}°',
            warn: rep.isWarn,
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: () => setState(() => _deadliftTracker.calibrate(_angles.trunkLean)),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              child: Text(
                '校準中立姿勢 Calibrate Neutral',
                style: AppText.body(size: 13, weight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricRow(String label, String value, {bool warn = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppText.body(size: 13)),
          Text(
            value,
            style: AppText.data(size: 14, color: warn ? AppColors.warn : AppColors.orange),
          ),
        ],
      ),
    );
  }

  Widget _repLogItem(String left, String right, {bool warn = false}) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: Border.all(color: warn ? AppColors.warn : AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(left, style: AppText.data(size: 11, color: warn ? AppColors.warn : AppColors.muted)),
          Flexible(
            child: Text(
              right,
              textAlign: TextAlign.right,
              style: AppText.data(size: 11, color: warn ? AppColors.warn : AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  /// Formats a nullable angle/delta reading — motion-capture-v2.html `fmt`.
  String _fmt(double? v, [int decimals = 1]) => v == null ? '--' : v.toStringAsFixed(decimals);
}
