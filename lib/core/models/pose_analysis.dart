// lib/core/models/pose_analysis.dart

class PoseAnalysisResult {
  final String exerciseType;
  final double formScore;
  final List<String> issues;
  final List<String> tips;
  final String phase;
  final int repCount;
  final Map<String, double> angles;

  PoseAnalysisResult({
    required this.exerciseType,
    required this.formScore,
    required this.issues,
    required this.tips,
    required this.phase,
    required this.repCount,
    required this.angles,
  });
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
