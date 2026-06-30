// lib/features/trainer/workout/workout_editor_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/models.dart';
import '../../../core/services/auth_provider.dart';

// Модель строки упражнения в редакторе
class _ExRow {
  String? exerciseId;
  String? exerciseName;
  String weightType;
  int sets;
  int reps;
  double? weight;
  List<TextEditingController> setWeightControllers;
  List<TextEditingController> setRepControllers;
  bool useSetWeights;
  bool useSetReps;
  int? supersetGroup;
  int? supersetOrder;
  bool isDone;

  _ExRow({
    this.exerciseId,
    this.exerciseName,
    this.weightType = 'WEIGHT_KG',
    this.sets = 3,
    this.reps = 10,
    this.weight,
    List<double?>? setWeights,
    List<int>? setReps,
    this.useSetWeights = false,
    this.useSetReps = false,
    this.supersetGroup,
    this.supersetOrder,
    this.isDone = false,
  })  : setWeightControllers = List.generate(
          sets,
          (i) => TextEditingController(
              text: setWeights != null && i < setWeights.length
                  ? (setWeights[i]?.toString() ?? '')
                  : ''),
        ),
        setRepControllers = List.generate(
          sets,
          (i) => TextEditingController(
              text: setReps != null && i < setReps.length
                  ? setReps[i].toString()
                  : ''),
        );

  void updateSetCount(int newSets) {
    void syncList(List<TextEditingController> list) {
      if (newSets > list.length) {
        for (int i = list.length; i < newSets; i++) {
          list.add(TextEditingController());
        }
      } else if (newSets < list.length) {
        for (int i = list.length - 1; i >= newSets; i--) {
          list[i].dispose();
          list.removeAt(i);
        }
      }
    }
    syncList(setWeightControllers);
    syncList(setRepControllers);
    sets = newSets;
  }

  List<double?> get parsedSetWeights =>
      setWeightControllers.map((c) => double.tryParse(c.text)).toList();

  List<int> get parsedSetReps =>
      setRepControllers.map((c) => int.tryParse(c.text) ?? reps).toList();

  void dispose() {
    for (final c in setWeightControllers) { c.dispose(); }
    for (final c in setRepControllers) { c.dispose(); }
  }
}

class WorkoutEditorScreen extends StatefulWidget {
  final String clientId;
  final String? seasonId;
  final String? workoutId;
  final bool readOnly;

  const WorkoutEditorScreen({
    super.key,
    required this.clientId,
    this.seasonId,
    this.workoutId,
    this.readOnly = false,
  });

  @override
  State<WorkoutEditorScreen> createState() => _WorkoutEditorScreenState();
}

class _WorkoutEditorScreenState extends State<WorkoutEditorScreen> {
  List<Exercise> _exercises = [];
  bool _loading = true;
  bool _saving = false;
  bool _isCompleted = false;
  final _notesCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<_ExRow> _rows = [];
  int _nextSupersetGroup = 1;

