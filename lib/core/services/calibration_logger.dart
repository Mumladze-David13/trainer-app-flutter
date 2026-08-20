// lib/core/services/calibration_logger.dart
import '../models/pose_analysis.dart';
import 'api_service.dart';

/// Batches raw pose-analysis frames for not-yet-scored metrics (heel lift,
/// knee-over-toe) and uploads them to the server, so thresholds can be
/// picked later from real recorded data instead of guessed upfront.
///
/// Best-effort: upload failures are swallowed rather than retried, since
/// losing a batch of calibration frames doesn't affect the live analysis
/// the user is watching.
class CalibrationLogger {
  final ApiService _api;
  final List<Map<String, dynamic>> _buffer = [];
  DateTime _lastWrite = DateTime.fromMillisecondsSinceEpoch(0);
  static const _minInterval = Duration(milliseconds: 300);
  static const _batchSize = 30;

  CalibrationLogger(this._api);

  void logFrame({
    required SupportedExercise exercise,
    required CameraViewMode viewMode,
    required PoseAnalysisResult result,
    required int imageWidth,
    required int imageHeight,
  }) {
    if (result.calibrationMetrics.isEmpty) return;
    final now = DateTime.now();
    if (now.difference(_lastWrite) < _minInterval) return;
    _lastWrite = now;

    _buffer.add({
      'ts': now.toIso8601String(),
      'exercise': exercise.name,
      'view': viewMode.name,
      'phase': result.phase,
      'formScore': result.formScore,
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
      'angles': result.angles,
      'calibrationMetrics': result.calibrationMetrics,
    });

    if (_buffer.length >= _batchSize) _flush();
  }

  void _flush() {
    if (_buffer.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();
    _api.uploadPoseCalibrationFrames(batch).catchError((_) {});
  }

  Future<void> close() async {
    _flush();
  }
}
