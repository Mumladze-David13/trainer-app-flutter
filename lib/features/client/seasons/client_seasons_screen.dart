// lib/features/client/seasons/client_seasons_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/models/models.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../workout/client_workout_screen.dart';
import '../sessions/client_sessions_screen.dart';
import '../reports/client_reports_screen.dart';
import '../../chat/chat_screen.dart';

class ClientSeasonsScreen extends StatefulWidget {
  const ClientSeasonsScreen({super.key});

  @override
  State<ClientSeasonsScreen> createState() => _ClientSeasonsScreenState();
}

class _ClientSeasonsScreenState extends State<ClientSeasonsScreen> {
  List<Season> _seasons = [];
  bool _loading = true;
  String? _trainerId;
  String? _trainerName;
  final _fmt = DateFormat('EEEE, dd.MM.yyyy', 'ru_RU');
  final _fmtShort = DateFormat('dd.MM.yyyy');

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    final api = auth.api;
    try {
      final settings = await api.getClientSettings();
      _trainerId = settings['trainerId'];

      if (_trainerId != null) {
        final seasons = await api.getClientSeasons(_trainerId!);
        // Получить имя тренера из списка тренеров
        try {
          final trainers = await api.getTrainers();
          final trainer = trainers.where((t) => t.id == _trainerId).toList();
          if (trainer.isNotEmpty) {
            _trainerName = trainer.first.fullName;
          }
        } catch (_) {}
        setState(() => _seasons = seasons);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openChat() {
    if (_trainerId == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(
        otherUserId: _trainerId!,
        otherUserName: _trainerName ?? 'Тренер',
      ),
    ));
  }

  Widget _buildNavButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white24,
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 15),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(icon, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Мои занятия',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _trainerId == null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_search,
                  size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Тренер не выбран',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text(
                'Перейдите в настройки, чтобы выбрать тренера',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      )
          : Column(
        children: [
          // Кнопка чата с тренером
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: InkWell(
              onTap: _openChat,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B0000),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.sports,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Чат с тренером',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 15),
                          ),
                          Text(
                            _trainerName ?? 'Ваш тренер',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chat_bubble_outline,
                        color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Кнопка самостоятельных тренировок
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ClientSessionsScreen(),
                ));
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.self_improvement,
                          color: Colors.white, size: 20),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Мои тренировки',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 15),
                          ),
                          Text(
                            'Самостоятельные занятия',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.self_improvement, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Кнопка: Отчёты
          _buildNavButton(
            title: 'Отчёты',
            subtitle: 'Анализ прогресса',
            icon: Icons.bar_chart,
            color: const Color(0xFF37474F),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ClientReportsScreen(),
            )),
          ),
          const SizedBox(height: 12),

          // Список сезонов
          Expanded(
            child: _seasons.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_note,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Нет занятий',
                      style: TextStyle(
                          color: Colors.grey, fontSize: 16)),
                  SizedBox(height: 4),
                  Text(
                    'Ваш тренер ещё не добавил занятия',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: () async {
                setState(() => _loading = true);
                await _init();
              },
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16),
                itemCount: _seasons.length,
                itemBuilder: (_, i) => _SeasonWidget(
                  season: _seasons[i],
                  isFirst: i == 0,
                  fmt: _fmt,
                  fmtShort: _fmtShort,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeasonWidget extends StatefulWidget {
  final Season season;
  final bool isFirst;
  final DateFormat fmt;
  final DateFormat fmtShort;

  const _SeasonWidget({
    required this.season,
    required this.isFirst,
    required this.fmt,
    required this.fmtShort,
  });

  @override
  State<_SeasonWidget> createState() => _SeasonWidgetState();
}

class _SeasonWidgetState extends State<_SeasonWidget> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isFirst;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.season;
    final completed = s.completedCount;
    final total = s.workouts.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.event_note, color: Color(0xFF8B0000)),
            title: Text(s.name,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
                '${widget.fmtShort.format(s.startDate)} · $completed/$total выполнено'),
            trailing: IconButton(
              icon:
              Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
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
                return sorted.asMap().entries.map((entry) {
                final i = entry.key;
                final w = entry.value;
                final isLast =
                    widget.isFirst && i == s.workouts.length - 1;
                final donePercent = w.totalCount > 0
                    ? (w.doneCount / w.totalCount * 100).round()
                    : 0;

                return Container(
                  decoration: isLast
                      ? BoxDecoration(
                    border: Border.all(
                        color: const Color(0xFF8B0000), width: 2),
                    borderRadius: BorderRadius.circular(4),
                  )
                      : null,
                  child: ListTile(
                    leading: w.isCompleted
                        ? const Icon(Icons.check_circle,
                        color: Colors.green)
                        : const Icon(Icons.radio_button_unchecked,
                        color: Colors.grey),
                    title: Text(
                      widget.fmt.format(w.date),
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      '${w.totalCount} упр.${!w.isCompleted && donePercent > 0 ? " · $donePercent% выполнено" : ""}',
                    ),
                    trailing: w.isCompleted
                        ? null
                        : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B0000),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Открыть',
                          style: TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ClientWorkoutScreen(workoutId: w.id),
                      ),
                    ),
                  ),
                );
              });
              })(),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}