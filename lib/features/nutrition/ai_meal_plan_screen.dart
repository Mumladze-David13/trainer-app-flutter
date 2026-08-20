// lib/features/nutrition/ai_meal_plan_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/meal_types.dart';
import '../../core/models/nutrition_models.dart';
import '../../core/services/auth_provider.dart';
import '../../core/widgets/macro_bar.dart';
import '../ai/ai_limit_bottom_sheet.dart';

class AiMealPlanScreen extends StatefulWidget {
  final String clientId;
  final DateTime date;

  const AiMealPlanScreen({super.key, required this.clientId, required this.date});

  @override
  State<AiMealPlanScreen> createState() => _AiMealPlanScreenState();
}

class _AiMealPlanScreenState extends State<AiMealPlanScreen> {
  int _step = 1; // 1 = форма, 2 = генерация, 3 = превью
  bool _loadingProfile = true;
  NutritionProfileData? _profileData;
  final _preferencesCtrl = TextEditingController();

  Map<String, dynamic>? _result;
  bool _saving = false;

  final _dateFmt = DateFormat('d MMMM', 'ru_RU');
  final _apiDateFmt = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _preferencesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final api = context.read<AuthProvider>().api;
    try {
      final data = await api.getNutritionProfile(widget.clientId);
      if (mounted) setState(() => _profileData = data);
    } catch (_) {
      // профиля может не быть — экран покажет предупреждение ниже
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _generate() async {
    setState(() => _step = 2);
    final api = context.read<AuthProvider>().api;
    try {
      final result = await api.aiGenerateMealPlan(
        widget.clientId,
        preferences: _preferencesCtrl.text.trim(),
      );
      if (mounted) setState(() { _result = result; _step = 3; });
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 403) {
        setState(() => _step = 1);
        showAiLimitBottomSheet(context);
      } else {
        setState(() => _step = 1);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка генерации. Попробуйте снова.')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _step = 1);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка генерации. Попробуйте снова.')));
      }
    }
  }

  Future<void> _savePlan() async {
    if (_result == null) return;
    setState(() => _saving = true);
    final api = context.read<AuthProvider>().api;
    try {
      await api.aiSaveMealPlan({
        'clientId': widget.clientId,
        'date': _apiDateFmt.format(widget.date),
        'meals': _result!['meals'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Меню сохранено в дневник')));
        Navigator.pop(context, true);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (e.response?.statusCode == 403) {
        showAiLimitBottomSheet(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка сохранения')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка сохранения')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI-меню на ${_dateFmt.format(widget.date)}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == 3) {
              setState(() => _step = 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _step == 1
          ? _buildStep1()
          : _step == 2
              ? _buildStep2()
              : _buildStep3(),
    );
  }

  Widget _buildStep1() {
    if (_loadingProfile) return const Center(child: CircularProgressIndicator());

    final calc = _profileData?.calculations;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFC62828), Color(0xFF8B0000)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.restaurant_menu, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AI-меню на день',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(_dateFmt.format(widget.date),
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (calc == null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Профиль питания не настроен — цели по КБЖУ неизвестны, меню будет составлено без точных ограничений.',
                style: TextStyle(color: Colors.orange),
              ),
            )
          else ...[
            const Text('Цель на день', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('${calc.targetCalories.round()} ккал  ·  '
                'Б${calc.macros.protein.round()} Ж${calc.macros.fat.round()} У${calc.macros.carbs.round()}'),
          ],
          const SizedBox(height: 20),
          const Text('Пожелания', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _preferencesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Например: не ем рыбу, вегетарианец, люблю острое...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Сгенерировать меню'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B0000),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 72, height: 72,
            child: CircularProgressIndicator(color: Color(0xFF8B0000), strokeWidth: 5),
          ),
          SizedBox(height: 24),
          Icon(Icons.restaurant_menu, size: 48, color: Color(0xFF8B0000)),
          SizedBox(height: 16),
          Text('AI составляет меню...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          SizedBox(height: 8),
          Text('Это может занять 15–30 секунд', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    if (_result == null) return const SizedBox();

    final meals = (_result!['meals'] as List? ?? []).cast<Map<String, dynamic>>();
    final totals = _result!['totals'] as Map<String, dynamic>? ?? {};
    final usage = _result!['usage'] as Map<String, dynamic>?;
    final calc = _profileData?.calculations;

    const order = ['breakfast', 'lunch', 'dinner', 'snack'];
    final sortedMeals = [...meals]..sort(
        (a, b) => order.indexOf(a['type']).compareTo(order.indexOf(b['type'])));

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (usage != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.toll, color: Color(0xFF8B0000), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Использовано ${usage['totalTokens']} токенов · \$${(usage['costUsd'] as num?)?.toStringAsFixed(4) ?? '0'}',
                        style: const TextStyle(color: Color(0xFF8B0000), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              if (calc != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Итого по меню', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('${(totals['calories'] as num?)?.round() ?? 0} / ${calc.targetCalories.round()} ккал',
                                style: const TextStyle(fontSize: 13, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        MacroBar('Белки', (totals['protein'] as num?)?.toDouble() ?? 0,
                            calc.macros.protein, const Color(0xFF1565C0)),
                        const SizedBox(height: 10),
                        MacroBar('Углеводы', (totals['carbs'] as num?)?.toDouble() ?? 0,
                            calc.macros.carbs, const Color(0xFFF57F17)),
                        const SizedBox(height: 10),
                        MacroBar('Жиры', (totals['fat'] as num?)?.toDouble() ?? 0,
                            calc.macros.fat, const Color(0xFF2E7D32)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ...sortedMeals.map((meal) {
                final type = meal['type'] as String? ?? 'snack';
                final time = meal['time'] as String?;
                final items = (meal['items'] as List? ?? []).cast<Map<String, dynamic>>();
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(mealTypeIcons[type] ?? Icons.restaurant,
                                color: const Color(0xFF8B0000), size: 20),
                            const SizedBox(width: 8),
                            Text(mealTypeLabels[type] ?? type,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (time != null) ...[
                              const SizedBox(width: 8),
                              Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ],
                        ),
                        const Divider(height: 16),
                        ...items.map((item) {
                          final grams = (item['amountGrams'] as num?)?.toDouble() ?? 0;
                          final cal100 = (item['caloriesPer100g'] as num?)?.toDouble() ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(item['name'] as String? ?? '—',
                                      style: const TextStyle(fontSize: 13)),
                                ),
                                Text('${grams.round()}г · ${(cal100 * grams / 100).round()} ккал',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, -2)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _step = 1),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Заново'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _savePlan,
                  icon: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Сохраняю...' : 'Сохранить на день'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B0000), foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
