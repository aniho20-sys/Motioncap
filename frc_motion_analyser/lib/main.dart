import 'package:flutter/material.dart';

import 'theme/tokens.dart';
import 'widgets/range_arc.dart';

void main() {
  runApp(const MotionAnalyserApp());
}

class MotionAnalyserApp extends StatelessWidget {
  const MotionAnalyserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FRC Motion Analyser',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.ink,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.orange,
          brightness: Brightness.dark,
        ),
      ),
      home: const _RangeArcGallery(),
    );
  }
}

/// Temporary preview screen for the Range Arc widget (DESIGN SPEC.md §9
/// step 1). Will be replaced by Screen 01 — Home in the next step.
class _RangeArcGallery extends StatelessWidget {
  const _RangeArcGallery();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text('Range Arc', style: AppText.display(size: 24)),
              const SizedBox(height: 4),
              Text(
                'Design tokens + signature component preview',
                style: AppText.body(size: 14, color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                children: const [
                  RangeArc(
                    arom: 104,
                    prom: 118,
                    normative: 120,
                    label: 'Hip Flex',
                  ),
                  RangeArc(
                    arom: 38,
                    prom: 41,
                    normative: 45,
                    label: 'Hip ER',
                  ),
                  RangeArc(
                    arom: 150,
                    prom: 168,
                    normative: 180,
                    label: 'SH Flex',
                    size: 86,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
