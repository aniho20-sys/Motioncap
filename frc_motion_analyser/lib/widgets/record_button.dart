import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Floating start/stop control for Live即時評估 — toggles between a red
/// record dot and a stop square, in the same chip styling as
/// `motion-capture-v2.html` (`rgba(0,0,0,.45)` + blur).
class RecordButton extends StatelessWidget {
  const RecordButton({super.key, required this.recording, required this.onPressed});

  final bool recording;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: const Color(0x73000000), // rgba(0,0,0,.45)
          shape: const CircleBorder(side: BorderSide(color: AppColors.line)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Center(
                child: recording
                    ? Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.deficit,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )
                    : Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: AppColors.deficit,
                          shape: BoxShape.circle,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
