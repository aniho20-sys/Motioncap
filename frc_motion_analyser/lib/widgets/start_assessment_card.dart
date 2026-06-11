import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// "開始評估" CTA — DESIGN SPEC.md §3 版面.
class StartAssessmentCard extends StatelessWidget {
  const StartAssessmentCard({super.key, required this.onSelectClient});

  final VoidCallback onSelectClient;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(20),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.orange, Color(0xFFFF8A3D)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  // rgba(10,10,10,.12)
                  color: const Color(0x1F0A0A0A),
                  width: 14,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '開始評估',
                style: AppText.display(
                  size: 19,
                  weight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'CARs · PAILs/RAILs · 姿勢排列',
                style: AppText.body(
                  size: 12,
                  weight: FontWeight.w500,
                  color: AppColors.ink.withOpacity(.75),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: onSelectClient,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '▶',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '選擇客戶',
                        style: AppText.body(
                          size: 13,
                          weight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
