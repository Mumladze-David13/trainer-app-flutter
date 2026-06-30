// lib/features/client/weight_log/weight_log_screen.dart
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/models/models.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/widgets/app_scaffold.dart';

class WeightLogScreen extends StatefulWidget {
  const WeightLogScreen({super.key});

  @override
  State<WeightLogScreen> createState() => _WeightLogScreenState();
}

class _WeightLogScreenState extends State<WeightLogScreen> {
  List<WeightLog> _logs = [];
  WeightAnalysis? _analysis;
  bool _loading = true;
  final _dateFmt = DateFormat('dd.MM.yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = context.read<AuthProvider>().api;
    try {
      final analysis = await api.getWeightAnalysis();
      if (mounted) {
        setState(() {
          _analysis = analysis;
          _logs = List.from(analysis.logs)
            ..sort((a, b) => a.date.compareTo(b.date));
        });
      }
    } catch (e) {
      // Попробовать загрузить просто список
      try {
        final logs = await api.getWeightLogs();
        if (mounted) {
          setState(() {
            _logs = List.from(logs)..sort((a, b) => a.date.compareTo(b.date));
          });
        }
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(WeightLog log) async {
    final api = context.read<AuthProvider>().api;
    try {
      await api.deleteWeightLog(log.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка удаления')));
      }
    }
  }

  void _showAddSheet() {
    final weightCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Добавить взвешивание',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: weightCtrl,
              decoration: const InputDecoration(
                labelText: 'Вес (кг)',
                border: OutlineInputBorder(),
                suffixText: 'кг',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Заметка (необязательно)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final weight = double.tryParse(
                      weightCtrl.text.trim().replaceAll(',', '.'));
                  if (weight == null || weight <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Введите корректный вес')));
                    return;
                  }
                  Navigator.of(ctx).pop();
                  final api = context.read<AuthProvider>().api;
                  try {
                    await api.addWeightLog(weight,
                        notes: notesCtrl.text.trim().isNotEmpty
                            ? notesCtrl.text.trim()
                            : null);
                    await _load();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Взвешивание добавлено')));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ошибка сохранения')));
                    }
                  }
                },
                child: const Text('Сохранить'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAnalysis() {
    if (_analysis == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, sc) => SingleChildScrollView(
          controller: sc,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('AI-анализ веса',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (_analysis!.stats != null) ...[
                _StatsCard(stats: _analysis!.stats!),
                const SizedBox(height: 16),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.smart_toy, color: Color(0xFF1976D2), size: 20),
                        SizedBox(width: 8),
                        Text('Анализ',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ]),
                      const SizedBox(height: 12),
                      Text(_analysis!.analysis,
                          style: const TextStyle(fontSize: 14, height: 1.5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Журнал веса',
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSheet,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // График
                  if (_logs.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('График веса',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 180,
                              child: CustomPaint(
                                size: const Size(double.infinity, 180),
                                painter: _WeightChartPainter(logs: _logs),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Кнопка AI-анализа
                    if (_analysis != null)
                      OutlinedButton.icon(
                        onPressed: _showAnalysis,
                        icon: const Icon(Icons.smart_toy, color: Color(0xFF1976D2)),
                        label: const Text('AI-анализ',
                            style: TextStyle(color: Color(0xFF1976D2))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF1976D2)),
                          minimumSize: const Size(double.infinity, 44),
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Text('История взвешиваний',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 8),
                  ],
                  if (_logs.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            Icon(Icons.monitor_weight_outlined,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            const Text('Нет записей о весе',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey)),
                            const SizedBox(height: 4),
                            const Text('Нажмите + чтобы добавить',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    )
                  else
                    // Список в обратном порядке (новые вверху)
                    ...(_logs.reversed.map((log) => Dismissible(
                          key: Key(log.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            color: Colors.red,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (_) async {
                            return await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Удалить запись?'),
                                content: Text(
                                    'Удалить запись ${log.weightKg} кг от ${_dateFmt.format(log.date)}?'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Отмена')),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Удалить',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDismissed: (_) => _delete(log),
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    const Color(0xFF1976D2).withOpacity(0.1),
                                child: Text(
                                  log.weightKg.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1976D2),
                                  ),
                                ),
                              ),
                              title: Text(
                                '${log.weightKg} кг',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_dateFmt.format(log.date)),
                                  if (log.notes != null &&
                                      log.notes!.isNotEmpty)
                                    Text(log.notes!,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey)),
                                ],
                              ),
                              trailing: const Icon(
                                Icons.swipe_left,
                                size: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ))),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}

// ─── Stats Card ──────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final WeightStats stats;

  const _StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final change = stats.totalChange;
    final isLoss = change < 0;
    final changeColor = isLoss ? Colors.green : Colors.orange;
    final changePrefix = change > 0 ? '+' : '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Статистика',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatChip('Начало', '${stats.firstWeight} кг', Colors.grey),
                const SizedBox(width: 8),
                _StatChip('Сейчас', '${stats.lastWeight} кг',
                    const Color(0xFF1976D2)),
                const SizedBox(width: 8),
                _StatChip(
                  'Изменение',
                  '$changePrefix${change.toStringAsFixed(1)} кг',
                  changeColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatChip(
                  'Темп/нед.',
                  '${stats.weeklyRate > 0 ? '+' : ''}${stats.weeklyRate.toStringAsFixed(2)} кг',
                  Colors.purple,
                ),
                const SizedBox(width: 8),
                _StatChip(
                    'Дней', '${stats.periodDays}', Colors.teal),
                const SizedBox(width: 8),
                _StatChip(
                    'Записей', '${stats.entriesCount}', Colors.indigo),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── Weight Chart Painter ─────────────────────────────────────────────────────

class _WeightChartPainter extends CustomPainter {
  final List<WeightLog> logs;

  _WeightChartPainter({required this.logs});

  @override
  void paint(Canvas canvas, Size size) {
    if (logs.isEmpty) return;

    const leftPadding = 48.0;
    const rightPadding = 12.0;
    const topPadding = 12.0;
    const bottomPadding = 28.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    final weights = logs.map((l) => l.weightKg).toList();
    final minW = weights.reduce(min) - 1;
    final maxW = weights.reduce(max) + 1;
    final range = maxW - minW;

    // Оси
    final axisPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;

    canvas.drawLine(
      const Offset(leftPadding, topPadding),
      Offset(leftPadding, topPadding + chartHeight),
      axisPaint,
    );
    canvas.drawLine(
      Offset(leftPadding, topPadding + chartHeight),
      Offset(leftPadding + chartWidth, topPadding + chartHeight),
      axisPaint,
    );

    // Горизонтальные сетки и метки Y
    final labelStyle = TextStyle(
        fontSize: 10, color: Colors.grey.shade600);
    final tp = TextPainter(textDirection: ui.TextDirection.ltr);

    const yTicks = 4;
    for (int i = 0; i <= yTicks; i++) {
      final y = topPadding + chartHeight - (i / yTicks) * chartHeight;
      final value = minW + (i / yTicks) * range;

      // Горизонтальная линия сетки
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        Paint()
          ..color = Colors.grey.shade200
          ..strokeWidth = 0.5,
      );

      // Метка
      tp.text = TextSpan(
          text: value.toStringAsFixed(1), style: labelStyle);
      tp.layout();
      tp.paint(canvas, Offset(leftPadding - tp.width - 4, y - tp.height / 2));
    }

    // Линия графика и точки
    if (logs.length < 2) {
      // Одна точка
      final x = leftPadding + chartWidth / 2;
      final y = topPadding + chartHeight -
          ((weights.first - minW) / range) * chartHeight;
      canvas.drawCircle(
        Offset(x, y),
        4,
        Paint()..color = const Color(0xFF1976D2),
      );
      return;
    }

    final linePaint = Paint()
      ..color = const Color(0xFF1976D2)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = const Color(0xFF1976D2)
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    final points = <Offset>[];

    for (int i = 0; i < logs.length; i++) {
      final x = leftPadding + (i / (logs.length - 1)) * chartWidth;
      final y = topPadding + chartHeight -
          ((weights[i] - minW) / range) * chartHeight;
      points.add(Offset(x, y));
    }

    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    // Заливка под линией
    final fillPath = Path.from(path);
    fillPath.lineTo(points.last.dx, topPadding + chartHeight);
    fillPath.lineTo(points.first.dx, topPadding + chartHeight);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..color = const Color(0xFF1976D2).withOpacity(0.08)
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(path, linePaint);

    // Точки на графике
    for (final p in points) {
      canvas.drawCircle(p, 5, dotBorderPaint);
      canvas.drawCircle(p, 4, dotPaint);
    }

    // Подписи оси X (первая и последняя дата)
    final dateFmt = DateFormat('dd.MM');
    final xLabelStyle = TextStyle(fontSize: 9, color: Colors.grey.shade600);

    void drawXLabel(String text, double x, {bool rightAlign = false}) {
      final xTp = TextPainter(
          text: TextSpan(text: text, style: xLabelStyle),
          textDirection: ui.TextDirection.ltr);
      xTp.layout();
      final dx = rightAlign ? x - xTp.width : x;
      xTp.paint(canvas,
          Offset(dx.clamp(leftPadding, leftPadding + chartWidth - xTp.width),
              topPadding + chartHeight + 4));
    }

    drawXLabel(dateFmt.format(logs.first.date), points.first.dx);
    if (logs.length > 1) {
      drawXLabel(dateFmt.format(logs.last.date), points.last.dx,
          rightAlign: true);
    }
  }

  @override
  bool shouldRepaint(_WeightChartPainter old) => old.logs != logs;
}
