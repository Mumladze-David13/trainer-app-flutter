// lib/features/ai/video_preview_sheet.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPreviewSheet extends StatefulWidget {
  final String videoPath;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  const VideoPreviewSheet({
    super.key,
    required this.videoPath,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<VideoPreviewSheet> createState() => _VideoPreviewSheetState();
}

class _VideoPreviewSheetState extends State<VideoPreviewSheet> {
  late VideoPlayerController _videoController;
  bool _isInitialized = false;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    _videoController = VideoPlayerController.file(File(widget.videoPath));

    await _videoController.initialize();
    await _videoController.setLooping(true);

    _videoController.addListener(() {
      if (mounted) {
        setState(() {
          _position = _videoController.value.position;
          _duration = _videoController.value.duration;
          _isPlaying = _videoController.value.isPlaying;
        });
      }
    });

    if (!mounted) return;
    setState(() => _isInitialized = true);
    await _videoController.play();
  }

  void _togglePlay() {
    if (_videoController.value.isPlaying) {
      _videoController.pause();
    } else {
      _videoController.play();
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.videocam, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Просмотр записи',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
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
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          GestureDetector(
                            onTap: _togglePlay,
                            child: AnimatedOpacity(
                              opacity: _isPlaying ? 0.0 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isInitialized)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2,
                              thumbShape:
                                  const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape:
                                  const RoundSliderOverlayShape(overlayRadius: 12),
                              activeTrackColor: const Color(0xFF1976D2),
                              inactiveTrackColor: Colors.grey[700],
                              thumbColor: Colors.white,
                              overlayColor: Colors.white.withOpacity(0.2),
                            ),
                            child: Slider(
                              value: _duration.inMilliseconds > 0
                                  ? _position.inMilliseconds / _duration.inMilliseconds
                                  : 0.0,
                              onChanged: (value) {
                                final newPosition = Duration(
                                  milliseconds:
                                      (value * _duration.inMilliseconds).round(),
                                );
                                _videoController.seekTo(newPosition);
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(_position),
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                ),
                                GestureDetector(
                                  onTap: _togglePlay,
                                  child: Icon(
                                    _isPlaying ? Icons.pause_circle : Icons.play_circle,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                Text(
                                  _formatDuration(_duration),
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _videoController.pause();
                      Navigator.pop(context);
                      widget.onDelete();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 20),
                    label: const Text(
                      'Удалить',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _videoController.pause();
                      Navigator.pop(context);
                      widget.onSave();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.save_alt,
                        color: Colors.white, size: 20),
                    label: const Text(
                      'Сохранить в "Мои видео"',
                      style: TextStyle(color: Colors.white),
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
}
