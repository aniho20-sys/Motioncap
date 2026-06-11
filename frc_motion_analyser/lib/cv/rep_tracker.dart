import 'package:flutter/foundation.dart';

import '../models/compensation.dart';

/// Squat rep-counting tunables (PLACEHOLDER — Ani to validate against real
/// footage) — motion-capture-v2.html `SQUAT_THRESH`.
class SquatThresholds {
  SquatThresholds._();

  /// ° knee angle = "standing".
  static const kneeStanding = 165.0;

  /// ° knee angle = "at depth" trigger.
  static const kneeBottom = 100.0;

  static const hysteresis = 8.0;

  /// hipY - kneeY <= this => at/below parallel.
  static const parallelDelta = 0.0;

  /// hipY - kneeY > this => shallow (normalized coords).
  static const shallowDelta = 0.04;
}

/// Deadlift rep-counting tunables (PLACEHOLDER — Ani to validate against
/// real footage) — motion-capture-v2.html `DEADLIFT_THRESH`.
class DeadliftThresholds {
  DeadliftThresholds._();

  /// ° hip angle = "standing/locked out".
  static const hipStanding = 165.0;

  /// ° hip angle = "at hinge bottom" trigger.
  static const hipHinge = 110.0;

  static const hysteresis = 8.0;
}

/// 蹲深 classification — motion-capture-v2.html `classifySquatDepth`.
enum SquatDepth { unknown, shallow, parallel, belowParallel }

extension SquatDepthLabel on SquatDepth {
  String get label => switch (this) {
        SquatDepth.unknown => '--',
        SquatDepth.shallow => '淺 Shallow',
        SquatDepth.parallel => '平行 Parallel',
        SquatDepth.belowParallel => '低於平行 Below Parallel',
      };
}

/// Classifies squat depth from [hipKneeDelta] (`PoseAngles.hipKneeDeltaY`) —
/// motion-capture-v2.html `classifySquatDepth`.
SquatDepth classifySquatDepth(double? hipKneeDelta) {
  if (hipKneeDelta == null) return SquatDepth.unknown;
  if (hipKneeDelta >= SquatThresholds.shallowDelta) return SquatDepth.shallow;
  if (hipKneeDelta > -SquatThresholds.parallelDelta) return SquatDepth.parallel;
  return SquatDepth.belowParallel;
}

/// One completed squat rep — motion-capture-v2.html `squatReps` entries.
@immutable
class SquatRep {
  const SquatRep({
    required this.n,
    required this.depth,
    required this.kneeMin,
    required this.backAngle,
  });

  final int n;
  final SquatDepth depth;

  /// Minimum knee angle reached (deepest point), in degrees.
  final double? kneeMin;

  /// Trunk lean at the deepest point, in degrees.
  final double? backAngle;

  /// `true` when the rep didn't reach parallel — motion-capture-v2.html
  /// flags `淺 Shallow` reps in the rep log.
  bool get isWarn => depth == SquatDepth.shallow;
}

enum _SquatState { standing, descending, bottom, ascending }

/// Squat rep-counting state machine —
/// `standing → descending → bottom → ascending → standing`, driven by
/// `avgOf(kneeL, kneeR)` — motion-capture-v2.html `updateSquatRep`.
class SquatRepTracker {
  _SquatState _state = _SquatState.standing;
  double? _prevKneeAvg;
  double? _repMinKneeAvg;
  double? _repMinHipKneeDelta;
  double? _repBackAngleAtBottom;

  final List<SquatRep> reps = [];

  int get repCount => reps.length;
  SquatRep? get lastRep => reps.isEmpty ? null : reps.last;

  void reset() {
    _state = _SquatState.standing;
    _prevKneeAvg = null;
    _repMinKneeAvg = null;
    _repMinHipKneeDelta = null;
    _repBackAngleAtBottom = null;
    reps.clear();
  }

  /// Feeds one frame's readings. [recording] gates whether a completed rep
  /// is finalized into [reps] — matches motion-capture-v2.html, which
  /// still runs the state machine while idle but only logs reps while
  /// recording.
  void update({
    required double? kneeAvg,
    required double? hipKneeDelta,
    required double? backAngle,
    required bool recording,
  }) {
    if (kneeAvg == null) return;

    if (_repMinKneeAvg == null || kneeAvg < _repMinKneeAvg!) {
      _repMinKneeAvg = kneeAvg;
    }
    if (hipKneeDelta != null &&
        (_repMinHipKneeDelta == null || hipKneeDelta < _repMinHipKneeDelta!)) {
      _repMinHipKneeDelta = hipKneeDelta;
      _repBackAngleAtBottom = backAngle;
    }

    switch (_state) {
      case _SquatState.standing:
        if (kneeAvg < SquatThresholds.kneeStanding - SquatThresholds.hysteresis) {
          _state = _SquatState.descending;
        }
      case _SquatState.descending:
        if (kneeAvg <= SquatThresholds.kneeBottom) _state = _SquatState.bottom;
      case _SquatState.bottom:
        if (_prevKneeAvg != null && kneeAvg > _prevKneeAvg! + 0.5) {
          _state = _SquatState.ascending;
        }
      case _SquatState.ascending:
        if (kneeAvg >= SquatThresholds.kneeStanding) {
          _state = _SquatState.standing;
          if (recording) _finalizeRep();
        } else if (_prevKneeAvg != null && kneeAvg < _prevKneeAvg! - 0.5) {
          _state = _SquatState.bottom;
        }
    }
    _prevKneeAvg = kneeAvg;
  }

