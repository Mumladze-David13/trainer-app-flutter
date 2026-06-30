import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/models/nutrition_models.dart';
import '../../core/services/auth_provider.dart';
import 'food_search_sheet.dart';

class NutritionScreen extends StatefulWidget {
  final String clientId;
  final bool isTrainer;
  final bool embedded;

  const NutritionScreen({
    super.key,
    required this.clientId,
    this.isTrainer = false,
    this.embedded = false,
  });

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Widget> get _tabs => const [
    Tab(icon: Icon(Icons.person_outline), text: 'Профиль'),
    Tab(icon: Icon(Icons.menu_book_outlined), text: 'Дневник'),
  ];

  List<Widget> get _tabViews => [
    _ProfileTab(clientId: widget.clientId, isTrainer: widget.isTrainer),
    _DiaryTab(clientId: widget.clientId, isTrainer: widget.isTrainer),
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: _tabs,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabViews,
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Питание'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: _tabs,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabViews,
      ),
    );
  }
}

// ─── Profile Tab ────────────────────────────────────────────────────────────

class _ProfileTab extends StatefulWidget {
  final String clientId;
  final bool isTrainer;

  const _ProfileTab({required this.clientId, required this.isTrainer});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  NutritionProfileData? _data;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;

  String _gender = 'male';
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  String _activityLevel = 'moderate';
  String _goal = 'maintain';
  final _weeklyChangeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _weeklyChangeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = context.read<AuthProvider>().api;
    try {
      final data = await api.getNutritionProfile(widget.clientId);
      if (mounted) {
        setState(() {
          _data = data;
          _prefill(data.profile);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _data = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prefill(NutritionProfile p) {
    _gender = p.gender;
    _ageCtrl.text = p.age.toString();
    _weightCtrl.text = p.weightKg.toString();
    _heightCtrl.text = p.heightCm.toString();
    _activityLevel = p.activityLevel;
    _goal = p.goal;
    _weeklyChangeCtrl.text = p.targetWeeklyChange?.toString() ?? '';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final api = context.read<AuthProvider>().api;
    try {
      final weeklyChange = _weeklyChangeCtrl.text.trim().isNotEmpty
          ? double.tryParse(_weeklyChangeCtrl.text.replaceAll(',', '.'))
          : null;
      await api.saveNutritionProfile(widget.clientId, {
        'gender': _gender,
        'age': int.tryParse(_ageCtrl.text) ?? 25,
        'weightKg': double.tryParse(_weightCtrl.text.replaceAll(',', '.')) ?? 70.0,
        'heightCm': double.tryParse(_heightCtrl.text.replaceAll(',', '.')) ?? 170.0,
        'activityLevel': _activityLevel,
        'goal': _goal,
        if (weeklyChange != null) 'targetWeeklyChange': weeklyChange,
      });
      await _load();
      if (mounted) {
        setState(() => _editing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профиль питания сохранён')));
      }
    } catch (_) {
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
    if (_loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_data != null && !_editing) ...[
            _CalculationsCard(calculations: _data!.calculations),
            const SizedBox(height: 8),
            _ProfileInfoCard(profile: _data!.profile),
            const SizedBox(height: 16),
          ],
          if (widget.isTrainer) ...[
            if (!_editing)
              ElevatedButton.icon(
                onPressed: () => setState(() {
                  _editing = true;
                  if (_data != null) _prefill(_data!.profile);
                }),
                icon: const Icon(Icons.edit),
                label: Text(_data == null
                    ? 'Создать профиль питания'
                    : 'Редактировать профиль'),
              )
            else ...[
              _ProfileForm(
                gender: _gender,
                ageCtrl: _ageCtrl,
                weightCtrl: _weightCtrl,
                heightCtrl: _heightCtrl,
                activityLevel: _activityLevel,
                goal: _goal,
                weeklyChangeCtrl: _weeklyChangeCtrl,
                onGenderChanged: (v) => setState(() => _gender = v),
                onActivityChanged: (v) => setState(() => _activityLevel = v),
                onGoalChanged: (v) => setState(() => _goal = v),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => setState(() => _editing = false),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Сохранить'),
                  ),
                ),
              ]),
            ],
          ] else if (_data == null) ...[
            const SizedBox(height: 60),
            const Icon(Icons.no_meals, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Профиль питания не создан',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('Обратитесь к тренеру',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
          ],
        ],
      ),
    );
  }
}

// ─── Profile Sub-Widgets ─────────────────────────────────────────────────────

class _CalculationsCard extends StatelessWidget {
  final NutritionCalculations calculations;

