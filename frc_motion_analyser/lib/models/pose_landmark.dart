import 'package:flutter/foundation.dart';

/// MediaPipe Pose landmark indices used by FRC angle calculations —
/// CLAUDE.md "MediaPipe Landmark → FRC計算對照".
class PoseLandmarkIndex {
  PoseLandmarkIndex._();

  static const nose = 0;
  static const leftShoulder = 11;
  static const rightShoulder = 12;
  static const leftElbow = 13;
  static const rightElbow = 14;
  static const leftWrist = 15;
  static const rightWrist = 16;
  static const leftHip = 23;
  static const rightHip = 24;
  static const leftKnee = 25;
  static const rightKnee = 26;
  static const leftAnkle = 27;
  static const rightAnkle = 28;

  /// Total landmarks MediaPipe Pose returns.
  static const total = 33;
}

/// A single normalized landmark position (`0..1`, image-relative), plus
/// MediaPipe's visibility/likelihood score.
@immutable
class PoseLandmark {
  const PoseLandmark({
    required this.x,
    required this.y,
    this.visibility = 1.0,
  });

  final double x;
  final double y;
  final double visibility;
}

/// One frame of pose-detection results.
@immutable
class PoseFrame {
  const PoseFrame({this.landmarks = const []});

  /// Indexed per [PoseLandmarkIndex] (33 entries when a full body is
  /// detected; may be empty when nothing is detected).
  final List<PoseLandmark> landmarks;

  /// Visibility threshold above which a landmark is considered "seen" —
  /// matches MediaPipe's conventional 0.5 cutoff.
  static const visibilityThreshold = 0.5;

  /// Number of landmarks with visibility above [visibilityThreshold].
  int get visibleCount =>
      landmarks.where((l) => l.visibility >= visibilityThreshold).length;

  bool get isEmpty => landmarks.isEmpty;
}
