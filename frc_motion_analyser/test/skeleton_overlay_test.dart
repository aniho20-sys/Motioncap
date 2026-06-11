import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frc_motion_analyser/models/pose_landmark.dart';
import 'package:frc_motion_analyser/widgets/skeleton_overlay.dart';

PoseFrame _fullBodyFrame() {
  return PoseFrame(
    landmarks: List.generate(
      PoseLandmarkIndex.total,
      (_) => const PoseLandmark(x: 0.5, y: 0.5, visibility: 1.0),
    ),
  );
}

void main() {
  testWidgets('renders without error for an empty frame', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 200,
          height: 200,
          child: SkeletonOverlay(frame: PoseFrame()),
        ),
      ),
    );

    expect(find.byType(SkeletonOverlay), findsOneWidget);
  });

  testWidgets('renders bones and joints for a full-body frame', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: 200,
          child: SkeletonOverlay(frame: _fullBodyFrame()),
        ),
      ),
    );

    expect(find.byType(SkeletonOverlay), findsOneWidget);
  });

  testWidgets('renders active landmarks without error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: 200,
          child: SkeletonOverlay(
            frame: _fullBodyFrame(),
            activeLandmarks: const {
              PoseLandmarkIndex.leftHip,
              PoseLandmarkIndex.rightHip,
            },
          ),
        ),
      ),
    );

    expect(find.byType(SkeletonOverlay), findsOneWidget);
  });
}
