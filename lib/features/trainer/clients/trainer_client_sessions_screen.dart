// lib/features/trainer/clients/trainer_client_sessions_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/models/models.dart';
import '../../../core/services/auth_provider.dart';

class TrainerClientSessionsScreen extends StatefulWidget {
  final String clientId;
  final String clientName;
  final bool embedded;

  const TrainerClientSessionsScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    this.embedded = false,
  });

  @override
  State<TrainerClientSessionsScreen> createState() =>
      _TrainerClientSessionsScreenState();
}

class _TrainerClientSessionsScreenState
    extends State<TrainerClientSessionsScreen> {
  List<ClientSession> _sessions = [];
  bool _loading = true;
  final _dateFmt = DateFormat('dd MMMM yyyy', 'ru_RU');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = context.read<AuthProvider>().api;
    try {
      final sessions = await api.getTrainerClientSessions(widget.clientId);
      if (mounted) {
        setState(() {
          _sessions = sessions
            ..sort((a, b) => b.date.compareTo(a.date));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка загрузки занятий')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: _sessions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.self_improvement,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text('Нет самостоятельных занятий',
                      style:
                          TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text('${widget.clientName} ещё не добавил занятия',
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final s = _sessions[i];
                return _SessionCard(session: s, dateFmt: _dateFmt);
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildBody();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Занятия: ${widget.clientName}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }
}

// ─── Session Card ─────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final ClientSession session;
  final DateFormat dateFmt;

  const _SessionCard({required this.session, required this.dateFmt});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  const Color(0xFF2E7D32).withOpacity(0.1),
              child: const Icon(Icons.self_improvement,
                  color: Color(0xFF2E7D32), size: 20),
            ),
            title: Text(dateFmt.format(session.date),
                style:
                    const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
                '${session.exercises.length} ${_exWord(session.exercises.length)}'),
          ),
          if (session.notes != null && session.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(session.notes!,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.grey)),
              ),
            ),
          if (session.exercises.isNotEmpty) ...[
            const Divider(height: 1),
            ...session.exercises.map((ex) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.fitness_center,
                      size: 16, color: Colors.grey),
                  title: Text(ex.displayName),
                  subtitle: Text(_exDetails(ex),
                      style: const TextStyle(fontSize: 12)),
                )),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  String _exWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'активность';
    if (count % 10 >= 2 &&
        count % 10 <= 4 &&
        (count % 100 < 10 || count % 100 >= 20)) return 'активности';
    return 'активностей';
  }

  String _exDetails(ClientSessionExercise ex) {
    final parts = <String>[];
    if (ex.sets != null && ex.reps != null) {
      parts.add('${ex.sets} × ${ex.reps}');
    } else if (ex.sets != null) {
      parts.add('${ex.sets} подх.');
    }
    if (ex.durationMinutes != null) {
      parts.add('${ex.durationMinutes} мин');
    }
    return parts.join(' · ');
  }
}
