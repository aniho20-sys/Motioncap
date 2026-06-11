import 'dart:ui';

import 'package:flutter/material.dart';

import '../cv/angle_calculator.dart';
import '../models/capture_mode.dart';
import '../models/compensation.dart';
import '../models/pose_landmark.dart';
import '../theme/tokens.dart';

/// Visual state of an [AngleTag] — DESIGN SPEC.md §4 版面: 正常=橙邊、注意=黃邊、
/// 代償=紅邊紅字.
enum AngleTagState { normal, warn, compensation }

/// A single floating joint-angle / compensation label — DESIGN SPEC.md §4
/// 角度tag: 黑底70%透明+blur, DM Mono 11px.
class AngleTag extends StatelessWidget {
  const AngleTag({super.key, required this.text, this.state = AngleTagState.normal});

  final String text;
  final AngleTagState state;

  @override
  Widget build(BuildContext context) {
    final Color borderColor;
    final Color textColor;
    switch (state) {
      case AngleTagState.normal:
        borderColor = const Color(0x80FF5C00); // rgba(255,92,0,.5)
        textColor = Colors.white;
      case AngleTagState.warn:
        borderColor = const Color(0x99FFB020); // rgba(255,176,32,.6)
        textColor = Colors.white;
      case AngleTagState.compensation:
        borderColor = const Color(0x99FF3B5C); // rgba(255,59,92,.6)
        textColor = const Color(0xFFFF8CA0);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xB30A0A0A), // rgba(10,10,10,.7)
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(text, style: AppText.data(size: 11, color: textColor)),
        ),
      ),
    );
  }
}

/// Floating overlay of [AngleTag]s anchored to joint positions, plus
/// compensation tags near the trunk — DESIGN SPEC.md §4 版面.
class AngleTagOverlay extends StatelessWidget {
  const AngleTagOverlay({
    super.key,
    required this.frame,
    required this.angles,
    this.mirror = true,
    this.mode = CaptureMode.hip,
    this.squatView = SquatView.side,
    this.backAngleDelta,
    this.kneeTravel,
  });

  final PoseFrame frame;
  final PoseAngles angles;
  final bool mirror;

  /// Active capture mode — gates which [detectCompensation] alerts surface
  /// as floating tags (e.g. trunk-lean suppression in squat/deadlift).
  final CaptureMode mode;
  final SquatView squatView;

  /// Pre-computed deadlift readings — see [detectCompensation].
  final double? backAngleDelta;
  final double? kneeTravel;

  @override
  Widget build(BuildContext context) {
    final lm = frame.landmarks;
    if (lm.length < PoseLandmarkIndex.total) return const SizedBox.shrink();

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final tags = <Widget>[];

          void addJointTag(int index, String label, double? value) {
            if (value == null) return;
            final point = lm[index];
            if (point.visibility < PoseFrame.visibilityThreshold) return;
            final x = mirror ? (1 - point.x) : point.x;
            tags.add(
              Positioned(
                left: x * size.width,
                top: point.y * size.height,
                child: FractionalTranslation(
                  translation: const Offset(-0.5, -1.4),
                  child: AngleTag(text: '$label ${value.round()}°'),
                ),
              ),
            );
          }

          addJointTag(PoseLandmarkIndex.leftHip, 'L HIP', angles.hipL);
          addJointTag(PoseLandmarkIndex.rightHip, 'R HIP', angles.hipR);
          addJointTag(PoseLandmarkIndex.leftKnee, 'L KNEE', angles.kneeL);
          addJointTag(PoseLandmarkIndex.rightKnee, 'R KNEE', angles.kneeR);
          addJointTag(
            PoseLandmarkIndex.leftShoulder,
            'L SHOULDER',
            angles.shoulderL,
          );
          addJointTag(
            PoseLandmarkIndex.rightShoulder,
            'R SHOULDER',
            angles.shoulderR,
          );

          final alerts = detectCompensation(
            angles,
            mode: mode,
            squatView: squatView,
            backAngleDelta: backAngleDelta,
            kneeTravel: kneeTravel,
          );
          for (var i = 0; i < alerts.length; i++) {
            final alert = alerts[i];
            tags.add(
              Positioned(
                left: size.width / 2,
                top: size.height * 0.32 + i * 30,
                child: FractionalTranslation(
                  translation: const Offset(-0.5, 0),
                  child: AngleTag(
                    text: '${alert.label} ${alert.degrees.abs().toStringAsFixed(1)}°',
                    state: AngleTagState.compensation,
                  ),
                ),
              ),
            );
          }

          return Stack(children: tags);
        },
      ),
    );
  }
}
