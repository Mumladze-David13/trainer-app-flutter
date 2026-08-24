// lib/features/solo/solo_onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/services/auth_provider.dart';
import 'solo_generate_program_screen.dart';

// Онбординг SOLO: форма профиля -> согласие с ответственностью -> выбор
// AI-генерации или ручного пути (см. flutter-prompt-solo-mode-20260824.md).
class SoloOnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  // Профиль сохраняется идемпотентно, но согласие с ответственностью — нет,
  // поэтому если пользователь ушёл из онбординга между шагами (профиль уже
  // есть, а agree-terms ещё нет), SoloGateScreen открывает сразу шаг 2.
  final int initialStep;
  const SoloOnboardingScreen({super.key, required this.onDone, this.initialStep = 1});

  @override
  State<SoloOnboardingScreen> createState() => _SoloOnboardingScreenState();
}

class _SoloOnboardingScreenState extends State<SoloOnboardingScreen> {
  late int _step = widget.initialStep;
  bool _saving = false;
  String? _error;

  String _goal = 'gain_muscle';
  String _level = 'beginner';
  int _daysPerWeek = 3;
  String _equipment = kSoloEquipmentBodyweight;
  final _notesCtrl = TextEditingController();

  static const _goals = {
    'lose_fat': '🔥 Похудение',
    'gain_muscle': '💪 Набор мышечной массы',
    'maintain': '⚖️ Поддержание формы',
    'strength': '🏋️ Силовые показатели',
    'endurance': '🏃 Выносливость',
  };
  static const _levels = {
    'beginner': '🌱 Начинающий',
    'intermediate': '🌿 Средний',
    'advanced': '🌳 Продвинутый',
  };
  static const _equipmentOptions = {
    kSoloEquipmentGym: 'Тренажёрный зал',
    kSoloEquipmentHomeDumbbells: 'Дома с гантелями',
    kSoloEquipmentBodyweight: 'Только вес тела',
  };

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() { _saving = true; _error = null; });
    final api = context.read<AuthProvider>().api;
    try {
      await api.saveSoloProfile(
        goal: _goal,
        level: _level,
        daysPerWeek: _daysPerWeek,
        equipment: _equipment,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (mounted) setState(() => _step = 2);
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось сохранить профиль. Попробуйте снова.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _agreeTerms() async {
    setState(() { _saving = true; _error = null; });
    final api = context.read<AuthProvider>().api;
    try {
      await api.agreeSoloTerms();
      if (mounted) setState(() => _step = 3);
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось сохранить согласие. Попробуйте снова.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _startWithAi() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SoloGenerateProgramScreen()),
    );
    // И успешная генерация, и отказ в пользу ручного пути возвращают
    // не-null — профиль и согласие уже сохранены, просто открываем главный
    // SOLO-экран.
    if (result != null) widget.onDone();
  }

  void _startManually() => widget.onDone();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройка SOLO-режима'),
        automaticallyImplyLeading: _step > 1,
        leading: _step > 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step -= 1),
              )
            : null,
      ),
      body: _step == 1
          ? _buildProfileStep()
          : _step == 2
              ? _buildTermsStep()
              : _buildChoiceStep(),
    );
  }

  Widget _sectionTitle(String text) =>
      Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600));

  Widget _buildProfileStep() {
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
            child: const Row(children: [
              Icon(Icons.self_improvement, color: Colors.white, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Расскажите о своих целях — это поможет составить программу',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
            ]),
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
                          backgroundColor:
                              _daysPerWeek == d ? const Color(0xFF8B0000) : Colors.grey.shade200,
                          child: Text(
                            '$d',
                            style: TextStyle(
                              color: _daysPerWeek == d ? Colors.white : Colors.black87,
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
            children: _equipmentOptions.entries
                .map((e) => ChoiceChip(
                      label: Text(e.value),
                      selected: _equipment == e.key,
                      onSelected: (_) => setState(() => _equipment = e.key),
                      selectedColor: Colors.red.shade100,
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          _sectionTitle('Дополнительно (необязательно)'),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Например: травмы, пожелания...',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration:
                  BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B0000),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Далее'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTermsStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
          const SizedBox(height: 12),
          const Text('Тренировки на свой риск',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                'Программа тренировок формируется автоматически (или собирается вами вручную) '
                'и не является медицинской консультацией. Перед началом занятий '
                'проконсультируйтесь с врачом, особенно при наличии травм или хронических '
                'заболеваний. Вы выполняете упражнения на свой риск и несёте ответственность за '
                'собственное самочувствие во время тренировок.',
                style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration:
                  BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _agreeTerms,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B0000),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Принимаю условия'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 56),
          const SizedBox(height: 16),
          const Text('Профиль готов!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Как хотите начать?', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startWithAi,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Сгенерировать программу с AI'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B0000),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _startManually,
              icon: const Icon(Icons.edit_note),
              label: const Text('Собрать программу самому'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ],
      ),
    );
  }
}
