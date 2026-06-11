import 'package:flutter/material.dart';

import '../models/client_summary.dart';
import '../theme/tokens.dart';

/// "本週數據" — two side-by-side stat cards (DESIGN SPEC.md §3 版面).
class WeeklyStatsRow extends StatelessWidget {
  const WeeklyStatsRow({super.key, required this.stats});

  final WeeklyStats stats;

  @override
  Widget build(BuildContext context) {
    final gain = stats.avgAromGainDeg;
    final gainText =
        '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(1)}°';

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '${stats.assessmentCount}',
            label: '評估次數',
            valueColor: AppColors.text,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: gainText,
            label: '平均AROM增幅',
            valueColor: gain >= 0 ? AppColors.good : AppColors.deficit,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          Text(value, style: AppText.data(size: 22, color: valueColor)),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppText.data(
              size: 10,
              color: AppColors.muted,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}
