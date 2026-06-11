import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frc_motion_analyser/widgets/live_hud.dart';

void main() {
  testWidgets('shows REC chip with elapsed time and locked landmark count',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LiveHud(
            recording: true,
            elapsed: Duration(minutes: 1, seconds: 5),
            poseLockState: PoseLockState.locked,
            visibleLandmarkCount: 33,
          ),
        ),
      ),
    );

    expect(find.text('REC 01:05'), findsOneWidget);
    expect(find.text('POSE LOCKED · 33/33'), findsOneWidget);
  });

  testWidgets('hides REC chip and shows RE-ACQUIRING when pose is lost',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LiveHud(
            recording: false,
            elapsed: Duration.zero,
            poseLockState: PoseLockState.reacquiring,
            visibleLandmarkCount: 12,
          ),
        ),
      ),
    );

    expect(find.textContaining('REC'), findsNothing);
    expect(find.text('RE-ACQUIRING'), findsOneWidget);
  });
}
