// lib/features/solo/solo_generate_program_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_provider.dart';

// Одношаговая AI-генерация для SOLO: POST /solo/generate-program сразу
// создаёт сезон и занятия на бэке (в отличие от тренерского
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
  bool _loading = true;
  bool _failed = false;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() { _loading = true; _failed = false; });
    final api = context.read<AuthProvider>().api;
    try {
      final result = await api.generateSoloProgram();
      if (mounted) setState(() { _result = result; _loading = false; });
    } on DioException catch (_) {
      if (mounted) {
        setState(() { _failed = true; _loading = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Не удалось сгенерировать программу, попробуйте позже или добавьте тренировки вручную'),
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
      body: _loading
          ? _buildLoading()
          : _failed
              ? _buildFailed()
              : _buildResult(),
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
                      '${season?['name'] ?? 'Программа'} создана: $workoutsCreated занятий',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                    ),
                  ),
                ]),
              ),
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
