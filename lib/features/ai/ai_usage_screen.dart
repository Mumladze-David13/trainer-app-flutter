// lib/features/ai/ai_usage_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_provider.dart';

class AiUsageScreen extends StatefulWidget {
  const AiUsageScreen({super.key});

  @override
  State<AiUsageScreen> createState() => _AiUsageScreenState();
}

class _AiUsageScreenState extends State<AiUsageScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final api = context.read<AuthProvider>().api;
    try {
      final data = await api.aiGetUsage();
      if (mounted) setState(() => _data = data);
    } catch (_) {
      if (mounted) setState(() => _error = 'Ошибка загрузки данных');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _planColor(String plan) => switch (plan) {
        'FREE' => Colors.grey,
        'BASIC' => Colors.blue,
        'PRO' => Colors.purple,
        'UNLIMITED' => Colors.amber.shade700,
        _ => Colors.grey,
      };

  String _planLabel(String plan) => switch (plan) {
        'FREE' => 'Бесплатный',
        'BASIC' => 'Базовый',
        'PRO' => 'Профессиональный',
        'UNLIMITED' => 'Безлимитный',
        _ => plan,
      };

  String _operationLabel(String op) => switch (op) {
        'generate_program' => 'Генерация программы',
        'chat' => 'Чат с AI',
        _ => op,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Использование AI'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                          onPressed: _load, child: const Text('Повторить')),
                    ],
                  ),
                )
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final d = _data!;
    final plan = d['plan'] as String;
    final monthlyLimit = d['monthlyLimit'] as int?;
    final tokensUsed = d['tokensUsed'] as int;
    final percentUsed = (d['percentUsed'] as num).toDouble();
    final costThisMonth = (d['costThisMonth'] as num).toDouble();
    final requestsThisMonth = d['requestsThisMonth'] as int;
    final recentHistory = d['recentHistory'] as List;
    final planColor = _planColor(plan);
    final fmt = DateFormat('dd.MM.yyyy HH:mm');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.smart_toy),
                  SizedBox(width: 8),
                  Text('Тарифный план',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 12),

                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: planColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_planLabel(plan),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),

                if (monthlyLimit != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Токены в этом месяце',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey)),
                      Text('$tokensUsed / $monthlyLimit',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (percentUsed / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(
                        percentUsed > 90
                            ? Colors.red
                            : percentUsed > 70
                                ? Colors.orange
                                : Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${percentUsed.toStringAsFixed(1)}% использовано',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ] else
                  const Text('Безлимитное использование',
                      style: TextStyle(
                          color: Colors.amber, fontWeight: FontWeight.w500)),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        label: 'Стоимость в месяц',
                        value: '\$${costThisMonth.toStringAsFixed(4)}',
                        icon: Icons.attach_money,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatBox(
                        label: 'Запросов',
                        value: '$requestsThisMonth',
                        icon: Icons.send,
                        color: const Color(0xFF8B0000),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.upgrade),
            label: const Text('Улучшить тариф'),
            style: ElevatedButton.styleFrom(
                backgroundColor: planColor, foregroundColor: Colors.white),
          ),
        ),

        if (recentHistory.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('История запросов',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...recentHistory.map((h) {
            final created = DateTime.parse(h['createdAt'] as String);
            final cost = (h['costUsd'] as num).toDouble();
            final tokens = h['totalTokens'] as int;
            final operation = h['operation'] as String;

            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.history, size: 20, color: Color(0xFF8B0000)),
                title: Text(_operationLabel(operation),
                    style: const TextStyle(fontSize: 14)),
                subtitle: Text(fmt.format(created),
                    style: const TextStyle(fontSize: 12)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$tokens токенов',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                    Text('\$${cost.toStringAsFixed(4)}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
