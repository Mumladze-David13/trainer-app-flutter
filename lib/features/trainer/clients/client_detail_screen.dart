// lib/features/trainer/clients/client_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/models/models.dart';
import '../../../core/services/auth_provider.dart';
import '../workout/workout_editor_screen.dart';
import '../../ai/generate_program_screen.dart';
import '../../chat/chat_screen.dart';
import '../../nutrition/nutrition_screen.dart';
import 'trainer_client_sessions_screen.dart';
import 'client_reports_screen.dart';

class ClientDetailScreen extends StatefulWidget {
  final String clientId;
  const ClientDetailScreen({super.key, required this.clientId});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  ClientWithSeasons? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = context.read<AuthProvider>().api;
    try {
      final data = await api.getClientDetail(widget.clientId);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка загрузки данных клиента')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_data?.client.fullName ?? 'Клиент'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text('Ошибка загрузки'))
              : _buildDashboard(),
    );
  }

  Widget _buildDashboard() {
    final client = _data!.client;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Client info card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF8B0000),
                  child: Text(
                    client.initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(client.fullName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w500)),
                      Text(client.email,
                          style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.event_repeat,
                          size: 16, color: Colors.grey),
                      Text('${_data!.sessionsPerSeason}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                      const Text('зан/сезон',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Dashboard tiles
        LayoutBuilder(builder: (context, constraints) {
          final cols = (constraints.maxWidth / 160).floor().clamp(2, 5);
          final tiles = [
            _DashTile(
              icon: Icons.event_note,
              label: 'Тренировки',
              color: const Color(0xFF8B0000),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => _TrainingsPage(
                  clientId: widget.clientId,
                  clientName: client.fullName,
                ),
              )),
            ),
            _DashTile(
              icon: Icons.chat_bubble_outline,
              label: 'Чат',
              color: const Color(0xFF1565C0),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChatScreen(
                  otherUserId: widget.clientId,
                  otherUserName: client.fullName,
                ),
              )),
            ),
            _DashTile(
              icon: Icons.restaurant_menu_outlined,
              label: 'Питание',
              color: const Color(0xFFBF360C),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => NutritionScreen(
                  clientId: widget.clientId,
                  isTrainer: true,
                ),
              )),
            ),
            _DashTile(
              icon: Icons.self_improvement,
              label: 'Занятия',
              color: const Color(0xFF6A1B9A),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TrainerClientSessionsScreen(
                  clientId: widget.clientId,
                  clientName: client.fullName,
                ),
              )),
            ),
            _DashTile(
              icon: Icons.bar_chart,
              label: 'Отчёты',
              color: const Color(0xFF37474F),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TrainerClientReportsScreen(
                  clientId: widget.clientId,
                  clientName: client.fullName,
                ),
              )),
            ),
          ];
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 100,
            ),
            itemCount: tiles.length,
            itemBuilder: (context, i) => tiles[i],
          );
        }),
      ],
    );
  }
}

// ─── Dashboard Tile ───────────────────────────────────────────────────────────

class _DashTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DashTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Trainings Page ───────────────────────────────────────────────────────────

class _TrainingsPage extends StatefulWidget {
  final String clientId;
  final String clientName;

  const _TrainingsPage({
    required this.clientId,
    required this.clientName,
  });

  @override
  State<_TrainingsPage> createState() => _TrainingsPageState();
}

