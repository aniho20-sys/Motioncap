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

  /// Starts saving the camera feed to a video file alongside live pose
  /// detection. Sources that can't record video should no-op.
  Future<void> startVideoRecording();

  /// Stops recording and returns the saved video file's path, or `null` if
  /// recording wasn't active or isn't supported by this source.
  Future<String?> stopVideoRecording();

  Future<void> dispose();
}
