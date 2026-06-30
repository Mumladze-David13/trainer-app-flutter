// lib/features/client/progress/exercise_progress_screen.dart
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/models/models.dart';
import '../../../core/services/auth_provider.dart';

class ExerciseProgressScreen extends StatefulWidget {
  final String exerciseId;
  final String exerciseName;
  final String? clientId;

  const ExerciseProgressScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    this.clientId,
  });

  @override
  State<ExerciseProgressScreen> createState() =>
      _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState extends State<ExerciseProgressScreen> {
  ExerciseProgress? _progress;
  bool _loading = true;
  bool _analyzingAi = false;
  final _dateFmt = DateFormat('dd.MM.yyyy');

  bool get _isTrainer => widget.clientId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = context.read<AuthProvider>().api;
    try {
      ExerciseProgress data;
      if (_isTrainer) {
        data = await api.getClientExerciseProgress(
            widget.exerciseId, widget.clientId!);
      } else {
        data = await api.getExerciseProgress(widget.exerciseId);
      }
      if (mounted) setState(() => _progress = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка загрузки прогресса')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showAiAnalysis() async {
    setState(() => _analyzingAi = true);
    final api = context.read<AuthProvider>().api;
    try {
      ExerciseProgress analysis;
      if (_isTrainer) {
        analysis = await api.getClientExerciseProgressAnalysis(
            widget.exerciseId, widget.clientId!);
      } else {
        analysis = await api.getExerciseProgressAnalysis(widget.exerciseId);
      }
      if (!mounted) return;
      _openAnalysisSheet(analysis);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка получения AI-анализа')));
      }
    } finally {
      if (mounted) setState(() => _analyzingAi = false);
    }
  }

  void _openAnalysisSheet(ExerciseProgress analysis) {
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              Text('AI-анализ: ${widget.exerciseName}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (analysis.stats != null) ...[
                _StatsCard(stats: analysis.stats!),
                const SizedBox(height: 16),
              ],
              if (analysis.analysis != null &&
                  analysis.analysis!.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.smart_toy,
                              color: Color(0xFF1976D2), size: 20),
                          SizedBox(width: 8),
                          Text('Анализ',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                        ]),
                        const SizedBox(height: 12),
                        Text(analysis.analysis!,
                            style:
                                const TextStyle(fontSize: 14, height: 1.5)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<ExerciseProgressEntry> get _weightEntries => _progress == null
      ? []
      : _progress!.history
          .where((e) => e.weight != null)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exerciseName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _progress == null
              ? const Center(child: Text('Нет данных'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_weightEntries.isNotEmpty) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('График прогрессии',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 180,
                                  child: CustomPaint(
                                    size: const Size(double.infinity, 180),
                                    painter: _ProgressChartPainter(
                                        entries: _weightEntries),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // AI Analysis button
                      OutlinedButton.icon(
                        onPressed: _analyzingAi ? null : _showAiAnalysis,
                        icon: _analyzingAi
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.smart_toy,
                                color: Color(0xFF1976D2)),
                        label: Text(
                            _analyzingAi ? 'Анализирую...' : 'AI-анализ',
                            style: const TextStyle(color: Color(0xFF1976D2))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF1976D2)),
                          minimumSize: const Size(double.infinity, 44),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // History table
                      if (_progress!.history.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.trending_up,
                                    size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Нет данных о прогрессии',
                                    style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        const Text('История',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 8),
                        Card(
                          child: Table(
                            columnWidths: const {
                              0: FlexColumnWidth(2),
                              1: FlexColumnWidth(1.5),
                              2: FlexColumnWidth(1.5),
                            },
                            children: [
                              TableRow(
                                decoration: BoxDecoration(
                                    color: Colors.grey[100]),
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    child: Text('Дата',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    child: Text('Вес (кг)',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    child: Text('Подх. × Повт.',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12)),
                                  ),
                                ],
                              ),
                              ..._progress!.history
                                  .reversed
                                  .map((e) => TableRow(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            child: Text(
                                                _dateFmt.format(e.date),
                                                style: const TextStyle(
                                                    fontSize: 12)),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 8),
                                            child: Text(
                                              e.weight != null
                                                  ? '${e.weight} кг'
                                                  : '—',
                                              style:
                                                  const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 8),
                                            child: Text(
                                              e.sets != null && e.reps != null
                                                  ? '${e.sets} × ${e.reps}'
                                                  : e.sets != null
                                                      ? '${e.sets} подх.'
                                                      : '—',
                                              style:
                                                  const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      )),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }
}

// ─── Stats Card ───────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final ExerciseProgressStats stats;

  const _StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final gain = stats.totalGain;
    final gainColor = gain >= 0 ? Colors.green : Colors.orange;
    final gainPrefix = gain > 0 ? '+' : '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Статистика',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatChip(
                  'Начало',
                  stats.firstWeight != null
                      ? '${stats.firstWeight} кг'
                      : '—',
                  Colors.grey,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  'Сейчас',
                  stats.lastWeight != null
                      ? '${stats.lastWeight} кг'
                      : '—',
                  const Color(0xFF1976D2),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  'Прирост',
                  '$gainPrefix${gain.toStringAsFixed(1)} кг',
                  gainColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatChip('Дней', '${stats.periodDays}', Colors.teal),
                const SizedBox(width: 8),
                _StatChip(
                    'Сессий', '${stats.sessionsCount}', Colors.indigo),
                const SizedBox(width: 8),
                const Expanded(child: SizedBox()),
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

// ─── Progress Chart Painter ───────────────────────────────────────────────────

class _ProgressChartPainter extends CustomPainter {
  final List<ExerciseProgressEntry> entries;

  _ProgressChartPainter({required this.entries});

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;

    const leftPadding = 52.0;
    const rightPadding = 12.0;
    const topPadding = 12.0;
    const bottomPadding = 28.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    final weights =
        entries.map((e) => e.weight!).toList();
    final minW = weights.reduce(min) - 1;
    final maxW = weights.reduce(max) + 1;
    final range = maxW - minW;

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

    final labelStyle = TextStyle(fontSize: 10, color: Colors.grey.shade600);
    final tp = TextPainter(textDirection: ui.TextDirection.ltr);

    const yTicks = 4;
    for (int i = 0; i <= yTicks; i++) {
      final y = topPadding + chartHeight - (i / yTicks) * chartHeight;
      final value = minW + (i / yTicks) * range;

      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        Paint()
          ..color = Colors.grey.shade200
          ..strokeWidth = 0.5,
      );

      tp.text = TextSpan(text: value.toStringAsFixed(1), style: labelStyle);
      tp.layout();
      tp.paint(canvas, Offset(leftPadding - tp.width - 4, y - tp.height / 2));
    }

    if (entries.length < 2) {
      final x = leftPadding + chartWidth / 2;
      final y = topPadding +
          chartHeight -
          ((weights.first - minW) / range) * chartHeight;
      canvas.drawCircle(
          Offset(x, y), 5, Paint()..color = const Color(0xFF8B0000));
      return;
    }

    final linePaint = Paint()
      ..color = const Color(0xFF8B0000)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final points = <Offset>[];

    for (int i = 0; i < entries.length; i++) {
      final x =
          leftPadding + (i / (entries.length - 1)) * chartWidth;
      final y = topPadding +
          chartHeight -
          ((weights[i] - minW) / range) * chartHeight;
      points.add(Offset(x, y));
    }

    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final fillPath = Path.from(path);
    fillPath.lineTo(points.last.dx, topPadding + chartHeight);
    fillPath.lineTo(points.first.dx, topPadding + chartHeight);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..color = const Color(0xFF8B0000).withOpacity(0.07)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(path, linePaint);

    for (final p in points) {
      canvas.drawCircle(p, 5, Paint()..color = Colors.white);
      canvas.drawCircle(p, 4, Paint()..color = const Color(0xFF8B0000));
    }

    final dateFmt = DateFormat('dd.MM');
    final xLabelStyle = TextStyle(fontSize: 9, color: Colors.grey.shade600);

    void drawXLabel(String text, double x, {bool rightAlign = false}) {
      final xTp = TextPainter(
          text: TextSpan(text: text, style: xLabelStyle),
          textDirection: ui.TextDirection.ltr);
      xTp.layout();
      final dx = rightAlign ? x - xTp.width : x;
      xTp.paint(
          canvas,
          Offset(
              dx.clamp(leftPadding, leftPadding + chartWidth - xTp.width),
              topPadding + chartHeight + 4));
    }

    drawXLabel(dateFmt.format(entries.first.date), points.first.dx);
    if (entries.length > 1) {
      drawXLabel(dateFmt.format(entries.last.date), points.last.dx,
          rightAlign: true);
    }
  }

  @override
  bool shouldRepaint(_ProgressChartPainter old) =>
      old.entries != entries;
}
