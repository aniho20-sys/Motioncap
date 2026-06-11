import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frc_motion_analyser/cv/pose_source.dart';
import 'package:frc_motion_analyser/data/session_storage.dart';
import 'package:frc_motion_analyser/models/pose_landmark.dart';
import 'package:frc_motion_analyser/models/session_recording.dart';
import 'package:frc_motion_analyser/screens/live_screen.dart';
import 'package:frc_motion_analyser/widgets/record_button.dart';

class _FakeSessionStorage implements SessionStorage {
  SessionRecording? saved;

  @override
  Future<String> save(SessionRecording recording) async {
    saved = recording;
    return 'fake/session.json';
  }
}

class _FakePoseSource implements PoseSource {
  final _controller = StreamController<PoseFrame>.broadcast();

  @override
  Future<void> initialize() async {}

  @override
  Stream<PoseFrame> get frames => _controller.stream;

  @override
  Widget? buildPreview(BuildContext context) =>
      const ColoredBox(color: Colors.black);

  @override
  Future<void> dispose() async {
    await _controller.close();
  }

  void emit(PoseFrame frame) => _controller.add(frame);
}

PoseFrame _frameWithVisibleCount(int count) {
  return PoseFrame(
    landmarks: List.generate(
      PoseLandmarkIndex.total,
      (i) => PoseLandmark(x: 0.5, y: 0.5, visibility: i < count ? 1.0 : 0.0),
    ),
  );
}

/// A perfectly upright standing pose — shoulder/hip/knee/ankle stacked
/// vertically per side, so hip/knee angles read ~180°.
PoseFrame _standingFrame() {
  final landmarks = List<PoseLandmark>.filled(
    PoseLandmarkIndex.total,
    const PoseLandmark(x: 0.5, y: 0.5, visibility: 1.0),
  );

  void at(int index, double x, double y) {
    landmarks[index] = PoseLandmark(x: x, y: y, visibility: 1.0);
  }

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

  return PoseFrame(landmarks: landmarks);
}

void main() {
  testWidgets('shows POSE LOCKED with visible landmark count', (tester) async {
    final poseSource = _FakePoseSource();
    addTearDown(poseSource.dispose);

    await tester.pumpWidget(MaterialApp(home: LiveScreen(poseSource: poseSource)));
    await tester.pump();

    poseSource.emit(_frameWithVisibleCount(30));
    await tester.pump();

    expect(find.text('POSE LOCKED · 30/33'), findsOneWidget);
  });

  testWidgets('shows live joint angle tags and the measured-joint list', (tester) async {
    final poseSource = _FakePoseSource();
    addTearDown(poseSource.dispose);

    await tester.pumpWidget(MaterialApp(home: LiveScreen(poseSource: poseSource)));
    await tester.pump();

    poseSource.emit(_standingFrame());
    await tester.pump();

    expect(find.text('L HIP 180°'), findsOneWidget);
    expect(find.text('R KNEE 180°'), findsOneWidget);
    expect(find.text('未有已測關節 · No joints measured yet'), findsNothing);
    expect(find.text('180°'), findsWidgets);
  });

  testWidgets('records a session and saves it on stop', (tester) async {
    final poseSource = _FakePoseSource();
    addTearDown(poseSource.dispose);
    final storage = _FakeSessionStorage();

    await tester.pumpWidget(MaterialApp(
      home: LiveScreen(poseSource: poseSource, sessionStorage: storage),
    ));
    await tester.pump();

    await tester.tap(find.byType(RecordButton));
    await tester.pump();

    expect(find.textContaining('REC'), findsOneWidget);

    poseSource.emit(_standingFrame());
    await tester.pump();

    await tester.tap(find.byType(RecordButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('REC'), findsNothing);
    expect(storage.saved, isNotNull);
    expect(storage.saved!.frames, isNotEmpty);
    expect(find.textContaining('已儲存 Session'), findsOneWidget);
  });

  testWidgets('shows RE-ACQUIRING after sustained pose loss', (tester) async {
    final poseSource = _FakePoseSource();
    addTearDown(poseSource.dispose);

    await tester.pumpWidget(MaterialApp(home: LiveScreen(poseSource: poseSource)));
    await tester.pump();

    for (var i = 0; i < 11; i++) {
      poseSource.emit(_frameWithVisibleCount(5));
      await tester.pump();
    }

    expect(find.text('RE-ACQUIRING'), findsOneWidget);
  });
}