class _TrainingsPageState extends State<_TrainingsPage> {
  ClientWithSeasons? _data;
  bool _loading = true;
  bool _showSeasonForm = false;
  bool _savingSeason = false;
  DateTime _startDate = DateTime.now();
  final _fmt = DateFormat('dd.MM.yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = context.read<AuthProvider>().api;
    try {
      final data = await api.getClientDetail(widget.clientId);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка загрузки')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createSeason() async {
    setState(() => _savingSeason = true);
    final api = context.read<AuthProvider>().api;
    try {
      await api.createSeason(
          widget.clientId, _startDate.toIso8601String(), null);
      setState(() => _showSeasonForm = false);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Сезон создан')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ошибка')));
      }
    } finally {
      if (mounted) setState(() => _savingSeason = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (d != null) setState(() => _startDate = d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Тренировки — ${widget.clientName}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text('Ошибка загрузки'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_showSeasonForm) _buildSeasonForm(),

                      Row(
                        children: [
                          const Text('Сезоны',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500)),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () async {
                              if (_data!.seasons.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Сначала создайте сезон')));
                                return;
                              }
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GenerateProgramScreen(
                                    clientId: widget.clientId,
                                    clientName: widget.clientName,
                                    seasonId: _data!.seasons.first.id,
                                  ),
                                ),
                              );
                              if (result == true) _load();
                            },
                            icon: const Icon(Icons.smart_toy,
                                size: 18, color: Colors.white),
                            label: const Text('AI',
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B0000),
                              minimumSize: const Size(0, 36),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => setState(
                                () => _showSeasonForm = !_showSeasonForm),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Новый сезон'),
                            style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 36)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (_data!.seasons.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Column(children: [
                              Icon(Icons.event_note,
                                  size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Нет сезонов',
                                  style: TextStyle(color: Colors.grey)),
                            ]),
                          ),
                        )
                      else
                        ...(_data!.seasons.asMap().entries.map((entry) {
                          final i = entry.key;
                          final season = entry.value;
                          return _SeasonCard(
                            season: season,
                            sessionsPerSeason: _data!.sessionsPerSeason,
                            clientId: widget.clientId,
                            isExpanded: i == 0,
                            fmt: _fmt,
                            onReload: () => _load(),
                          );
                        })),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSeasonForm() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Новый сезон',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () =>
                      setState(() => _showSeasonForm = false),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFF8B0000), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Название присваивается автоматически: Сезон ${(_data?.seasons.length ?? 0) + 1}',
                      style: const TextStyle(
                          color: Color(0xFF8B0000), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Дата начала',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(_fmt.format(_startDate)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: OutlinedButton(
                  onPressed: () =>
                      setState(() => _showSeasonForm = false),
                  child: const Text('Отмена'),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: ElevatedButton(
                  onPressed: _savingSeason ? null : _createSeason,
                  child: _savingSeason
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Создать'),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Season Card ──────────────────────────────────────────────────────────────

class _SeasonCard extends StatefulWidget {
  final Season season;
  final int sessionsPerSeason;
  final String clientId;
  final bool isExpanded;
  final DateFormat fmt;
  final VoidCallback onReload;

  const _SeasonCard({
    required this.season,
    required this.sessionsPerSeason,
    required this.clientId,
    required this.isExpanded,
    required this.fmt,
    required this.onReload,
  });

  @override
  State<_SeasonCard> createState() => _SeasonCardState();
}

class _SeasonCardState extends State<_SeasonCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.season;
    final isAtLimit = s.workouts.length >= widget.sessionsPerSeason;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.event_note, color: Color(0xFF8B0000)),
            title: Text(s.name,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              '${widget.fmt.format(s.startDate)} · ${s.workouts.length}/${widget.sessionsPerSeason} занятий',
              style: TextStyle(
                  color: isAtLimit ? Colors.orange : Colors.green),
            ),
            trailing: IconButton(
              icon: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () =>
                  setState(() => _expanded = !_expanded),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (isAtLimit)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(children: [
                        const Icon(Icons.warning,
                            color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Text(
                            'Лимит занятий достигнут (${widget.sessionsPerSeason})',
                            style: const TextStyle(
                                color: Colors.orange, fontSize: 13)),
                      ]),
                    ),
                  Row(
                    children: [
                      const Text('Занятия',
                          style:
                              TextStyle(fontWeight: FontWeight.w500)),
                      const Spacer(),
                      if (!isAtLimit)
                        TextButton.icon(
                          onPressed: () async {
                            final result =
                                await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => WorkoutEditorScreen(
                                  clientId: widget.clientId,
                                  seasonId: s.id,
                                ),
                              ),
                            );
                            if (result == true) widget.onReload();
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Добавить'),
                          style: TextButton.styleFrom(
                              minimumSize: const Size(0, 32)),
                        ),
                    ],
                  ),
                  if (s.workouts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Нет занятий',
                          style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ...(() {
                      final sorted = List.of(s.workouts)
                        ..sort((a, b) => b.date.compareTo(a.date));
                      return sorted.map((w) => ListTile(
                            dense: true,
                            leading: w.isCompleted
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green, size: 20)
                                : const Icon(Icons.today, size: 20),
                            title: Text(widget.fmt.format(w.date)),
                            subtitle: Text(
                                '${w.workoutExercises.length} упр.${w.isCompleted ? " · выполнено" : ""}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              final result =
                                  await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => WorkoutEditorScreen(
                                    clientId: widget.clientId,
                                    workoutId: w.id,
                                    readOnly: w.isCompleted,
                                  ),
                                ),
                              );
                              if (result == true) widget.onReload();
                            },
                          ));
                    })(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
