// lib/core/services/pose_analysis_service.dart
import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/pose_analysis.dart';

class PoseAnalysisService {
  int _repCount = 0;
  String _lastPhase = 'up';

  void resetReps() {
    _repCount = 0;
    _lastPhase = 'up';
  }

  PoseAnalysisResult? analyzePose(Pose pose, SupportedExercise exercise) {
    switch (exercise) {
      case SupportedExercise.squat:
        return _analyzeSquat(pose);
      case SupportedExercise.pushUp:
        return _analyzePushUp(pose);
      case SupportedExercise.deadlift:
        return _analyzeDeadlift(pose);
      case SupportedExercise.bicepCurl:
        return _analyzeBicepCurl(pose);
      case SupportedExercise.shoulderPress:
        return _analyzeShoulderPress(pose);
    }
  }

  double _calculateAngle(
      PoseLandmark first, PoseLandmark mid, PoseLandmark end) {
    final radians = atan2(end.y - mid.y, end.x - mid.x) -
        atan2(first.y - mid.y, first.x - mid.x);
    double angle = radians * 180 / pi;
    if (angle < 0) angle += 360;
    if (angle > 180) angle = 360 - angle;
    return angle;
  }

  PoseAnalysisResult _analyzeSquat(Pose pose) {
    final landmarks = pose.landmarks;
    final issues = <String>[];
    final tips = <String>[];
    double score = 100;

    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];

    if (leftHip == null ||
        leftKnee == null ||
        leftAnkle == null ||
        leftShoulder == null) {
      return PoseAnalysisResult(
        exerciseType: 'squat',
        formScore: 0,
        issues: ['Не вижу тело полностью. Отойдите от камеры.'],
        tips: [],
        phase: _lastPhase,
        repCount: _repCount,
        angles: {},
      );
    }

    final kneeAngle = _calculateAngle(leftHip, leftKnee, leftAnkle);
    final hipAngle = _calculateAngle(leftShoulder, leftHip, leftKnee);

    final currentPhase = kneeAngle < 100 ? 'down' : 'up';
    if (_lastPhase == 'down' && currentPhase == 'up') _repCount++;
    _lastPhase = currentPhase;

    if (currentPhase == 'down') {
      if (kneeAngle > 110) {
        issues.add('Недостаточная глубина приседа');
        tips.add('Приседайте ниже — бёдра должны быть параллельны полу');
        score -= 20;
      }
      if (hipAngle < 45) {
        issues.add('Слишком большой наклон вперёд');
        tips.add('Держите спину прямее, грудь вверх');
        score -= 15;
      }
    }

