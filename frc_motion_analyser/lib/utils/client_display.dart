import 'package:flutter/material.dart';

import '../models/client_summary.dart';
import '../theme/tokens.dart';
import 'retest.dart';

/// What to render in a client row's "mini-arc" value/label slot.
class ClientHighlightDisplay {
  const ClientHighlightDisplay({
    required this.color,
    required this.valueText,
    required this.labelText,
  });

  final Color color;
  final String valueText;
  final String labelText;
}

/// Colour for a joint's deficit trend vs. the previous assessment —
/// DESIGN SPEC.md §3 功能需求: deficit 較上次收窄 → 綠；不變 → 黃；惡化 → 紅。
Color jointDeficitTrendColor(JointHighlight joint) {
  final previous = joint.previousDeficit;
  if (previous == null) return AppColors.warn;

  final deficit = joint.deficit;
  if (deficit < previous) return AppColors.good;
  if (deficit == previous) return AppColors.warn;
  return AppColors.deficit;
}

/// Full display (colour + text) for a client's "今日客戶" row highlight,
/// including the 8週重評到期 override (DESIGN SPEC.md §3 功能需求).
ClientHighlightDisplay clientHighlightDisplay(ClientSummary client, DateTime now) {
  final lastFull = client.lastFullAssessmentDate;
  if (lastFull != null && isRetestDue(lastFull, now)) {
    return const ClientHighlightDisplay(
      color: AppColors.deficit,
      valueText: 'RE-TEST',
      labelText: 'DUE',
    );
  }

  final joint = client.worstJoint;
  if (joint == null) {
    return const ClientHighlightDisplay(
      color: AppColors.muted,
      valueText: '--',
      labelText: '',
    );
  }

  return ClientHighlightDisplay(
    color: jointDeficitTrendColor(joint),
    valueText: '${joint.arom.round()}°',
    labelText: joint.label,
  );
}

/// Meta line under the client name, e.g. "52 · 髖關節重點 · 第6週" or, once
/// 8週重評到期, "58 · 8週重評到期".
String clientMetaText(ClientSummary client, DateTime now) {
  final lastFull = client.lastFullAssessmentDate;
  if (lastFull != null && isRetestDue(lastFull, now)) {
    return '${client.age} · 8週重評到期';
  }
  return '${client.age} · ${client.focus} · 第${client.weekNumber}週';
}