  bool get isNew => widget.workoutId == null;
  bool get readOnly => widget.readOnly || _isCompleted;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _scrollCtrl.dispose();
    for (final r in _rows) { r.dispose(); }
    super.dispose();
  }

  Future<void> _init() async {
    final api = context.read<AuthProvider>().api;
    final exercises = await api.getExercises();
    setState(() => _exercises = exercises);

    if (!isNew) {
      final w = await api.getWorkout(widget.workoutId!);
      setState(() {
        _isCompleted = w.isCompleted;
        _notesCtrl.text = w.notes ?? '';
        _rows = w.workoutExercises.map((e) {
          // Ищем упражнение сначала по exerciseId, потом по exercise.id
          final lookupId = e.exerciseId.isNotEmpty ? e.exerciseId : e.exercise.id;
          final ex = exercises.firstWhere(
            (ex) => ex.id == lookupId,
            orElse: () => Exercise(id: '', name: '', weightType: 'WEIGHT_KG'),
          );
          final resolvedWeightType = ex.id.isNotEmpty
              ? ex.weightType
              : (e.exercise.weightType.isNotEmpty ? e.exercise.weightType : 'WEIGHT_KG');
          final resolvedName = ex.id.isNotEmpty
              ? ex.name
              : (e.exercise.name.isNotEmpty ? e.exercise.name : null);
          return _ExRow(
            exerciseId: lookupId.isNotEmpty ? lookupId : null,
            exerciseName: resolvedName,
            weightType: resolvedWeightType,
            sets: e.sets,
            reps: e.reps,
            weight: e.weight,
            setWeights: e.setWeights,
            setReps: e.setReps,
            useSetWeights: e.hasSetWeights,
            useSetReps: e.hasSetReps,
            supersetGroup: e.supersetGroup,
            supersetOrder: e.supersetOrder,
            isDone: e.isDone,
          );
        }).toList();
        // Найти максимальный номер супер-сета
        final groups = _rows
            .where((r) => r.supersetGroup != null)
            .map((r) => r.supersetGroup!)
            .toList();
        if (groups.isNotEmpty) {
          _nextSupersetGroup = groups.reduce((a, b) => a > b ? a : b) + 1;
        }
      });
    } else {
      _rows.add(_ExRow());
    }
    setState(() => _loading = false);
  }

  void _addRow() {
    setState(() => _rows.add(_ExRow()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _removeRow(int i) {
    _rows[i].dispose();
    setState(() => _rows.removeAt(i));
  }

  // Создать супер-сет из выбранных упражнений
  void _createSuperset(List<int> indices) {
    setState(() {
      for (int i = 0; i < indices.length; i++) {
        _rows[indices[i]].supersetGroup = _nextSupersetGroup;
        _rows[indices[i]].supersetOrder = i;
      }
      _nextSupersetGroup++;
    });
  }

  // Убрать упражнение из супер-сета
  void _removeFromSuperset(int i) {
    setState(() {
      _rows[i].supersetGroup = null;
      _rows[i].supersetOrder = null;
    });
  }

  Future<void> _save() async {
    if (_rows.isEmpty || _rows.any((r) => r.exerciseId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выберите упражнение для каждой строки')));
      return;
    }
    setState(() => _saving = true);
    final api = context.read<AuthProvider>().api;

    final exercises = _rows.asMap().entries.map((e) {
      final row = e.value;
      final Map<String, dynamic> data = {
        'exerciseId': row.exerciseId!,
        'sets': row.sets,
        'reps': row.reps,
        'order': e.key,
      };

      if (row.weightType != 'BODYWEIGHT') {
        if (row.useSetWeights) {
          data['setWeights'] = row.parsedSetWeights;
          final first = row.parsedSetWeights.firstWhere(
              (w) => w != null, orElse: () => null);
          if (first != null) data['weight'] = first;
        } else if (row.weight != null) {
          data['weight'] = row.weight;
        }
      }

      if (row.useSetReps) {
        data['setReps'] = row.parsedSetReps;
      }

      if (row.supersetGroup != null) {
        data['supersetGroup'] = row.supersetGroup;
        data['supersetOrder'] = row.supersetOrder ?? 0;
      }

      return data;
    }).toList();

    try {
      if (isNew) {
        await api.createWorkout(
          seasonId: widget.seasonId!,
          notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
          exercises: exercises,
        );
      } else {
        await api.updateWorkout(widget.workoutId!,
          notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
          exercises: exercises,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isNew ? 'Занятие создано' : 'Занятие обновлено')));
        Navigator.of(context).pop(true);
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data is Map
            ? (e.response?.data['message'] ?? 'Ошибка сохранения')
            : 'Ошибка сохранения';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка сохранения')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Показать диалог выбора упражнений для супер-сета
  Future<void> _showSupersetDialog() async {
    final available = _rows.asMap().entries
        .where((e) => e.value.supersetGroup == null)
        .toList();

    if (available.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нужно минимум 2 упражнения без супер-сета')));
      return;
    }

    final selected = <int>{};

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Создать супер-сет'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Выберите упражнения для супер-сета:',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 8),
              ...available.map((entry) {
                final i = entry.key;
                final row = entry.value;
                final exName = _exercises
                    .firstWhere((e) => e.id == row.exerciseId,
                        orElse: () => Exercise(id: '', name: 'Не выбрано'))
                    .name;
                return CheckboxListTile(
                  dense: true,
                  title: Text('${i + 1}. $exName'),
                  value: selected.contains(i),
                  onChanged: (v) => setDlgState(() {
                    if (v == true) { selected.add(i); }
                    else { selected.remove(i); }
                  }),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: selected.length < 2
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _createSuperset(selected.toList()..sort());
                    },
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew
            ? 'Новое занятие'
            : readOnly
                ? 'Просмотр занятия'
                : 'Редактировать занятие'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Notes — фиксировано вверху, не скроллится
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Примечания (необязательно)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                ),

                // Sticky заголовок «Упражнения» + маленькие кнопки
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                  child: Row(
                    children: [
                      const Text('Упражнения',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (!readOnly) ...[
                        TextButton.icon(
                          onPressed: _showSupersetDialog,
                          icon: const Icon(Icons.link, size: 14, color: Colors.orange),
                          label: const Text('Супер-сет',
                              style: TextStyle(color: Colors.orange, fontSize: 12)),
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          onPressed: _addRow,
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('Добавить', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Скроллируемый список упражнений
                Expanded(
                  child: _rows.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Нет упражнений. Добавьте хотя бы одно.',
                                style: TextStyle(color: Colors.grey)),
                          ),
                        )
                      : ListView(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          children: _buildExerciseList(),
                        ),
                ),

                // Bottom action bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2))],
                  ),
                  child: readOnly
                      ? SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Закрыть'),
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Закрыть без сохранения'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _saving || _rows.isEmpty ? null : _save,
                                icon: _saving
                                    ? const SizedBox(width: 16, height: 16,
                                        child: CircularProgressIndicator(
                                            color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.save, size: 18),
                                label: Text(_saving ? 'Сохраняю...' : 'Сохранить'),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  List<Widget> _buildExerciseList() {
    final widgets = <Widget>[];
    // Группируем по супер-сетам для визуального отображения
    final processed = <int>{};

    for (int i = 0; i < _rows.length; i++) {
      if (processed.contains(i)) continue;
      final row = _rows[i];

      if (row.supersetGroup != null) {
        // Найти все упражнения этого супер-сета
        final groupIndices = _rows.asMap().entries
            .where((e) => e.value.supersetGroup == row.supersetGroup)
            .map((e) => e.key)
            .toList();
        processed.addAll(groupIndices);
        widgets.add(_buildSupersetCard(groupIndices));
      } else {
        widgets.add(_buildExerciseCard(i));
      }
    }
    return widgets;
  }

  // Карточка обычного упражнения
  Widget _buildExerciseCard(int i) {
    final row = _rows[i];
    final exReadOnly = readOnly || row.isDone;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: row.isDone ? Colors.green[50] : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _ExerciseHeader(
              index: i,
              isDone: row.isDone,
              onDelete: exReadOnly ? null : () => _removeRow(i),
            ),
            const SizedBox(height: 8),
            _ExerciseDropdown(
              exerciseId: row.exerciseId,
              exerciseName: row.exerciseName,
              exercises: _exercises,
              enabled: !exReadOnly,
              onChanged: (v) => setState(() {
                row.exerciseId = v;
                row.exerciseName = null;
                if (v != null) {
                  final ex = _exercises.firstWhere(
                    (e) => e.id == v,
                    orElse: () => Exercise(id: '', name: '', weightType: 'WEIGHT_KG'),
                  );
                  row.weightType = ex.weightType;
                }
              }),
            ),
            const SizedBox(height: 8),
            _SetsRepsRow(
              sets: row.sets,
              reps: row.reps,
              showReps: !row.useSetReps,
              enabled: !exReadOnly,
              onSetsChanged: (v) => setState(() => row.updateSetCount(v)),
              onRepsChanged: (v) => setState(() => row.reps = v),
            ),
            const SizedBox(height: 8),
            _RepsSection(
              row: row,
              readOnly: exReadOnly,
              onToggle: () => setState(() => row.useSetReps = !row.useSetReps),
            ),
            const SizedBox(height: 8),
            _WeightSection(
              row: row,
              readOnly: exReadOnly,
              onToggle: () => setState(() => row.useSetWeights = !row.useSetWeights),
              onWeightChanged: (v) => setState(() => row.weight = v),
            ),
          ],
        ),
      ),
    );
  }

  // Карточка супер-сета
  Widget _buildSupersetCard(List<int> indices) {
    final groupNum = _rows[indices.first].supersetGroup!;
    final anyDone = indices.any((i) => _rows[i].isDone);
    final allDone = indices.every((i) => _rows[i].isDone);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: allDone ? Colors.green[50] : null,
        border: Border.all(color: Colors.orange, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Заголовок супер-сета
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                const Icon(Icons.link, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Text('Супер-сет $groupNum',
                    style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                if (allDone) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                ],
                const Spacer(),
                if (!readOnly)
                  TextButton(
                    onPressed: () => setState(() {
                      for (final i in indices) { _removeFromSuperset(i); }
                    }),
                    style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                    child: const Text('Разбить',
                        style: TextStyle(color: Colors.orange, fontSize: 12)),
                  ),
              ],
            ),
          ),
          // Упражнения супер-сета
          ...indices.map((i) {
            final row = _rows[i];
            final exReadOnly = readOnly || row.isDone;
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (i != indices.first)
                    const Divider(height: 1),
                  if (i != indices.first)
                    const SizedBox(height: 12),
                  _ExerciseHeader(
                    index: i,
                    isDone: row.isDone,
                    onDelete: exReadOnly ? null : () => _removeRow(i),
                    label: 'Упр. ${indices.indexOf(i) + 1}',
                  ),
                  const SizedBox(height: 8),
                  _ExerciseDropdown(
                    exerciseId: row.exerciseId,
                    exerciseName: row.exerciseName,
                    exercises: _exercises,
                    enabled: !exReadOnly,
                    onChanged: (v) => setState(() {
                      row.exerciseId = v;
                      row.exerciseName = null;
                      if (v != null) {
                        final ex = _exercises.firstWhere(
                          (e) => e.id == v,
                          orElse: () => Exercise(id: '', name: '', weightType: 'WEIGHT_KG'),
                        );
                        row.weightType = ex.weightType;
                      }
                    }),
                  ),
                  const SizedBox(height: 8),
                  // В супер-сете подходы/повторы только у первого
                  if (i == indices.first) ...[
                    _SetsRepsRow(
                      sets: row.sets,
                      reps: row.reps,
                      enabled: !(readOnly || anyDone),
                      onSetsChanged: (v) => setState(() {
                        for (final idx in indices) {
                          _rows[idx].updateSetCount(v);
                        }
                      }),
                      onRepsChanged: (v) => setState(() {
                        for (final idx in indices) {
                          _rows[idx].reps = v;
                        }
                      }),
                      label: 'Подходы/Повторы для всего супер-сета',
                    ),
                    const SizedBox(height: 8),
                  ],
                  _WeightSection(
                    row: row,
                    readOnly: exReadOnly,
                    onToggle: () => setState(() => row.useSetWeights = !row.useSetWeights),
                    onWeightChanged: (v) => setState(() => row.weight = v),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Вспомогательные виджеты ───────────────────────────────────────────

class _ExerciseHeader extends StatelessWidget {
  final int index;
  final VoidCallback? onDelete;
  final String? label;
  final bool isDone;

  const _ExerciseHeader({
    required this.index,
    this.onDelete,
    this.label,
    this.isDone = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: isDone ? Colors.green : const Color(0xFF8B0000),
          child: isDone
              ? const Icon(Icons.check, color: Colors.white, size: 14)
              : Text(
                  label ?? '${index + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
        ),
        if (isDone) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green),
            ),
            child: const Text(
              'Выполнено',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.green,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
        const Spacer(),
        if (onDelete != null)
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            onPressed: onDelete,
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
      ],
    );
  }
}

class _ExerciseDropdown extends StatelessWidget {
  final String? exerciseId;
  final String? exerciseName;
  final List<Exercise> exercises;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  const _ExerciseDropdown({
    required this.exerciseId,
    this.exerciseName,
    required this.exercises,
    required this.onChanged,
    this.enabled = true,
  });

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ExercisePickerSheet(exercises: exercises),
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final selected = exercises.where((e) => e.id == exerciseId).toList();
    final selectedName = selected.isNotEmpty ? selected.first.name : exerciseName;

    return InkWell(
      onTap: enabled ? () => _openPicker(context) : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Упражнение',
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: enabled ? const Icon(Icons.search) : null,
          filled: !enabled,
          fillColor: enabled ? null : Colors.grey[100],
        ),
        child: Text(
          selectedName ?? 'Выберите упражнение',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selectedName == null ? Colors.grey : (!enabled ? Colors.black54 : null),
          ),
        ),
      ),
    );
  }
}

// Модальное окно с поиском упражнений
class _ExercisePickerSheet extends StatefulWidget {
  final List<Exercise> exercises;
  const _ExercisePickerSheet({required this.exercises});

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.exercises.where((e) =>
        e.name.toLowerCase().contains(_query.toLowerCase())).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Выберите упражнение',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Поиск упражнения...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('Ничего не найдено',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final ex = filtered[i];
                        return ListTile(
                          title: Text(ex.name),
                          subtitle: ex.description != null && ex.description!.isNotEmpty
                              ? Text(ex.description!,
                                  maxLines: 1, overflow: TextOverflow.ellipsis)
                              : null,
                          trailing: ex.weightType == 'BODYWEIGHT'
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1976D2).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Без веса',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF1976D2))),
                                )
                              : ex.weightType == 'MACHINE'
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text('Тренажёр',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.orange)),
                                    )
                                  : null,
                          onTap: () => Navigator.pop(context, ex.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetsRepsRow extends StatelessWidget {
  final int sets;
  final int reps;
  final ValueChanged<int> onSetsChanged;
  final ValueChanged<int> onRepsChanged;
  final String? label;
  final bool showReps;
  final bool enabled;

  const _SetsRepsRow({
    required this.sets,
    required this.reps,
    required this.onSetsChanged,
    required this.onRepsChanged,
    this.label,
    this.showReps = true,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
        ],
        Row(
          children: [
            Expanded(child: _NumField(
              label: 'Подходы',
              value: sets.toString(),
              enabled: enabled,
              onChanged: (v) => onSetsChanged(int.tryParse(v) ?? 3),
            )),
            if (showReps) ...[
              const SizedBox(width: 8),
              Expanded(child: _NumField(
                label: 'Повторы',
                value: reps.toString(),
                enabled: enabled,
                onChanged: (v) => onRepsChanged(int.tryParse(v) ?? 10),
              )),
            ],
          ],
        ),
      ],
    );
  }
}