    return PoseAnalysisResult(
      exerciseType: 'squat',
      formScore: score.clamp(0, 100),
      issues: issues,
      tips: tips,
      phase: currentPhase,
      repCount: _repCount,
      angles: {'knee': kneeAngle, 'hip': hipAngle},
    );
  }

  PoseAnalysisResult _analyzePushUp(Pose pose) {
    final landmarks = pose.landmarks;
    final issues = <String>[];
    final tips = <String>[];
    double score = 100;

    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];

    if (leftShoulder == null ||
        leftElbow == null ||
        leftWrist == null ||
        leftHip == null ||
        leftAnkle == null) {
      return PoseAnalysisResult(
        exerciseType: 'pushup',
        formScore: 0,
        issues: ['Не вижу тело полностью. Расположите камеру сбоку.'],
        tips: [],
        phase: _lastPhase,
        repCount: _repCount,
        angles: {},
      );
    }

    final elbowAngle = _calculateAngle(leftShoulder, leftElbow, leftWrist);
    final bodyAlignment = _calculateAngle(leftShoulder, leftHip, leftAnkle);

    final currentPhase = elbowAngle < 90 ? 'down' : 'up';
    if (_lastPhase == 'down' && currentPhase == 'up') _repCount++;
    _lastPhase = currentPhase;

    if (bodyAlignment < 160 || bodyAlignment > 200) {
      issues.add('Бёдра провисают или подняты');
      tips.add('Держите тело в одну прямую линию от головы до пят');
      score -= 25;
    }

    if (currentPhase == 'down' && elbowAngle > 100) {
      issues.add('Недостаточная глубина отжимания');
      tips.add('Опускайтесь пока грудь почти не касается пола');
      score -= 15;
    }

    return PoseAnalysisResult(
      exerciseType: 'pushup',
      formScore: score.clamp(0, 100),
      issues: issues,
      tips: tips,
      phase: currentPhase,
      repCount: _repCount,
      angles: {'elbow': elbowAngle, 'body': bodyAlignment},
    );
  }

  PoseAnalysisResult _analyzeDeadlift(Pose pose) {
    final landmarks = pose.landmarks;
    final issues = <String>[];
    final tips = <String>[];
    double score = 100;

    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];

    if (leftShoulder == null ||
        leftHip == null ||
        leftKnee == null ||
        leftAnkle == null) {
      return PoseAnalysisResult(
        exerciseType: 'deadlift',
        formScore: 0,
        issues: ['Встаньте боком к камере'],
        tips: [],
        phase: _lastPhase,
        repCount: _repCount,
        angles: {},
      );
    }

    final hipAngle = _calculateAngle(leftShoulder, leftHip, leftKnee);
    final kneeAngle = _calculateAngle(leftHip, leftKnee, leftAnkle);

    final currentPhase = hipAngle < 130 ? 'down' : 'up';
    if (_lastPhase == 'down' && currentPhase == 'up') _repCount++;
    _lastPhase = currentPhase;

    if (leftShoulder.x > leftHip.x + 50) {
      issues.add('Спина округлена');
      tips.add('Держите спину прямой, лопатки сведены');
      score -= 30;
    }

    return PoseAnalysisResult(
      exerciseType: 'deadlift',
      formScore: score.clamp(0, 100),
      issues: issues,
      tips: tips,
      phase: currentPhase,
      repCount: _repCount,
      angles: {'hip': hipAngle, 'knee': kneeAngle},
    );
  }

  PoseAnalysisResult _analyzeBicepCurl(Pose pose) {
    final landmarks = pose.landmarks;
    final issues = <String>[];
    final tips = <String>[];
    double score = 100;

    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final leftHip = landmarks[PoseLandmarkType.leftHip];

    if (leftShoulder == null ||
        leftElbow == null ||
        leftWrist == null ||
        leftHip == null) {
      return PoseAnalysisResult(
        exerciseType: 'bicep_curl',
        formScore: 0,
        issues: ['Не вижу руку полностью'],
        tips: [],
        phase: _lastPhase,
        repCount: _repCount,
        angles: {},
      );
    }

    final elbowAngle = _calculateAngle(leftShoulder, leftElbow, leftWrist);

    final currentPhase = elbowAngle < 60 ? 'up' : 'down';
    if (_lastPhase == 'up' && currentPhase == 'down') _repCount++;
    _lastPhase = currentPhase;

    if (leftElbow.x < leftShoulder.x - 20) {
      issues.add('Локоть уходит вперёд');
      tips.add('Держите локоть прижатым к телу');
      score -= 20;
    }

    if (leftShoulder.x < leftHip.x - 30) {
      issues.add('Раскачка корпуса');
      tips.add('Не используйте инерцию — контролируйте движение');
      score -= 25;
    }

    return PoseAnalysisResult(
      exerciseType: 'bicep_curl',
      formScore: score.clamp(0, 100),
      issues: issues,
      tips: tips,
      phase: currentPhase,
      repCount: _repCount,
      angles: {'elbow': elbowAngle},
    );
  }

  PoseAnalysisResult _analyzeShoulderPress(Pose pose) {
    final landmarks = pose.landmarks;
    final issues = <String>[];
    final tips = <String>[];
    double score = 100;

    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];

    if (leftShoulder == null || leftElbow == null || leftWrist == null) {
      return PoseAnalysisResult(
        exerciseType: 'shoulder_press',
        formScore: 0,
        issues: ['Встаньте лицом к камере'],
        tips: [],
        phase: _lastPhase,
        repCount: _repCount,
        angles: {},
      );
    }

    final elbowAngle = _calculateAngle(leftShoulder, leftElbow, leftWrist);

    final currentPhase = elbowAngle > 150 ? 'up' : 'down';
    if (_lastPhase == 'up' && currentPhase == 'down') _repCount++;
    _lastPhase = currentPhase;

    if (currentPhase == 'down' && elbowAngle > 100) {
      issues.add('Недостаточно опускаете вес');
      tips.add('Опускайте до уровня плеч');
      score -= 15;
    }

    return PoseAnalysisResult(
      exerciseType: 'shoulder_press',
      formScore: score.clamp(0, 100),
      issues: issues,
      tips: tips,
      phase: currentPhase,
      repCount: _repCount,
      angles: {'elbow': elbowAngle},
    );
  }
}
