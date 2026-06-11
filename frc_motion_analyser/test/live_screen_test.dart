import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frc_motion_analyser/cv/pose_source.dart';
import 'package:frc_motion_analyser/models/pose_landmark.dart';
import 'package:frc_motion_analyser/screens/live_screen.dart';

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
