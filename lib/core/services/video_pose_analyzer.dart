// lib/core/services/video_pose_analyzer.dart
//
// Локальный AI-анализ уже записанного видео: не требует бэкенда и никуда не
// отправляет само видео — только семплирует кадры (video_thumbnail),
// прогоняет их через тот же ML Kit + PoseAnalysisService, что и живой
// анализ, и собирает результат по повторениям. Позы всех кадров
// сохраняются, чтобы при воспроизведении рисовать поверх видео скелет.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart' show Size;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;
import '../models/pose_analysis.dart';
import 'pose_analysis_service.dart';

/// Один проанализированный кадр ролика. [pose] == null — человек не найден.
class VideoPoseFrame {
  final int timeMs;
  final Pose? pose;
  final PoseAnalysisResult? result;

  VideoPoseFrame({required this.timeMs, this.pose, this.result});
}

class VideoAnalysisReport {
  final List<RepRecord> reps;
  // Момент ролика, на котором закончился каждый повтор (для перемотки).
  final List<int> repEndTimesMs;
  final List<VideoPoseFrame> frames;
  // Размер кадров, по которым считались координаты скелета (кадры уже
  // повёрнуты так, как видео показывается на экране).
  final Size frameSize;
  final int sampleIntervalMs;
  final int framesAnalyzed;
  final int framesWithoutPerson;

  VideoAnalysisReport({
    required this.reps,
    required this.repEndTimesMs,
    required this.frames,
    required this.frameSize,
    required this.sampleIntervalMs,
    required this.framesAnalyzed,
    required this.framesWithoutPerson,
  });

  int get repCount => reps.length;

  /// Кадр, ближайший к моменту воспроизведения, или null если рядом нет.
  VideoPoseFrame? frameAt(int positionMs) {
    if (frames.isEmpty) return null;
    var lo = 0;
    var hi = frames.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (frames[mid].timeMs < positionMs) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    var best = frames[lo];
    if (lo > 0 &&
        (frames[lo - 1].timeMs - positionMs).abs() <
            (best.timeMs - positionMs).abs()) {
      best = frames[lo - 1];
    }
    return (best.timeMs - positionMs).abs() <= sampleIntervalMs ? best : null;
  }
}

class VideoPoseAnalyzer {
  // Не больше ~200 семплов на ролик — иначе анализ длинного видео
  // занимает неоправданно долго на телефоне. Шаг не реже 150 мс, чтобы
  // не пропускать нижнюю точку быстрых повторений.
  static const _maxSamples = 200;
  static const _minIntervalMs = 150;

  Future<VideoAnalysisReport?> analyze({
    required String videoPath,
    required SupportedExercise exercise,
    CameraViewMode viewMode = CameraViewMode.side,
    void Function(double progress)? onProgress,
  }) async {
    final durationMs = await _readDurationMs(videoPath);
    if (durationMs == null || durationMs <= 0) return null;

    final intervalMs = (durationMs / _maxSamples).ceil() < _minIntervalMs
        ? _minIntervalMs
        : (durationMs / _maxSamples).ceil();
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
    final frames = <VideoPoseFrame>[];
    final repEndTimesMs = <int>[];
    Size? frameSize;

    try {
      for (var i = 0; i < sampleTimes.length; i++) {
        final timeMs = sampleTimes[i];
        final framePath =
            '${tempDir.path}/vpa_frame_${DateTime.now().microsecondsSinceEpoch}.jpg';
        String? savedPath;
        try {
          savedPath = await vt.VideoThumbnail.thumbnailFile(
            video: videoPath,
            thumbnailPath: framePath,
            imageFormat: vt.ImageFormat.JPEG,
            timeMs: timeMs,
            quality: 80,
          );
          if (savedPath == null) continue;
          frameSize ??= await _readImageSize(savedPath);

          final poses =
              await detector.processImage(InputImage.fromFilePath(savedPath));
          if (poses.isEmpty) {
            framesWithoutPerson++;
            frames.add(VideoPoseFrame(timeMs: timeMs));
            continue;
          }

          final repsBefore = analysisService.reps.length;
          final result = analysisService.analyzePose(poses.first, exercise,
              viewMode: viewMode);
          if (analysisService.reps.length > repsBefore) {
            repEndTimesMs.add(timeMs);
          }
          if (result != null && !result.bodyNotVisible) framesAnalyzed++;
          frames.add(VideoPoseFrame(
              timeMs: timeMs, pose: poses.first, result: result));
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

    // print('VideoPoseAnalyzer: samples=${sampleTimes.length} '
    //     'analyzed=$framesAnalyzed noPerson=$framesWithoutPerson '
    //     'reps=${analysisService.reps.length} frameSize=$frameSize');

    return VideoAnalysisReport(
      reps: analysisService.reps,
      repEndTimesMs: repEndTimesMs,
      frames: frames,
      frameSize: frameSize ?? Size.zero,
      sampleIntervalMs: intervalMs,
      framesAnalyzed: framesAnalyzed,
      framesWithoutPerson: framesWithoutPerson,
    );
  }

  Future<Size?> _readImageSize(String path) async {
    try {
      final codec =
          await ui.instantiateImageCodec(await File(path).readAsBytes());
      final frame = await codec.getNextFrame();
      final size =
          Size(frame.image.width.toDouble(), frame.image.height.toDouble());
      frame.image.dispose();
      codec.dispose();
      return size;
    } catch (_) {
      return null;
    }
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
