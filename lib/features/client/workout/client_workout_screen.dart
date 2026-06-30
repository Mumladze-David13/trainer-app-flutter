// lib/features/client/workout/client_workout_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/models/models.dart';
import '../../../core/services/auth_provider.dart';

class ClientWorkoutScreen extends StatefulWidget {
  final String workoutId;
  const ClientWorkoutScreen({super.key, required this.workoutId});

  @override
  State<ClientWorkoutScreen> createState() => _ClientWorkoutScreenState();
}

class _ClientWorkoutScreenState extends State<ClientWorkoutScreen> {
  Workout? _workout;
  bool _loading = true;
  bool _saving = false;
  Set<String> _doneIds = {};
  final _fmt = DateFormat('EEEE, dd MMMM yyyy', 'ru_RU');

  int get _total => _workout?.workoutExercises.length ?? 0;
  int get _doneCount => _doneIds.length;
  double get _donePercent => _total > 0 ? _doneCount / _total : 0;
  bool get _canComplete => _donePercent >= 0.5;
  int get _needMore => (_total * 0.5).ceil() - _doneCount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<AuthProvider>().api;
    final w = await api.getWorkout(widget.workoutId);
    setState(() {
      _workout = w;
      _doneIds = w.workoutExercises.where((e) => e.isDone).map((e) => e.id).toSet();
      _loading = false;
    });
  }

  Future<void> _saveAndClose() async {
    setState(() => _saving = true);
    final api = context.read<AuthProvider>().api;
    try {
      await api.saveProgress(widget.workoutId, _doneIds.toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Прогресс сохранён')));
        Navigator.of(context).pop();
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

  Future<void> _complete() async {
    if (!_canComplete) return;
    setState(() => _saving = true);
    final api = context.read<AuthProvider>().api;
    try {
      final w = await api.completeWorkout(widget.workoutId, _doneIds.toList());
      setState(() => _workout = w);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🎉 Занятие выполнено!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Занятие'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Header
                      Row(
                        children: [
                          Expanded(child: Text(
                            _fmt.format(_workout!.date),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w500),
                          )),
                          if (_workout!.isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.green),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                                  SizedBox(width: 4),
                                  Text('Выполнено',
                                      style: TextStyle(color: Colors.green, fontSize: 13)),
                                ],
                              ),
                            ),
                        ],
                      ),

                      if (_workout!.notes != null && _workout!.notes!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8)),
                          child: Row(children: [
                            const Icon(Icons.notes, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_workout!.notes!,
                                style: const TextStyle(fontSize: 13))),
                          ]),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Progress
                      Row(
                        children: [
                          const Text('Прогресс',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          const Spacer(),
                          Text(
                            '$_doneCount/$_total (${(_donePercent * 100).round()}%)',
                            style: TextStyle(
                              color: _canComplete ? Colors.green : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _donePercent,
                          minHeight: 8,
                          backgroundColor: Colors.grey[200],
                          color: _canComplete ? Colors.green : const Color(0xFF8B0000),
                        ),
                      ),
                      if (_canComplete && !_workout!.isCompleted) ...[
                        const SizedBox(height: 6),
                        const Row(children: [
                          Icon(Icons.star, color: Colors.orange, size: 16),
                          SizedBox(width: 4),
                          Text('Можно завершить занятие!',
                              style: TextStyle(color: Colors.orange, fontSize: 13)),
                        ]),
                      ] else if (!_workout!.isCompleted && _total > 0 && _doneCount > 0) ...[
                        const SizedBox(height: 4),
                        Text('Ещё $_needMore упр. для завершения',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],

                      const SizedBox(height: 16),

                      // Exercise list — с поддержкой супер-сетов
                      ..._buildExerciseList(),

                      if (_workout!.isCompleted) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.celebration, color: Colors.orange),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text('Занятие завершено! Отличная работа!',
                                    style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w500)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Назад'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Bottom actions
                if (!_workout!.isCompleted)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8, offset: const Offset(0, -2),
                      )],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving ? null : _saveAndClose,
                            child: const Text('Сохранить и закрыть'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: !_canComplete || _saving ? null : _complete,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green),
                            icon: _saving
                                ? const SizedBox(width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.emoji_events, size: 18),
                            label: const Text('Занятие выполнено!'),
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
    final exercises = _workout!.workoutExercises;
    final processed = <int>{};

    for (int i = 0; i < exercises.length; i++) {
      if (processed.contains(i)) continue;
      final ex = exercises[i];

      if (ex.supersetGroup != null) {
        // Супер-сет
        final groupItems = exercises.asMap().entries
            .where((e) => e.value.supersetGroup == ex.supersetGroup)
            .toList();
        processed.addAll(groupItems.map((e) => e.key));
        widgets.add(_buildSupersetCard(groupItems.map((e) => e.value).toList()));
      } else {
        widgets.add(_buildExerciseCard(ex, i));
      }
    }
    return widgets;
  }

  Widget _buildExerciseCard(WorkoutExercise we, int globalIndex) {
    final isDone = _doneIds.contains(we.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDone ? Colors.green[50] : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: isDone,
              onChanged: _workout!.isCompleted ? null : (v) {
                setState(() {
                  if (v == true) { _doneIds.add(we.id); }
                  else { _doneIds.remove(we.id); }
                });
              },
              activeColor: Colors.green,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${globalIndex + 1}. ${we.exercise.name}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone ? Colors.grey : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (we.hasSetWeights || we.hasSetReps)
                    _buildSetDetails(we)
                  else
                    Text(
                      '${we.exercise.weightType != 'BODYWEIGHT' && we.weight != null ? "${we.weight} кг · " : ""}${we.sets} подх. × ${we.reps} повт.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
            if (isDone)
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSetDetails(WorkoutExercise we) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: List.generate(we.sets, (i) {
        final w = we.weightForSet(i);
        final r = we.repsForSet(i);
        final label = w != null ? '${i + 1}: $rп × $wкг' : '${i + 1}: $r повт.';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red[200]!),
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8B0000))),
        );
      }),
    );
  }

  Widget _buildSupersetCard(List<WorkoutExercise> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Transform.scale(
                  scale: 0.85,
                  child: Checkbox(
                    value: items.every((e) => _doneIds.contains(e.id)),
                    tristate: false,
                    onChanged: _workout!.isCompleted ? null : (v) {
                      setState(() {
                        if (v == true) {
                          for (final e in items) _doneIds.add(e.id);
                        } else {
                          for (final e in items) _doneIds.remove(e.id);
                        }
                      });
                    },
                    activeColor: Colors.green,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.link, color: Colors.orange, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Супер-сет · ${items.first.sets} подх. × ${items.first.reps} повт.',
                    style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          ...items.asMap().entries.map((entry) {
            final i = entry.key;
            final we = entry.value;
            final isDone = _doneIds.contains(we.id);
            return Column(
              children: [
                if (i > 0) const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: isDone,
                        onChanged: _workout!.isCompleted ? null : (v) {
                          setState(() {
                            if (v == true) { _doneIds.add(we.id); }
                            else { _doneIds.remove(we.id); }
                          });
                        },
                        activeColor: Colors.green,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${i + 1}. ${we.exercise.name}',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                                color: isDone ? Colors.grey : null,
                              ),
                            ),
                            if (we.hasSetWeights || we.hasSetReps) ...[
                              const SizedBox(height: 4),
                              _buildSetDetails(we),
                            ] else if (we.exercise.weightType != 'BODYWEIGHT' && we.weight != null)
                              Text('${we.weight} кг',
                                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      if (isDone)
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
