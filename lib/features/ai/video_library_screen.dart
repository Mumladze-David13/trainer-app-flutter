// lib/features/ai/video_library_screen.dart
//
// Список записей из lib/core/services/workout_video_library.dart. Отсюда
// можно открыть любую сохранённую запись для просмотра/удаления и запустить
// её локальный AI-анализ (video_analysis_sheet.dart) — видео остаётся на
// телефоне клиента, никуда не загружается.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/workout_video_library.dart';
import 'video_analysis_sheet.dart';

class VideoLibraryScreen extends StatefulWidget {
  const VideoLibraryScreen({super.key});

  @override
  State<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends State<VideoLibraryScreen> {
  final _library = WorkoutVideoLibrary();
  late Future<List<File>> _videosFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _videosFuture = _library.listVideos());
  }

  void _openVideo(File file) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VideoAnalysisSheet(
        videoPath: file.path,
        onDeleted: _reload,
      ),
    );
  }

  String _formatEntry(File file) {
    final stat = file.statSync();
    final sizeMb = (stat.size / (1024 * 1024)).toStringAsFixed(1);
    return '${DateFormat('d MMM, HH:mm', 'ru').format(stat.modified)} · $sizeMb МБ';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Мои видео'),
      ),
      body: FutureBuilder<List<File>>(
        future: _videosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }
          final videos = snapshot.data ?? [];
          if (videos.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Здесь появятся видео, записанные на экране анализа '
                  'техники. Они хранятся только на этом телефоне.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: videos.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
            itemBuilder: (context, i) {
              final file = videos[i];
              return ListTile(
                leading: const Icon(Icons.videocam, color: Colors.white70),
                title: Text(
                  file.uri.pathSegments.last,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(_formatEntry(file),
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                onTap: () => _openVideo(file),
              );
            },
          );
        },
      ),
    );
  }
}
