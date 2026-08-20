// lib/features/trainer/exercises/global_exercises_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/models.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/exercise_thumbnail.dart';

const _kCategories = ['силовые', 'растяжка', 'кардио', 'плиометрика'];
const _kEquipment = ['штанга', 'гантели', 'собственный вес', 'тренажёр'];
const _kLevels = ['beginner', 'intermediate', 'advanced'];

const _kLevelLabels = {
  'beginner': 'Начальный',
  'intermediate': 'Средний',
  'advanced': 'Продвинутый',
};

class GlobalExercisesScreen extends StatefulWidget {
  const GlobalExercisesScreen({super.key});

  @override
  State<GlobalExercisesScreen> createState() => _GlobalExercisesScreenState();
}

class _GlobalExercisesScreenState extends State<GlobalExercisesScreen> {
  List<GlobalExercise> _all = [];
  bool _loading = true;
  bool _importing = false;

  String? _category;
  String? _equipment;
  String? _level;
  final _searchCtrl = TextEditingController();

  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AuthProvider>().api;
      final data = await api.fetchGlobalExercises();
      setState(() => _all = data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<GlobalExercise> get _filtered {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _all.where((e) {
      if (_category != null && e.category != _category) return false;
      if (_equipment != null && e.equipment != _equipment) return false;
      if (_level != null && e.level != _level) return false;
      if (query.isNotEmpty && !e.displayName.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _importSelected() async {
    if (_selected.isEmpty) return;
    setState(() => _importing = true);
    try {
      final api = context.read<AuthProvider>().api;
      final result = await api.importGlobalExercises(ids: _selected.toList());
      setState(() => _selected.clear());
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Добавлено: ${result.imported}, пропущено: ${result.skipped}'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка импорта')));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _importAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Добавить весь справочник?'),
        content: Text('Будет импортировано до ${_all.length} упражнений. '
            'Упражнения, которые у вас уже есть под тем же названием, будут пропущены.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Добавить')),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    setState(() => _importing = true);
    try {
      final api = context.read<AuthProvider>().api;
      final result = await api.importGlobalExercises();
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Добавлено: ${result.imported}, пропущено: ${result.skipped}'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка импорта')));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return AppScaffold(
      title: 'Справочник упражнений',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Поиск',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _searchCtrl.clear()),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _FilterDropdown(
                        hint: 'Категория',
                        value: _category,
                        options: _kCategories,
                        labelBuilder: (v) => v,
                        onChanged: (v) => setState(() => _category = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FilterDropdown(
                        hint: 'Оборудование',
                        value: _equipment,
                        options: _kEquipment,
                        labelBuilder: (v) => v,
                        onChanged: (v) => setState(() => _equipment = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FilterDropdown(
                        hint: 'Уровень',
                        value: _level,
                        options: _kLevels,
                        labelBuilder: (v) => _kLevelLabels[v] ?? v,
                        onChanged: (v) => setState(() => _level = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Найдено: ${filtered.length}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _importing ? null : _importAll,
                  icon: const Icon(Icons.library_add),
                  label: const Text('Добавить весь справочник'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off, message: 'Ничего не найдено')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final ex = filtered[i];
                          final selected = _selected.contains(ex.id);
                          return Card(
                            child: CheckboxListTile(
                              value: selected,
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _selected.add(ex.id);
                                } else {
                                  _selected.remove(ex.id);
                                }
                              }),
                              secondary: ExerciseThumbnail(imageUrl: ex.imageUrl),
                              title: Text(ex.displayName,
                                  style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text(
                                [
                                  if (ex.category != null) ex.category!,
                                  if (ex.equipment != null) ex.equipment!,
                                  if (ex.level != null)
                                    _kLevelLabels[ex.level] ?? ex.level!,
                                ].join(' · '),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: _selected.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _importing ? null : _importSelected,
              icon: _importing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add),
              label: Text('Добавить выбранные (${_selected.length})'),
            ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> options;
  final String Function(String) labelBuilder;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.hint,
    required this.value,
    required this.options,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: hint,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      style: const TextStyle(fontSize: 12, color: Colors.black),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Все')),
        ...options.map((o) => DropdownMenuItem<String?>(
              value: o,
              child: Text(labelBuilder(o), overflow: TextOverflow.ellipsis),
            )),
      ],
      onChanged: onChanged,
    );
  }
}
