// lib/core/services/workout_video_library.dart
//
// Локальная папка для видео тренировок — единственное место, куда попадают
// записи с камеры анализа техники. Видео никогда никуда не отправляется:
// только сохраняется здесь и может быть удалено или открыто для локального
// AI-анализа (см. video_pose_analyzer.dart).
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class WorkoutVideoLibrary {
  static const _folderName = 'workout_videos';

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_folderName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // Переносит временный файл записи (из camera-плагина) в папку библиотеки
  // под именем с таймстампом, чтобы записи не перезаписывали друг друга.
  Future<File> saveVideo(String tempPath) async {
    final dir = await _dir();
    final ext = tempPath.split('.').last;
    final name = 'workout_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final dest = File('${dir.path}/$name');
    return File(tempPath).copy(dest.path).then((f) async {
      try {
        await File(tempPath).delete();
      } catch (_) {}
      return f;
    });
  }

  // Новее — первые.
  Future<List<File>> listVideos() async {
    final dir = await _dir();
    final entries = await dir.list().toList();
    final files = entries.whereType<File>().toList();
    files.sort((a, b) =>
        b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

  Future<void> deleteVideo(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }
}
