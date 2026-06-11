import 'package:flutter/material.dart';

import '../models/pose_landmark.dart';
import '../theme/tokens.dart';

/// Bones drawn over the camera feed — shoulders/hips girdle plus arms and
/// legs (CLAUDE.md landmark set).
const List<List<int>> poseConnections = [
  [PoseLandmarkIndex.leftShoulder, PoseLandmarkIndex.rightShoulder],
  [PoseLandmarkIndex.leftShoulder, PoseLandmarkIndex.leftElbow],
  [PoseLandmarkIndex.leftElbow, PoseLandmarkIndex.leftWrist],
  [PoseLandmarkIndex.rightShoulder, PoseLandmarkIndex.rightElbow],
  [PoseLandmarkIndex.rightElbow, PoseLandmarkIndex.rightWrist],
  [PoseLandmarkIndex.leftShoulder, PoseLandmarkIndex.leftHip],
  [PoseLandmarkIndex.rightShoulder, PoseLandmarkIndex.rightHip],
  [PoseLandmarkIndex.leftHip, PoseLandmarkIndex.rightHip],
  [PoseLandmarkIndex.leftHip, PoseLandmarkIndex.leftKnee],
  [PoseLandmarkIndex.leftKnee, PoseLandmarkIndex.leftAnkle],
  [PoseLandmarkIndex.rightHip, PoseLandmarkIndex.rightKnee],
  [PoseLandmarkIndex.rightKnee, PoseLandmarkIndex.rightAnkle],
];

/// Skeleton overlay — DESIGN SPEC.md §4 版面: 橙線2.5px，關節點：黑底橙邊圓，
/// 活躍關節實心橙.
class SkeletonOverlay extends StatelessWidget {
  const SkeletonOverlay({
    super.key,
    required this.frame,
    this.activeLandmarks = const {},
    this.mirror = true,
  });

  final PoseFrame frame;

  /// Landmark indices to render as solid orange (the joint(s) currently
  /// being measured).
  final Set<int> activeLandmarks;

  /// Mirror horizontally — front-facing camera feeds are mirrored so the
  /// overlay matches what the user sees of themselves.
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _SkeletonPainter(
          frame: frame,
          activeLandmarks: activeLandmarks,
          mirror: mirror,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter({
    required this.frame,
    required this.activeLandmarks,
    required this.mirror,
  });

  final PoseFrame frame;
  final Set<int> activeLandmarks;
  final bool mirror;

  static const double _boneWidth = 2.5;
  static const double _jointRadius = 5;
  static const double _jointBorderWidth = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final landmarks = frame.landmarks;
    if (landmarks.isEmpty) return;

    Offset position(int index) {
      final lm = landmarks[index];
      final x = mirror ? (1 - lm.x) : lm.x;
      return Offset(x * size.width, lm.y * size.height);
    }

    bool visible(int index) =>
        index < landmarks.length &&
        landmarks[index].visibility >= PoseFrame.visibilityThreshold;

    final bonePaint = Paint()
      ..color = AppColors.orange
      ..strokeWidth = _boneWidth
      ..strokeCap = StrokeCap.round;

    for (final bone in poseConnections) {
      final a = bone[0];
      final b = bone[1];
      if (a >= landmarks.length || b >= landmarks.length) continue;
      if (!visible(a) || !visible(b)) continue;
      canvas.drawLine(position(a), position(b), bonePaint);
    }

    final jointFillPaint = Paint()..color = AppColors.ink;
    final jointBorderPaint = Paint()
      ..color = AppColors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = _jointBorderWidth;
    final activeJointPaint = Paint()..color = AppColors.orange;

    for (var i = 0; i < landmarks.length; i++) {
      if (!visible(i)) continue;
      final center = position(i);
      if (activeLandmarks.contains(i)) {
        canvas.drawCircle(center, _jointRadius, activeJointPaint);
      } else {
        canvas.drawCircle(center, _jointRadius, jointFillPaint);
        canvas.drawCircle(center, _jointRadius, jointBorderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SkeletonPainter oldDelegate) {
    return oldDelegate.frame != frame ||
        !setEquals(oldDelegate.activeLandmarks, activeLandmarks) ||
        oldDelegate.mirror != mirror;
  }
}
