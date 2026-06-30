// lib/features/client/reports/client_reports_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/models/models.dart';
import '../../../core/services/auth_provider.dart';
import '../weight_log/weight_log_screen.dart';
import '../progress/exercise_progress_screen.dart';

class ClientReportsScreen extends StatelessWidget {
  const ClientReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои отчёты'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ReportCard(
            icon: Icons.monitor_weight,
            color: const Color(0xFF1976D2),
            title: 'Анализ веса тела',
            subtitle: 'Динамика веса и AI-анализ',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const WeightLogScreen(),
            )),
          ),
          const SizedBox(height: 12),
          _ReportCard(
            icon: Icons.trending_up,
            color: const Color(0xFF8B0000),
            title: 'Прогрессия упражнений',
            subtitle: 'Выберите упражнение для просмотра прогресса',
            onTap: () => _pickExercise(context),
          ),
          const SizedBox(height: 12),
          _ReportCard(
            icon: Icons.local_fire_department,
            color: const Color(0xFFBF360C),
            title: 'Сожжённые калории',
            subtitle: 'Калории за выбранный день',
            onTap: () => _pickDateAndShowCalories(context),
          ),
        ],
      ),
    );
  }

  void _pickExercise(BuildContext context) {
    final api = context.read<AuthProvider>().api;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _ExercisePickerSheet(
        loadExercises: () => api.getExercises(),
        onSelected: (exercise) {
          Navigator.of(ctx).pop();
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ExerciseProgressScreen(
              exerciseId: exercise.id,
              exerciseName: exercise.name,
            ),
          ));
        },
      ),
    );
  }

  void _pickDateAndShowCalories(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked == null || !context.mounted) return;

    final dateStr = DateFormat('yyyy-MM-dd').format(picked);
    final api = context.read<AuthProvider>().api;

    try {
      final result = await api.getBurnedCalories(dateStr);
      if (!context.mounted) return;
      _showCaloriesSheet(context, result, picked);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Нет данных за выбранный день')));
      }
    }
  }

  void _showCaloriesSheet(
      BuildContext context, BurnedCalories data, DateTime date) {
    final dateFmt = DateFormat('dd MMMM yyyy', 'ru_RU');
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Icon(Icons.local_fire_department,
                color: Color(0xFFBF360C), size: 48),
            const SizedBox(height: 12),
            Text(dateFmt.format(date),
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
              '${data.burnedCalories.toStringAsFixed(0)} ккал',
              style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFBF360C)),
            ),
            const SizedBox(height: 4),
            const Text('сожжено за день',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Report Card ──────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ReportCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          radius: 24,
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// ─── Exercise Picker Sheet ────────────────────────────────────────────────────

class _ExercisePickerSheet extends StatefulWidget {
  final Future<List<Exercise>> Function() loadExercises;
  final ValueChanged<Exercise> onSelected;

  const _ExercisePickerSheet({
    required this.loadExercises,
    required this.onSelected,
  });

  @override
  State<_ExercisePickerSheet> createState() =>
      _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  List<Exercise> _exercises = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await widget.loadExercises();
    if (mounted) {
      setState(() {
        _exercises = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _exercises
        .where(
            (e) => e.name.toLowerCase().contains(_query.toLowerCase()))
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
              width: 40,
              height: 4,
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
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
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
                              subtitle: ex.description != null &&
                                      ex.description!.isNotEmpty
                                  ? Text(ex.description!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12))
                                  : null,
                              onTap: () => widget.onSelected(ex),
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
