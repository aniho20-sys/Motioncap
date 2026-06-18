import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    hide PoseLandmark;

import '../models/pose_landmark.dart';
import 'pose_source.dart';

/// MediaPipe-style landmark order (CLAUDE.md / [PoseLandmarkIndex]) — ML
/// Kit's [PoseLandmarkType] enum mirrors this 33-point layout 1:1, so list
/// position == [PoseLandmarkIndex] value.
const List<PoseLandmarkType> _landmarkOrder = [
  PoseLandmarkType.nose,
  PoseLandmarkType.leftEyeInner,
  PoseLandmarkType.leftEye,
  PoseLandmarkType.leftEyeOuter,
  PoseLandmarkType.rightEyeInner,
  PoseLandmarkType.rightEye,
  PoseLandmarkType.rightEyeOuter,
  PoseLandmarkType.leftEar,
  PoseLandmarkType.rightEar,
  PoseLandmarkType.leftMouth,
  PoseLandmarkType.rightMouth,
  PoseLandmarkType.leftShoulder,
  PoseLandmarkType.rightShoulder,
  PoseLandmarkType.leftElbow,
  PoseLandmarkType.rightElbow,
  PoseLandmarkType.leftWrist,
  PoseLandmarkType.rightWrist,
  PoseLandmarkType.leftPinky,
  PoseLandmarkType.rightPinky,
  PoseLandmarkType.leftIndex,
  PoseLandmarkType.rightIndex,
  PoseLandmarkType.leftThumb,
  PoseLandmarkType.rightThumb,
  PoseLandmarkType.leftHip,
  PoseLandmarkType.rightHip,
  PoseLandmarkType.leftKnee,
  PoseLandmarkType.rightKnee,
  PoseLandmarkType.leftAnkle,
  PoseLandmarkType.rightAnkle,
  PoseLandmarkType.leftHeel,
  PoseLandmarkType.rightHeel,
  PoseLandmarkType.leftFootIndex,
  PoseLandmarkType.rightFootIndex,
];

/// Camera + on-device MediaPipe/ML Kit pose detection — production
/// [PoseSource].
///
/// The `CameraImage` → `InputImage` conversion below follows the standard
/// `google_mlkit_pose_detection` example pattern, but image-format/rotation
/// handling is notoriously device-specific and can't be exercised in this
/// sandbox (no camera hardware). Verify on a real Android + iOS device —
/// if frames are silently dropped, check `image.format`/`planes.length`
/// against what the device actually streams.
class CameraPoseSource implements PoseSource {
  CameraPoseSource({this.lensDirection = CameraLensDirection.front});

  final CameraLensDirection lensDirection;

  CameraController? _controller;
  PoseDetector? _detector;
  final _frameController = StreamController<PoseFrame>.broadcast();
  bool _isDetecting = false;
  bool _isRecordingVideo = false;

  @override
  Stream<PoseFrame> get frames => _frameController.stream;

  @override
  Future<void> initialize() async {
    final cameras = await availableCameras();
    final description = cameras.firstWhere(
      (c) => c.lensDirection == lensDirection,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup:
          Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    await controller.initialize();
    _controller = controller;

    _detector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
    );

    await controller.startImageStream(_onImage);
  }

  void _onImage(CameraImage image) {
    if (_isDetecting) return;
    final controller = _controller;
    final detector = _detector;
    if (controller == null || detector == null) return;

    final inputImage = _inputImageFromCameraImage(image, controller.description);
    if (inputImage == null) return;

    _isDetecting = true;
    detector.processImage(inputImage).then((poses) {
      if (_frameController.isClosed) return;
      _frameController.add(
        _toPoseFrame(poses, Size(image.width.toDouble(), image.height.toDouble())),
      );
    }).whenComplete(() => _isDetecting = false);
  }

  @override
  Widget? buildPreview(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return null;
    return CameraPreview(controller);
  }

  // `startImageStream` (live pose detection, above) and `startVideoRecording`
  // both reconfigure the camera's capture session. Running them concurrently
  // is the standard pattern with CameraX on modern Android and AVFoundation
  // on iOS, but it hasn't been exercised on real hardware in this sandbox —
  // if recording silently fails or pose detection drops out while recording,
  // check here first.
  @override
  Future<void> startVideoRecording() async {
    final controller = _controller;
    if (controller == null || _isRecordingVideo) return;
    await controller.startVideoRecording();
    _isRecordingVideo = true;
  }

  @override
  Future<String?> stopVideoRecording() async {
    final controller = _controller;
    if (controller == null || !_isRecordingVideo) return null;
    _isRecordingVideo = false;
    final file = await controller.stopVideoRecording();
    return file.path;
  }

  @override
  Future<void> dispose() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    await _detector?.close();
    await _frameController.close();
  }
}

InputImage? _inputImageFromCameraImage(CameraImage image, CameraDescription camera) {
  final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
  if (rotation == null) return null;

  final format = InputImageFormatValue.fromRawValue(image.format.raw);
  if (format == null) return null;

  // `imageFormatGroup` above pins Android to nv21 (single plane) and iOS to
  // bgra8888 — anything else is skipped rather than risking a native crash.
  if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
  if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
  if (image.planes.length != 1) return null;

  final plane = image.planes.first;
  return InputImage.fromBytes(
    bytes: plane.bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: plane.bytesPerRow,
    ),
  );
}

PoseFrame _toPoseFrame(List<Pose> poses, Size imageSize) {
  if (poses.isEmpty) return const PoseFrame();

  final pose = poses.first;
  final landmarks = _landmarkOrder.map((type) {
    final lm = pose.landmarks[type];
    if (lm == null) return const PoseLandmark(x: 0, y: 0, visibility: 0);
    return PoseLandmark(
      x: lm.x / imageSize.width,
      y: lm.y / imageSize.height,
      visibility: lm.likelihood,
    );
  }).toList(growable: false);

  return PoseFrame(landmarks: landmarks);
}