  void _finalizeRep() {
    reps.add(SquatRep(
      n: reps.length + 1,
      depth: classifySquatDepth(_repMinHipKneeDelta),
      kneeMin: _repMinKneeAvg,
      backAngle: _repBackAngleAtBottom,
    ));
    _repMinKneeAvg = null;
    _repMinHipKneeDelta = null;
    _repBackAngleAtBottom = null;
  }
}

/// One completed deadlift rep — motion-capture-v2.html `deadliftReps`
/// entries.
@immutable
class DeadliftRep {
  const DeadliftRep({
    required this.n,
    required this.hipMin,
    required this.backDelta,
    required this.kneeTravel,
  });

  final int n;

  /// Minimum hip angle reached (deepest hinge), in degrees.
  final double? hipMin;

  /// Back angle at the hinge vs calibrated neutral, in degrees.
  final double? backDelta;

  /// Max knee-angle travel during the rep, in degrees.
  final double? kneeTravel;

  bool get isBackRoundingWarn =>
      backDelta != null && backDelta!.abs() > CompensationThresholds.backRounding;

  bool get isKneeTravelWarn =>
      kneeTravel != null && kneeTravel! > CompensationThresholds.kneeTravel;

  bool get isWarn => isBackRoundingWarn || isKneeTravelWarn;
}

enum _DeadliftState { standing, lowering, bottom, lifting }

/// Deadlift rep-counting state machine —
/// `standing → lowering → bottom → lifting → standing`, driven by
/// `avgOf(hipL, hipR)` — motion-capture-v2.html `updateDeadliftRep`.
class DeadliftRepTracker {
  _DeadliftState _state = _DeadliftState.standing;
  double? _prevHipAvg;
  double? _repMinHipAvg;
  double? _repBackAngleAtHinge;
  double? _repKneeAtStart;
  double? _repMaxKneeTravel;
  double? _neutralBackAngle;

  final List<DeadliftRep> reps = [];

  int get repCount => reps.length;
  DeadliftRep? get lastRep => reps.isEmpty ? null : reps.last;
  double? get neutralBackAngle => _neutralBackAngle;

  /// Max knee-angle travel observed so far in the rep currently in
  /// progress — exposed for live compensation alerts
  /// (motion-capture-v2.html `repMaxKneeTravel`).
  double? get currentKneeTravel => _repMaxKneeTravel;

  /// Clears rep history and the in-progress rep, but preserves
  /// [neutralBackAngle] — matches `resetDeadliftRep`, which doesn't touch
  /// the calibration.
  void reset() {
    _state = _DeadliftState.standing;
    _prevHipAvg = null;
    _repMinHipAvg = null;
    _repBackAngleAtHinge = null;
    _repKneeAtStart = null;
    _repMaxKneeTravel = null;
    reps.clear();
  }

  /// Sets [neutralBackAngle] to [backAngle] — motion-capture-v2.html
  /// `btn-calibrate` handler.
  void calibrate(double? backAngle) {
    if (backAngle != null) _neutralBackAngle = backAngle;
  }

  /// Current [backAngle] vs [neutralBackAngle], or `null` if either is
  /// unavailable — used for the live "vs neutral" readout and the
  /// back-rounding compensation alert.
  double? backAngleDelta(double? backAngle) {
    if (_neutralBackAngle == null || backAngle == null) return null;
    return backAngle - _neutralBackAngle!;
  }

  /// Feeds one frame's readings. [recording] gates whether a completed rep
  /// is finalized into [reps].
  void update({
    required double? hipAvg,
    required double? kneeAvg,
    required double? backAngle,
    required bool recording,
  }) {
    if (hipAvg == null) return;

    if (_repMinHipAvg == null || hipAvg < _repMinHipAvg!) {
      _repMinHipAvg = hipAvg;
      _repBackAngleAtHinge = backAngle;
    }
    if (_repKneeAtStart == null && _state == _DeadliftState.standing) {
      _repKneeAtStart = kneeAvg;
    }
    if (kneeAvg != null && _repKneeAtStart != null) {
      final travel = (kneeAvg - _repKneeAtStart!).abs();
      if (_repMaxKneeTravel == null || travel > _repMaxKneeTravel!) {
        _repMaxKneeTravel = travel;
      }
    }

    switch (_state) {
      case _DeadliftState.standing:
        if (hipAvg < DeadliftThresholds.hipStanding - DeadliftThresholds.hysteresis) {
          _state = _DeadliftState.lowering;
        }
      case _DeadliftState.lowering:
        if (hipAvg <= DeadliftThresholds.hipHinge) _state = _DeadliftState.bottom;
      case _DeadliftState.bottom:
        if (_prevHipAvg != null && hipAvg > _prevHipAvg! + 0.5) {
          _state = _DeadliftState.lifting;
        }
      case _DeadliftState.lifting:
        if (hipAvg >= DeadliftThresholds.hipStanding) {
          _state = _DeadliftState.standing;
          if (recording) _finalizeRep();
          _repKneeAtStart = kneeAvg;
        } else if (_prevHipAvg != null && hipAvg < _prevHipAvg! - 0.5) {
          _state = _DeadliftState.bottom;
        }
    }
    _prevHipAvg = hipAvg;
  }

  void _finalizeRep() {
    reps.add(DeadliftRep(
      n: reps.length + 1,
      hipMin: _repMinHipAvg,
      backDelta: backAngleDelta(_repBackAngleAtHinge),
      kneeTravel: _repMaxKneeTravel,
    ));
    _repMinHipAvg = null;
    _repBackAngleAtHinge = null;
    _repMaxKneeTravel = null;
  }
}
