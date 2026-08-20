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

  PoseAnalysisResult({
    required this.exerciseType,
    required this.formScore,
    required this.issues,
    required this.tips,
    required this.phase,
    required this.repCount,
    required this.angles,
    this.calibrationMetrics = const {},
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
