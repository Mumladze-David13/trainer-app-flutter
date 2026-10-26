// lib/core/models/pose_analysis.dart

class PoseAnalysisResult {
  final String exerciseType;
  final double formScore;
  final List<String> issues;
  final List<String> tips;
  final String phase;
  final int repCount;
  final Map<String, double> angles;
  // Raw, uncalibrated measurements (e.g. heel lift, knee-over-toe) that
  // aren't scored yet — collected so real thresholds can be picked later
  // from logged data instead of guessed upfront.
  final Map<String, double> calibrationMetrics;
  // Angles were measured on the person's right side (the side facing the
  // camera) instead of the left — the overlay needs it to put angle labels
  // on the right joints.
  final bool measuredRightSide;
  // Verdict for the most recently completed rep, if any.
  final RepRecord? lastRep;
  // Body not visible well enough to measure anything in this frame.
  final bool bodyNotVisible;

  PoseAnalysisResult({
    required this.exerciseType,
    required this.formScore,
    required this.issues,
    required this.tips,
    required this.phase,
    required this.repCount,
    required this.angles,
    this.calibrationMetrics = const {},
    this.measuredRightSide = false,
    this.lastRep,
    this.bodyNotVisible = false,
  });
}

/// One completed repetition and what was wrong with it. Form is judged per
/// rep (at its deepest point / over its whole range), not per frame — a
/// single frame mid-movement can't tell whether the rep was deep enough.
class RepRecord {
  final int index;
  final double score;
  final List<String> issues;
  final List<String> tips;
  // Most extreme value of the main joint angle reached during the rep
  // (deepest knee angle for squats, smallest elbow angle for push-ups...).
  final double peakAngle;

  RepRecord({
    required this.index,
    required this.score,
    required this.issues,
    required this.tips,
    required this.peakAngle,
  });
}

/// Camera placement relative to the person, chosen manually by the user —
/// some checks (knee valgus, left/right symmetry, stance width) need both
/// legs visible from the front, others (depth, torso lean) work side-on.
enum CameraViewMode { side, front }

extension CameraViewModeExtension on CameraViewMode {
  String get nameRu {
    switch (this) {
      case CameraViewMode.side:
        return 'Сбоку';
      case CameraViewMode.front:
        return 'Спереди';
    }
  }
}

enum SupportedExercise {
  squat,
  pushUp,
  deadlift,
  bicepCurl,
  shoulderPress,
}

extension SupportedExerciseExtension on SupportedExercise {
  String get nameRu {
    switch (this) {
      case SupportedExercise.squat:
        return 'Приседания';
      case SupportedExercise.pushUp:
        return 'Отжимания';
      case SupportedExercise.deadlift:
        return 'Становая тяга';
      case SupportedExercise.bicepCurl:
        return 'Подъём на бицепс';
      case SupportedExercise.shoulderPress:
        return 'Жим над головой';
    }
  }

  String get description {
    switch (this) {
      case SupportedExercise.squat:
        return 'Встаньте боком к камере для лучшего анализа';
      case SupportedExercise.pushUp:
        return 'Расположите телефон сбоку на уровне пола';
      case SupportedExercise.deadlift:
        return 'Встаньте боком к камере';
      case SupportedExercise.bicepCurl:
        return 'Встаньте лицом или боком к камере';
      case SupportedExercise.shoulderPress:
        return 'Встаньте лицом к камере';
    }
  }
}
