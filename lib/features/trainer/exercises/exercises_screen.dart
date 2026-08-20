// lib/features/trainer/exercises/exercises_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/models/models.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/cloudinary_upload_service.dart';
import '../../../core/services/image_compress_util.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/exercise_thumbnail.dart';
import 'global_exercises_screen.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  List<Exercise> _exercises = [];
  bool _loading = true;
  Exercise? _editing;
  bool _showForm = false;

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _metValueCtrl = TextEditingController();
  final _equipmentCtrl = TextEditingController();
  String _weightType = 'WEIGHT_KG';
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _metValueCtrl.dispose();
    _equipmentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AuthProvider>().api;
      final data = await api.getExercises();
      setState(() { _exercises = data; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openForm([Exercise? ex]) {
    setState(() {
      _editing = ex;
      _nameCtrl.text = ex?.name ?? '';
      _descCtrl.text = ex?.description ?? '';
      _weightType = ex?.weightType ?? 'WEIGHT_KG';
      _metValueCtrl.text = ex?.metValue?.toString() ?? '';
      _equipmentCtrl.text = ex?.equipment ?? '';
      _showForm = true;
    });
  }

  void _closeForm() => setState(() { _showForm = false; _editing = null; });

  Future<void> _openGlobalExercises() async {
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const GlobalExercisesScreen()),
    );
    if (imported == true) await _load();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    final api = context.read<AuthProvider>().api;
    final metValue = double.tryParse(_metValueCtrl.text.trim());
    try {
      if (_editing != null) {
        await api.updateExercise(
          _editing!.id,
          _nameCtrl.text.trim(),
          _descCtrl.text.trim(),
          weightType: _weightType,
          metValue: metValue,
          equipment: _equipmentCtrl.text.trim(),
        );
      } else {
        await api.createExercise(
          _nameCtrl.text.trim(),
          _descCtrl.text.trim(),
          weightType: _weightType,
          metValue: metValue,
          equipment: _equipmentCtrl.text.trim(),
        );
      }
      _closeForm();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_editing != null ? 'Обновлено' : 'Добавлено')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка сохранения')));
      }
    }
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    Navigator.of(context).pop();
    final editing = _editing;
    if (editing == null) return;

    final picker = ImagePicker();
    final XFile? picked;
    try {
      picked = await picker.pickImage(source: source, imageQuality: 90);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось открыть камеру/галерею')));
      }
      return;
    }
    if (picked == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    final api = context.read<AuthProvider>().api;
    final service = CloudinaryUploadService(api);
    try {
      final compressed = await compressImageForUpload(File(picked.path));
      final updated = await service.uploadExercisePhoto(compressed, editing.id);
      if (!mounted) return;
      setState(() {
        _editing = updated;
        _exercises = _exercises.map((e) => e.id == updated.id ? updated : e).toList();
      });
    } on CloudinaryUploadException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось загрузить фото. Попробуйте снова')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _showPhotoPicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Камера'),
              onTap: () => _pickAndUploadPhoto(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Галерея'),
              onTap: () => _pickAndUploadPhoto(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePhoto() async {
    final editing = _editing;
    if (editing == null) return;

    setState(() => _uploadingPhoto = true);
    final api = context.read<AuthProvider>().api;
    try {
      final updated = await api.deleteExercisePhoto(editing.id);
      if (!mounted) return;
      setState(() {
        _editing = updated;
        _exercises = _exercises.map((e) => e.id == updated.id ? updated : e).toList();
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось удалить фото')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _delete(Exercise ex) async {
    final api = context.read<AuthProvider>().api;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить упражнение?'),
        content: Text('Удалить "${ex.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await api.deleteExercise(ex.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Упражнения',
      actions: [
        IconButton(
          icon: const Icon(Icons.library_add),
          tooltip: 'Добавить из справочника',
          onPressed: _openGlobalExercises,
        ),
      ],
      floatingActionButton: _showForm ? null : FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: _showForm
          ? _buildForm()
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _exercises.isEmpty
                    ? const Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fitness_center, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('Нет упражнений', style: TextStyle(color: Colors.grey)),
                        ],
                      ))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _exercises.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final ex = _exercises[i];
                            return Card(
                              child: ListTile(
                                leading: ExerciseThumbnail(imageUrl: ex.imageUrl),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(ex.name,
                                          style: const TextStyle(fontWeight: FontWeight.w500)),
                                    ),
                                    if (ex.weightType == 'BODYWEIGHT')
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1976D2).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                              color: const Color(0xFF1976D2).withOpacity(0.4)),
                                        ),
                                        child: const Text(
                                          'Без веса',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF1976D2),
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    if (ex.weightType == 'MACHINE')
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.orange.withOpacity(0.4)),
                                        ),
                                        child: const Text(
                                          'Тренажёр',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.orange,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: (ex.description == null || ex.description!.isEmpty) &&
                                        (ex.equipment == null || ex.equipment!.isEmpty)
                                    ? null
                                    : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (ex.description != null && ex.description!.isNotEmpty)
                                      Text(ex.description!),
                                    if (ex.equipment != null && ex.equipment!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.fitness_center,
                                                size: 12, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(ex.equipment!,
                                                style: const TextStyle(
                                                    fontSize: 12, color: Colors.grey)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                        icon: const Icon(Icons.edit, color: Color(0xFF8B0000)),
                                        onPressed: () => _openForm(ex)),
                                    IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _delete(ex)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
    );
  }

  Widget _buildForm() {
    final dropdownValue = kEquipmentPresets.contains(_equipmentCtrl.text.trim())
        ? _equipmentCtrl.text.trim()
        : null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Row(
                children: [
                  Text(_editing != null ? 'Редактировать' : 'Новое упражнение',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: _closeForm),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_editing != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Stack(
                              children: [
                                ExerciseThumbnail(imageUrl: _editing!.imageUrl, size: 64),
                                if (_uploadingPhoto)
                                  const Positioned.fill(
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _uploadingPhoto ? null : _showPhotoPicker,
                                    icon: const Icon(Icons.add_a_photo, size: 16),
                                    label: const Text('Изменить фото'),
                                  ),
                                  if (_editing!.ownImageUrl != null)
                                    TextButton.icon(
                                      onPressed: _uploadingPhoto ? null : _deletePhoto,
                                      icon: const Icon(Icons.delete_outline,
                                          size: 16, color: Colors.red),
                                      label: const Text('Удалить фото',
                                          style: TextStyle(color: Colors.red)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Название', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Описание (необязательно)', border: OutlineInputBorder()),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      const Text('Тип упражнения',
                          style: TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        style: SegmentedButton.styleFrom(
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        segments: const [
                          ButtonSegment(value: 'WEIGHT_KG', label: Text('С весом')),
                          ButtonSegment(value: 'BODYWEIGHT', label: Text('Без веса')),
                          ButtonSegment(value: 'MACHINE', label: Text('Трен.')),
                        ],
                        selected: {_weightType},
                        onSelectionChanged: (v) =>
                            setState(() => _weightType = v.first),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _metValueCtrl,
                        decoration: const InputDecoration(
                          labelText: 'MET коэффициент (для кардио)',
                          hintText: 'например: 7.0',
                          border: OutlineInputBorder(),
                          helperText: 'Необязательно',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: dropdownValue,
                        decoration: const InputDecoration(
                          labelText: 'Оборудование (необязательно)',
                          border: OutlineInputBorder(),
                        ),
                        items: kEquipmentPresets
                            .map((preset) => DropdownMenuItem(
                                  value: preset,
                                  child: Text(preset),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _equipmentCtrl.text = v);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: OutlinedButton(onPressed: _closeForm, child: const Text('Отмена'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ElevatedButton(onPressed: _save, child: const Text('Сохранить'))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
