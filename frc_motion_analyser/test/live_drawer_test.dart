import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frc_motion_analyser/widgets/live_drawer.dart';

void main() {
  testWidgets('renders peek and expanded content once expanded',
      (tester) async {
    final controller = DraggableScrollableController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              LiveDrawer(
                controller: controller,
                peekBuilder: (_) => const Text('PEEK CONTENT'),
                expandedBuilder: (_) => const Text('EXPANDED CONTENT'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    controller.jumpTo(LiveDrawer.expandedSize);
    await tester.pumpAndSettle();

    expect(find.text('PEEK CONTENT'), findsOneWidget);
    expect(find.text('EXPANDED CONTENT'), findsOneWidget);
  });
}
