// lib/core/services/pose_analysis_service.dart
import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/pose_analysis.dart';

class _Issue {
  final String text;
  final String tip;
  final double penalty;
  const _Issue(this.text, this.tip, this.penalty);
}

enum _J { shoulder, elbow, wrist, hip, knee, ankle, heel, foot }

const _leftSide = {
  _J.shoulder: PoseLandmarkType.leftShoulder,
  _J.elbow: PoseLandmarkType.leftElbow,
  _J.wrist: PoseLandmarkType.leftWrist,
  _J.hip: PoseLandmarkType.leftHip,
  _J.knee: PoseLandmarkType.leftKnee,
  _J.ankle: PoseLandmarkType.leftAnkle,
  _J.heel: PoseLandmarkType.leftHeel,
  _J.foot: PoseLandmarkType.leftFootIndex,
};

const _rightSide = {
  _J.shoulder: PoseLandmarkType.rightShoulder,
  _J.elbow: PoseLandmarkType.rightElbow,
  _J.wrist: PoseLandmarkType.rightWrist,
  _J.hip: PoseLandmarkType.rightHip,
  _J.knee: PoseLandmarkType.rightKnee,
  _J.ankle: PoseLandmarkType.rightAnkle,
  _J.heel: PoseLandmarkType.rightHeel,
  _J.foot: PoseLandmarkType.rightFootIndex,
};

/// Analyses form rep by rep.
///
/// Every exercise is reduced to one main signal (usually a joint angle).
/// The signal crossing `enter` starts the working phase of a rep, crossing
/// `exit` (with a gap between them, so noise around one threshold can't
/// double-count) finishes it. Depth/range-of-motion is judged once per rep
/// from the most extreme value reached, posture problems are collected from
/// the frames inside the rep.
class PoseAnalysisService {
  // ML Kit always returns all 33 landmarks, including ones it can't see —
  // those come back as guesses with low likelihood. Measuring on them gives
  // garbage angles, so anything below this counts as "not visible".
  static const double _minLikelihood = 0.5;
  // A posture issue has to show up in at least this many frames of a rep to
  // be attributed to it — single-frame landmark jitter isn't a mistake.
  static const int _minIssueFrames = 2;

  int _repCount = 0;
  String _lastPhase = 'up';
  double? _peak;
  // Most "rest-like" value seen between the previous rep and this one
  // (e.g. the knee lockout angle while standing before a squat).
  double? _restExtreme;
  final Map<String, int> _repIssueFrames = {};
  final Map<String, _Issue> _repIssueDefs = {};
  final List<RepRecord> _reps = [];

  // knee-spread/ankle-spread ratio captured while standing (front view),
  // used as this person's own baseline stance instead of a fixed constant —
  // people's standing knee/ankle ratio varies naturally, so an absolute
  // threshold flagged normal stances as "knees caving in".
  double? _squatBaselineKneeAnkleRatio;

  List<RepRecord> get reps => List.unmodifiable(_reps);

  void resetReps() {
    _repCount = 0;
    _lastPhase = 'up';
    _peak = null;
    _restExtreme = null;
    _repIssueFrames.clear();
    _repIssueDefs.clear();
    _reps.clear();
    _squatBaselineKneeAnkleRatio = null;
  }

