// lib/features/ai/pose_data_collection_screen.dart
//
// Record labeled pose examples (correct / incorrect + what's wrong) for any
// exercise, uploaded as raw landmarks to the server. Used to calibrate
// exercise-analysis thresholds from real recorded data instead of guessing
// them upfront. Reached from a button on the analysis screen's app bar.
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:provider/provider.dart';
import '../../core/models/pose_analysis.dart';
import '../../core/services/auth_provider.dart';
import '../../core/services/exercise_dataset_logger.dart';
import '../../core/services/pose_input_image_converter.dart';

class PoseDataCollectionScreen extends StatefulWidget {
  const PoseDataCollectionScreen({super.key});

  @override
  State<PoseDataCollectionScreen> createState() =>
      _PoseDataCollectionScreenState();
}

class _PoseDataCollectionScreenState extends State<PoseDataCollectionScreen> {
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  late final ExerciseDatasetLogger _logger;
  bool _isUploading = false;

  bool _isDetecting = false;
  bool _isCameraInitialized = false;
  List<CameraDescription> _cameras = [];
  CameraLensDirection _lensDirection = CameraLensDirection.back;

  final _exerciseCtrl = TextEditingController();
  final _exerciseFocusNode = FocusNode();
  final _commentCtrl = TextEditingController();
  CameraViewMode _viewMode = CameraViewMode.side;
  String _label = 'correct';
  bool _isRecording = false;
  int _frameCount = 0;
  Pose? _lastPose;

  // Exercise name suggestions from the global exercises catalog. Loading is
  // best-effort — if it fails (offline, not logged in) the field just stays
  // free text with no suggestions instead of blocking the tool.
  List<String> _globalExerciseNames = [];
  bool _catalogLoadFailed = false;

