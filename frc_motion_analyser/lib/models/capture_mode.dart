import '../cv/angle_calculator.dart';

/// Live capture modes — motion-capture-v2.html `#modebar` (5 modes).
///
/// Each mode functionally filters which joint-angle cards are shown
/// ([modeJointCards]) and, for [squat]/[deadlift], adds a dedicated
/// analysis section with rep counting.
enum CaptureMode { hip, shoulder, full, squat, deadlift }

extension CaptureModeLabel on CaptureMode {
  /// Mode-bar button label — motion-capture-v2.html `#modebar` buttons.
  String get label => switch (this) {
        CaptureMode.hip => '髖 Hip',
        CaptureMode.shoulder => '肩 Shoulder',
        CaptureMode.full => '全身 Full',
        CaptureMode.squat => '深蹲 Squat',
        CaptureMode.deadlift => '硬舉 Deadlift',
      };
}

/// Camera-facing sub-view for [CaptureMode.squat] — depth/back-angle need
/// a side view, knee valgus needs a front view (one camera angle can't
/// give both) — motion-capture-v2.html `squatView`.
enum SquatView { side, front }

extension SquatViewLabel on SquatView {
  String get label => switch (this) {
        SquatView.side => '側面 Side',
        SquatView.front => '正面 Front',
      };
}

/// The six tracked joint angles shown as cards / list rows.
enum JointKey { hipL, hipR, kneeL, kneeR, shoulderL, shoulderR }

extension JointKeyValue on JointKey {
  /// Display label for the expanded joint list.
  String get label => switch (this) {
        JointKey.hipL => 'L HIP',
        JointKey.hipR => 'R HIP',
        JointKey.kneeL => 'L KNEE',
        JointKey.kneeR => 'R KNEE',
        JointKey.shoulderL => 'L SHOULDER',
        JointKey.shoulderR => 'R SHOULDER',
      };

  /// Reads the matching field off [angles].
  double? valueOf(PoseAngles angles) => switch (this) {
        JointKey.hipL => angles.hipL,
        JointKey.hipR => angles.hipR,
        JointKey.kneeL => angles.kneeL,
        JointKey.kneeR => angles.kneeR,
        JointKey.shoulderL => angles.shoulderL,
        JointKey.shoulderR => angles.shoulderR,
      };
}

/// Which [JointKey]s are relevant to each [CaptureMode] —
/// motion-capture-v2.html `MODE_ANGLE_CARDS`.
const modeJointCards = <CaptureMode, Set<JointKey>>{
  CaptureMode.hip: {JointKey.hipL, JointKey.hipR},
  CaptureMode.shoulder: {JointKey.shoulderL, JointKey.shoulderR},
  CaptureMode.full: {
    JointKey.hipL,
    JointKey.hipR,
    JointKey.kneeL,
    JointKey.kneeR,
    JointKey.shoulderL,
    JointKey.shoulderR,
  },
  CaptureMode.squat: {
    JointKey.hipL,
    JointKey.hipR,
    JointKey.kneeL,
    JointKey.kneeR,
  },
  CaptureMode.deadlift: {
    JointKey.hipL,
    JointKey.hipR,
    JointKey.kneeL,
    JointKey.kneeR,
  },
};

/// Recommended camera framing for [mode] (squat depends on [squatView]) —
/// motion-capture-v2.html `MODE_HINTS`. Returns `null` when no hint applies.
String? cameraHint(CaptureMode mode, SquatView squatView) {
  switch (mode) {
    case CaptureMode.squat:
      return squatView == SquatView.side
          ? '建議側面拍攝以分析深蹲深度與背部角度 — Side view recommended for depth & back angle'
          : '建議正面拍攝以檢查膝關節內扣 — Front view recommended for knee tracking';
    case CaptureMode.deadlift:
      return '建議側面拍攝以分析髖鉸鏈與背部角度 — Side view recommended for hip hinge & back angle';
    case CaptureMode.hip:
    case CaptureMode.shoulder:
    case CaptureMode.full:
      return null;
  }
}
