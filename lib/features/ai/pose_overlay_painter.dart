// lib/features/ai/pose_overlay_painter.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../core/models/pose_analysis.dart';

/// Draws the detected skeleton (bones + joints + angle labels) over the
/// camera preview.
///
/// Landmark x/y from ML Kit are in the coordinate space of the raw
/// [imageSize] (the unrotated camera sensor buffer), not the on-screen
/// preview box, so each point has to be translated using the same
/// rotation/mirroring rules the camera preview itself applies — swap axes
/// for 90/270deg sensor rotation, and mirror horizontally for the front
/// camera at 0/180deg. This is the standard ML Kit + camera plugin mapping
/// (matches google_mlkit_flutter's own example painter).
class PoseOverlayPainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;
  final PoseAnalysisResult? result;

  PoseOverlayPainter({
    required this.pose,
    required this.imageSize,
    required this.rotation,
    required this.cameraLensDirection,
    this.result,
  });

  static const double _minLikelihood = 0.5;

  static const List<List<PoseLandmarkType>> _bones = [
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
    [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
    [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
    [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
    [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
    [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
    [PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel],
    [PoseLandmarkType.leftHeel, PoseLandmarkType.leftFootIndex],
    [PoseLandmarkType.leftAnkle, PoseLandmarkType.leftFootIndex],
    [PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel],
    [PoseLandmarkType.rightHeel, PoseLandmarkType.rightFootIndex],
    [PoseLandmarkType.rightAnkle, PoseLandmarkType.rightFootIndex],
  ];

  // Which landmark each PoseAnalysisResult.angles key was measured at, so
  // its label can be drawn next to the matching joint. Must stay in sync
  // with the vertex landmark used in PoseAnalysisService._calculateAngle
  // calls for each key.
  static const Map<String, PoseLandmarkType> _angleLandmarks = {
    'knee': PoseLandmarkType.leftKnee,
    'kneeRight': PoseLandmarkType.rightKnee,
    'hip': PoseLandmarkType.leftHip,
    'elbow': PoseLandmarkType.leftElbow,
    'body': PoseLandmarkType.leftHip,
  };

  double _translateX(double x, Size canvasSize) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        return x * canvasSize.width / imageSize.height;
      case InputImageRotation.rotation270deg:
        return canvasSize.width - x * canvasSize.width / imageSize.height;
      case InputImageRotation.rotation0deg:
      case InputImageRotation.rotation180deg:
        if (cameraLensDirection == CameraLensDirection.front) {
          return canvasSize.width - x * canvasSize.width / imageSize.width;
        }
        return x * canvasSize.width / imageSize.width;
    }
  }

  double _translateY(double y, Size canvasSize) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return y * canvasSize.height / imageSize.width;
      case InputImageRotation.rotation0deg:
      case InputImageRotation.rotation180deg:
        return y * canvasSize.height / imageSize.height;
    }
  }

  Offset? _point(PoseLandmarkType type, Size canvasSize) {
    final landmark = pose.landmarks[type];
    if (landmark == null || landmark.likelihood < _minLikelihood) return null;
    return Offset(
      _translateX(landmark.x, canvasSize),
      _translateY(landmark.y, canvasSize),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final score = result?.formScore;
    final color = score == null
        ? Colors.cyanAccent
        : (score >= 80 ? Colors.greenAccent : Colors.orangeAccent);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final bone in _bones) {
      final p1 = _point(bone[0], size);
      final p2 = _point(bone[1], size);
      if (p1 != null && p2 != null) {
        canvas.drawLine(p1, p2, linePaint);
      }
    }

    for (final type in pose.landmarks.keys) {
      final point = _point(type, size);
      if (point != null) {
        canvas.drawCircle(point, 6, pointPaint);
      }
    }

    if (result != null) {
      for (final entry in result!.angles.entries) {
        final landmarkType = _angleLandmarks[entry.key];
        if (landmarkType == null) continue;
        final point = _point(landmarkType, size);
        if (point == null) continue;
        _drawAngleLabel(canvas, point, '${entry.value.round()}°', color);
      }
    }
  }

  void _drawAngleLabel(Canvas canvas, Offset point, String text, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          backgroundColor: color.withOpacity(0.75),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, point + const Offset(10, -8));
  }

  @override
  bool shouldRepaint(covariant PoseOverlayPainter oldDelegate) {
    return oldDelegate.pose != pose || oldDelegate.result != result;
  }
}
