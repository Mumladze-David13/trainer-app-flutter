// lib/features/ai/pose_analysis_screen.dart
import 'dart:io';
import 'package:flutter/foundation.dart'
    show kDebugMode, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:provider/provider.dart';
import '../../core/models/pose_analysis.dart';
import '../../core/services/auth_provider.dart';
import '../../core/services/pose_analysis_service.dart';
import '../../core/services/calibration_logger.dart';
import '../../core/services/pose_input_image_converter.dart';
import '../../core/services/workout_video_library.dart';
import 'pose_data_collection_screen.dart';
import 'pose_overlay_painter.dart';
import 'video_library_screen.dart';
import 'video_preview_sheet.dart';

class PoseAnalysisScreen extends StatefulWidget {
  final SupportedExercise? initialExercise;

  const PoseAnalysisScreen({super.key, this.initialExercise});

  @override
  State<PoseAnalysisScreen> createState() => _PoseAnalysisScreenState();
}

class _PoseAnalysisScreenState extends State<PoseAnalysisScreen> {
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  final PoseAnalysisService _analysisService = PoseAnalysisService();
  late final CalibrationLogger _calibrationLogger;

  bool _isDetecting = false;
  bool _isCameraInitialized = false;
  SupportedExercise _selectedExercise = SupportedExercise.squat;
  CameraViewMode _viewMode = CameraViewMode.side;
  PoseAnalysisResult? _lastResult;
  Pose? _lastPose;
  Size? _lastImageSize;
  InputImageRotation? _lastImageRotation;
  bool _isAnalyzing = false;
  bool _isRecording = false;
  List<CameraDescription> _cameras = [];
  CameraLensDirection _lensDirection = CameraLensDirection.front;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialExercise != null) {
      _selectedExercise = widget.initialExercise!;
    }
    _calibrationLogger = CalibrationLogger(context.read<AuthProvider>().api);
    _initPoseDetector();
    _initCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector?.close();
    _calibrationLogger.close();
    super.dispose();
  }

  void _initPoseDetector() {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    await _openCamera(_lensDirection);
  }

  Future<void> _openCamera(CameraLensDirection direction) async {
    final camera = _cameras.firstWhere(
      (c) => c.lensDirection == direction,
      orElse: () => _cameras.first,
    );

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      // ML Kit's Android bridge only accepts NV21/YV12 bytes; the platform
      // default (yuv420/YUV_420_888) is rejected for every frame, which
      // silently kills pose detection with no visible error.
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();

    if (mounted) {
      setState(() {
        _lensDirection = direction;
        _isCameraInitialized = true;
        _errorMessage = null;
      });
      _startImageStream();
    }
  }

  Future<void> _switchCamera() async {
    final hasBoth = _cameras.any((c) => c.lensDirection == CameraLensDirection.front) &&
        _cameras.any((c) => c.lensDirection == CameraLensDirection.back);
    if (!hasBoth) return;

    final newDirection = _lensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;

    setState(() {
      _isAnalyzing = false;
      _isCameraInitialized = false;
      _lastResult = null;
    });
    _analysisService.resetReps();

    final oldController = _cameraController;
    _cameraController = null;
    if (oldController != null) {
      if (oldController.value.isStreamingImages) {
        await oldController.stopImageStream();
      }
      await oldController.dispose();
    }

    await _openCamera(newDirection);
  }

  void _startImageStream() {
    _cameraController?.startImageStream(_onImageAvailable);
  }

  // Кадры для живого анализа техники (startImageStream). Во время записи
  // видео поток кадров остановлен — см. _startRecording.
  Future<void> _onImageAvailable(CameraImage image) async {
    if (_isDetecting || !_isAnalyzing) return;
    _isDetecting = true;

    try {
      final camera = _cameraController?.description;
      if (camera == null) return;
      final inputImage = convertCameraImageToInputImage(image, camera);
      if (inputImage == null) return;

      final poses = await _poseDetector!.processImage(inputImage);
      if (!mounted) return;

      if (poses.isNotEmpty) {
        final pose = poses.first;
        final result = _analysisService.analyzePose(pose, _selectedExercise,
            viewMode: _viewMode);
        if (result != null) {
          _calibrationLogger.logFrame(
            exercise: _selectedExercise,
            viewMode: _viewMode,
            result: result,
            imageWidth: image.width,
            imageHeight: image.height,
          );
        }
        setState(() {
          _lastResult = result;
          _lastPose = pose;
          _lastImageSize = Size(image.width.toDouble(), image.height.toDouble());
          _lastImageRotation =
              InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
                  InputImageRotation.rotation0deg;
        });
      } else {
        setState(() => _lastPose = null);
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Pose detection error: $e');
      }
      if (mounted && _errorMessage == null) {
        setState(() => _errorMessage = 'Ошибка анализа: $e');
      }
    } finally {
      _isDetecting = false;
    }
  }

  void _toggleAnalysis() {
    setState(() {
      _isAnalyzing = !_isAnalyzing;
      _errorMessage = null;
      if (!_isAnalyzing) {
        _lastResult = null;
        _lastPose = null;
        _analysisService.resetReps();
      }
    });
  }

  Future<void> _startRecording() async {
    final controller = _cameraController;
    if (controller == null || !_isCameraInitialized || _isRecording) return;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      // Записываем плоским startVideoRecording() без onAvailable: связка
      // "запись + доставка кадров в один и тот же колбэк" на реальных
      // устройствах (проверено на Redmi Note 10) обрывает запись через
      // ~2 секунды без ошибки и без участия кнопки "Стоп" — плагин camera
      // не тянет одновременно кодирование видео и ML Kit обработку кадров
      // в одном потоке. Живой анализ/скелет во время записи временно не
      // работает — это осознанный компромисс ради надёжной записи видео.
      await controller.startVideoRecording();
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _isAnalyzing = false;
        _lastPose = null;
        _lastResult = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось начать запись видео: $e')));
      }
    }
  }

  Future<void> _stopRecording() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isRecordingVideo) return;
    try {
      final file = await controller.stopVideoRecording();
      if (!mounted) return;
      setState(() => _isRecording = false);
      // stopVideoRecording() also stops frame streaming — resume it so live
      // analysis keeps working after the recording ends.
      if (!controller.value.isStreamingImages) {
        controller.startImageStream(_onImageAvailable);
      }
      await _showSaveVideoDialog(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка остановки записи: $e')));
      }
    }
  }

  Future<void> _showSaveVideoDialog(String videoPath) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => VideoPreviewSheet(
        videoPath: videoPath,
        onSave: () => _saveVideoToLibrary(videoPath),
        onDelete: () => _deleteVideo(videoPath),
      ),
    );
  }

  // Видео остаётся только в приватной папке приложения на этом телефоне —
  // никуда не отправляется. Из "Моих видео" его можно позже открыть для
  // локального AI-анализа или удалить.
  Future<void> _saveVideoToLibrary(String videoPath) async {
    try {
      await WorkoutVideoLibrary().saveVideo(videoPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Видео сохранено в "Мои видео"')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось сохранить видео: $e')));
      }
    }
  }

  Future<void> _deleteVideo(String videoPath) async {
    try {
      await File(videoPath).delete();
    } catch (_) {}
  }

  Color _scoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Анализ техники'),
            if (_isRecording) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'REC',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.video_library_outlined),
            tooltip: 'Мои видео',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const VideoLibraryScreen(),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.dataset_outlined),
            tooltip: 'Сбор данных калибровки',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const PoseDataCollectionScreen(),
            )),
          ),
          IconButton(
            icon: Icon(_isRecording ? Icons.stop_circle : Icons.videocam,
                color: _isRecording ? Colors.red : Colors.white),
            tooltip: _isRecording ? 'Остановить запись' : 'Записать видео',
            onPressed: _isCameraInitialized
                ? (_isRecording ? _stopRecording : _startRecording)
                : null,
          ),
          if (_cameras.where((c) =>
                  c.lensDirection == CameraLensDirection.front ||
                  c.lensDirection == CameraLensDirection.back).length > 1)
            IconButton(
              icon: const Icon(Icons.cameraswitch),
              tooltip: 'Сменить камеру',
              onPressed:
                  _isCameraInitialized && !_isRecording ? _switchCamera : null,
            ),
        ],
      ),
      body: Column(
        children: [
          // Exercise selector chips
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: SupportedExercise.values.map((exercise) {
                  final isSelected = _selectedExercise == exercise;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedExercise = exercise;
                        _isAnalyzing = false;
                        _lastResult = null;
                        _lastPose = null;
                        _analysisService.resetReps();
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1976D2)
                            : Colors.grey[800],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        exercise.nameRu,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // View mode selector (side/front) — only some exercises support it
          if (_selectedExercise == SupportedExercise.squat)
            Container(
              color: Colors.black,
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: Row(
                children: CameraViewMode.values.map((mode) {
                  final isSelected = _viewMode == mode;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _viewMode = mode;
                        _isAnalyzing = false;
                        _lastResult = null;
                        _lastPose = null;
                        _analysisService.resetReps();
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1976D2)
                            : Colors.transparent,
                        border: Border.all(
                            color: isSelected
                                ? const Color(0xFF1976D2)
                                : Colors.grey[700]!),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Камера: ${mode.nameRu}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white54,
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Camera preview + overlay
          Expanded(
            child: Stack(
              children: [
                if (_isCameraInitialized)
                  Center(
                    child: AspectRatio(
                      aspectRatio: _cameraController!.value.aspectRatio,
                      child: Stack(
                        children: [
                          CameraPreview(_cameraController!),
                          if (_lastPose != null &&
                              _lastImageSize != null &&
                              _lastImageRotation != null)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: PoseOverlayPainter(
                                  pose: _lastPose!,
                                  imageSize: _lastImageSize!,
                                  rotation: _lastImageRotation!,
                                  cameraLensDirection: _lensDirection,
                                  result: _lastResult,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  const Center(
                      child: CircularProgressIndicator(color: Colors.white)),

                // Error banner
                if (_errorMessage != null)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Results overlay
                if (_errorMessage == null && _lastResult != null)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: _buildResultOverlay(_lastResult!),
                  ),

                // Rep counter
                if (_isAnalyzing && _lastResult != null)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Text('Повторений',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 11)),
                          Text(
                            '${_lastResult!.repCount}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Hint when not analyzing
                if (!_isAnalyzing)
                  Positioned(
                    bottom: 100,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: Colors.white54, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedExercise.description,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Start/Stop button
          Container(
            color: Colors.black,
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isCameraInitialized ? _toggleAnalysis : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isAnalyzing ? Colors.red : const Color(0xFF1976D2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(_isAnalyzing ? Icons.stop : Icons.play_arrow,
                    color: Colors.white),
                label: Text(
                  _isAnalyzing ? 'Остановить анализ' : 'Начать анализ',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _angleLabel(String key) {
    switch (key) {
      case 'knee':
        return 'Колено';
      case 'hip':
        return 'Таз';
      case 'elbow':
        return 'Локоть';
      case 'body':
        return 'Корпус';
      default:
        return key;
    }
  }

  Widget _buildResultOverlay(PoseAnalysisResult result) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Техника:',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(width: 8),
              Text(
                '${result.formScore.round()}%',
                style: TextStyle(
                    color: _scoreColor(result.formScore),
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: result.formScore / 100,
                    backgroundColor: Colors.grey[700],
                    color: _scoreColor(result.formScore),
                    minHeight: 6,
                  ),
                ),
              ),
            ],
          ),
          if (result.angles.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              children: result.angles.entries
                  .map((e) => Text(
                        '${_angleLabel(e.key)}: ${e.value.round()}°',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                      ))
                  .toList(),
            ),
          ],
          if (result.issues.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...result.issues.take(2).map((issue) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber,
                          color: Colors.orange, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Text(issue,
                              style: const TextStyle(
                                  color: Colors.orange, fontSize: 12))),
                    ],
                  ),
                )),
          ],
          if (result.tips.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...result.tips.take(1).map((tip) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        color: Colors.yellow, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(tip,
                            style: const TextStyle(
                                color: Colors.yellow, fontSize: 12))),
                  ],
                )),
          ],
          if (result.issues.isEmpty)
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 14),
                SizedBox(width: 4),
                Text('Отличная техника!',
                    style: TextStyle(color: Colors.green, fontSize: 12)),
              ],
            ),
        ],
      ),
    );
  }
}
