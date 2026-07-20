// lib/features/ai/pose_analysis_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../core/models/pose_analysis.dart';
import '../../core/services/pose_analysis_service.dart';

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

  bool _isDetecting = false;
  bool _isCameraInitialized = false;
  SupportedExercise _selectedExercise = SupportedExercise.squat;
  PoseAnalysisResult? _lastResult;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialExercise != null) {
      _selectedExercise = widget.initialExercise!;
    }
    _initPoseDetector();
    _initCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector?.close();
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
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();

    if (mounted) {
      setState(() => _isCameraInitialized = true);
      _startImageStream();
    }
  }

  void _startImageStream() {
    _cameraController?.startImageStream((CameraImage image) async {
      if (_isDetecting || !_isAnalyzing) return;
      _isDetecting = true;

      try {
        final inputImage = _convertToInputImage(image);
        if (inputImage == null) return;

        final poses = await _poseDetector!.processImage(inputImage);

        if (poses.isNotEmpty && mounted) {
          final result =
              _analysisService.analyzePose(poses.first, _selectedExercise);
          setState(() => _lastResult = result);
        }
      } finally {
        _isDetecting = false;
      }
    });
  }

  InputImage? _convertToInputImage(CameraImage image) {
    final camera = _cameraController?.description;
    if (camera == null) return null;

    final rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
            InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (format == null) return null;

    final bytes = _concatenatePlanes(image.planes);

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    int totalLength = 0;
    for (final plane in planes) {
      totalLength += plane.bytes.length;
    }
    final result = Uint8List(totalLength);
    int offset = 0;
    for (final plane in planes) {
      result.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }
    return result;
  }

  void _toggleAnalysis() {
    setState(() {
      _isAnalyzing = !_isAnalyzing;
      if (!_isAnalyzing) {
        _lastResult = null;
        _analysisService.resetReps();
      }
    });
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
        title: const Text('Анализ техники'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
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

          // Camera preview + overlay
          Expanded(
            child: Stack(
              children: [
                if (_isCameraInitialized)
                  Center(
                    child: AspectRatio(
                      aspectRatio: _cameraController!.value.aspectRatio,
                      child: CameraPreview(_cameraController!),
                    ),
                  )
                else
                  const Center(
                      child: CircularProgressIndicator(color: Colors.white)),

                // Results overlay
                if (_lastResult != null)
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