  const _CalculationsCard({required this.calculations});

  @override
  Widget build(BuildContext context) {
    final c = calculations;
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Расчёты',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                _infoRow('Базовый обмен (BMR)', '${c.bmr.round()} ккал'),
                _infoRow('Суточная норма (TDEE)', '${c.tdee.round()} ккал'),
                _infoRow('Цель по калориям', '${c.targetCalories.round()} ккал'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Норма КБЖУ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                _MacroBar('Белки', 0, c.macros.protein, const Color(0xFF1565C0)),
                const SizedBox(height: 10),
                _MacroBar('Углеводы', 0, c.macros.carbs, const Color(0xFFF57F17)),
                const SizedBox(height: 10),
                _MacroBar('Жиры', 0, c.macros.fat, const Color(0xFF2E7D32)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  final NutritionProfile profile;

  const _ProfileInfoCard({required this.profile});

  static const _activityLabels = {
    'sedentary': 'Сидячий образ жизни',
    'light': 'Лёгкая активность',
    'moderate': 'Умеренная активность',
    'active': 'Высокая активность',
    'very_active': 'Очень высокая активность',
  };

  static const _goalLabels = {
    'lose_fat': 'Похудение',
    'maintain': 'Поддержание веса',
    'gain_muscle': 'Набор мышечной массы',
  };

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Параметры',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _infoRow('Пол', p.gender == 'male' ? 'Мужской' : 'Женский'),
            _infoRow('Возраст', '${p.age} лет'),
            _infoRow('Вес', '${p.weightKg} кг'),
            _infoRow('Рост', '${p.heightCm} см'),
            _infoRow('Активность',
                _activityLabels[p.activityLevel] ?? p.activityLevel),
            _infoRow('Цель', _goalLabels[p.goal] ?? p.goal),
            if (p.targetWeeklyChange != null)
              _infoRow('Изменение/нед.',
                  '${p.targetWeeklyChange! > 0 ? '+' : ''}${p.targetWeeklyChange} кг'),
          ],
        ),
      ),
    );
  }
}

class _ProfileForm extends StatelessWidget {
  final String gender;
  final TextEditingController ageCtrl;
  final TextEditingController weightCtrl;
  final TextEditingController heightCtrl;
  final String activityLevel;
  final String goal;
  final TextEditingController weeklyChangeCtrl;
  final ValueChanged<String> onGenderChanged;
  final ValueChanged<String> onActivityChanged;
  final ValueChanged<String> onGoalChanged;

  const _ProfileForm({
    required this.gender,
    required this.ageCtrl,
    required this.weightCtrl,
    required this.heightCtrl,
    required this.activityLevel,
    required this.goal,
    required this.weeklyChangeCtrl,
    required this.onGenderChanged,
    required this.onActivityChanged,
    required this.onGoalChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Параметры клиента',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        const Text('Пол', style: TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'male', label: Text('Мужской')),
            ButtonSegment(value: 'female', label: Text('Женский')),
          ],
          selected: {gender},
          onSelectionChanged: (s) => onGenderChanged(s.first),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: TextField(
              controller: ageCtrl,
              decoration: const InputDecoration(
                  labelText: 'Возраст', suffixText: 'лет'),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: weightCtrl,
              decoration:
                  const InputDecoration(labelText: 'Вес', suffixText: 'кг'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: heightCtrl,
          decoration:
              const InputDecoration(labelText: 'Рост', suffixText: 'см'),
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: activityLevel,
          decoration:
              const InputDecoration(labelText: 'Уровень активности'),
          items: const [
            DropdownMenuItem(
                value: 'sedentary',
                child: Text('Сидячий образ жизни')),
            DropdownMenuItem(
                value: 'light', child: Text('Лёгкая активность')),
            DropdownMenuItem(
                value: 'moderate',
                child: Text('Умеренная активность')),
            DropdownMenuItem(
                value: 'active',
                child: Text('Высокая активность')),
            DropdownMenuItem(
                value: 'very_active',
                child: Text('Очень высокая активность')),
          ],
          onChanged: (v) => onActivityChanged(v!),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: goal,
          decoration: const InputDecoration(labelText: 'Цель'),
          items: const [
            DropdownMenuItem(
                value: 'lose_fat', child: Text('Похудение')),
            DropdownMenuItem(
                value: 'maintain',
                child: Text('Поддержание веса')),
            DropdownMenuItem(
                value: 'gain_muscle',
                child: Text('Набор мышечной массы')),
          ],
          onChanged: (v) => onGoalChanged(v!),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: weeklyChangeCtrl,
          decoration: const InputDecoration(
            labelText: 'Изменение в неделю (необязательно)',
            hintText: '-0.5 — похудение, +0.3 — набор',
            suffixText: 'кг',
          ),
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true, signed: true),
        ),
      ],
    );
  }
}

