import 'package:flutter/widgets.dart';

import '../models/pose_landmark.dart';

/// Supplies camera preview + pose-detection frames to Screen 02 — Live.
///
/// Decouples the screen from the `camera` / `google_mlkit_pose_detection`
/// packages so the UI can be previewed and tested without real camera
/// hardware (see [CameraPoseSource] for the production implementation).
abstract class PoseSource {
  /// Prepares the camera and pose detector. Must complete before [frames]
  /// emits or [buildPreview] is used.
  Future<void> initialize();

  /// Emits a new frame each time pose detection runs on a camera frame
  /// (target ≥30fps — DESIGN SPEC.md §4 功能需求).
  Stream<PoseFrame> get frames;

  /// The live camera preview, or `null` if unavailable (e.g. before
  /// [initialize] completes, or permission denied).
  Widget? buildPreview(BuildContext context);

  Future<void> dispose();
}
