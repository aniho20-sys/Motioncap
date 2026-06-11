import 'package:flutter_test/flutter_test.dart';

import 'package:frc_motion_analyser/cv/rep_tracker.dart';

void main() {
  group('classifySquatDepth', () {
    test('returns unknown for null', () {
      expect(classifySquatDepth(null), SquatDepth.unknown);
    });

    test('returns shallow at/above the shallow threshold', () {
      expect(classifySquatDepth(0.05), SquatDepth.shallow);
      expect(classifySquatDepth(0.04), SquatDepth.shallow);
    });

    test('returns parallel between 0 and the shallow threshold', () {
      expect(classifySquatDepth(0.02), SquatDepth.parallel);
    });

    test('returns belowParallel at/below zero', () {
      expect(classifySquatDepth(0.0), SquatDepth.belowParallel);
      expect(classifySquatDepth(-0.01), SquatDepth.belowParallel);
    });
  });

  group('SquatRep', () {
    test('isWarn is true only for shallow depth', () {
      const shallow = SquatRep(n: 1, depth: SquatDepth.shallow, kneeMin: 150, backAngle: 5);
      const parallel = SquatRep(n: 2, depth: SquatDepth.parallel, kneeMin: 100, backAngle: 10);
      expect(shallow.isWarn, isTrue);
      expect(parallel.isWarn, isFalse);
    });
  });

  group('SquatRepTracker', () {
    test('completes one rep, tracking depth/knee-min/back-angle at the deepest point', () {
      final tracker = SquatRepTracker();

      tracker.update(kneeAvg: 170, hipKneeDelta: 0.05, backAngle: 5, recording: true); // standing
      tracker.update(kneeAvg: 150, hipKneeDelta: 0.02, backAngle: 10, recording: true); // descending
      tracker.update(kneeAvg: 95, hipKneeDelta: -0.01, backAngle: 20, recording: true); // bottom
      tracker.update(kneeAvg: 100, hipKneeDelta: 0.0, backAngle: 18, recording: true); // ascending
      tracker.update(kneeAvg: 170, hipKneeDelta: 0.05, backAngle: 5, recording: true); // standing

      expect(tracker.repCount, 1);
      final rep = tracker.lastRep!;
      expect(rep.n, 1);
      expect(rep.kneeMin, 95);
      expect(rep.depth, SquatDepth.belowParallel);
      expect(rep.backAngle, 20);
    });

    test('does not finalize a rep while not recording', () {
      final tracker = SquatRepTracker();

      tracker.update(kneeAvg: 170, hipKneeDelta: 0.05, backAngle: 5, recording: false);
      tracker.update(kneeAvg: 150, hipKneeDelta: 0.02, backAngle: 10, recording: false);
      tracker.update(kneeAvg: 95, hipKneeDelta: -0.01, backAngle: 20, recording: false);
      tracker.update(kneeAvg: 100, hipKneeDelta: 0.0, backAngle: 18, recording: false);
      tracker.update(kneeAvg: 170, hipKneeDelta: 0.05, backAngle: 5, recording: false);

      expect(tracker.repCount, 0);
      expect(tracker.lastRep, isNull);
    });

    test('ignores frames with no knee reading', () {
      final tracker = SquatRepTracker();
      tracker.update(kneeAvg: null, hipKneeDelta: 0.05, backAngle: 5, recording: true);
      expect(tracker.repCount, 0);
      expect(tracker.lastRep, isNull);
    });

    test('reset clears state and rep history', () {
      final tracker = SquatRepTracker();
      tracker.update(kneeAvg: 170, hipKneeDelta: 0.05, backAngle: 5, recording: true);
      tracker.update(kneeAvg: 150, hipKneeDelta: 0.02, backAngle: 10, recording: true);
      tracker.update(kneeAvg: 95, hipKneeDelta: -0.01, backAngle: 20, recording: true);
      tracker.update(kneeAvg: 100, hipKneeDelta: 0.0, backAngle: 18, recording: true);
      tracker.update(kneeAvg: 170, hipKneeDelta: 0.05, backAngle: 5, recording: true);
      expect(tracker.repCount, 1);

      tracker.reset();
      expect(tracker.repCount, 0);
      expect(tracker.lastRep, isNull);
      expect(tracker.reps, isEmpty);
    });
  });

  group('DeadliftRep', () {
    test('warn flags use the compensation thresholds', () {
      const rounding = DeadliftRep(n: 1, hipMin: 100, backDelta: 20, kneeTravel: 5);
      const travel = DeadliftRep(n: 2, hipMin: 100, backDelta: 5, kneeTravel: 15);
      const clean = DeadliftRep(n: 3, hipMin: 100, backDelta: 5, kneeTravel: 5);

      expect(rounding.isBackRoundingWarn, isTrue);
      expect(rounding.isWarn, isTrue);
      expect(travel.isKneeTravelWarn, isTrue);
      expect(travel.isWarn, isTrue);
      expect(clean.isWarn, isFalse);
    });
  });

  group('DeadliftRepTracker', () {
    test('completes one rep, tracking hip-min/knee-travel/back-delta vs calibrated neutral', () {
      final tracker = DeadliftRepTracker();
      tracker.calibrate(5.0);

      tracker.update(hipAvg: 170, kneeAvg: 175, backAngle: 5, recording: true); // standing
      tracker.update(hipAvg: 150, kneeAvg: 170, backAngle: 8, recording: true); // lowering
      tracker.update(hipAvg: 105, kneeAvg: 160, backAngle: 25, recording: true); // bottom
      tracker.update(hipAvg: 110, kneeAvg: 162, backAngle: 22, recording: true); // lifting
      tracker.update(hipAvg: 170, kneeAvg: 175, backAngle: 5, recording: true); // standing

      expect(tracker.repCount, 1);
      final rep = tracker.lastRep!;
      expect(rep.hipMin, 105);
      expect(rep.backDelta, 20);
      expect(rep.kneeTravel, 15);
    });

    test('reset preserves the calibrated neutral back angle', () {
      final tracker = DeadliftRepTracker();
      tracker.calibrate(7.0);
      tracker.update(hipAvg: 170, kneeAvg: 175, backAngle: 7, recording: true);

      tracker.reset();

      expect(tracker.neutralBackAngle, 7.0);
      expect(tracker.repCount, 0);
    });

    test('calibrate ignores a null back angle', () {
      final tracker = DeadliftRepTracker();
      tracker.calibrate(null);
      expect(tracker.neutralBackAngle, isNull);
    });

    test('backAngleDelta is null without calibration or a current reading', () {
      final tracker = DeadliftRepTracker();
      expect(tracker.backAngleDelta(10), isNull);

      tracker.calibrate(5);
      expect(tracker.backAngleDelta(null), isNull);
      expect(tracker.backAngleDelta(10), 5);
    });
  });
}
