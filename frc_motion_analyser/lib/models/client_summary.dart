import 'package:flutter/foundation.dart';

/// A joint highlighted on a client's "今日客戶" row — the worst joint from
/// their last assessment (DESIGN SPEC.md §3).
@immutable
class JointHighlight {
  const JointHighlight({
    required this.label,
    required this.arom,
    required this.prom,
    this.previousDeficit,
  });

  /// e.g. "HIP ER", "SH FLEX".
  final String label;

  final double arom;
  final double prom;

  /// Passive deficit (PROM − AROM) recorded at the previous assessment.
  /// `null` if there is no prior assessment to compare against.
  final double? previousDeficit;

  double get deficit => prom - arom;
}

/// A client scheduled for today, as shown on Screen 01 — Home.
@immutable
class ClientSummary {
  const ClientSummary({
    required this.id,
    required this.name,
    required this.age,
    required this.focus,
    required this.weekNumber,
    required this.scheduledFor,
    this.lastFullAssessmentDate,
    this.worstJoint,
  });

  final String id;
  final String name;
  final int age;

  /// 重點，e.g. "髖關節重點".
  final String focus;

  /// 週數，e.g. 6 → "第6週".
  final int weekNumber;

  /// Today's appointment time, used to sort the "今日客戶" list.
  final DateTime scheduledFor;

  /// Date of the last *full* assessment, used for the 8週重評到期 check.
  final DateTime? lastFullAssessmentDate;

  /// Worst joint from the last assessment, shown on the right of the row.
  final JointHighlight? worstJoint;

  /// Up to two-letter avatar initials, e.g. "Marcus Lee" → "ML".
  String get initials {
    final letters = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0]);
    return letters.take(2).join().toUpperCase();
  }
}

/// "本週數據" summary cards.
@immutable
class WeeklyStats {
  const WeeklyStats({
    required this.assessmentCount,
    required this.avgAromGainDeg,
  });

  final int assessmentCount;
  final double avgAromGainDeg;
}
