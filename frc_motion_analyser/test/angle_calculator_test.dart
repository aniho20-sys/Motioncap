import 'package:flutter_test/flutter_test.dart';

import 'package:frc_motion_analyser/cv/angle_calculator.dart';
import 'package:frc_motion_analyser/models/capture_mode.dart';
import 'package:frc_motion_analyser/models/compensation.dart';
import 'package:frc_motion_analyser/models/joint_rom.dart';
import 'package:frc_motion_analyser/models/pose_landmark.dart';

const _vis = 1.0;

PoseLandmark _p(double x, double y) => PoseLandmark(x: x, y: y, visibility: _vis);

void main() {
  group('angle3', () {
    test('returns 90 for a right angle', () {
      final angle = angle3(_p(0, -1), _p(0, 0), _p(1, 0));
      expect(angle, closeTo(90, 1e-9));
    });

    test('returns 180 for a straight line', () {
      final angle = angle3(_p(0, -1), _p(0, 0), _p(0, 1));
      expect(angle, closeTo(180, 1e-9));
    });

    test('returns null when a leg has zero length', () {
      expect(angle3(_p(0, 0), _p(0, 0), _p(1, 0)), isNull);
    });
  });

  group('tiltAngle', () {
    test('returns 0 for a level horizontal pair', () {
      expect(tiltAngle(_p(0, 0.5), _p(1, 0.5)), closeTo(0, 1e-9));
    });

    test('is positive when b is below a', () {
      expect(tiltAngle(_p(0, 0.4), _p(1, 0.5)), greaterThan(0));
    });
  });

  group('avgOf', () {
    test('averages two values', () {
      expect(avgOf(10, 20), 15);
    });

    test('falls back to whichever side is non-null', () {
      expect(avgOf(null, 20), 20);
      expect(avgOf(10, null), 10);
      expect(avgOf(null, null), isNull);
    });
  });

  group('computeAngles', () {
    test('returns empty for a frame without a full body', () {
      final frame = PoseFrame(
        landmarks: List.generate(10, (_) => _p(0.5, 0.5)),
      );
      expect(computeAngles(frame), PoseAngles.empty);
    });

    test('computes hip/knee/shoulder angles and alignment for a standing pose', () {
      final landmarks = List<PoseLandmark>.filled(
        PoseLandmarkIndex.total,
        _p(0.5, 0.5),
      );

      PoseLandmark at(int index, double x, double y) {
        landmarks[index] = _p(x, y);
        return landmarks[index];
      }

      // A perfectly upright standing pose: shoulder/hip/knee/ankle stacked
      // vertically per side, shoulders and hips level L/R.
      at(PoseLandmarkIndex.leftShoulder, 0.45, 0.2);
      at(PoseLandmarkIndex.rightShoulder, 0.55, 0.2);
      at(PoseLandmarkIndex.leftElbow, 0.45, 0.35);
      at(PoseLandmarkIndex.rightElbow, 0.55, 0.35);
      at(PoseLandmarkIndex.leftHip, 0.45, 0.5);
      at(PoseLandmarkIndex.rightHip, 0.55, 0.5);
      at(PoseLandmarkIndex.leftKnee, 0.45, 0.7);
      at(PoseLandmarkIndex.rightKnee, 0.55, 0.7);
      at(PoseLandmarkIndex.leftAnkle, 0.45, 0.9);
      at(PoseLandmarkIndex.rightAnkle, 0.55, 0.9);

      final angles = computeAngles(PoseFrame(landmarks: landmarks));

      // Standing: shoulder-hip-knee roughly colinear → ~180° (hip extended).
      expect(angles.hipL, closeTo(180, 1));
      expect(angles.hipR, closeTo(180, 1));
      // Knee straight → ~180°.
      expect(angles.kneeL, closeTo(180, 1));
      expect(angles.kneeR, closeTo(180, 1));
      // Level hips/shoulders → ~0° tilt.
      expect(angles.pelvisTilt, closeTo(0, 1));
      expect(angles.shoulderTilt, closeTo(0, 1));
      // Mid-hip directly below mid-shoulder → ~0° trunk lean.
      expect(angles.trunkLean, closeTo(0, 1));
      // hipY (0.5) - kneeY (0.7) — 深蹲深度 proxy.
      expect(angles.hipKneeDeltaY, closeTo(-0.2, 1e-9));
      // |kneeL.x - kneeR.x| / |ankleL.x - ankleR.x| — both 0.1 wide here.
      expect(angles.kneeValgusRatio, closeTo(1.0, 1e-9));
    });
  });

  group('detectCompensation', () {
    test('returns no alerts when within thresholds', () {
      const angles = PoseAngles(pelvisTilt: 1, shoulderTilt: 2, trunkLean: 5);
      expect(detectCompensation(angles), isEmpty);
    });

    test('flags pelvic shift, shoulder hike and trunk lean over threshold', () {
      const angles = PoseAngles(pelvisTilt: 5, shoulderTilt: 8, trunkLean: 15);
      final alerts = detectCompensation(angles);
      expect(alerts, hasLength(3));
      expect(alerts.map((a) => a.label), contains('骨盆側傾 Pelvic Shift'));
      expect(alerts.map((a) => a.label), contains('肩胛代償 Shoulder Hike'));
      expect(alerts.map((a) => a.label), contains('軀幹前傾代償 Trunk Lean'));
    });

    test('suppresses trunk lean alert in squat and deadlift modes', () {
      const angles = PoseAngles(trunkLean: 15);
      expect(detectCompensation(angles, mode: CaptureMode.squat), isEmpty);
      expect(detectCompensation(angles, mode: CaptureMode.deadlift), isEmpty);
      expect(detectCompensation(angles, mode: CaptureMode.hip), hasLength(1));
    });

    test('flags left/right joint-angle asymmetry over threshold', () {
      const angles = PoseAngles(
        hipL: 100,
        hipR: 80,
        kneeL: 90,
        kneeR: 70,
        shoulderL: 100,
        shoulderR: 80,
      );
      final labels = detectCompensation(angles).map((a) => a.label);
      expect(labels, contains('髖 Hip 左右不對稱 Asymmetry'));
      expect(labels, contains('膝 Knee 左右不對稱 Asymmetry'));
      expect(labels, contains('肩 Shoulder 左右不對稱 Asymmetry'));
    });

    test('flags knee valgus only in squat front view', () {
      const angles = PoseAngles(kneeValgusRatio: 0.5);
      expect(
        detectCompensation(angles, mode: CaptureMode.squat, squatView: SquatView.front)
            .map((a) => a.label),
        contains('膝內扣 Knee Valgus'),
      );
      expect(
        detectCompensation(angles, mode: CaptureMode.squat, squatView: SquatView.side),
        isEmpty,
      );
      expect(detectCompensation(angles, mode: CaptureMode.hip), isEmpty);
    });

    test('flags back angle deviation and excessive knee travel for deadlift', () {
      final labels = detectCompensation(
        PoseAngles.empty,
        mode: CaptureMode.deadlift,
        backAngleDelta: 20,
        kneeTravel: 15,
      ).map((a) => a.label);
      expect(labels, contains('背部角度偏離中立 Back Angle Deviation'));
      expect(labels, contains('膝關節過度移動 Excessive Knee Travel'));
    });
  });

  group('HipFlexionTracker', () {
    test('tracks the maximum flexion observed', () {
      final tracker = HipFlexionTracker();
      expect(tracker.update(180), 0);
      expect(tracker.update(120), 60);
      expect(tracker.update(150), 30);
      expect(tracker.arom, 60);
    });

    test('reset clears the tracked AROM', () {
      final tracker = HipFlexionTracker();
      tracker.update(100);
      expect(tracker.arom, 80);
      tracker.reset();
      expect(tracker.arom, 0);
    });

    test('returns null without updating for a null reading', () {
      final tracker = HipFlexionTracker();
      expect(tracker.update(null), isNull);
      expect(tracker.arom, 0);
    });
  });
}
