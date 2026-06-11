import 'package:flutter/material.dart';

import '../models/capture_mode.dart';
import '../theme/tokens.dart';

/// Capture-mode selector — motion-capture-v2.html `#modebar` (5 modes).
class CaptureModeBar extends StatelessWidget {
  const CaptureModeBar({super.key, required this.mode, required this.onChanged});

  final CaptureMode mode;
  final ValueChanged<CaptureMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final m in CaptureMode.values)
          _ModeChip(label: m.label, active: m == mode, onTap: () => onChanged(m)),
      ],
    );
  }
}

/// Side/front sub-toggle for [CaptureMode.squat] — motion-capture-v2.html
/// `#squat-view-toggle`.
class SquatViewToggle extends StatelessWidget {
  const SquatViewToggle({super.key, required this.view, required this.onChanged});

  final SquatView view;
  final ValueChanged<SquatView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final v in SquatView.values)
          _ModeChip(label: v.label, active: v == view, onTap: () => onChanged(v)),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.orange : AppColors.surface2,
          border: Border.all(color: active ? AppColors.orange : AppColors.line),
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Text(
          label,
          style: AppText.data(
            size: 11,
            weight: FontWeight.w600,
            color: active ? Colors.white : AppColors.text,
          ),
        ),
      ),
    );
  }
}

/// Recommended-camera-framing pill — motion-capture-v2.html `#camera-hint`.
class CameraHintBanner extends StatelessWidget {
  const CameraHintBanner({super.key, required this.hint});

  /// The hint text, or `null` to render nothing — [cameraHint].
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final hint = this.hint;
    if (hint == null) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0x99141414), // rgba(20,20,20,.6)
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Text(
          hint,
          textAlign: TextAlign.center,
          style: AppText.data(size: 11, weight: FontWeight.w600, color: AppColors.muted),
        ),
      ),
    );
  }
}
