import 'package:flutter/foundation.dart';

import '../cv/angle_calculator.dart';

/// 代償偵測閾值 — CLAUDE.md 代償偵測邏輯 / `motion-capture-v2.html` `THRESH`.
class CompensationThresholds {
  CompensationThresholds._();

  /// ° — 骨盆側傾 proxy for >3cm hip height difference.
  static const pelvisTilt = 2.0;

  /// ° — 肩胛上提 / 軀幹側彎.
  static const shoulderTilt = 4.0;

  /// ° — 軀幹前傾代償 from vertical.
  static const trunkLean = 10.0;
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
/// CLAUDE.md 代償偵測邏輯 (骨盆側傾 / 肩胛上提 / 軀幹前傾).
List<CompensationAlert> detectCompensation(PoseAngles angles) {
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

  final trunkLean = angles.trunkLean;
  if (trunkLean != null &&
      trunkLean.abs() > CompensationThresholds.trunkLean) {
    alerts.add(CompensationAlert(label: '軀幹前傾代償 Trunk Lean', degrees: trunkLean));
  }

  return alerts;
}