  PoseAnalysisResult? analyzePose(
    Pose pose,
    SupportedExercise exercise, {
    CameraViewMode viewMode = CameraViewMode.side,
  }) {
    switch (exercise) {
      case SupportedExercise.squat:
        return viewMode == CameraViewMode.front
            ? _analyzeSquatFront(pose)
            : _analyzeSquatSide(pose);
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

  // Deviation of the segment a→b from vertical, in degrees.
  double _angleFromVertical(PoseLandmark a, PoseLandmark b) {
    return atan2((a.x - b.x).abs(), (a.y - b.y).abs()) * 180 / pi;
  }

  /// Picks the body side facing the camera for the given joints: the one
  /// whose landmarks ML Kit is more confident about. Returns null when
  /// neither side is clearly visible.
  Map<_J, PoseLandmark>? _visibleSide(Pose pose, List<_J> joints,
      {required void Function(bool right) onSide}) {
    Map<_J, PoseLandmark>? collect(Map<_J, PoseLandmarkType> side) {
      final out = <_J, PoseLandmark>{};
      for (final j in joints) {
        final lm = pose.landmarks[side[j]!];
        if (lm == null) return null;
        out[j] = lm;
      }
      return out;
    }

    double confidence(Map<_J, PoseLandmark>? lms) => lms == null
        ? -1
        : lms.values.map((l) => l.likelihood).reduce(min);

    final left = collect(_leftSide);
    final right = collect(_rightSide);
    final useRight = confidence(right) > confidence(left);
    final chosen = useRight ? right : left;
    if (chosen == null || confidence(chosen) < _minLikelihood) return null;
    onSide(useRight);
    return chosen;
  }

  PoseAnalysisResult _notVisible(String type, String message) {
    return PoseAnalysisResult(
      exerciseType: type,
      formScore: 0,
      issues: [message],
      tips: const [],
      phase: _lastPhase,
      repCount: _repCount,
      angles: const {},
      lastRep: _reps.isEmpty ? null : _reps.last,
      bodyNotVisible: true,
    );
  }

  /// Advances the rep state machine with this frame's main signal and
  /// builds the frame result.
  PoseAnalysisResult _track({
    required String type,
    required double signal,
    required bool workWhenLower,
    required double enter,
    required double exit,
    required List<_Issue> frameIssues,
    required List<_Issue> Function(double peak, double? restExtreme)
        evaluateRep,
    required Map<String, double> angles,
    Map<String, double> calibrationMetrics = const {},
    bool rightSide = false,
  }) {
    double towardWork(double a, double b) =>
        workWhenLower ? min(a, b) : max(a, b);
    double towardRest(double a, double b) =>
        workWhenLower ? max(a, b) : min(a, b);
    final entered = workWhenLower ? signal < enter : signal > enter;
    final exited = workWhenLower ? signal > exit : signal < exit;

    if (_lastPhase == 'up') {
      _restExtreme =
          _restExtreme == null ? signal : towardRest(_restExtreme!, signal);
      if (entered) {
        _lastPhase = 'down';
        _peak = signal;
      }
    } else {
      _peak = _peak == null ? signal : towardWork(_peak!, signal);
      if (exited) {
        _completeRep(evaluateRep(_peak!, _restExtreme));
        _lastPhase = 'up';
        _restExtreme = signal;
        _peak = null;
      }
    }

    // Posture issues are attributed to the rep they happen in, including
    // the rest phase right before it (stance, lockout position).
    for (final issue in frameIssues) {
      _repIssueFrames[issue.text] = (_repIssueFrames[issue.text] ?? 0) + 1;
      _repIssueDefs[issue.text] = issue;
    }

    final frameScore =
        100 - frameIssues.fold<double>(0, (s, i) => s + i.penalty);
    return PoseAnalysisResult(
      exerciseType: type,
      formScore: frameScore.clamp(0, 100).toDouble(),
      issues: frameIssues.map((i) => i.text).toList(),
      tips: frameIssues.map((i) => i.tip).toList(),
      phase: _lastPhase,
      repCount: _repCount,
      angles: angles,
      calibrationMetrics: calibrationMetrics,
      measuredRightSide: rightSide,
      lastRep: _reps.isEmpty ? null : _reps.last,
    );
  }

  void _completeRep(List<_Issue> rangeIssues) {
    final issues = <_Issue>[...rangeIssues];
    _repIssueFrames.forEach((text, frames) {
      if (frames >= _minIssueFrames) issues.add(_repIssueDefs[text]!);
    });
    _repIssueFrames.clear();
    _repIssueDefs.clear();

    _repCount++;
    final score = 100 - issues.fold<double>(0, (s, i) => s + i.penalty);
    _reps.add(RepRecord(
      index: _repCount,
      score: score.clamp(0, 100).toDouble(),
      issues: issues.map((i) => i.text).toList(),
      tips: issues.map((i) => i.tip).toList(),
      peakAngle: _peak ?? 0,
    ));
  }

  // Penalty grows with how far the rep fell short of the target angle.
  double _shortfallPenalty(double deficit) => (deficit * 1.5).clamp(10, 40);

  PoseAnalysisResult _analyzeSquatSide(Pose pose) {
    var right = false;
    final lm = _visibleSide(
        pose, [_J.shoulder, _J.hip, _J.knee, _J.ankle],
        onSide: (r) => right = r);
    if (lm == null) {
      return _notVisible(
          'squat', 'Не вижу ногу и корпус целиком. Отойдите от камеры.');
    }

    final kneeAngle = _calculateAngle(lm[_J.hip]!, lm[_J.knee]!, lm[_J.ankle]!);
    final hipAngle =
        _calculateAngle(lm[_J.shoulder]!, lm[_J.hip]!, lm[_J.knee]!);

    final frameIssues = <_Issue>[];
    if (_lastPhase == 'down' && hipAngle < 45) {
      frameIssues.add(const _Issue('Слишком большой наклон вперёд',
          'Держите спину прямее, грудь вверх', 15));
    }

    // Not scored yet — logged raw so thresholds can be picked later from
    // real collected data instead of guessed upfront.
    final calibrationMetrics = <String, double>{};
    final sideLms = right ? _rightSide : _leftSide;
    final heel = pose.landmarks[sideLms[_J.heel]!];
    final foot = pose.landmarks[sideLms[_J.foot]!];
    if (heel != null && foot != null) {
      calibrationMetrics['heelLiftPx'] = foot.y - heel.y;
      calibrationMetrics['kneeOverToePx'] = lm[_J.knee]!.x - foot.x;
    }

    return _track(
      type: 'squat',
      signal: kneeAngle,
      workWhenLower: true,
      enter: 140,
      exit: 160,
      frameIssues: frameIssues,
      evaluateRep: (peak, rest) => [
        if (peak > 100)
          _Issue('Недостаточная глубина (колено ${peak.round()}°, нужно ≤100°)',
              'Приседайте ниже — бёдра должны быть параллельны полу',
              _shortfallPenalty(peak - 100)),
        if (rest != null && rest < 165)
          const _Issue('Ноги не выпрямились полностью вверху',
              'Полностью выпрямляйте колени в верхней точке', 10),
      ],
      angles: {'knee': kneeAngle, 'hip': hipAngle},
      calibrationMetrics: calibrationMetrics,
      rightSide: right,
    );
  }

  PoseAnalysisResult _analyzeSquatFront(Pose pose) {
    final l = <_J, PoseLandmark>{};
    final r = <_J, PoseLandmark>{};
    for (final j in [_J.shoulder, _J.hip, _J.knee, _J.ankle]) {
      final a = pose.landmarks[_leftSide[j]!];
      final b = pose.landmarks[_rightSide[j]!];
      if (a == null ||
          b == null ||
          a.likelihood < _minLikelihood ||
          b.likelihood < _minLikelihood) {
        return _notVisible('squat',
            'Не вижу обе ноги целиком. Встаньте лицом к камере, отойдите дальше.');
      }
      l[j] = a;
      r[j] = b;
    }

    final kneeL = _calculateAngle(l[_J.hip]!, l[_J.knee]!, l[_J.ankle]!);
    final kneeR = _calculateAngle(r[_J.hip]!, r[_J.knee]!, r[_J.ankle]!);

    // From the front the 2D knee angle barely changes during a squat, so
    // reps are tracked by how far the hips drop toward knee height instead:
    // thigh height / shin height, ~1 standing, ~0 at parallel.
    final thigh = ((l[_J.knee]!.y - l[_J.hip]!.y) +
            (r[_J.knee]!.y - r[_J.hip]!.y)) /
        2;
    final shin = ((l[_J.ankle]!.y - l[_J.knee]!.y) +
            (r[_J.ankle]!.y - r[_J.knee]!.y)) /
        2;
    final hipDrop = shin > 1 ? (thigh / shin).clamp(-1.0, 2.0) : 1.0;

    final frameIssues = <_Issue>[];
    final calibrationMetrics = <String, double>{'hipDropRatio': hipDrop};

    final asymmetry = (kneeL - kneeR).abs();
    if (_lastPhase == 'down' && asymmetry > 15) {
      frameIssues.add(_Issue(
          'Несимметричное приседание (разница колен ${asymmetry.round()}°)',
          'Приседайте равномерно на обе ноги',
          15));
    }

    final kneeSpread = (l[_J.knee]!.x - r[_J.knee]!.x).abs();
    final ankleSpread = (l[_J.ankle]!.x - r[_J.ankle]!.x).abs();
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

    // Capture this person's own standing stance as the baseline, compare
    // the down phase against it.
    if (_lastPhase == 'up' && hipDrop > 0.85 && kneeAnkleRatio != null) {
      _squatBaselineKneeAnkleRatio = kneeAnkleRatio;
    }
    if (_lastPhase == 'down' &&
        kneeAnkleRatio != null &&
        _squatBaselineKneeAnkleRatio != null) {
      final relativeDrop = 1 - (kneeAnkleRatio / _squatBaselineKneeAnkleRatio!);
      if (relativeDrop > 0.15) {
        frameIssues.add(const _Issue('Колени заваливаются внутрь',
            'Разводите колени по направлению носков', 20));
      }
    }

    final shoulderSpread = (l[_J.shoulder]!.x - r[_J.shoulder]!.x).abs();
    if (_lastPhase == 'up' && shoulderSpread > 10) {
      final stanceRatio = ankleSpread / shoulderSpread;
      if (stanceRatio < 0.7) {
        frameIssues.add(const _Issue('Слишком узкая постановка ног',
            'Расставьте ноги примерно на ширину плеч', 10));
      } else if (stanceRatio > 1.6) {
        frameIssues.add(const _Issue('Слишком широкая постановка ног',
            'Сузьте стойку примерно до ширины плеч', 10));
      }
    }

    return _track(
      type: 'squat',
      signal: hipDrop,
      workWhenLower: true,
      enter: 0.65,
      exit: 0.85,
      frameIssues: frameIssues,
      evaluateRep: (peak, rest) => [
        if (peak > 0.35)
          const _Issue('Недостаточная глубина приседа',
              'Приседайте ниже — бёдра до параллели с полом', 20),
      ],
      angles: {'knee': kneeL, 'kneeRight': kneeR},
      calibrationMetrics: calibrationMetrics,
    );
  }

  PoseAnalysisResult _analyzePushUp(Pose pose) {
    var right = false;
    final lm = _visibleSide(
        pose, [_J.shoulder, _J.elbow, _J.wrist, _J.hip, _J.ankle],
        onSide: (r) => right = r);
    if (lm == null) {
      return _notVisible(
          'pushup', 'Не вижу тело полностью. Расположите камеру сбоку.');
    }

    final elbowAngle =
        _calculateAngle(lm[_J.shoulder]!, lm[_J.elbow]!, lm[_J.wrist]!);
    final bodyAlignment =
        _calculateAngle(lm[_J.shoulder]!, lm[_J.hip]!, lm[_J.ankle]!);

    final frameIssues = <_Issue>[
      if (bodyAlignment < 160)
        const _Issue('Бёдра провисают или подняты',
            'Держите тело в одну прямую линию от головы до пят', 20),
    ];

    return _track(
      type: 'pushup',
      signal: elbowAngle,
      workWhenLower: true,
      enter: 140,
      exit: 155,
      frameIssues: frameIssues,
      evaluateRep: (peak, rest) => [
        if (peak > 90)
          _Issue(
              'Недостаточная глубина (локоть ${peak.round()}°, нужно ≤90°)',
              'Опускайтесь, пока грудь почти не коснётся пола',
              _shortfallPenalty(peak - 90)),
        if (rest != null && rest < 155)
          const _Issue('Руки не выпрямляются полностью вверху',
              'Полностью разгибайте локти в верхней точке', 10),
      ],
      angles: {'elbow': elbowAngle, 'body': bodyAlignment},
      rightSide: right,
    );
  }

  PoseAnalysisResult _analyzeDeadlift(Pose pose) {
    var right = false;
    final lm = _visibleSide(
        pose, [_J.shoulder, _J.hip, _J.knee, _J.ankle],
        onSide: (r) => right = r);
    if (lm == null) {
      return _notVisible('deadlift', 'Встаньте боком к камере целиком в кадре');
    }

    final hipAngle =
        _calculateAngle(lm[_J.shoulder]!, lm[_J.hip]!, lm[_J.knee]!);
    final kneeAngle =
        _calculateAngle(lm[_J.hip]!, lm[_J.knee]!, lm[_J.ankle]!);

    final frameIssues = <_Issue>[
      if (_lastPhase == 'down' && kneeAngle < 90)
        const _Issue('Слишком сильно сгибаете колени — получается присед',
            'Отводите таз назад, колени сгибайте умеренно', 15),
    ];

    return _track(
      type: 'deadlift',
      signal: hipAngle,
      workWhenLower: true,
      enter: 140,
      exit: 160,
      frameIssues: frameIssues,
      evaluateRep: (peak, rest) => [
        if (rest != null && rest < 165)
          const _Issue('Нет полного выпрямления вверху',
              'В верхней точке полностью выпрямляйте таз и колени', 15),
      ],
      angles: {'hip': hipAngle, 'knee': kneeAngle},
      rightSide: right,
    );
  }

  PoseAnalysisResult _analyzeBicepCurl(Pose pose) {
    var right = false;
    final lm = _visibleSide(
        pose, [_J.shoulder, _J.elbow, _J.wrist, _J.hip],
        onSide: (r) => right = r);
    if (lm == null) {
      return _notVisible('bicep_curl', 'Не вижу руку и корпус полностью');
    }

    final elbowAngle =
        _calculateAngle(lm[_J.shoulder]!, lm[_J.elbow]!, lm[_J.wrist]!);
    // Angle between torso and upper arm — should stay small, the elbow is
    // pinned to the side. Direction-independent, unlike comparing x coords.
    final upperArm =
        _calculateAngle(lm[_J.hip]!, lm[_J.shoulder]!, lm[_J.elbow]!);
    final torsoLean = _angleFromVertical(lm[_J.shoulder]!, lm[_J.hip]!);

    final frameIssues = <_Issue>[
      if (_lastPhase == 'down' && upperArm > 35)
        const _Issue('Локоть уходит вперёд',
            'Держите локоть прижатым к корпусу', 20),
      if (torsoLean > 15)
        const _Issue('Раскачка корпуса',
            'Не используйте инерцию — корпус неподвижен', 20),
    ];

    return _track(
      type: 'bicep_curl',
      signal: elbowAngle,
      workWhenLower: true,
      enter: 90,
      exit: 130,
      frameIssues: frameIssues,
      evaluateRep: (peak, rest) => [
        if (peak > 60)
          const _Issue('Неполная амплитуда вверху',
              'Поднимайте вес до полного сгибания руки', 15),
        if (rest != null && rest < 150)
          const _Issue('Рука не разгибается полностью внизу',
              'Опускайте вес до почти прямой руки', 15),
      ],
      angles: {'elbow': elbowAngle},
      rightSide: right,
    );
  }

  PoseAnalysisResult _analyzeShoulderPress(Pose pose) {
    var right = false;
    final lm = _visibleSide(pose, [_J.shoulder, _J.elbow, _J.wrist],
        onSide: (r) => right = r);
    if (lm == null) {
      return _notVisible('shoulder_press', 'Встаньте лицом к камере');
    }

    final elbowAngle =
        _calculateAngle(lm[_J.shoulder]!, lm[_J.elbow]!, lm[_J.wrist]!);

    return _track(
      type: 'shoulder_press',
      signal: elbowAngle,
      workWhenLower: false,
      enter: 140,
      exit: 110,
      frameIssues: const [],
      evaluateRep: (peak, rest) => [
        if (peak < 160)
          const _Issue('Руки не выпрямляются полностью вверху',
              'Выжимайте вес до прямых рук', 15),
        if (rest != null && rest > 100)
          const _Issue('Недостаточно опускаете вес',
              'Опускайте гриф/гантели до уровня плеч', 15),
      ],
      angles: {'elbow': elbowAngle},
      rightSide: right,
    );
  }
}
