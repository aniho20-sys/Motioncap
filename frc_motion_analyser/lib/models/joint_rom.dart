/// Normative ROM reference values, in degrees — CLAUDE.md ROM參考數據.
class NormativeRom {
  NormativeRom._();

  /// 髖關節 Flexion 正常範圍 0–120°.
  static const hipFlexion = 120.0;
}

/// Tracks active range of motion for 髖屈曲 (hip flexion) across a session.
///
/// `angle3(SHOULDER, HIP, KNEE)` reads ~180° standing (hip extended) and
/// decreases as the hip flexes, so flexion-degrees = `180 - angle3`.
/// [arom] is the largest flexion observed since the last [reset].
class HipFlexionTracker {
  double _arom = 0;

  /// Active range of motion observed so far, in degrees.
  double get arom => _arom;

  /// Feeds a raw `angle3(SHOULDER, HIP, KNEE)` reading (averaged L/R) and
  /// returns the current flexion angle, or `null` if [rawAngle] is `null`.
  double? update(double? rawAngle) {
    if (rawAngle == null) return null;
    final flexion = (180 - rawAngle).clamp(0.0, 180.0);
    if (flexion > _arom) _arom = flexion;
    return flexion;
  }

  void reset() => _arom = 0;
}
