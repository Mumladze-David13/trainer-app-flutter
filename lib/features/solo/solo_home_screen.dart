// lib/features/solo/solo_home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/models/models.dart';
import '../../core/services/auth_provider.dart';
import '../../core/widgets/app_scaffold.dart';
import '../client/workout/client_workout_screen.dart';
import '../trainer/workout/workout_editor_screen.dart';
import 'solo_generate_program_screen.dart';

// Главный SOLO-экран: список сезонов/занятий (GET /solo/seasons), плюс
// создание сезона/занятия вручную или запуск AI-генерации. SOLO работает
// через обычные тренерские/клиентские эндпоинты сезонов и занятий с
// clientId = собственный userId (self-relation на бэке) — см.
// flutter-prompt-solo-mode-20260824.md.
class SoloHomeScreen extends StatefulWidget {
  const SoloHomeScreen({super.key});

  @override
  State<SoloHomeScreen> createState() => _SoloHomeScreenState();
}

class _SoloHomeScreenState extends State<SoloHomeScreen> {
  List<Season> _seasons = [];
  bool _loading = true;
  bool _showSeasonForm = false;
  bool _savingSeason = false;
  DateTime _startDate = DateTime.now();
  final _fmt = DateFormat('EEEE, dd.MM.yyyy', 'ru_RU');
  final _fmtShort = DateFormat('dd.MM.yyyy');

  String get _myId => context.read<AuthProvider>().user!.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = context.read<AuthProvider>().api;
    try {
      final seasons = await api.getSoloSeasons();
      if (mounted) setState(() => _seasons = seasons);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ошибка загрузки тренировок')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createSeason() async {
    setState(() => _savingSeason = true);
    final api = context.read<AuthProvider>().api;
    try {
      await api.createSeason(_myId, _startDate.toIso8601String(), null);
      setState(() => _showSeasonForm = false);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сезон создан')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка')));
      }
    } finally {
      if (mounted) setState(() => _savingSeason = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (d != null) setState(() => _startDate = d);
  }

  Future<void> _openAiGenerate() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SoloGenerateProgramScreen()),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Мои тренировки',
      isDashboard: true,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_showSeasonForm) _buildSeasonForm(),
                  Row(
                    children: [
                      const Text('Сезоны',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _openAiGenerate,
                        icon: const Icon(Icons.smart_toy, size: 18, color: Colors.white),
                        label: const Text('AI', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B0000), minimumSize: const Size(0, 36)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _showSeasonForm = !_showSeasonForm),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Сезон'),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(0, 36)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_seasons.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(children: [
                          const Icon(Icons.event_note, size: 64, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('Нет тренировок',
                              style: TextStyle(color: Colors.grey, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('Сгенерируйте программу с AI или создайте сезон вручную',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600])),
                        ]),
                      ),
                    )
                  else
                    ..._seasons.asMap().entries.map((entry) => _SoloSeasonCard(
                          season: entry.value,
                          myId: _myId,
                          isExpanded: entry.key == 0,
                          fmt: _fmt,
                          fmtShort: _fmtShort,
                          onReload: _load,
                        )),
                ],
              ),
            ),
    );
  }

  Widget _buildSeasonForm() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('Новый сезон', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _showSeasonForm = false)),
            ]),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Дата начала',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(_fmtShort.format(_startDate)),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                onPressed: () => setState(() => _showSeasonForm = false),
                child: const Text('Отмена'),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: ElevatedButton(
                onPressed: _savingSeason ? null : _createSeason,
                child: _savingSeason
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Создать'),
              )),
            ]),
          ],
        ),
      ),
    );
  }
}

class _SoloSeasonCard extends StatefulWidget {
  final Season season;
  final String myId;
  final bool isExpanded;
  final DateFormat fmt;
  final DateFormat fmtShort;
  final VoidCallback onReload;

  const _SoloSeasonCard({
    required this.season,
    required this.myId,
    required this.isExpanded,
    required this.fmt,
    required this.fmtShort,
    required this.onReload,
  });

  @override
  State<_SoloSeasonCard> createState() => _SoloSeasonCardState();
}

class _SoloSeasonCardState extends State<_SoloSeasonCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isExpanded;
  }

  Future<void> _deleteSeason() async {
    final s = widget.season;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить сезон?'),
        content: Text(
            'Удалить "${s.name}" вместе со всеми занятиями (${s.workouts.length})? '
            'Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final api = context.read<AuthProvider>().api;
    try {
      await api.deleteSeason(widget.myId, s.id);
      widget.onReload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Не удалось удалить сезон')));
      }
    }
  }

  Future<void> _deleteWorkout(Workout w) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить занятие?'),
        content:
            Text('Удалить занятие от ${widget.fmt.format(w.date)}? Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final api = context.read<AuthProvider>().api;
    try {
      await api.deleteWorkout(w.id);
      widget.onReload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Не удалось удалить занятие')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.season;
    final completed = s.completedCount;
    final total = s.workouts.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.event_note, color: Color(0xFF8B0000)),
            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text('${widget.fmtShort.format(s.startDate)} · $completed/$total выполнено'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    tooltip: 'Удалить сезон',
                    onPressed: _deleteSeason),
                IconButton(
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                const Text('Занятия', style: TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) =>
                              WorkoutEditorScreen(clientId: widget.myId, seasonId: s.id)),
                    );
                    if (result == true) widget.onReload();
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Добавить'),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 32)),
                ),
              ]),
            ),
            if (s.workouts.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Нет занятий', style: TextStyle(color: Colors.grey)))
            else
              ...(() {
                final sorted = List.of(s.workouts)..sort((a, b) => b.date.compareTo(a.date));
                return sorted.map((w) {
                  final donePercent =
                      w.totalCount > 0 ? (w.doneCount / w.totalCount * 100).round() : 0;
                  return ListTile(
                    leading: w.isCompleted
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                    title: Text(widget.fmt.format(w.date), style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                        '${w.totalCount} упр.${!w.isCompleted && donePercent > 0 ? " · $donePercent% выполнено" : ""}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!w.isCompleted)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: 'Редактировать',
                            onPressed: () async {
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => WorkoutEditorScreen(
                                        clientId: widget.myId, workoutId: w.id)),
                              );
                              if (result == true) widget.onReload();
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          tooltip: 'Удалить занятие',
                          onPressed: () => _deleteWorkout(w),
                        ),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ClientWorkoutScreen(workoutId: w.id)),
                      );
                      widget.onReload();
                    },
                  );
                });
              })(),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
