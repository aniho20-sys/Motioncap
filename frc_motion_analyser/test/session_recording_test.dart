import 'package:flutter_test/flutter_test.dart';

import 'package:frc_motion_analyser/cv/angle_calculator.dart';
import 'package:frc_motion_analyser/cv/rep_tracker.dart';
import 'package:frc_motion_analyser/models/capture_mode.dart';
import 'package:frc_motion_analyser/models/compensation.dart';
import 'package:frc_motion_analyser/models/session_recording.dart';

void main() {
  test('SessionFrame.toJson includes the timestamp and all angles', () {
    const angles = PoseAngles(
      hipL: 170,
      hipR: 168,
      kneeL: 175,
      kneeR: 174,
      shoulderL: 90,
      shoulderR: 92,
      pelvisTilt: 1.5,
      shoulderTilt: 2.0,
      trunkLean: 8.0,
    );
    final frame = SessionFrame(elapsed: const Duration(milliseconds: 1500), angles: angles);

    expect(frame.toJson(), {
      'tMs': 1500,
      'hipL': 170,
      'hipR': 168,
      'kneeL': 175,
      'kneeR': 174,
      'shoulderL': 90,
      'shoulderR': 92,
      'pelvisTilt': 1.5,
      'shoulderTilt': 2.0,
      'trunkLean': 8.0,
    });
  });

  test('CompensationEvent.toJson includes the timestamp and alert', () {
    const alert = CompensationAlert(label: '骨盆側傾 Pelvic Shift', degrees: 5.0);
    final event = CompensationEvent(elapsed: const Duration(milliseconds: 500), alert: alert);

    expect(event.toJson(), {
      'tMs': 500,
      'label': '骨盆側傾 Pelvic Shift',
      'degrees': 5.0,
    });
  });

  test('SessionRecording.toJson aggregates frames, events and AROM', () {
    final recording = SessionRecording(
      startedAt: DateTime.utc(2026, 1, 1),
      mode: CaptureMode.hip,
    );
    recording.addFrame(Duration.zero, PoseAngles.empty);
    recording.addFrame(const Duration(milliseconds: 500), PoseAngles.empty);
    recording.addCompensationEvent(
      const Duration(milliseconds: 500),
      const CompensationAlert(label: '骨盆側傾 Pelvic Shift', degrees: 5.0),
    );
    recording.hipFlexionAromDeg = 95.0;

    final json = recording.toJson();

    expect(json['startedAt'], '2026-01-01T00:00:00.000Z');
    expect(json['mode'], 'hip');
    expect(json['durationMs'], 500);
    expect(json['hipFlexionAromDeg'], 95.0);
    expect(json['videoPath'], isNull);
    expect((json['frames'] as List).length, 2);
    expect((json['compensationEvents'] as List).length, 1);
    expect((json['squatReps'] as List), isEmpty);
    expect((json['deadliftReps'] as List), isEmpty);
  });

  test('SessionRecording.toJson reports zero duration with no frames', () {
    final recording = SessionRecording(
      startedAt: DateTime.utc(2026, 1, 1),
      mode: CaptureMode.hip,
    );

    expect(recording.toJson()['durationMs'], 0);
  });

  test('SessionRecording.toJson includes squat and deadlift rep logs', () {
    final recording = SessionRecording(
      startedAt: DateTime.utc(2026, 1, 1),
      mode: CaptureMode.squat,
    );
    recording.squatReps.add(const SquatRep(
      n: 1,
      depth: SquatDepth.parallel,
      kneeMin: 95.0,
      backAngle: 12.0,
    ));
    recording.deadliftReps.add(const DeadliftRep(
      n: 1,
      hipMin: 100.0,
      backDelta: 3.0,
      kneeTravel: 8.0,
    ));

    final json = recording.toJson();

    expect(json['squatReps'], [
      {'n': 1, 'depth': 'parallel', 'kneeMin': 95.0, 'backAngle': 12.0},
    ]);
    expect(json['deadliftReps'], [
      {'n': 1, 'hipMin': 100.0, 'backDelta': 3.0, 'kneeTravel': 8.0},
    ]);
  });
}