// ─── Diary Tab ───────────────────────────────────────────────────────────────

class _DiaryTab extends StatefulWidget {
  final String clientId;
  final bool isTrainer;

  const _DiaryTab({required this.clientId, this.isTrainer = false});

  @override
  State<_DiaryTab> createState() => _DiaryTabState();
}

class _DiaryTabState extends State<_DiaryTab> {
  DateTime _date = DateTime.now();
  NutritionSummary? _summary;
  String? _mealPlanId;
  double? _burnedCalories;
  bool _loading = true;
  bool _noProfile = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _noProfile = false; });
    final api = context.read<AuthProvider>().api;
    final dateStr = DateFormat('yyyy-MM-dd').format(_date);

    NutritionSummary? summary;
    Map<String, dynamic>? plan;
    bool summaryFailed = false;
    double? burnedCalories;

    await Future.wait([
      Future<void>(() async {
        try {
          summary = await api.getNutritionSummary(widget.clientId, dateStr);
        } catch (_) {
          summaryFailed = true;
        }
      }),
      Future<void>(() async {
        try {
          plan = await api.getMealPlan(widget.clientId, dateStr);
        } catch (_) {}
      }),
      Future<void>(() async {
        try {
          if (widget.isTrainer) {
            final burned = await api.getTrainerClientBurnedCalories(
                widget.clientId, dateStr);
            burnedCalories = burned.burnedCalories;
          } else {
            final burned = await api.getBurnedCalories(dateStr);
            burnedCalories = burned.burnedCalories;
          }
        } catch (_) {}
      }),
    ]);

    if (mounted) {
      setState(() {
        _summary = summary;
        _mealPlanId = plan?['id'] as String?;
        _burnedCalories = burnedCalories;
        _noProfile = summaryFailed;
        _loading = false;
      });
    }
  }

  void _prevDay() {
    _date = _date.subtract(const Duration(days: 1));
    _load();
  }

  void _nextDay() {
    if (_date.isBefore(DateTime.now().subtract(const Duration(hours: 1)))) {
      _date = _date.add(const Duration(days: 1));
      _load();
    }
  }

  void _showAddMeal() {
    if (_mealPlanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Создайте профиль питания перед добавлением приёмов пищи')));
      return;
    }

    String selectedType = 'breakfast';
    final timeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Приём пищи'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Тип'),
                items: const [
                  DropdownMenuItem(value: 'breakfast', child: Text('Завтрак')),
                  DropdownMenuItem(value: 'lunch', child: Text('Обед')),
                  DropdownMenuItem(value: 'dinner', child: Text('Ужин')),
                  DropdownMenuItem(value: 'snack', child: Text('Перекус')),
                ],
                onChanged: (v) => setS(() => selectedType = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Время (необязательно)',
                  hintText: '08:30',
                ),
                keyboardType: TextInputType.datetime,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final api = context.read<AuthProvider>().api;
                try {
                  await api.addMealToMealPlan(
                    _mealPlanId!,
                    selectedType,
                    time: timeCtrl.text.trim().isNotEmpty ? timeCtrl.text.trim() : null,
                  );
                  _load();
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ошибка добавления')));
                  }
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteItem(String itemId) async {
    final api = context.read<AuthProvider>().api;
    try {
      await api.deleteMealItem(itemId);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка удаления')));
      }
    }
  }

  Future<void> _editMealItem(MealItemData item) async {
    final ctrl = TextEditingController(text: item.amountGrams.round().toString());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.foodItem.name, style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Количество', suffixText: 'г'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final grams = double.tryParse(ctrl.text.replaceAll(',', '.'));
    if (grams == null || grams < 1) return;
    final api = context.read<AuthProvider>().api;
    try {
      await api.updateMealItem(item.id, grams);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка обновления')));
      }
    }
  }

  Future<void> _editMeal(MealData meal) async {
    String selectedType = meal.type;
    final timeCtrl = TextEditingController(text: meal.time ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Редактировать приём пищи'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Тип'),
                items: const [
                  DropdownMenuItem(value: 'breakfast', child: Text('Завтрак')),
                  DropdownMenuItem(value: 'lunch', child: Text('Обед')),
                  DropdownMenuItem(value: 'dinner', child: Text('Ужин')),
                  DropdownMenuItem(value: 'snack', child: Text('Перекус')),
                ],
                onChanged: (v) => setS(() => selectedType = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Время (необязательно)',
                  hintText: '08:30',
                ),
                keyboardType: TextInputType.datetime,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final api = context.read<AuthProvider>().api;
    try {
      final time = timeCtrl.text.trim().isNotEmpty ? timeCtrl.text.trim() : null;
      await api.updateMeal(meal.id, type: selectedType, time: time);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка обновления')));
      }
    }
  }

  Future<void> _deleteMeal(String mealId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить приём пищи?'),
        content: const Text('Все продукты в этом приёме будут удалены.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final api = context.read<AuthProvider>().api;
    try {
      await api.deleteMeal(mealId);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка удаления')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(_date, DateTime.now());
    final dateLabel = isToday
        ? 'Сегодня'
        : DateFormat('d MMMM yyyy', 'ru_RU').format(_date);

    return Column(
      children: [
        _buildDateNav(dateLabel, isToday),
        Expanded(
          child: Stack(
            children: [
              _loading
                ? const Center(child: CircularProgressIndicator())
                : _noProfile
                  ? _buildNoProfile()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                        children: [
                          if (_summary != null) ...[
                            _CalorieCard(summary: _summary!, burnedCalories: _burnedCalories),
                            const SizedBox(height: 8),
                            _MacrosCard(summary: _summary!),
                            const SizedBox(height: 12),
                          ],
                          if (_summary == null || _summary!.meals.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Column(
                                children: [
                                  Icon(Icons.restaurant_menu,
                                      size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Нет приёмов пищи',
                                    style: TextStyle(color: Colors.grey, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Нажмите + чтобы добавить',
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          else
                            ..._summary!.meals.map((meal) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _MealCard(
                                    meal: meal,
                                    onAddFood: () => showFoodSearchSheet(
                                      context,
                                      mealId: meal.id,
                                      onAdded: _load,
                                      clientId: widget.clientId,
                                    ),
                                    onDeleteItem: _deleteItem,
                                    onEditItem: _editMealItem,
                                    onEditMeal: () => _editMeal(meal),
                                    onDeleteMeal: () => _deleteMeal(meal.id),
                                  ),
                                )),
                        ],
                      ),
                    ),
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
                  onPressed: _showAddMeal,
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateNav(String label, bool isToday) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _prevDay,
          ),
          Expanded(
            child: TextButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  _date = picked;
                  _load();
                }
              },
              child: Text(
                label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: isToday ? Colors.grey.shade300 : null,
            ),
            onPressed: isToday ? null : _nextDay,
          ),
        ],
      ),
    );
  }

  Widget _buildNoProfile() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.no_meals, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Профиль питания не настроен',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          SizedBox(height: 8),
          Text('Обратитесь к тренеру',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

}

// ─── Calorie Circle Card ──────────────────────────────────────────────────────

class _CalorieCard extends StatelessWidget {
  final NutritionSummary summary;
  final double? burnedCalories;

  const _CalorieCard({required this.summary, this.burnedCalories});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final burned = (burnedCalories ?? 0.0) > 0 ? (burnedCalories ?? 0.0) : 0.0;
    final effectiveTarget = s.targetCalories + burned;
    final percent = effectiveTarget > 0
        ? (s.consumedCalories / effectiveTarget).clamp(0.0, 1.0)
        : 0.0;
    final remaining =
        (effectiveTarget - s.consumedCalories).clamp(0.0, double.infinity);
    final overEaten = s.consumedCalories > effectiveTarget;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(90, 90),
                    painter: _ArcPainter(
                      percent: percent,
                      color: overEaten ? Colors.red : const Color(0xFF8B0000),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.consumedCalories.round().toString(),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Text('ккал',
                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Калории',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  _statRow('Цель', '${s.targetCalories.round()} ккал'),
                  _statRow('Съедено', '${s.consumedCalories.round()} ккал'),
                  if (burned > 0)
                    _statRow('Потрачено', '+${burned.round()} ккал'),
                  _statRow(
                    overEaten ? 'Превышение' : 'Осталось',
                    '${remaining.round()} ккал',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${s.percentCalories.round()}% от нормы',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: overEaten ? Colors.red : Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Macros Card ─────────────────────────────────────────────────────────────

class _MacrosCard extends StatelessWidget {
  final NutritionSummary summary;

  const _MacrosCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Макронутриенты',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            _MacroBar('Белки', s.consumedProtein, s.targetProtein,
                const Color(0xFF1565C0)),
            const SizedBox(height: 10),
            _MacroBar('Углеводы', s.consumedCarbs, s.targetCarbs,
                const Color(0xFFF57F17)),
            const SizedBox(height: 10),
            _MacroBar('Жиры', s.consumedFat, s.targetFat,
                const Color(0xFF2E7D32)),
          ],
        ),
      ),
    );
  }
}

// ─── Meal Card ───────────────────────────────────────────────────────────────

class _MealCard extends StatefulWidget {
  final MealData meal;
  final VoidCallback onAddFood;
  final Function(String) onDeleteItem;
  final Function(MealItemData)? onEditItem;
  final VoidCallback? onEditMeal;
  final VoidCallback? onDeleteMeal;

  const _MealCard({
    required this.meal,
    required this.onAddFood,
    required this.onDeleteItem,
    this.onEditItem,
    this.onEditMeal,
    this.onDeleteMeal,
  });

  @override
  State<_MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<_MealCard> {
  bool _expanded = true;

  static const _typeLabels = {
    'breakfast': 'Завтрак',
    'lunch': 'Обед',
    'dinner': 'Ужин',
    'snack': 'Перекус',
  };

  static const _typeIcons = {
    'breakfast': Icons.wb_sunny_outlined,
    'lunch': Icons.wb_cloudy_outlined,
    'dinner': Icons.nights_stay_outlined,
    'snack': Icons.coffee_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final m = widget.meal;
    final label = _typeLabels[m.type] ?? m.type;
    final icon = _typeIcons[m.type] ?? Icons.restaurant;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: const Color(0xFF8B0000)),
            title: Row(
              children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                if (m.time != null) ...[
                  const SizedBox(width: 8),
                  Text(m.time!,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.grey)),
                ],
              ],
            ),
            subtitle: Text(
              '${m.subtotalCalories.round()} ккал  ·  '
              'Б${m.subtotalProtein.round()}  '
              'Ж${m.subtotalFat.round()}  '
              'У${m.subtotalCarbs.round()}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: Color(0xFF8B0000), size: 22),
                  tooltip: 'Добавить продукт',
                  onPressed: widget.onAddFood,
                ),
                if (widget.onEditMeal != null || widget.onDeleteMeal != null)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (v) {
                      if (v == 'edit') widget.onEditMeal?.call();
                      if (v == 'delete') widget.onDeleteMeal?.call();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Редактировать'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline, color: Colors.red),
                          title: Text('Удалить', style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                IconButton(
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 22,
                  ),
                  onPressed: () =>
                      setState(() => _expanded = !_expanded),
                ),
              ],
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            if (m.items.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Text(
                  'Нет продуктов — нажмите + чтобы добавить',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              )
            else
              ...m.items.map((item) => ListTile(
                dense: true,
                title: Text(item.foodItem.name),
                subtitle: Text(
                  '${item.amountGrams.round()} г  ·  '
                  '${item.calories.round()} ккал  '
                  'Б${item.protein.round()} '
                  'Ж${item.fat.round()} '
                  'У${item.carbs.round()}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onEditItem != null)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            size: 18, color: Colors.grey),
                        onPressed: () => widget.onEditItem!(item),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.grey),
                      onPressed: () => widget.onDeleteItem(item.id),
                    ),
                  ],
                ),
              )),
          ],
        ],
      ),
    );
  }
}

// ─── Shared Helpers ───────────────────────────────────────────────────────────

class _MacroBar extends StatelessWidget {
  final String label;
  final double consumed;
  final double target;
  final Color color;

  const _MacroBar(this.label, this.consumed, this.target, this.color);

  @override
  Widget build(BuildContext context) {
    final pct =
        target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    final showConsumed = consumed > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(fontSize: 13)),
              ],
            ),
            const Spacer(),
            Text(
              showConsumed
                  ? '${consumed.round()} / ${target.round()} г'
                  : '${target.round()} г',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

Widget _infoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w500, fontSize: 13)),
      ],
    ),
  );
}

Widget _statRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
}

// ─── Calorie Arc Painter ──────────────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  final double percent;
  final Color color;

  _ArcPainter({required this.percent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    if (percent > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * percent,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.percent != percent || old.color != color;
}
