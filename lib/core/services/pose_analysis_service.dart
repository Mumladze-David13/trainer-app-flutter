// lib/core/services/pose_analysis_service.dart
import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/pose_analysis.dart';

class PoseAnalysisService {
  int _repCount = 0;
  String _lastPhase = 'up';
  // Peak knee angle reached during the current/last 'up' phase, used to
  // judge whether the previous rep locked out fully at the top.
  double? _squatTopAngle;
  // knee-spread/ankle-spread ratio captured while standing (front view),
  // used as this person's own baseline stance instead of a fixed constant —
  // people's standing knee/ankle ratio varies naturally, so an absolute
  // threshold flagged normal stances as "knees caving in".
  double? _squatBaselineKneeAnkleRatio;

  void resetReps() {
    _repCount = 0;
    _lastPhase = 'up';
    _squatTopAngle = null;
    _squatBaselineKneeAnkleRatio = null;
  }

  PoseAnalysisResult? analyzePose(
    Pose pose,
    SupportedExercise exercise, {
    CameraViewMode viewMode = CameraViewMode.side,
  }) {
    switch (exercise) {
      case SupportedExercise.squat:
        return _analyzeSquat(pose, viewMode);
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

  PoseAnalysisResult _analyzeSquat(Pose pose, CameraViewMode viewMode) {
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

    final currentPhase = kneeAngle < 120 ? 'down' : 'up';
    final wasUp = _lastPhase == 'up';
    if (_lastPhase == 'down' && currentPhase == 'up') _repCount++;

    // Track the peak knee angle reached during the 'up' phase so the next
    // descent can flag if the previous rep never fully locked out at top.
    if (currentPhase == 'up') {
      _squatTopAngle = wasUp && _squatTopAngle != null
          ? (kneeAngle > _squatTopAngle! ? kneeAngle : _squatTopAngle!)
          : kneeAngle;
    }
    _lastPhase = currentPhase;

    final angles = <String, double>{'knee': kneeAngle, 'hip': hipAngle};
    // Not scored yet — no established good/bad threshold for some of these.
    // Logged raw so thresholds can be picked later from real collected data
    // instead of guessed upfront.
    final calibrationMetrics = <String, double>{};

    // Depth is judged continuously (not just once "down" is reached) so the
    // score reflects how close to full depth (~100°) the current frame is,
    // instead of staying at 100 the whole time the knee hasn't crossed the
    // phase threshold yet.
    final depthDeficit = (kneeAngle - 100).clamp(0, 80);
    if (depthDeficit > 0) {
      issues.add(
          'Недостаточная глубина приседа (колено ${kneeAngle.round()}°, нужно ≤100°)');
      tips.add('Приседайте ниже — бёдра должны быть параллельны полу');
      score -= depthDeficit;
    }

    if (viewMode == CameraViewMode.side) {
      if (currentPhase == 'down' && hipAngle < 45) {
        issues.add('Слишком большой наклон вперёд');
        tips.add('Держите спину прямее, грудь вверх');
        score -= 15;
      }

      if (currentPhase == 'down' &&
          _squatTopAngle != null &&
          _squatTopAngle! < 165) {
        issues.add('В предыдущем повторении ноги не выпрямились полностью вверху');
        tips.add('Полностью выпрямляйте колени в верхней точке');
        score -= 10;
      }
    }

    if (viewMode == CameraViewMode.front) {
      final rightHip = landmarks[PoseLandmarkType.rightHip];
      final rightKnee = landmarks[PoseLandmarkType.rightKnee];
      final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];
      final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];

      if (rightHip != null &&
          rightKnee != null &&
          rightAnkle != null &&
          rightShoulder != null) {
        final rightKneeAngle = _calculateAngle(rightHip, rightKnee, rightAnkle);
        angles['kneeRight'] = rightKneeAngle;

        final asymmetry = (kneeAngle - rightKneeAngle).abs();
        if (asymmetry > 15) {
          issues.add(
              'Несимметричное приседание (разница углов колен ${asymmetry.round()}°)');
          tips.add('Приседайте равномерно на обе ноги');
          score -= 15;
        }

        final kneeSpread = (leftKnee.x - rightKnee.x).abs();
        final ankleSpread = (leftAnkle.x - rightAnkle.x).abs();
        final kneeAnkleRatio = ankleSpread > 10 ? kneeSpread / ankleSpread : null;
        calibrationMetrics['kneeSpreadPx'] = kneeSpread;
        calibrationMetrics['ankleSpreadPx'] = ankleSpread;
        if (kneeAnkleRatio != null) {
          calibrationMetrics['kneeAnkleRatio'] = kneeAnkleRatio;
        }
        if (_squatBaselineKneeAnkleRatio != null) {
          calibrationMetrics['kneeAnkleBaselineRatio'] =
              _squatBaselineKneeAnkleRatio!;
        }

        // Capture this person's own standing stance as the baseline —
        // people's natural knee/ankle ratio varies (stance width, how much
        // the feet turn out), so comparing against a fixed constant flagged
        // normal stances as "knees caving in". Only valid during the down
        // phase, compared against how wide the knees were before descending.
        if (currentPhase == 'up' && kneeAngle > 160 && kneeAnkleRatio != null) {
          _squatBaselineKneeAnkleRatio = kneeAnkleRatio;
        }
        if (currentPhase == 'down' &&
            kneeAnkleRatio != null &&
            _squatBaselineKneeAnkleRatio != null) {
          final relativeDrop =
              1 - (kneeAnkleRatio / _squatBaselineKneeAnkleRatio!);
          if (relativeDrop > 0.15) {
            issues.add(
                'Колени заваливаются внутрь (${(relativeDrop * 100).round()}% уже, чем в стойке)');
            tips.add('Разводите колени по направлению носков');
            score -= 20;
          }
        }

        final shoulderSpread = (leftShoulder.x - rightShoulder.x).abs();
        if (currentPhase == 'up' && shoulderSpread > 10) {
          final stanceRatio = ankleSpread / shoulderSpread;
          if (stanceRatio < 0.7) {
            issues.add('Слишком узкая постановка ног');
            tips.add('Расставьте ноги примерно на ширину плеч');
            score -= 10;
          } else if (stanceRatio > 1.6) {
            issues.add('Слишком широкая постановка ног');
            tips.add('Сузьте стойку примерно до ширины плеч');
            score -= 10;
          }
        }
      }
    }

    final leftHeel = landmarks[PoseLandmarkType.leftHeel];
    final leftFootIndex = landmarks[PoseLandmarkType.leftFootIndex];
    if (leftHeel != null && leftFootIndex != null) {
      calibrationMetrics['heelLiftPx'] = leftFootIndex.y - leftHeel.y;
      calibrationMetrics['kneeOverToePx'] = leftKnee.x - leftFootIndex.x;
    }

    return PoseAnalysisResult(
      exerciseType: 'squat',
      formScore: score.clamp(0, 100),
      issues: issues,
      tips: tips,
      phase: currentPhase,
      repCount: _repCount,
      angles: angles,
      calibrationMetrics: calibrationMetrics,
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

    final currentPhase = elbowAngle < 120 ? 'down' : 'up';
    if (_lastPhase == 'down' && currentPhase == 'up') _repCount++;
    _lastPhase = currentPhase;

    if (bodyAlignment < 160 || bodyAlignment > 200) {
      issues.add('Бёдра провисают или подняты');
      tips.add('Держите тело в одну прямую линию от головы до пят');
      score -= 25;
    }

    final depthDeficit = (elbowAngle - 90).clamp(0, 90);
    if (depthDeficit > 0) {
      issues.add(
          'Недостаточная глубина отжимания (локоть ${elbowAngle.round()}°, нужно ≤90°)');
      tips.add('Опускайтесь пока грудь почти не касается пола');
      score -= depthDeficit;
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
