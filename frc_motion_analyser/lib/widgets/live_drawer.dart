import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Bottom drawer shell — DESIGN SPEC.md §4 版面 + §8: 三段狀態
/// (收起/peek/全開)，`DraggableScrollableSheet` snap points
/// `[0.08, 0.28, 0.85]`.
class LiveDrawer extends StatelessWidget {
  const LiveDrawer({
    super.key,
    required this.controller,
    required this.peekBuilder,
    required this.expandedBuilder,
  });

  final DraggableScrollableController controller;

  /// Content shown once expanded past [collapsedSize] — Range Arc + 2×2
  /// metrics grid (DESIGN SPEC.md §4 版面).
  final WidgetBuilder peekBuilder;

  /// Content shown when fully expanded — list of joints measured this
  /// session (DESIGN SPEC.md §4 功能需求).
  final WidgetBuilder expandedBuilder;

  static const collapsedSize = 0.08;
  static const peekSize = 0.28;
  static const expandedSize = 0.85;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: controller,
      initialChildSize: collapsedSize,
      minChildSize: collapsedSize,
      maxChildSize: expandedSize,
      snap: true,
      snapSizes: const [collapsedSize, peekSize, expandedSize],
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.drawerTop),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: const BoxDecoration(
                // rgba(14,14,14,.94)
                color: Color(0xF00E0E0E),
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  peekBuilder(context),
                  const SizedBox(height: 24),
                  expandedBuilder(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One cell of the peek-state 2×2 metrics grid — DESIGN SPEC.md §4 版面.
class LiveMetricCell extends StatelessWidget {
  const LiveMetricCell({
    super.key,
    required this.value,
    required this.label,
    this.unit,
    this.valueColor = AppColors.text,
  });

  final String value;
  final String? unit;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: AppText.data(size: 21, weight: FontWeight.w500, color: valueColor),
            children: [
              TextSpan(text: value),
              if (unit != null)
                TextSpan(
                  text: unit,
                  style: AppText.data(size: 12, color: AppColors.muted),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: AppText.data(size: 9.5, color: AppColors.muted, letterSpacing: 1.4),
        ),
      ],
    );
  }
}
