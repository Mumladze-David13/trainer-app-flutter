// lib/features/ai/generate_program_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_provider.dart';
import 'ai_usage_screen.dart';

class GenerateProgramScreen extends StatefulWidget {
  final String clientId;
  final String clientName;
  final String seasonId;

  const GenerateProgramScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.seasonId,
  });

  @override
  State<GenerateProgramScreen> createState() => _GenerateProgramScreenState();
}

class _GenerateProgramScreenState extends State<GenerateProgramScreen> {
  int _step = 1;

  String _goal = 'gain_muscle';
  String _level = 'intermediate';
  int _daysPerWeek = 3;
  String _equipment = 'тренажёрный зал';
  final _notesCtrl = TextEditingController();

  Map<String, dynamic>? _result;
  bool _saving = false;

  final _fmt = DateFormat('dd.MM.yyyy');

  static const _goals = {
    'lose_fat': '🔥 Похудение',
    'gain_muscle': '💪 Набор мышечной массы',
    'strength': '🏋️ Силовые показатели',
    'maintain': '⚖️ Поддержание формы',
    'endurance': '🏃 Выносливость',
  };

  static const _levels = {
    'beginner': '🌱 Начинающий',
    'intermediate': '🌿 Средний',
    'advanced': '🌳 Продвинутый',
  };

