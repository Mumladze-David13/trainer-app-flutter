// lib/features/client/sessions/client_sessions_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/models/models.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/widgets/app_scaffold.dart';

class ClientSessionsScreen extends StatefulWidget {
  const ClientSessionsScreen({super.key});

  @override
  State<ClientSessionsScreen> createState() => _ClientSessionsScreenState();
}

class _ClientSessionsScreenState extends State<ClientSessionsScreen> {
  List<ClientSession> _sessions = [];
  bool _loading = true;
  final _dateFmt = DateFormat('dd.MM.yyyy', 'ru_RU');
  final _dtFmt = DateFormat('dd MMMM yyyy', 'ru_RU');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = context.read<AuthProvider>().api;
    try {
      final sessions = await api.getClientSessions();
      if (mounted) {
        setState(() {
          _sessions = sessions
            ..sort((a, b) => b.date.compareTo(a.date));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка загрузки занятий')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(ClientSession session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить занятие?'),
        content: Text('Удалить занятие от ${_dateFmt.format(session.date)}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    final api = context.read<AuthProvider>().api;
    try {
      await api.deleteClientSession(session.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка удаления')));
      }
    }
  }

  void _openCreate() async {
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => const _SessionFormScreen(),
    ));
    if (result == true) _load();
  }

  void _openEdit(ClientSession session) async {
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _SessionFormScreen(session: session),
    ));
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Мои тренировки',
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _sessions.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.self_improvement,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('Нет самостоятельных занятий',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey)),
                          SizedBox(height: 4),
                          Text('Нажмите + чтобы добавить',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sessions.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final s = _sessions[i];
                        return _SessionCard(
                          session: s,
                          dateFmt: _dtFmt,
                          onEdit: () => _openEdit(s),
                          onDelete: () => _delete(s),
                        );
                      },
                    ),
            ),
    );
  }
}

// ─── Session Card ─────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final ClientSession session;
  final DateFormat dateFmt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SessionCard({
    required this.session,
    required this.dateFmt,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF2E7D32).withOpacity(0.1),
              child: const Icon(Icons.self_improvement,
                  color: Color(0xFF2E7D32), size: 20),
            ),
            title: Text(dateFmt.format(session.date),
                style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
                '${session.exercises.length} ${_exWord(session.exercises.length)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: Color(0xFF1976D2), size: 20),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
          if (session.notes != null && session.notes!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(session.notes!,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.grey)),
              ),
            ),
          ],
          if (session.exercises.isNotEmpty) ...[
            const Divider(height: 1),
            ...session.exercises.map((ex) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.fitness_center,
                      size: 16, color: Colors.grey),
                  title: Text(ex.displayName),
                  subtitle: Text(_exDetails(ex),
                      style: const TextStyle(fontSize: 12)),
                )),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  String _exWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'активность';
    if (count % 10 >= 2 &&
        count % 10 <= 4 &&
        (count % 100 < 10 || count % 100 >= 20)) return 'активности';
    return 'активностей';
  }

  String _exDetails(ClientSessionExercise ex) {
    final parts = <String>[];
    if (ex.sets != null && ex.reps != null) {
      parts.add('${ex.sets} × ${ex.reps}');
    } else if (ex.sets != null) {
      parts.add('${ex.sets} подх.');
    }
    if (ex.durationMinutes != null) {
      parts.add('${ex.durationMinutes} мин');
    }
    return parts.join(' · ');
  }
}

// ─── Session Form Screen ──────────────────────────────────────────────────────

class _ActivityRow {
  // true = from trainer's exercise library (exerciseId)
  // false = from client's personal activities (clientActivityId)
  bool fromLibrary = true;
  String? exerciseId;
  String? clientActivityId;
  final setsCtrl = TextEditingController();
  final repsCtrl = TextEditingController();
  final durationCtrl = TextEditingController();

  _ActivityRow();

  _ActivityRow.fromExisting(ClientSessionExercise ex) {
    fromLibrary = ex.exerciseId != null;
    exerciseId = ex.exerciseId;
    clientActivityId = ex.clientActivityId;
    setsCtrl.text = ex.sets?.toString() ?? '';
    repsCtrl.text = ex.reps?.toString() ?? '';
    durationCtrl.text = ex.durationMinutes?.toString() ?? '';
  }

  void dispose() {
    setsCtrl.dispose();
    repsCtrl.dispose();
    durationCtrl.dispose();
  }

