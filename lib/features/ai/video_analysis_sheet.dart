// lib/features/ai/video_analysis_sheet.dart
//
// Открывается из библиотеки видео (video_library_screen.dart) для одного
// сохранённого ролика: просмотр, выбор упражнения/ракурса, локальный
// AI-анализ (video_pose_analyzer.dart — видео никуда не отправляется) и
// удаление файла.
import 'dart:io';
import 'package:camera/camera.dart' show CameraLensDirection;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    show InputImageRotation;
import 'package:video_player/video_player.dart';
import '../../core/models/pose_analysis.dart';
import '../../core/services/video_pose_analyzer.dart';
import '../../core/services/workout_video_library.dart';
import 'pose_overlay_painter.dart';
import 'pose_session_summary.dart';

class VideoAnalysisSheet extends StatefulWidget {
  final String videoPath;
  final VoidCallback onDeleted;

  const VideoAnalysisSheet({
    super.key,
    required this.videoPath,
    required this.onDeleted,
  });

  @override
  State<VideoAnalysisSheet> createState() => _VideoAnalysisSheetState();
}

class _VideoAnalysisSheetState extends State<VideoAnalysisSheet> {
  late VideoPlayerController _videoController;
  bool _isInitialized = false;

  SupportedExercise _exercise = SupportedExercise.squat;
  CameraViewMode _viewMode = CameraViewMode.side;

  bool _isAnalyzing = false;
  double _progress = 0;
  VideoAnalysisReport? _report;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.file(File(widget.videoPath));
    _videoController.initialize().then((_) {
      if (!mounted) return;
      setState(() => _isInitialized = true);
    });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_videoController.value.isPlaying) {
      _videoController.pause();
    } else {
      _videoController.play();
    }
    setState(() {});
  }

  Future<void> _analyze() async {
    setState(() {
      _isAnalyzing = true;
      _progress = 0;
      _report = null;
    });
    _videoController.pause();
    try {
      final report = await VideoPoseAnalyzer().analyze(
        videoPath: widget.videoPath,
        exercise: _exercise,
        viewMode: _viewMode,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      if (report == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Не удалось прочитать видео для анализа')));
      }
      setState(() => _report = report);
      // Отчёт рисуется под видео и выбором упражнения — прокручиваем к нему,
      // иначе на высоком вертикальном видео его просто не видно.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка анализа: $e')));
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить видео?'),
        content: const Text('Файл будет удалён с телефона без возможности восстановления.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    await WorkoutVideoLibrary().deleteVideo(widget.videoPath);
    if (!mounted) return;
    Navigator.pop(context);
    widget.onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.92;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Вертикальное видео во всю ширину занимало почти весь
                  // экран, и прогресс/отчёт анализа уезжали за его край.
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45),
                    child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AspectRatio(
                      aspectRatio: _isInitialized
                          ? _videoController.value.aspectRatio
                          : 9 / 16,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_isInitialized)
                            VideoPlayer(_videoController)
                          else
                            const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white)),
                          if (_report != null &&
                              _report!.frameSize != Size.zero)
                            Positioned.fill(child: _buildSkeletonOverlay(_report!)),
                          GestureDetector(
                            onTap: _isInitialized ? _togglePlay : null,
                            child: AnimatedOpacity(
                              opacity: _isInitialized &&
                                      !_videoController.value.isPlaying
                                  ? 1.0
                                  : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.play_arrow,
                                    color: Colors.white, size: 32),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Упражнение',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: SupportedExercise.values.map((ex) {
                      final selected = ex == _exercise;
                      return ChoiceChip(
                        label: Text(ex.nameRu),
                        selected: selected,
                        onSelected: _isAnalyzing
                            ? null
                            : (_) => setState(() => _exercise = ex),
                        selectedColor: const Color(0xFF1976D2),
                        labelStyle: TextStyle(
                            color: selected ? Colors.white : Colors.white70,
                            fontSize: 12),
                        backgroundColor: Colors.grey[850],
                      );
                    }).toList(),
                  ),
                  if (_exercise == SupportedExercise.squat) ...[
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Камера была',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: CameraViewMode.values.map((mode) {
                        final selected = mode == _viewMode;
                        return ChoiceChip(
                          label: Text(mode.nameRu),
                          selected: selected,
                          onSelected: _isAnalyzing
                              ? null
                              : (_) => setState(() => _viewMode = mode),
                          selectedColor: const Color(0xFF1976D2),
                          labelStyle: TextStyle(
                              color: selected ? Colors.white : Colors.white70,
                              fontSize: 12),
                          backgroundColor: Colors.grey[850],
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_isAnalyzing) ...[
                    LinearProgressIndicator(value: _progress),
                    const SizedBox(height: 8),
                    Text('Анализ… ${(_progress * 100).round()}%',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 12),
                  ] else if (_report != null) ...[
                    _buildReport(_report!),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isAnalyzing ? null : _delete,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 20),
                    label: const Text('Удалить', style: TextStyle(color: Colors.red)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isAnalyzing || !_isInitialized ? null : _analyze,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 20),
                    label: Text(
                      _isAnalyzing
                          ? 'Анализ… ${(_progress * 100).round()}%'
                          : (_report == null
                              ? 'Анализировать'
                              : 'Анализировать заново'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Скелет найденной позы поверх воспроизводимого видео: берётся кадр
  // анализа, ближайший к текущей позиции плеера.
  Widget _buildSkeletonOverlay(VideoAnalysisReport report) {
    return IgnorePointer(
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: _videoController,
        builder: (_, value, __) {
          final frame = report.frameAt(value.position.inMilliseconds);
          if (frame?.pose == null) return const SizedBox.shrink();
          return CustomPaint(
            // Кадры уже повёрнуты как на экране и не отзеркалены — поэтому
            // rotation0 + задняя камера = простое масштабирование координат.
            painter: PoseOverlayPainter(
              pose: frame!.pose!,
              imageSize: report.frameSize,
              rotation: InputImageRotation.rotation0deg,
              cameraLensDirection: CameraLensDirection.back,
              result: frame.result,
            ),
          );
        },
      ),
    );
  }

  Widget _buildReport(VideoAnalysisReport report) {
    if (report.framesAnalyzed == 0) {
      return const PoseSessionSummary(
        reps: [],
        emptyMessage: 'Человек не найден почти ни на одном кадре — переснимите '
            'видео так, чтобы всё тело было видно в кадре.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Нажмите ▶ — скелет будет показан поверх видео',
            style: TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 6),
        PoseSessionSummary(
          reps: report.reps,
          emptyMessage: 'Человек найден, но ни одного полного повторения не '
              'засчитано. Проверьте, что выбрано правильное упражнение и '
              'ракурс камеры, и что в кадре видно всё движение.',
          onRepTap: (i) {
            if (i >= report.repEndTimesMs.length) return;
            // Повтор длится ~1.5-3 с — отматываем немного назад от его конца.
            final ms = (report.repEndTimesMs[i] - 2000).clamp(0, 1 << 31);
            _videoController.seekTo(Duration(milliseconds: ms));
            _videoController.play();
            setState(() {});
          },
        ),
      ],
    );
  }
}
