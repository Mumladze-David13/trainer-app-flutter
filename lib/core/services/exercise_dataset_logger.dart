// lib/core/services/exercise_dataset_logger.dart
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'api_service.dart';

/// Collects labeled pose-landmark recordings (correct vs. incorrect
/// technique, with a comment describing the fault) and uploads each
/// completed case to the server, used to calibrate exercise-analysis
/// thresholds from real data instead of guessing them upfront. See
/// pose_data_collection_screen.dart.
class ExerciseDatasetLogger {
  final ApiService _api;
  String? _currentCaseId;
  String _currentExercise = '';
  String _currentViewMode = '';
  String _currentLabel = '';
  String _currentComment = '';
  int _frameIndex = 0;
  final List<Map<String, dynamic>> _frames = [];
  DateTime _lastWrite = DateTime.fromMillisecondsSinceEpoch(0);
  static const _minInterval = Duration(milliseconds: 100);

  ExerciseDatasetLogger(this._api);

  String startCase(String exerciseSlug) {
    _currentCaseId =
        '${exerciseSlug}_${DateTime.now().millisecondsSinceEpoch}';
    _frameIndex = 0;
    _frames.clear();
    return _currentCaseId!;
  }

  void logFrame({
    required Pose pose,
    required String exercise,
    required String viewMode,
    required String label,
    required String comment,
    required int imageWidth,
    required int imageHeight,
  }) {
    if (_currentCaseId == null) return;
    final now = DateTime.now();
    if (now.difference(_lastWrite) < _minInterval) return;
    _lastWrite = now;

    _currentExercise = exercise;
    _currentViewMode = viewMode;
    _currentLabel = label;
    _currentComment = comment;

    final landmarks = <String, dynamic>{};
    for (final entry in pose.landmarks.entries) {
      landmarks[entry.key.name] = {
        'x': entry.value.x,
        'y': entry.value.y,
        'z': entry.value.z,
        'likelihood': entry.value.likelihood,
      };
    }

    _frames.add({
      'frameIndex': _frameIndex++,
      'ts': now.toIso8601String(),
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
      'landmarks': landmarks,
    });
  }

  int get frameCount => _frameIndex;

  /// Uploads the completed case as one request. Throws if the upload fails
  /// — the caller decides how to surface that to the user.
  Future<void> endCase() async {
    final caseId = _currentCaseId;
    _currentCaseId = null;
    if (caseId == null || _frames.isEmpty) return;

    await _api.uploadPoseDatasetCase({
      'caseId': caseId,
      'exercise': _currentExercise,
      'viewMode': _currentViewMode,
      'label': _currentLabel,
      'comment': _currentComment,
      'frames': List<Map<String, dynamic>>.from(_frames),
    });
  }
}
