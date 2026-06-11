import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/pose_landmark.dart';

/// Angle ABC at vertex [b], in degrees (0–180) — CLAUDE.md `angle3`.
///
/// Returns `null` if either leg of the angle has zero length (landmarks
/// coincide), matching the JS prototype's guard.
double? angle3(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
  final abX = a.x - b.x, abY = a.y - b.y;
  final cbX = c.x - b.x, cbY = c.y - b.y;
  final magAb = math.sqrt(abX * abX + abY * abY);
  final magCb = math.sqrt(cbX * cbX + cbY * cbY);
  if (magAb == 0 || magCb == 0) return null;
  var cos = (abX * cbX + abY * cbY) / (magAb * magCb);
  cos = cos.clamp(-1.0, 1.0);
  return math.acos(cos) * 180 / math.pi;
}

/// Tilt of the line a→b from horizontal, in degrees — CLAUDE.md `tiltAngle`.
double tiltAngle(PoseLandmark a, PoseLandmark b) {
  return math.atan2(b.y - a.y, b.x - a.x) * 180 / math.pi;
}

bool _visible(Iterable<PoseLandmark> points) =>
    points.every((p) => p.visibility >= PoseFrame.visibilityThreshold);

/// Returns the average of [a] and [b], or whichever is non-null —
/// CLAUDE.md / `motion-capture-v2.html` `avgOf`.
double? avgOf(double? a, double? b) {
  if (a == null) return b;
  if (b == null) return a;
  return (a + b) / 2;
}

/// One frame's worth of FRC joint angles + alignment readings — CLAUDE.md
/// "MediaPipe Landmark → FRC計算對照".
@immutable
class PoseAngles {
  const PoseAngles({
    this.hipL,
    this.hipR,
    this.kneeL,
    this.kneeR,
    this.shoulderL,
    this.shoulderR,
    this.pelvisTilt,
    this.shoulderTilt,
    this.trunkLean,
  });

  static const empty = PoseAngles();

  /// 髖屈曲角 angle3(SHOULDER, HIP, KNEE).
  final double? hipL;
  final double? hipR;

  /// 膝屈曲角 angle3(HIP, KNEE, ANKLE).
  final double? kneeL;
  final double? kneeR;

  /// 肩屈曲角 angle3(HIP, SHOULDER, ELBOW).
  final double? shoulderL;
  final double? shoulderR;

  /// 骨盆傾斜 tiltAngle(LEFT_HIP, RIGHT_HIP), in degrees.
  final double? pelvisTilt;

  /// 肩膀水平 tiltAngle(LEFT_SHOULDER, RIGHT_SHOULDER), in degrees.
  final double? shoulderTilt;

  /// 軀幹前傾, in degrees — angle of the mid-hip→mid-shoulder line from
  /// vertical.
  final double? trunkLean;
}

/// Computes [PoseAngles] from a [PoseFrame] — CLAUDE.md 主要計算.
///
/// Returns [PoseAngles.empty] if the frame doesn't carry a full 33-point
/// MediaPipe Pose result.
PoseAngles computeAngles(PoseFrame frame) {
  final lm = frame.landmarks;
  if (lm.length < PoseLandmarkIndex.total) return PoseAngles.empty;

  final ls = lm[PoseLandmarkIndex.leftShoulder];
  final rs = lm[PoseLandmarkIndex.rightShoulder];
  final le = lm[PoseLandmarkIndex.leftElbow];
  final re = lm[PoseLandmarkIndex.rightElbow];
  final lh = lm[PoseLandmarkIndex.leftHip];
  final rh = lm[PoseLandmarkIndex.rightHip];
  final lk = lm[PoseLandmarkIndex.leftKnee];
  final rk = lm[PoseLandmarkIndex.rightKnee];
  final la = lm[PoseLandmarkIndex.leftAnkle];
  final ra = lm[PoseLandmarkIndex.rightAnkle];

  double? pelvisTilt;
  double? shoulderTilt;
  double? trunkLean;

  if (_visible([lh, rh])) pelvisTilt = tiltAngle(lh, rh);
  if (_visible([ls, rs])) shoulderTilt = tiltAngle(ls, rs);
  if (_visible([lh, rh, ls, rs])) {
    final midHipX = (lh.x + rh.x) / 2;
    final midHipY = (lh.y + rh.y) / 2;
    final midShoulderX = (ls.x + rs.x) / 2;
    final midShoulderY = (ls.y + rs.y) / 2;
    trunkLean = math.atan2(midHipX - midShoulderX, midHipY - midShoulderY) *
        180 /
        math.pi;
  }

  return PoseAngles(
    hipL: _visible([ls, lh, lk]) ? angle3(ls, lh, lk) : null,
    hipR: _visible([rs, rh, rk]) ? angle3(rs, rh, rk) : null,
    kneeL: _visible([lh, lk, la]) ? angle3(lh, lk, la) : null,
    kneeR: _visible([rh, rk, ra]) ? angle3(rh, rk, ra) : null,
    shoulderL: _visible([lh, ls, le]) ? angle3(lh, ls, le) : null,
    shoulderR: _visible([rh, rs, re]) ? angle3(rh, rs, re) : null,
    pelvisTilt: pelvisTilt,
    shoulderTilt: shoulderTilt,
    trunkLean: trunkLean,
  );
}