  bool get _canStart =>
      _exerciseCtrl.text.trim().isNotEmpty &&
      (_label == 'correct' || _commentCtrl.text.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );
    _logger = ExerciseDatasetLogger(context.read<AuthProvider>().api);
    _initCamera();
    _loadGlobalExercises();
  }

  Future<void> _loadGlobalExercises() async {
    try {
      final api = context.read<AuthProvider>().api;
      final list = await api.fetchGlobalExercises();
      if (!mounted) return;
      setState(() {
        _globalExerciseNames = list.map((e) => e.displayName).toSet().toList()
          ..sort();
      });
    } catch (_) {
      if (mounted) setState(() => _catalogLoadFailed = true);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector?.close();
    _exerciseCtrl.dispose();
    _exerciseFocusNode.dispose();
    _commentCtrl.dispose();
    super.dispose();
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
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();
    if (!mounted) return;
    setState(() {
      _lensDirection = direction;
      _isCameraInitialized = true;
    });
    _cameraController!.startImageStream(_onImage);
  }

  Future<void> _switchCamera() async {
    final hasBoth = _cameras
            .any((c) => c.lensDirection == CameraLensDirection.front) &&
        _cameras.any((c) => c.lensDirection == CameraLensDirection.back);
    if (!hasBoth || _isRecording) return;

    final newDirection = _lensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;

    setState(() => _isCameraInitialized = false);
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

  void _onImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;
    try {
      final camera = _cameraController?.description;
      if (camera == null) return;
      final inputImage = convertCameraImageToInputImage(image, camera);
      if (inputImage == null) return;

      final poses = await _poseDetector!.processImage(inputImage);
      if (poses.isEmpty || !mounted) return;
      final pose = poses.first;
      _lastPose = pose;

      if (_isRecording) {
        _logger.logFrame(
          pose: pose,
          exercise: _exerciseCtrl.text.trim(),
          viewMode: _viewMode.name,
          label: _label,
          comment: _commentCtrl.text.trim(),
          imageWidth: image.width,
          imageHeight: image.height,
        );
        setState(() => _frameCount = _logger.frameCount);
      }
    } finally {
      _isDetecting = false;
    }
  }

  void _startRecording() {
    if (!_canStart) return;
    final slug = _exerciseCtrl.text.trim().toLowerCase().replaceAll(
        RegExp(r'\s+'), '_');
    _logger.startCase('${slug}_$_label');
    setState(() {
      _isRecording = true;
      _frameCount = 0;
    });
  }

  Future<void> _stopRecording() async {
    final count = _frameCount;
    final label = _label;
    setState(() {
      _isRecording = false;
      _isUploading = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Записано $count кадров (${_labelRu(label)}) — отправка...'),
    ));
    // Comment is per-take; exercise/view/label stay so the next take is one
    // tap away.
    _commentCtrl.clear();

    try {
      await _logger.endCase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Пример отправлен на сервер')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось отправить пример: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _labelRu(String label) => label == 'correct' ? 'правильно' : 'неправильно';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Сбор данных калибровки'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Куда уходят данные',
            onPressed: _showFileInfo,
          ),
          if (_cameras.where((c) =>
                  c.lensDirection == CameraLensDirection.front ||
                  c.lensDirection == CameraLensDirection.back).length >
              1)
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IgnorePointer(
                  ignoring: _isRecording,
                  child: Opacity(
                    opacity: _isRecording ? 0.5 : 1,
                    child: RawAutocomplete<String>(
                      textEditingController: _exerciseCtrl,
                      focusNode: _exerciseFocusNode,
                      optionsBuilder: (value) {
                        if (value.text.trim().isEmpty) {
                          return const Iterable<String>.empty();
                        }
                        final query = value.text.toLowerCase();
                        return _globalExerciseNames
                            .where((n) => n.toLowerCase().contains(query));
                      },
                      onSelected: (_) => setState(() {}),
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            color: Colors.grey[900],
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final option = options.elementAt(index);
                                  return ListTile(
                                    dense: true,
                                    title: Text(option,
                                        style: const TextStyle(
                                            color: Colors.white)),
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Название упражнения',
                            labelStyle: TextStyle(color: Colors.white54),
                            isDense: true,
                            border: OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white24)),
                          ),
                          onChanged: (_) => setState(() {}),
                        );
                      },
                    ),
                  ),
                ),
                if (_catalogLoadFailed)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Справочник недоступен — свободный ввод',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ChoiceRow<CameraViewMode>(
                        values: CameraViewMode.values,
                        selected: _viewMode,
                        labelBuilder: (v) => v.nameRu,
                        enabled: !_isRecording,
                        onSelected: (v) => setState(() => _viewMode = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _LabelButton(
                        label: 'Правильно',
                        color: Colors.green,
                        selected: _label == 'correct',
                        enabled: !_isRecording,
                        onTap: () => setState(() => _label = 'correct'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _LabelButton(
                        label: 'Неправильно',
                        color: Colors.red,
                        selected: _label == 'incorrect',
                        enabled: !_isRecording,
                        onTap: () => setState(() => _label = 'incorrect'),
                      ),
                    ),
                  ],
                ),
                if (_label == 'incorrect') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentCtrl,
                    enabled: !_isRecording,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Что не так (обязательно)',
                      labelStyle: TextStyle(color: Colors.white54),
                      isDense: true,
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ],
            ),
          ),
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
                if (_isRecording)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fiber_manual_record,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text('REC · $_frameCount кадров',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                if (!_isRecording && _lastPose == null)
                  const Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Text(
                      'Человек не найден в кадре',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isRecording
                    ? _stopRecording
                    : (_isCameraInitialized && _canStart && !_isUploading
                        ? _startRecording
                        : null),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isRecording ? Colors.red : const Color(0xFF1976D2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(
                        _isRecording ? Icons.stop : Icons.fiber_manual_record,
                        color: Colors.white),
                label: Text(
                  _isRecording
                      ? 'Остановить запись'
                      : (_isUploading ? 'Отправка...' : 'Начать запись'),
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

  void _showFileInfo() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Куда уходят данные'),
        content: const SelectableText(
          'После нажатия "Остановить запись" все кадры текущего примера '
          'отправляются на сервер одним запросом '
          '(POST /pose-analysis/dataset-cases). Локально ничего не '
          'сохраняется — если отправка не удалась, пример нужно '
          'записать заново.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) labelBuilder;
  final bool enabled;
  final ValueChanged<T> onSelected;

  const _ChoiceRow({
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: values.map((v) {
        final isSelected = v == selected;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: enabled ? () => onSelected(v) : null,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1976D2) : Colors.transparent,
                border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1976D2)
                        : Colors.grey[700]!),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                labelBuilder(v),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LabelButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _LabelButton({
    required this.label,
    required this.color,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.85) : Colors.transparent,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
