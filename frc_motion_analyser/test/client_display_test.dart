import 'package:flutter_test/flutter_test.dart';

import 'package:frc_motion_analyser/models/client_summary.dart';
import 'package:frc_motion_analyser/theme/tokens.dart';
import 'package:frc_motion_analyser/utils/client_display.dart';

void main() {
  final now = DateTime(2026, 6, 11);

  group('jointDeficitTrendColor', () {
    test('narrowed deficit -> good', () {
      const joint = JointHighlight(
        label: 'HIP ER',
        arom: 60,
        prom: 64,
        previousDeficit: 8,
      );
      expect(jointDeficitTrendColor(joint), AppColors.good);
    });

    test('unchanged deficit -> warn', () {
      const joint = JointHighlight(
        label: 'HIP ER',
        arom: 60,
        prom: 65,
        previousDeficit: 5,
      );
      expect(jointDeficitTrendColor(joint), AppColors.warn);
    });

    test('worsened deficit -> deficit', () {
      const joint = JointHighlight(
        label: 'HIP ER',
        arom: 60,
        prom: 70,
        previousDeficit: 5,
      );
      expect(jointDeficitTrendColor(joint), AppColors.deficit);
    });

    test('no previous data -> warn', () {
      const joint = JointHighlight(label: 'HIP ER', arom: 60, prom: 65);
      expect(jointDeficitTrendColor(joint), AppColors.warn);
    });
  });

  group('clientHighlightDisplay', () {
    test('retest due overrides joint trend with RE-TEST / DUE', () {
      final client = ClientSummary(
        id: 'x',
        name: 'Test User',
        age: 50,
        focus: '髖關節重點',
        weekNumber: 9,
        scheduledFor: now,
        lastFullAssessmentDate: now.subtract(const Duration(days: 60)),
        worstJoint: const JointHighlight(
          label: 'HIP ER',
          arom: 60,
          prom: 64,
          previousDeficit: 8,
        ),
      );

      final display = clientHighlightDisplay(client, now);
      expect(display.valueText, 'RE-TEST');
      expect(display.labelText, 'DUE');
      expect(display.color, AppColors.deficit);
    });

    test('on-track client shows worst joint value and label', () {
      final client = ClientSummary(
        id: 'y',
        name: 'On Track',
        age: 50,
        focus: '髖關節重點',
        weekNumber: 6,
        scheduledFor: now,
        lastFullAssessmentDate: now.subtract(const Duration(days: 14)),
        worstJoint: const JointHighlight(
          label: 'HIP ER',
          arom: 62,
          prom: 67,
          previousDeficit: 5,
        ),
      );

      final display = clientHighlightDisplay(client, now);
      expect(display.valueText, '62°');
      expect(display.labelText, 'HIP ER');
      expect(display.color, AppColors.warn);
    });
  });

  group('clientMetaText', () {
    test('shows focus and week number when on track', () {
      final client = ClientSummary(
        id: 'a',
        name: 'A',
        age: 50,
        focus: '髖關節重點',
        weekNumber: 6,
        scheduledFor: now,
        lastFullAssessmentDate: now.subtract(const Duration(days: 14)),
      );
      expect(clientMetaText(client, now), '50 · 髖關節重點 · 第6週');
    });

    test('shows retest-due message when 8週重評到期', () {
      final client = ClientSummary(
        id: 'b',
        name: 'B',
        age: 58,
        focus: '腰椎活動度',
        weekNumber: 9,
        scheduledFor: now,
        lastFullAssessmentDate: now.subtract(const Duration(days: 60)),
      );
      expect(clientMetaText(client, now), '58 · 8週重評到期');
    });
  });
}
