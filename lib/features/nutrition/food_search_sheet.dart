import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/nutrition_models.dart';
import '../../core/services/auth_provider.dart';

Future<void> showFoodSearchSheet(
  BuildContext context, {
  required String mealId,
  required VoidCallback onAdded,
  String? clientId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _FoodSearchSheet(mealId: mealId, onAdded: onAdded, clientId: clientId),
  );
}

class _FoodSearchSheet extends StatefulWidget {
  final String mealId;
  final VoidCallback onAdded;
  final String? clientId;

  const _FoodSearchSheet({required this.mealId, required this.onAdded, this.clientId});

  @override
  State<_FoodSearchSheet> createState() => _FoodSearchSheetState();
}

class _FoodSearchSheetState extends State<_FoodSearchSheet> {
  final _searchCtrl = TextEditingController();
  List<FoodItem> _results = [];
  bool _searching = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _search(''));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    final api = context.read<AuthProvider>().api;
    try {
      final results = await api.searchFood(query.trim(), clientId: widget.clientId);
      if (mounted) setState(() { _results = results; _hasSearched = true; });
    } catch (_) {
      if (mounted) setState(() => _hasSearched = true);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _showGramsDialog(FoodItem food) {
    final ctrl = TextEditingController(text: '100');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(food.name, style: const TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${food.caloriesPer100g.round()} ккал / 100г  |  '
              'Б ${food.proteinPer100g.round()}г  '
              'Ж ${food.fatPer100g.round()}г  '
              'У ${food.carbsPer100g.round()}г',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Количество',
                suffixText: 'г',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
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
              final grams = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (grams == null || grams <= 0) return;
              Navigator.pop(ctx);
              final api = context.read<AuthProvider>().api;
              try {
                await api.addFoodToMeal(widget.mealId, food.id, grams);
                widget.onAdded();
                if (mounted) Navigator.of(context).pop();
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ошибка добавления продукта')));
                }
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  void _showEditFoodDialog(FoodItem food) {
    final nameCtrl = TextEditingController(text: food.name);
    final calCtrl = TextEditingController(text: food.caloriesPer100g.toString());
    final proteinCtrl = TextEditingController(text: food.proteinPer100g.toString());
    final fatCtrl = TextEditingController(text: food.fatPer100g.toString());
    final carbsCtrl = TextEditingController(text: food.carbsPer100g.toString());
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Редактировать продукт'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Название')),
                const SizedBox(height: 10),
                TextField(controller: calCtrl,
                  decoration: const InputDecoration(labelText: 'Ккал / 100г'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 10),
                TextField(controller: proteinCtrl,
                  decoration: const InputDecoration(labelText: 'Белки / 100г'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 10),
                TextField(controller: fatCtrl,
                  decoration: const InputDecoration(labelText: 'Жиры / 100г'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 10),
                TextField(controller: carbsCtrl,
                  decoration: const InputDecoration(labelText: 'Углеводы / 100г'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: saving ? null : () async {
                if (nameCtrl.text.trim().isEmpty) return;
                setS(() => saving = true);
                final api = context.read<AuthProvider>().api;
                try {
                  await api.updateFoodItem(
                    food.id,
                    name: nameCtrl.text.trim(),
                    caloriesPer100g: double.tryParse(calCtrl.text.replaceAll(',', '.')),
                    proteinPer100g: double.tryParse(proteinCtrl.text.replaceAll(',', '.')),
                    fatPer100g: double.tryParse(fatCtrl.text.replaceAll(',', '.')),
                    carbsPer100g: double.tryParse(carbsCtrl.text.replaceAll(',', '.')),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Продукт обновлён')));
                    _search(_searchCtrl.text);
                  }
                } catch (_) {
                  if (ctx.mounted) setS(() => saving = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ошибка обновления продукта')));
                  }
                }
              },
              child: saving
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteFoodItem(FoodItem food) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить продукт?'),
        content: Text('«${food.name}» будет удалён из справочника.'),
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
      await api.deleteFoodItem(food.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Продукт удалён')));
        _search(_searchCtrl.text);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка удаления продукта')));
      }
    }
  }

  void _showAddCustomFood() {
    final nameCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final proteinCtrl = TextEditingController();
    final fatCtrl = TextEditingController();
    final carbsCtrl = TextEditingController();
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Новый продукт'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Название')),
                const SizedBox(height: 10),
                TextField(controller: calCtrl,
                  decoration: const InputDecoration(labelText: 'Ккал / 100г'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 10),
                TextField(controller: proteinCtrl,
                  decoration: const InputDecoration(labelText: 'Белки / 100г'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 10),
                TextField(controller: fatCtrl,
                  decoration: const InputDecoration(labelText: 'Жиры / 100г'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 10),
                TextField(controller: carbsCtrl,
                  decoration: const InputDecoration(labelText: 'Углеводы / 100г'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: saving ? null : () async {
                if (nameCtrl.text.trim().isEmpty) return;
                setS(() => saving = true);
                final api = context.read<AuthProvider>().api;
                try {
                  await api.createFoodItem(
                    name: nameCtrl.text.trim(),
                    caloriesPer100g: double.tryParse(calCtrl.text.replaceAll(',', '.')) ?? 0,
                    proteinPer100g: double.tryParse(proteinCtrl.text.replaceAll(',', '.')) ?? 0,
                    fatPer100g: double.tryParse(fatCtrl.text.replaceAll(',', '.')) ?? 0,
                    carbsPer100g: double.tryParse(carbsCtrl.text.replaceAll(',', '.')) ?? 0,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Продукт добавлен в справочник')));
                    _search(_searchCtrl.text);
                  }
                } catch (_) {
                  if (ctx.mounted) setS(() => saving = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ошибка создания продукта')));
                  }
                }
              },
              child: saving
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Поиск продукта...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)))
                        : _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                _search('');
                              })
                          : null,
                    ),
                    onChanged: _search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _search,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: const Color(0xFF8B0000),
                  tooltip: 'Добавить свой продукт',
                  onPressed: _showAddCustomFood,
                ),
              ],
            ),
          ),
          Expanded(
            child: _results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _hasSearched ? Icons.search_off : Icons.search,
                        size: 48, color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _hasSearched
                          ? 'Ничего не найдено'
                          : 'Введите название продукта',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      if (_hasSearched) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _showAddCustomFood,
                          icon: const Icon(Icons.add),
                          label: const Text('Добавить свой продукт'),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  controller: scrollCtrl,
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final food = _results[i];
                    return ListTile(
                      title: Text(food.name),
                      subtitle: Text(
                        '${food.caloriesPer100g.round()} ккал  ·  '
                        'Б ${food.proteinPer100g.round()}  '
                        'Ж ${food.fatPer100g.round()}  '
                        'У ${food.carbsPer100g.round()}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_circle_outline,
                              color: Color(0xFF8B0000)),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert,
                                size: 20, color: Colors.grey),
                            onSelected: (v) {
                              if (v == 'edit') _showEditFoodDialog(food);
                              if (v == 'delete') _deleteFoodItem(food);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit_outlined),
                                  title: Text('Редактировать'),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(Icons.delete_outline,
                                      color: Colors.red),
                                  title: Text('Удалить',
                                      style: TextStyle(color: Colors.red)),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => _showGramsDialog(food),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
