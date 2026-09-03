// lib/features/ai/video_analysis_sheet.dart
//
// Открывается из библиотеки видео (video_library_screen.dart) для одного
// сохранённого ролика: просмотр, выбор упражнения/ракурса, локальный
// AI-анализ (video_pose_analyzer.dart — видео никуда не отправляется) и
// удаление файла.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/models/pose_analysis.dart';
import '../../core/services/video_pose_analyzer.dart';
import '../../core/services/workout_video_library.dart';

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

  Color _scoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Container(
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
                      _report == null ? 'Анализировать' : 'Анализировать заново',
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

  Widget _buildReport(VideoAnalysisReport report) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Повторений: ',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text('${report.repCount}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              const Text('Техника: ',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text('${report.avgFormScore.round()}%',
                  style: TextStyle(
                      color: _scoreColor(report.avgFormScore),
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          if (report.framesAnalyzed == 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Человек не найден почти ни на одном кадре — переснимите '
                'видео так, чтобы всё тело было видно в кадре.',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            )
          else if (report.topIssues.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Частые проблемы:',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            ...report.topIssues.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber,
                          color: Colors.orange, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text('${e.key} (${e.value})',
                            style: const TextStyle(
                                color: Colors.orange, fontSize: 12)),
                      ),
                    ],
                  ),
                )),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 14),
                  SizedBox(width: 4),
                  Text('Явных проблем не найдено',
                      style: TextStyle(color: Colors.green, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
