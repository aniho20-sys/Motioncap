import 'package:flutter/foundation.dart';

import '../cv/angle_calculator.dart';
import 'capture_mode.dart';

/// 代償偵測閾值 — CLAUDE.md 代償偵測邏輯 / `motion-capture-v2.html` `THRESH`.
class CompensationThresholds {
  CompensationThresholds._();

  /// ° — 骨盆側傾 proxy for >3cm hip height difference.
  static const pelvisTilt = 2.0;

  /// ° — 肩胛上提 / 軀幹側彎.
  static const shoulderTilt = 4.0;

  /// ° — 軀幹前傾代償 from vertical (suppressed in squat/deadlift, where
  /// forward lean is expected/intentional).
  static const trunkLean = 10.0;

  /// ° — left/right joint-angle asymmetry (hip/knee/shoulder).
  static const asymmetry = 15.0;

  /// knee-dist/ankle-dist below this = knees caving in (squat front view).
  static const kneeValgusRatio = 0.80;

  /// ° deviation from calibrated neutral = back rounding (deadlift).
  static const backRounding = 15.0;

  /// ° knee-angle change during a deadlift rep = excessive knee travel.
  static const kneeTravel = 12.0;
}

/// A single triggered compensation reading — CLAUDE.md 代償偵測邏輯.
@immutable
class CompensationAlert {
  const CompensationAlert({required this.label, required this.degrees});

  /// Chinese/English label, e.g. "骨盆側傾 Pelvic Shift".
  final String label;

  /// Signed angle reading that triggered the alert, in degrees.
  final double degrees;
}

/// Returns the compensation alerts currently triggered by [angles] —
/// CLAUDE.md 代償偵測邏輯 (骨盆側傾 / 肩胛上提 / 軀幹前傾 / 左右不對稱), extended
/// per `motion-capture-v2.html` `updateAlerts` for [CaptureMode.squat] /
/// [CaptureMode.deadlift] (knee valgus, back-angle deviation, knee travel).
///
/// [backAngleDelta] and [kneeTravel] are pre-computed by the deadlift rep
/// tracker (current-vs-calibrated-neutral back angle, and the current rep's
/// max knee-angle travel) — pass `null` outside [CaptureMode.deadlift].
List<CompensationAlert> detectCompensation(
  PoseAngles angles, {
  CaptureMode mode = CaptureMode.hip,
  SquatView squatView = SquatView.side,
  double? backAngleDelta,
  double? kneeTravel,
}) {
  final alerts = <CompensationAlert>[];

  final pelvisTilt = angles.pelvisTilt;
  if (pelvisTilt != null &&
      pelvisTilt.abs() > CompensationThresholds.pelvisTilt) {
    alerts.add(CompensationAlert(label: '骨盆側傾 Pelvic Shift', degrees: pelvisTilt));
  }

  final shoulderTilt = angles.shoulderTilt;
  if (shoulderTilt != null &&
      shoulderTilt.abs() > CompensationThresholds.shoulderTilt) {
    alerts.add(
      CompensationAlert(label: '肩胛代償 Shoulder Hike', degrees: shoulderTilt),
    );
  }

  // Forward trunk lean is expected/intentional during squat/deadlift, so the
  // alert is suppressed for those modes.
  final trunkLean = angles.trunkLean;
  if (mode != CaptureMode.squat &&
      mode != CaptureMode.deadlift &&
      trunkLean != null &&
      trunkLean.abs() > CompensationThresholds.trunkLean) {
    alerts.add(CompensationAlert(label: '軀幹前傾代償 Trunk Lean', degrees: trunkLean));
  }

  void checkAsymmetry(double? left, double? right, String name) {
    if (left == null || right == null) return;
    final diff = left - right;
    if (diff.abs() > CompensationThresholds.asymmetry) {
      alerts.add(CompensationAlert(label: '$name 左右不對稱 Asymmetry', degrees: diff));
    }
  }

  checkAsymmetry(angles.hipL, angles.hipR, '髖 Hip');
  checkAsymmetry(angles.kneeL, angles.kneeR, '膝 Knee');
  checkAsymmetry(angles.shoulderL, angles.shoulderR, '肩 Shoulder');

  // Knee valgus ratio is only meaningful from a front-view squat — a side
  // view can't reliably distinguish caving knees from camera angle.
  final valgusRatio = angles.kneeValgusRatio;
  if (mode == CaptureMode.squat &&
      squatView == SquatView.front &&
      valgusRatio != null &&
      valgusRatio < CompensationThresholds.kneeValgusRatio) {
    alerts.add(CompensationAlert(label: '膝內扣 Knee Valgus', degrees: valgusRatio));
  }

  if (backAngleDelta != null &&
      backAngleDelta.abs() > CompensationThresholds.backRounding) {
    alerts.add(
      CompensationAlert(label: '背部角度偏離中立 Back Angle Deviation', degrees: backAngleDelta),
    );
  }

  if (kneeTravel != null && kneeTravel > CompensationThresholds.kneeTravel) {
    alerts.add(
      CompensationAlert(label: '膝關節過度移動 Excessive Knee Travel', degrees: kneeTravel),
    );
  }

  return alerts;
}
