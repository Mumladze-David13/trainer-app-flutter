// lib/core/services/video_pose_analyzer.dart
//
// Локальный AI-анализ уже записанного видео: не требует бэкенда и никуда не
// отправляет само видео — только семплирует кадры (video_thumbnail),
// прогоняет их через тот же ML Kit + PoseAnalysisService, что и живой
// анализ, и агрегирует результат по всему ролику.
import 'dart:io';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;
import '../models/pose_analysis.dart';
import 'pose_analysis_service.dart';

class VideoAnalysisReport {
  final int repCount;
  final double avgFormScore;
  final double minFormScore;
  final int framesAnalyzed;
  final int framesWithoutPerson;
  // Проблема -> сколько кадров её показали, отсортировано по убыванию.
  final List<MapEntry<String, int>> topIssues;

  VideoAnalysisReport({
    required this.repCount,
    required this.avgFormScore,
    required this.minFormScore,
    required this.framesAnalyzed,
    required this.framesWithoutPerson,
    required this.topIssues,
  });
}

class VideoPoseAnalyzer {
  // Не больше ~120 семплов на ролик — иначе анализ пятиминутного видео
  // занимает неоправданно долго на телефоне.
  static const _maxSamples = 120;
  static const _minIntervalMs = 150;

  Future<VideoAnalysisReport?> analyze({
    required String videoPath,
    required SupportedExercise exercise,
    CameraViewMode viewMode = CameraViewMode.side,
    void Function(double progress)? onProgress,
  }) async {
    final durationMs = await _readDurationMs(videoPath);
    if (durationMs == null || durationMs <= 0) return null;

    final intervalMs =
        durationMs / _maxSamples < _minIntervalMs ? _minIntervalMs : (durationMs / _maxSamples).ceil();
    final sampleTimes = <int>[
      for (var t = 0; t < durationMs; t += intervalMs) t,
    ];

    final detector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.single,
        model: PoseDetectionModel.base,
      ),
    );
    final analysisService = PoseAnalysisService();
    final tempDir = await getTemporaryDirectory();

    var framesAnalyzed = 0;
    var framesWithoutPerson = 0;
    var repCount = 0;
    final scores = <double>[];
    final issueCounts = <String, int>{};

    try {
      for (var i = 0; i < sampleTimes.length; i++) {
        final framePath =
            '${tempDir.path}/vpa_frame_${DateTime.now().microsecondsSinceEpoch}.jpg';
        String? savedPath;
        try {
          savedPath = await vt.VideoThumbnail.thumbnailFile(
            video: videoPath,
            thumbnailPath: framePath,
            imageFormat: vt.ImageFormat.JPEG,
            timeMs: sampleTimes[i],
            quality: 70,
          );
          if (savedPath == null) continue;

          final poses =
              await detector.processImage(InputImage.fromFilePath(savedPath));
          if (poses.isEmpty) {
            framesWithoutPerson++;
            continue;
          }

          final result = analysisService.analyzePose(poses.first, exercise,
              viewMode: viewMode);
          if (result == null) continue;
          framesAnalyzed++;
          repCount = result.repCount;
          scores.add(result.formScore);
          for (final issue in result.issues) {
            issueCounts[issue] = (issueCounts[issue] ?? 0) + 1;
          }
        } finally {
          if (savedPath != null) {
            try {
              await File(savedPath).delete();
            } catch (_) {}
          }
        }
        onProgress?.call((i + 1) / sampleTimes.length);
      }
    } finally {
      await detector.close();
    }

    final topIssues = issueCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return VideoAnalysisReport(
      repCount: repCount,
      avgFormScore:
          scores.isEmpty ? 0 : scores.reduce((a, b) => a + b) / scores.length,
      minFormScore: scores.isEmpty ? 0 : scores.reduce((a, b) => a < b ? a : b),
      framesAnalyzed: framesAnalyzed,
      framesWithoutPerson: framesWithoutPerson,
      topIssues: topIssues.take(5).toList(),
    );
  }

  Future<int?> _readDurationMs(String videoPath) async {
    final controller = VideoPlayerController.file(File(videoPath));
    try {
      await controller.initialize();
      return controller.value.duration.inMilliseconds;
    } catch (_) {
      return null;
    } finally {
      await controller.dispose();
    }
  }
}
