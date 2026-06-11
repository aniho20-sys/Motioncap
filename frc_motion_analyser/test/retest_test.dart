import 'package:flutter_test/flutter_test.dart';

import 'package:frc_motion_analyser/utils/retest.dart';

void main() {
  group('isRetestDue', () {
    final now = DateTime(2026, 6, 11);

    test('55 days since last full assessment is not yet due', () {
      final lastFull = now.subtract(const Duration(days: 55));
      expect(isRetestDue(lastFull, now), isFalse);
    });

    test('56 days since last full assessment is due', () {
      final lastFull = now.subtract(const Duration(days: 56));
      expect(isRetestDue(lastFull, now), isTrue);
    });

    test('57 days since last full assessment is due', () {
      final lastFull = now.subtract(const Duration(days: 57));
      expect(isRetestDue(lastFull, now), isTrue);
    });
  });
}