  Map<String, dynamic> toMap(int order) {
    final Map<String, dynamic> data = {'order': order};
    if (fromLibrary && exerciseId != null) {
      data['exerciseId'] = exerciseId;
    } else if (!fromLibrary && clientActivityId != null) {
      data['clientActivityId'] = clientActivityId;
    }
    final sets = int.tryParse(setsCtrl.text.trim());
    final reps = int.tryParse(repsCtrl.text.trim());
    final dur = double.tryParse(durationCtrl.text.trim());
    if (sets != null) data['sets'] = sets;
    if (reps != null) data['reps'] = reps;
    if (dur != null) data['durationMinutes'] = dur;
    return data;
  }
}

class _SessionFormScreen extends StatefulWidget {
  final ClientSession? session;

  const _SessionFormScreen({this.session});

  @override
  State<_SessionFormScreen> createState() => _SessionFormScreenState();
}

class _SessionFormScreenState extends State<_SessionFormScreen> {
  final _notesCtrl = TextEditingController();
  final List<_ActivityRow> _activities = [];
  List<Exercise> _exercises = [];
  List<ClientActivity> _clientActivities = [];
  bool _loadingExercises = true;
  bool _loadingActivities = true;
  bool _saving = false;

  bool get isEdit => widget.session != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _notesCtrl.text = widget.session!.notes ?? '';
      for (final ex in widget.session!.exercises) {
        _activities.add(_ActivityRow.fromExisting(ex));
      }
    } else {
      _activities.add(_ActivityRow());
    }
    _loadExercises();
    _loadClientActivities();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (final a in _activities) {
      a.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExercises() async {
    final api = context.read<AuthProvider>().api;
    try {
      final exs = await api.getExercises();
      if (mounted) setState(() => _exercises = exs);
    } catch (_) {}
    if (mounted) setState(() => _loadingExercises = false);
  }

  Future<void> _loadClientActivities() async {
    final api = context.read<AuthProvider>().api;
    try {
      final acts = await api.getClientActivities();
      if (mounted) setState(() => _clientActivities = acts);
    } catch (_) {}
    if (mounted) setState(() => _loadingActivities = false);
  }

  Future<void> _save() async {
    if (_activities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Добавьте хотя бы одну активность')));
      return;
    }
    setState(() => _saving = true);
    final api = context.read<AuthProvider>().api;
    final exercises = _activities
        .asMap()
        .entries
        .map((e) => e.value.toMap(e.key))
        .toList();
    try {
      if (isEdit) {
        await api.updateClientSession(
          widget.session!.id,
          notes: _notesCtrl.text.trim().isNotEmpty
              ? _notesCtrl.text.trim()
              : null,
          exercises: exercises,
        );
      } else {
        await api.createClientSession(
          notes: _notesCtrl.text.trim().isNotEmpty
              ? _notesCtrl.text.trim()
              : null,
          exercises: exercises,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEdit ? 'Занятие обновлено' : 'Занятие создано')));
        Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Редактировать занятие' : 'Новое занятие'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Сохранить',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Заметка (необязательно)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Активности',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _activities.add(_ActivityRow())),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Добавить'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...(_activities.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value;
            return _ActivityRowCard(
              row: row,
              index: i,
              exercises: _exercises,
              clientActivities: _clientActivities,
              loadingExercises: _loadingExercises,
              loadingActivities: _loadingActivities,
              onDelete: _activities.length > 1
                  ? () => setState(() {
                        row.dispose();
                        _activities.removeAt(i);
                      })
                  : null,
              onChanged: () => setState(() {}),
            );
          })),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _ActivityRowCard extends StatelessWidget {
  final _ActivityRow row;
  final int index;
  final List<Exercise> exercises;
  final List<ClientActivity> clientActivities;
  final bool loadingExercises;
  final bool loadingActivities;
  final VoidCallback? onDelete;
  final VoidCallback onChanged;

  const _ActivityRowCard({
    required this.row,
    required this.index,
    required this.exercises,
    required this.clientActivities,
    required this.loadingExercises,
    required this.loadingActivities,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF2E7D32),
                  child: Text('${index + 1}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11)),
                ),
                const SizedBox(width: 8),
                const Text('Активность',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 20),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Тип активности
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false,
                    label: Text('Мой справочник'),
                    icon: Icon(Icons.directions_run, size: 14)),
                ButtonSegment(
                    value: true,
                    label: Text('Библиотека тренера'),
                    icon: Icon(Icons.fitness_center, size: 14)),
              ],
              selected: {row.fromLibrary},
              onSelectionChanged: (s) {
                row.fromLibrary = s.first;
                onChanged();
              },
            ),
            const SizedBox(height: 10),
            if (row.fromLibrary) ...[
              loadingExercises
                  ? const LinearProgressIndicator()
                  : _ExercisePicker(
                      exerciseId: row.exerciseId,
                      exercises: exercises,
                      onChanged: (id) {
                        row.exerciseId = id;
                        onChanged();
                      },
                    ),
            ] else ...[
              loadingActivities
                  ? const LinearProgressIndicator()
                  : _ClientActivityPicker(
                      activityId: row.clientActivityId,
                      activities: clientActivities,
                      onChanged: (id) {
                        row.clientActivityId = id;
                        onChanged();
                      },
                    ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.setsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Подходы',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: row.repsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Повторения',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: row.durationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Мин.',
                      border: OutlineInputBorder(),
                      isDense: true,
                      suffixText: 'мин',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExercisePicker extends StatelessWidget {
  final String? exerciseId;
  final List<Exercise> exercises;
  final ValueChanged<String?> onChanged;

  const _ExercisePicker({
    required this.exerciseId,
    required this.exercises,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected =
        exercises.where((e) => e.id == exerciseId).toList();
    final name =
        selected.isNotEmpty ? selected.first.name : null;

    return InkWell(
      onTap: () async {
        final id = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(16))),
          builder: (_) => _ExPickerSheet(exercises: exercises),
        );
        if (id != null) onChanged(id);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Упражнение',
          border: OutlineInputBorder(),
          isDense: true,
          suffixIcon: Icon(Icons.search),
        ),
        child: Text(
          name ?? 'Выберите упражнение',
          style: TextStyle(color: name == null ? Colors.grey : null),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _ExPickerSheet extends StatefulWidget {
  final List<Exercise> exercises;
  const _ExPickerSheet({required this.exercises});

  @override
  State<_ExPickerSheet> createState() => _ExPickerSheetState();
}

class _ExPickerSheetState extends State<_ExPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.exercises
        .where((e) =>
            e.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, sc) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            const Text('Выберите упражнение',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Поиск...',
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
                      controller: sc,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final ex = filtered[i];
                        return ListTile(
                          title: Text(ex.name),
                          onTap: () =>
                              Navigator.pop(context, ex.id),
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

// ─── Client Activity Picker ───────────────────────────────────────────────────

class _ClientActivityPicker extends StatelessWidget {
  final String? activityId;
  final List<ClientActivity> activities;
  final ValueChanged<String?> onChanged;

  const _ClientActivityPicker({
    required this.activityId,
    required this.activities,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = activities.where((a) => a.id == activityId).toList();
    final name = selected.isNotEmpty ? selected.first.name : null;

    return InkWell(
      onTap: () async {
        final id = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(16))),
          builder: (_) => _ClientActivityPickerSheet(activities: activities),
        );
        if (id != null) onChanged(id);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Моя активность',
          border: OutlineInputBorder(),
          isDense: true,
          suffixIcon: Icon(Icons.search),
        ),
        child: Text(
          name ?? 'Выберите активность',
          style: TextStyle(color: name == null ? Colors.grey : null),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _ClientActivityPickerSheet extends StatefulWidget {
  final List<ClientActivity> activities;
  const _ClientActivityPickerSheet({required this.activities});

  @override
  State<_ClientActivityPickerSheet> createState() =>
      _ClientActivityPickerSheetState();
}

class _ClientActivityPickerSheetState
    extends State<_ClientActivityPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.activities
        .where((a) => a.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, sc) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            const Text('Выберите активность',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Поиск...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Ничего не найдено',
                              style: TextStyle(color: Colors.grey)),
                          if (widget.activities.isEmpty) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Добавьте активности в раздел "Мои активности"',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: sc,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final act = filtered[i];
                        return ListTile(
                          leading: const Icon(Icons.directions_run,
                              color: Color(0xFF6A1B9A), size: 20),
                          title: Text(act.name),
                          subtitle: act.metValue != null
                              ? Text('MET: ${act.metValue}',
                                  style: const TextStyle(fontSize: 12))
                              : null,
                          onTap: () =>
                              Navigator.pop(context, act.id),
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
