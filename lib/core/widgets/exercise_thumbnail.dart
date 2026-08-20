// lib/core/widgets/exercise_thumbnail.dart
import 'package:flutter/material.dart';

/// Small square thumbnail for an exercise, used in the exercise directory,
/// workouts and sessions. Falls back to a generic icon when there's no
/// image (own exercises that weren't imported from the global catalog).
/// Tapping always opens a full-size viewer — or a "no image" message if
/// there's nothing to show, so the tap target works the same whether or not
/// a photo exists.
class ExerciseThumbnail extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const ExerciseThumbnail({super.key, this.imageUrl, this.size = 40});

  void _openViewer(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет изображения')));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ExerciseImageViewer(imageUrl: imageUrl!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(size / 2),
      onTap: () => _openViewer(context),
      child: imageUrl == null || imageUrl!.isEmpty
          ? CircleAvatar(
              radius: size / 2,
              child: Icon(Icons.fitness_center, size: size * 0.5),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => CircleAvatar(
                  radius: size / 2,
                  child: Icon(Icons.fitness_center, size: size * 0.5),
                ),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : SizedBox(
                        width: size,
                        height: size,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
              ),
            ),
    );
  }
}

class _ExerciseImageViewer extends StatelessWidget {
  final String imageUrl;
  const _ExerciseImageViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            errorBuilder: (_, __, ___) => const Text(
              'Не удалось загрузить изображение',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }
}
