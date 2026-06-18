import 'package:flutter/foundation.dart';

import '../cv/angle_calculator.dart';
import '../cv/rep_tracker.dart';
import 'capture_mode.dart';
import 'compensation.dart';

/// A timestamped snapshot of [PoseAngles] captured during a recording
/// session — DESIGN SPEC.md §4 功能需求 "連同時間戳記嘅角度數據".
@immutable
class SessionFrame {
  const SessionFrame({required this.elapsed, required this.angles});

  final Duration elapsed;
  final PoseAngles angles;

  Map<String, dynamic> toJson() => {
        'tMs': elapsed.inMilliseconds,
        'hipL': angles.hipL,
        'hipR': angles.hipR,
        'kneeL': angles.kneeL,
        'kneeR': angles.kneeR,
        'shoulderL': angles.shoulderL,
        'shoulderR': angles.shoulderR,
        'pelvisTilt': angles.pelvisTilt,
        'shoulderTilt': angles.shoulderTilt,
        'trunkLean': angles.trunkLean,
      };
}

/// A compensation alert that newly triggered during a recording session.
@immutable
class CompensationEvent {
  const CompensationEvent({required this.elapsed, required this.alert});

  final Duration elapsed;
  final CompensationAlert alert;

  Map<String, dynamic> toJson() => {
        'tMs': elapsed.inMilliseconds,
        'label': alert.label,
        'degrees': alert.degrees,
      };
}

/// One Live即時評估 session — sampled joint angles + compensation events,
/// plus the resulting AROM. Saved locally pending Firestore sync (CLAUDE.md
/// "之後": Firebase project建立).
class SessionRecording {
  SessionRecording({required this.startedAt, required this.mode});

  final DateTime startedAt;
  final CaptureMode mode;
  final List<SessionFrame> frames = [];
  final List<CompensationEvent> compensationEvents = [];
  final List<SquatRep> squatReps = [];
  final List<DeadliftRep> deadliftReps = [];

  /// 髖屈曲 AROM reached during the session, in degrees — set when the
  /// session ends.
  double hipFlexionAromDeg = 0;

  /// Path to the recorded video file, or `null` if video recording wasn't
  /// active/supported for this session.
  String? videoPath;

  void addFrame(Duration elapsed, PoseAngles angles) {
    frames.add(SessionFrame(elapsed: elapsed, angles: angles));
  }

  void addCompensationEvent(Duration elapsed, CompensationAlert alert) {
    compensationEvents.add(CompensationEvent(elapsed: elapsed, alert: alert));
  }

  Map<String, dynamic> toJson() => {
        'startedAt': startedAt.toIso8601String(),
        'mode': mode.name,
        'durationMs': frames.isEmpty ? 0 : frames.last.elapsed.inMilliseconds,
        'hipFlexionAromDeg': hipFlexionAromDeg,
        'videoPath': videoPath,
        'frames': frames.map((f) => f.toJson()).toList(),
        'compensationEvents':
            compensationEvents.map((e) => e.toJson()).toList(),
        'squatReps': squatReps.map((r) => r.toJson()).toList(),
        'deadliftReps': deadliftReps.map((r) => r.toJson()).toList(),
      };
}
