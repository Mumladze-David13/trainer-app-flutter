// lib/features/solo/solo_generate_program_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_provider.dart';
import '../ai/ai_error_text.dart';

// Одношаговая AI-генерация для SOLO: POST /solo/generate-program сразу
// добавляет занятия в текущий сезон (новый — только при переполнении) (в отличие от тренерского
// /ai/generate-program + /ai/save-program). Пока на проде не настроен ключ
// AI-провайдера, эндпоинт может вернуть 500 — обрабатываем как обычную
// сетевую ошибку и предлагаем ручной путь, не блокируя пользователя
// (см. flutter-prompt-solo-mode-20260824.md).
class SoloGenerateProgramScreen extends StatefulWidget {
  const SoloGenerateProgramScreen({super.key});

  @override
  State<SoloGenerateProgramScreen> createState() => _SoloGenerateProgramScreenState();
}

class _SoloGenerateProgramScreenState extends State<SoloGenerateProgramScreen> {
  // Сначала выбор количества тренировок, генерация — по кнопке.
  bool _picking = true;
  bool _loading = false;
  bool _failed = false;
  Map<String, dynamic>? _result;
  int _workoutsCount = 3;

  @override
  void initState() {
    super.initState();
    _loadDefaultCount();
  }

  // По умолчанию — daysPerWeek из SOLO-профиля (как и на бэке).
  Future<void> _loadDefaultCount() async {
    try {
      final profile = await context.read<AuthProvider>().api.getSoloProfile();
      if (mounted && profile != null) {
        setState(() => _workoutsCount = profile.daysPerWeek.clamp(1, 7));
      }
    } catch (_) {}
  }

  Future<void> _generate() async {
    setState(() { _picking = false; _loading = true; _failed = false; });
    final api = context.read<AuthProvider>().api;
    try {
      final result = await api.generateSoloProgram(workoutsCount: _workoutsCount);
      if (mounted) setState(() { _result = result; _loading = false; });
    } on DioException catch (e) {
      if (mounted) {
        setState(() { _failed = true; _loading = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Не удалось сгенерировать программу, попробуйте позже или добавьте тренировки вручную\n${aiErrorDetail(e)}'),
        ));
      }
    } catch (_) {
      if (mounted) setState(() { _failed = true; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI-генерация программы'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(_result != null ? true : null),
        ),
      ),
      body: _picking
          ? _buildPicker()
          : _loading
          ? _buildLoading()
          : _failed
              ? _buildFailed()
              : _buildResult(),
    );
  }

  Widget _buildPicker() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Сколько тренировок создать',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Тренировки добавятся в текущий сезон после последней запланированной',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [1, 2, 3, 4, 5, 6, 7]
                .map((n) => GestureDetector(
                      onTap: () => setState(() => _workoutsCount = n),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: _workoutsCount == n
                            ? const Color(0xFF8B0000)
                            : Colors.grey.shade200,
                        child: Text(
                          '$n',
                          style: TextStyle(
                            color: _workoutsCount == n ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ))
                .toList(),
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
        ],
      ),
    );
  }

  Widget _buildLoading() {
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
          Text('Это может занять 15–30 секунд', style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildFailed() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.orange, size: 56),
            const SizedBox(height: 16),
            const Text('Не удалось сгенерировать программу',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Попробуйте позже или добавьте тренировки вручную',
                style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.refresh),
                label: const Text('Попробовать снова'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B0000), foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Собрать программу самому'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final season = _result!['season'] as Map<String, dynamic>?;
    final newSeason = _result!['newSeason'] as Map<String, dynamic>?;
    final workoutsCreated = _result!['workoutsCreated'] as int? ?? 0;
    final recommendations = _result!['recommendations'] as String? ?? '';
    final usage = _result!['usage'] as Map<String, dynamic>?;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(children: [
                  const Icon(Icons.celebration, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${season?['name'] ?? 'Сезон'}: добавлено $workoutsCreated занятий',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                    ),
                  ),
                ]),
              ),
              if (newSeason != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Часть тренировок не поместилась в текущий сезон — создан «${newSeason['name']}»',
                        style: TextStyle(color: Colors.blue.shade800, fontSize: 13),
                      ),
                    ),
                  ]),
                ),
              ],
              if (usage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.toll, color: Color(0xFF8B0000), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Использовано ${usage['totalTokens']} токенов · '
                        '\$${(usage['costUsd'] as num?)?.toStringAsFixed(4) ?? '0'}',
                        style: const TextStyle(color: Color(0xFF8B0000), fontSize: 13),
                      ),
                    ),
                  ]),
                ),
              ],
              if (recommendations.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
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
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, -2))
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B0000), foregroundColor: Colors.white),
              child: const Text('Готово'),
            ),
          ),
        ),
      ],
    );
  }
}
