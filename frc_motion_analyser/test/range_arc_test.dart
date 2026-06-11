import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frc_motion_analyser/widgets/range_arc.dart';

void main() {
  group('arcFraction', () {
    test('returns the value/normative ratio', () {
      expect(arcFraction(60, 120), 0.5);
    });

    test('clamps to 0 when normative is non-positive', () {
      expect(arcFraction(60, 0), 0);
      expect(arcFraction(60, -10), 0);
    });

    test('clamps to 1 when value exceeds normative', () {
      expect(arcFraction(150, 120), 1.0);
    });

    test('clamps to 0 when value is negative', () {
      expect(arcFraction(-10, 120), 0.0);
    });
  });

  group('RangeArc widget', () {
    testWidgets('renders the main value and label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RangeArc(
              arom: 104,
              prom: 118,
              normative: 120,
              label: 'Hip Flex',
            ),
          ),
        ),
      );

      expect(find.text('104°'), findsOneWidget);
      expect(find.text('HIP FLEX'), findsOneWidget);
    });

    testWidgets('animates value changes over 300ms ease-out', (tester) async {
      Widget build(double arom) {
        return MaterialApp(
          home: Scaffold(
            body: RangeArc(
              arom: arom,
              prom: 118,
              normative: 120,
              label: 'Hip Flex',
            ),
          ),
        );
      }

      await tester.pumpWidget(build(60));
      expect(find.text('60°'), findsOneWidget);

      await tester.pumpWidget(build(90));

      // Mid-animation: value should have moved away from the start but
      // not yet reached the end.
      await tester.pump(const Duration(milliseconds: 150));
      final midText = (find
              .byType(Text)
              .evaluate()
              .map((e) => (e.widget as Text).data)
              .firstWhere((t) => t != null && t.endsWith('°')))!;
      final midValue = int.parse(midText.replaceAll('°', ''));
      expect(midValue, greaterThanOrEqualTo(60));
      expect(midValue, lessThanOrEqualTo(90));

      await tester.pumpAndSettle();
      expect(find.text('90°'), findsOneWidget);
    });
  });
}