  static const _equipmentOptions = [
    'тренажёрный зал',
    'штанга и гантели',
    'только собственный вес',
    'дома с гантелями',
    'резиновые ленты',
  ];

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() => _step = 2);
    final api = context.read<AuthProvider>().api;
    try {
      final result = await api.aiGenerateProgram({
        'clientId': widget.clientId,
        'goal': _goal,
        'level': _level,
        'daysPerWeek': _daysPerWeek,
        'equipment': _equipment,
        if (_notesCtrl.text.isNotEmpty) 'notes': _notesCtrl.text,
      });
      if (mounted) setState(() { _result = result; _step = 3; });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _step = 1);
      if (e.response?.statusCode == 403) {
        _showLimitBottomSheet();
      } else {
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

  void _showLimitBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning, color: Colors.orange, size: 48),
            const SizedBox(height: 12),
            const Text('Лимит токенов исчерпан',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Перейдите на тариф выше для продолжения',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AiUsageScreen()));
              },
              child: const Text('Посмотреть тарифы'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProgram() async {
    if (_result == null) return;
    setState(() => _saving = true);

    final workouts = _result!['workouts'] as List;
    final now = DateTime.now();
    final interval = (_daysPerWeek > 0) ? (7 / _daysPerWeek).round().clamp(1, 7) : 2;

    final saveWorkouts = workouts.asMap().entries.map((entry) {
      final i = entry.key;
      final w = entry.value as Map<String, dynamic>;
      final date = now.add(Duration(days: i * interval));

      final exercises = (w['exercises'] as List).map((e) {
        final Map<String, dynamic> ex = {
          'exerciseId': e['exerciseId'],
          'sets': e['sets'],
          'reps': e['reps'],
          'order': e['order'],
        };
        if (e['weight'] != null) ex['weight'] = e['weight'];
        if (e['setWeights'] != null) ex['setWeights'] = e['setWeights'];
        if (e['supersetGroup'] != null) ex['supersetGroup'] = e['supersetGroup'];
        if (e['supersetOrder'] != null) ex['supersetOrder'] = e['supersetOrder'];
        return ex;
      }).toList();

      return {
        'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        if (w['notes'] != null && (w['notes'] as String).isNotEmpty) 'notes': w['notes'],
        'exercises': exercises,
      };
    }).toList();

    final api = context.read<AuthProvider>().api;
    try {
      await api.aiSaveProgram({'seasonId': widget.seasonId, 'workouts': saveWorkouts});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Программа сохранена в сезон')));
        Navigator.pop(context, true);
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
    return Scaffold(
      appBar: AppBar(
        title: Text('AI для ${widget.clientName}'),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFC62828), Color(0xFF8B0000)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.smart_toy, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AI Генератор программ',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text('Для ${widget.clientName}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _sectionTitle('Цель'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _goals.entries
                .map((e) => ChoiceChip(
                      label: Text(e.value),
                      selected: _goal == e.key,
                      onSelected: (_) => setState(() => _goal = e.key),
                      selectedColor: Colors.red.shade100,
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),

          _sectionTitle('Уровень подготовки'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _levels.entries
                .map((e) => ChoiceChip(
                      label: Text(e.value),
                      selected: _level == e.key,
                      onSelected: (_) => setState(() => _level = e.key),
                      selectedColor: Colors.red.shade100,
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),

          _sectionTitle('Дней в неделю'),
          const SizedBox(height: 8),
          Row(
            children: [2, 3, 4, 5, 6]
                .map((d) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _daysPerWeek = d),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: _daysPerWeek == d
                              ? const Color(0xFF8B0000)
                              : Colors.grey.shade200,
                          child: Text(
                            '$d',
                            style: TextStyle(
                              color: _daysPerWeek == d
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),

          _sectionTitle('Оборудование'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _equipmentOptions
                .map((eq) => ChoiceChip(
                      label: Text(eq),
                      selected: _equipment == eq,
                      onSelected: (_) => setState(() => _equipment = eq),
                      selectedColor: Colors.red.shade100,
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),

          _sectionTitle('Дополнительные пожелания'),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Например: избегать упражнений на спину, фокус на ноги...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Сгенерировать программу'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B0000),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(color: Color(0xFF8B0000), strokeWidth: 5),
          ),
          const SizedBox(height: 24),
          const Icon(Icons.smart_toy, size: 48, color: Color(0xFF8B0000)),
          const SizedBox(height: 16),
          const Text('AI составляет программу...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Это может занять 15–30 секунд',
              style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    if (_result == null) return const SizedBox();

    final workouts = _result!['workouts'] as List;
    final recommendations = _result!['recommendations'] as String? ?? '';
    final usage = _result!['usage'] as Map<String, dynamic>?;
    final now = DateTime.now();
    final interval = (_daysPerWeek > 0) ? (7 / _daysPerWeek).round().clamp(1, 7) : 2;

    final tokensUsed = usage?['tokensUsedThisMonth'] as int? ?? 0;
    final monthlyLimit = usage?['monthlyLimit'] as int?;
    final isAtLimit = monthlyLimit != null && tokensUsed >= monthlyLimit;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (isAtLimit)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Лимит токенов исчерпан',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange)),
                            TextButton(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const AiUsageScreen())),
                              style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                              child: const Text('Улучшить тариф'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

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
                        'Использовано ${usage['totalTokens']} токенов · \$${(usage['costUsd'] as num).toStringAsFixed(4)}',
                        style: const TextStyle(color: Color(0xFF8B0000), fontSize: 13),
                      ),
                    ],
                  ),
                ),

              if (recommendations.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.lightbulb, color: Colors.amber.shade800, size: 18),
                        const SizedBox(width: 8),
                        Text('Рекомендации AI',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: Colors.amber.shade800)),
                      ]),
                      const SizedBox(height: 8),
                      Text(recommendations, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],

              Text('Программа: ${workouts.length} тренировок',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),

              ...workouts.asMap().entries.map((entry) {
                final i = entry.key;
                final w = entry.value as Map<String, dynamic>;
                final date = now.add(Duration(days: i * interval));
                final exercises = w['exercises'] as List;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B0000),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('День ${w['dayNumber']}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            Text(_fmt.format(date),
                                style: const TextStyle(fontWeight: FontWeight.w500)),
                            const Spacer(),
                            Text('${exercises.length} упр.',
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 13)),
                          ],
                        ),
                        if (w['notes'] != null &&
                            (w['notes'] as String).isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(w['notes'] as String,
                              style: TextStyle(
                                  color: Colors.grey.shade700, fontSize: 13)),
                        ],
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        ...exercises.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      e['exerciseName'] as String? ?? '—',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  Text(
                                    '${e['sets']}×${e['reps']}'
                                    '${e['weight'] != null ? ' · ${e['weight']}кг' : ''}',
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            )),
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
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2))
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
                  onPressed: _saving ? null : _saveProgram,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Сохраняю...' : 'Сохранить в сезон'),
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

  Widget _sectionTitle(String text) =>
      Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600));
}
