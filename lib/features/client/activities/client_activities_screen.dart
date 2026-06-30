// lib/features/client/activities/client_activities_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/models.dart';
import '../../../core/services/auth_provider.dart';

class ClientActivitiesScreen extends StatefulWidget {
  const ClientActivitiesScreen({super.key});

  @override
  State<ClientActivitiesScreen> createState() => _ClientActivitiesScreenState();
}

class _ClientActivitiesScreenState extends State<ClientActivitiesScreen> {
  List<ClientActivity> _activities = [];
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
      final data = await api.getClientActivities();
      if (mounted) setState(() => _activities = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка загрузки активностей')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(ClientActivity activity) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить активность?'),
        content: Text('Удалить "${activity.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final api = context.read<AuthProvider>().api;
    try {
      await api.deleteClientActivity(activity.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ошибка удаления')));
      }
    }
  }

  void _openSheet([ClientActivity? activity]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _ActivityFormSheet(
        activity: activity,
        onSaved: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои активности'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openSheet(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _activities.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_run,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('Нет активностей',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey)),
                          SizedBox(height: 4),
                          Text('Нажмите + чтобы добавить',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: _activities.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final act = _activities[i];
                        return Dismissible(
                          key: Key(act.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.delete,
                                color: Colors.white),
                          ),
                          confirmDismiss: (_) async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Удалить активность?'),
                                content: Text('Удалить "${act.name}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Отмена'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Удалить',
                                        style:
                                            TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                            return confirm == true;
                          },
                          onDismissed: (_) => _delete(act),
                          child: Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    const Color(0xFF6A1B9A).withOpacity(0.1),
                                child: const Icon(Icons.directions_run,
                                    color: Color(0xFF6A1B9A), size: 20),
                              ),
                              title: Text(act.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (act.metValue != null)
                                    Text('MET: ${act.metValue}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF6A1B9A))),
                                  if (act.description != null &&
                                      act.description!.isNotEmpty)
                                    Text(act.description!,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey)),
                                ],
                              ),
                              onTap: () => _openSheet(act),
                              trailing: const Icon(Icons.edit_outlined,
                                  color: Color(0xFF6A1B9A)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

// ─── Activity Form Sheet ──────────────────────────────────────────────────────

class _ActivityFormSheet extends StatefulWidget {
  final ClientActivity? activity;
  final VoidCallback onSaved;

  const _ActivityFormSheet({this.activity, required this.onSaved});

  @override
  State<_ActivityFormSheet> createState() => _ActivityFormSheetState();
}

class _ActivityFormSheetState extends State<_ActivityFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _metCtrl;
  late final TextEditingController _descCtrl;
  bool _saving = false;

  bool get isEdit => widget.activity != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.activity?.name ?? '');
    _metCtrl = TextEditingController(
        text: widget.activity?.metValue?.toString() ?? '');
    _descCtrl =
        TextEditingController(text: widget.activity?.description ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _metCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Введите название')));
      return;
    }
    setState(() => _saving = true);
    final api = context.read<AuthProvider>().api;
    final metValue = double.tryParse(_metCtrl.text.trim());
    final desc = _descCtrl.text.trim();
    try {
      if (isEdit) {
        await api.updateClientActivity(
          widget.activity!.id,
          name: name,
          metValue: metValue,
          description: desc.isNotEmpty ? desc : null,
        );
      } else {
        await api.createClientActivity(
          name: name,
          metValue: metValue,
          description: desc.isNotEmpty ? desc : null,
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
      }
    } catch (e) {
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
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          Text(
            isEdit ? 'Редактировать активность' : 'Новая активность',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Название *',
              border: OutlineInputBorder(),
            ),
            autofocus: !isEdit,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _metCtrl,
            decoration: const InputDecoration(
              labelText: 'MET коэффициент',
              hintText: 'например 8.0 для бега',
              border: OutlineInputBorder(),
              helperText: 'Необязательно',
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Описание',
              border: OutlineInputBorder(),
              helperText: 'Необязательно',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Сохранить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
