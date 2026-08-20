// lib/features/nutrition/ai_meal_quick_add_sheet.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/meal_types.dart';
import '../../core/services/auth_provider.dart';
import '../ai/ai_limit_bottom_sheet.dart';

Future<void> showAiMealQuickAddSheet(
  BuildContext context, {
  required String clientId,
  required String date,
  String? defaultMealType,
  required VoidCallback onSaved,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AiMealQuickAddSheet(
      clientId: clientId,
      date: date,
      defaultMealType: defaultMealType,
      onSaved: onSaved,
    ),
  );
}

class _ParsedFoodItem {
  String name;
  double amountGrams;
  double caloriesPer100g;
  double proteinPer100g;
  double carbsPer100g;
  double fatPer100g;

  _ParsedFoodItem({
    required this.name,
    required this.amountGrams,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
  });

  factory _ParsedFoodItem.fromJson(Map<String, dynamic> j) => _ParsedFoodItem(
        name: j['name'] as String? ?? '',
        amountGrams: (j['amountGrams'] as num?)?.toDouble() ?? 0,
        caloriesPer100g: (j['caloriesPer100g'] as num?)?.toDouble() ?? 0,
        proteinPer100g: (j['proteinPer100g'] as num?)?.toDouble() ?? 0,
        carbsPer100g: (j['carbsPer100g'] as num?)?.toDouble() ?? 0,
        fatPer100g: (j['fatPer100g'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'amountGrams': amountGrams,
        'caloriesPer100g': caloriesPer100g,
        'proteinPer100g': proteinPer100g,
        'carbsPer100g': carbsPer100g,
        'fatPer100g': fatPer100g,
      };

  double get calories => caloriesPer100g * amountGrams / 100;
  double get protein => proteinPer100g * amountGrams / 100;
  double get carbs => carbsPer100g * amountGrams / 100;
  double get fat => fatPer100g * amountGrams / 100;
}

class _AiMealQuickAddSheet extends StatefulWidget {
  final String clientId;
  final String date;
  final String? defaultMealType;
  final VoidCallback onSaved;

  const _AiMealQuickAddSheet({
    required this.clientId,
    required this.date,
    this.defaultMealType,
    required this.onSaved,
  });

  @override
  State<_AiMealQuickAddSheet> createState() => _AiMealQuickAddSheetState();
}

class _AiMealQuickAddSheetState extends State<_AiMealQuickAddSheet> {
  int _step = 1; // 1 = ввод текста, 2 = распознавание, 3 = проверка
  late String _mealType;
  final _textCtrl = TextEditingController();
  final _items = <_ParsedFoodItem>[];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mealType = widget.defaultMealType ?? guessMealTypeForHour(DateTime.now().hour);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _parse() async {
    if (_textCtrl.text.trim().isEmpty) return;
    setState(() => _step = 2);
    final api = context.read<AuthProvider>().api;
    try {
      final result = await api.aiParseMeal(_textCtrl.text.trim(), mealType: _mealType);
      final items = (result['items'] as List? ?? [])
          .map((e) => _ParsedFoodItem.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _items
            ..clear()
            ..addAll(items);
          _step = 3;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 403) {
        Navigator.pop(context);
        showAiLimitBottomSheet(context);
      } else {
        setState(() => _step = 1);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось распознать. Попробуйте ещё раз.')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _step = 1);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось распознать. Попробуйте ещё раз.')));
      }
    }
  }

  void _addManualRow() {
    setState(() {
      _items.add(_ParsedFoodItem(
        name: '',
        amountGrams: 100,
        caloriesPer100g: 0,
        proteinPer100g: 0,
        carbsPer100g: 0,
        fatPer100g: 0,
      ));
    });
  }

  Future<void> _save() async {
    final validItems = _items.where((i) => i.name.trim().isNotEmpty && i.amountGrams > 0).toList();
    if (validItems.isEmpty) return;
    setState(() => _saving = true);
    final api = context.read<AuthProvider>().api;
    try {
      await api.aiLogMeal({
        'clientId': widget.clientId,
        'date': widget.date,
        'mealType': _mealType,
        'items': validItems.map((i) => i.toJson()).toList(),
      });
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (e.response?.statusCode == 403) {
        Navigator.pop(context);
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
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: _step == 1
                ? _buildStep1(scrollCtrl)
                : _step == 2
                    ? _buildStep2()
                    : _buildStep3(scrollCtrl),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1(ScrollController scrollCtrl) {
    return SingleChildScrollView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF8B0000)),
              SizedBox(width: 8),
              Text('Что вы съели?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: mealTypeLabels.entries
                .map((e) => ChoiceChip(
                      label: Text(e.value),
                      selected: _mealType == e.key,
                      onSelected: (_) => setState(() => _mealType = e.key),
                      selectedColor: Colors.red.shade100,
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textCtrl,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Например: гречка с курицей 250г и чай с сахаром',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _parse,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Распознать'),
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
            width: 56, height: 56,
            child: CircularProgressIndicator(color: Color(0xFF8B0000), strokeWidth: 4),
          ),
          SizedBox(height: 20),
          Text('AI оценивает...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStep3(ScrollController scrollCtrl) {
    final totalCal = _items.fold<double>(0, (s, i) => s + i.calories);
    final totalP = _items.fold<double>(0, (s, i) => s + i.protein);
    final totalC = _items.fold<double>(0, (s, i) => s + i.carbs);
    final totalF = _items.fold<double>(0, (s, i) => s + i.fat);

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            children: [
              Text('${mealTypeLabels[_mealType]} — проверьте перед сохранением',
                  style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('AI не смог распознать блюда. Добавьте вручную.',
                      style: TextStyle(color: Colors.grey)),
                )
              else
                ..._items.asMap().entries.map((entry) => _ReviewItemRow(
                      key: ValueKey(entry.key),
                      item: entry.value,
                      onChanged: () => setState(() {}),
                      onDelete: () => setState(() => _items.removeAt(entry.key)),
                    )),
              TextButton.icon(
                onPressed: _addManualRow,
                icon: const Icon(Icons.add),
                label: const Text('Добавить продукт вручную'),
              ),
              if (_items.isNotEmpty) ...[
                const Divider(),
                Text(
                  'Итого: ${totalCal.round()} ккал  ·  '
                  'Б${totalP.round()} Ж${totalF.round()} У${totalC.round()}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
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
                child: OutlinedButton(
                  onPressed: _saving ? null : () => setState(() => _step = 1),
                  child: const Text('Заново'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Сохраняю...' : 'Сохранить'),
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

class _ReviewItemRow extends StatefulWidget {
  final _ParsedFoodItem item;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _ReviewItemRow({super.key, required this.item, required this.onChanged, required this.onDelete});

  @override
  State<_ReviewItemRow> createState() => _ReviewItemRowState();
}

class _ReviewItemRowState extends State<_ReviewItemRow> {
  late final _nameCtrl = TextEditingController(text: widget.item.name);
  late final _gramsCtrl = TextEditingController(text: widget.item.amountGrams.round().toString());

  @override
  void dispose() {
    _nameCtrl.dispose();
    _gramsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(isDense: true, hintText: 'Название'),
                    onChanged: (v) {
                      i.name = v;
                      widget.onChanged();
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${i.calories.round()} ккал · Б${i.protein.round()} Ж${i.fat.round()} У${i.carbs.round()}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 70,
              child: TextField(
                controller: _gramsCtrl,
                textAlign: TextAlign.end,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(isDense: true, suffixText: 'г'),
                onChanged: (v) {
                  i.amountGrams = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                  widget.onChanged();
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
              onPressed: widget.onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