class _RepsSection extends StatelessWidget {
  final _ExRow row;
  final VoidCallback onToggle;
  final bool readOnly;

  const _RepsSection({required this.row, required this.onToggle, this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Повторения', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const Spacer(),
            GestureDetector(
              onTap: readOnly ? null : onToggle,
              child: Row(
                children: [
                  Text(
                    row.useSetReps ? 'По подходам' : 'Одинаковые',
                    style: TextStyle(
                      fontSize: 12,
                      color: readOnly
                          ? Colors.grey
                          : (row.useSetReps ? const Color(0xFF8B0000) : Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    row.useSetReps ? Icons.toggle_on : Icons.toggle_off,
                    color: readOnly
                        ? Colors.grey[400]
                        : (row.useSetReps ? const Color(0xFF8B0000) : Colors.grey),
                    size: 28,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (row.useSetReps) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(row.sets, (i) => SizedBox(
              width: 80,
              child: TextFormField(
                controller: row.setRepControllers[i],
                keyboardType: TextInputType.number,
                readOnly: readOnly,
                decoration: InputDecoration(
                  labelText: '${i + 1} подх.',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixText: 'повт',
                  filled: readOnly,
                  fillColor: readOnly ? Colors.grey[100] : null,
                ),
              ),
            )),
          ),
        ],
      ],
    );
  }
}

class _WeightSection extends StatelessWidget {
  final _ExRow row;
  final VoidCallback onToggle;
  final ValueChanged<double?> onWeightChanged;
  final bool readOnly;

  const _WeightSection({
    required this.row,
    required this.onToggle,
    required this.onWeightChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    // Для упражнений без веса — показать метку
    if (row.weightType == 'BODYWEIGHT') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1976D2).withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1976D2).withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.accessibility_new, size: 16, color: Color(0xFF1976D2)),
            SizedBox(width: 8),
            Text(
              'Упражнение без веса (масса тела)',
              style: TextStyle(color: Color(0xFF1976D2), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Переключатель
        Row(
          children: [
            Text(
              row.weightType == 'MACHINE' ? 'Количество плит' : 'Вес',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const Spacer(),
            GestureDetector(
              onTap: readOnly ? null : onToggle,
              child: Row(
                children: [
                  Text(
                    row.useSetWeights ? 'По подходам' : 'Общий',
                    style: TextStyle(
                        fontSize: 12,
                        color: readOnly
                            ? Colors.grey
                            : (row.useSetWeights ? const Color(0xFF8B0000) : Colors.grey)),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    row.useSetWeights ? Icons.toggle_on : Icons.toggle_off,
                    color: readOnly
                        ? Colors.grey[400]
                        : (row.useSetWeights ? const Color(0xFF8B0000) : Colors.grey),
                    size: 28,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        if (!row.useSetWeights)
          _NumField(
            label: row.weightType == 'MACHINE' ? 'Кол-во плит' : 'Вес (кг)',
            value: row.weight?.toString() ?? '',
            enabled: !readOnly,
            onChanged: (v) => onWeightChanged(double.tryParse(v)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(row.sets, (i) => SizedBox(
              width: 80,
              child: TextFormField(
                controller: row.setWeightControllers[i],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                readOnly: readOnly,
                decoration: InputDecoration(
                  labelText: '${i + 1} подх.',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixText: row.weightType == 'MACHINE' ? 'пл.' : 'кг',
                  filled: readOnly,
                  fillColor: readOnly ? Colors.grey[100] : null,
                ),
              ),
            )),
          ),
      ],
    );
  }
}

class _NumField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  const _NumField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        filled: !enabled,
        fillColor: !enabled ? Colors.grey[100] : null,
      ),
      onChanged: onChanged,
    );
  }
}
