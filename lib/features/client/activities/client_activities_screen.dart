// lib/features/client/activities/client_activities_screen.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/models/models.dart';
import '../../../core/services/auth_provider.dart';

// На широких web-экранах модальный bottom sheet растягивается на всю ширину
// окна и "прилипает" к низу — выглядит странно. На таких экранах показываем
// ту же форму в виде обычного центрированного диалога вместо шторки снизу.
bool _isWideScreen(BuildContext context) =>
    kIsWeb && MediaQuery.of(context).size.width >= 700;

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
        content: Text(
            'Удалить "${activity.name}" вместе со всей историей выполнения?'),
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

  void _openEditSheet([ClientActivity? activity]) {
    if (_isWideScreen(context)) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _ActivityFormSheet(
              activity: activity,
              onSaved: _load,
              showDragHandle: false,
            ),
          ),
        ),
      );
      return;
    }
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
        onPressed: () => _openEditSheet(),
        tooltip: 'Новая активность в справочнике',
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _activities.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Icon(Icons.directions_run,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Center(
                          child: Text('Нет активностей',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey)),
                        ),
                        SizedBox(height: 4),
                        Center(
                          child: Text('Нажмите + чтобы добавить в справочник',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: _activities.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _ActivityCard(
                        activity: _activities[i],
                        onEdit: () => _openEditSheet(_activities[i]),
                        onDelete: () => _delete(_activities[i]),
                      ),
                    ),
            ),
    );
  }
}

// ─── Activity Card (справочник + история выполнения) ─────────────────────────

class _ActivityCard extends StatefulWidget {
  final ClientActivity activity;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ActivityCard({
    required this.activity,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  bool _expanded = false;
  bool _loadingLogs = false;
  bool _loadedOnce = false;
  List<ClientActivityLog> _logs = [];
  final _dateFmt = DateFormat('dd.MM.yyyy', 'ru_RU');

  Future<void> _loadLogs() async {
    setState(() => _loadingLogs = true);
    final api = context.read<AuthProvider>().api;
    try {
      final logs = await api.getClientActivityLogs(widget.activity.id);
      if (mounted) setState(() { _logs = logs; _loadedOnce = true; });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось загрузить историю')));
      }
    } finally {
      if (mounted) setState(() => _loadingLogs = false);
    }
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    if (_expanded && !_loadedOnce) _loadLogs();
  }

  Future<void> _addLog() async {
    final activity = widget.activity;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _ActivityLogFormSheet(activity: activity),
    );
    if (result == true) _loadLogs();
  }

  Future<void> _deleteLog(ClientActivityLog log) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить запись?'),
        content: Text(
            'Удалить запись от ${_dateFmt.format(log.date)} (${_formatValue(log.value)} ${widget.activity.unit.label})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final api = context.read<AuthProvider>().api;
    try {
      await api.deleteClientActivityLog(widget.activity.id, log.id);
      _loadLogs();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ошибка удаления')));
      }
    }
  }

  String _formatValue(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  Widget build(BuildContext context) {
    final act = widget.activity;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF6A1B9A).withOpacity(0.1),
              child: const Icon(Icons.directions_run,
                  color: Color(0xFF6A1B9A), size: 20),
            ),
            title: Text(act.name,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Учёт: ${act.unit.label}${act.metValue != null ? ' · MET: ${act.metValue}' : ''}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6A1B9A))),
                if (act.description != null && act.description!.isNotEmpty)
                  Text(act.description!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            onTap: _toggleExpanded,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 20, color: Color(0xFF6A1B9A)),
                  tooltip: 'Редактировать справочник',
                  onPressed: widget.onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: Colors.red),
                  tooltip: 'Удалить активность',
                  onPressed: widget.onDelete,
                ),
                IconButton(
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: _toggleExpanded,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  const Text('История выполнения',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addLog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Записать'),
                    style: TextButton.styleFrom(minimumSize: const Size(0, 32)),
                  ),
                ],
              ),
            ),
            if (_loadingLogs)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_logs.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text('Пока нет записей', style: TextStyle(color: Colors.grey)),
              )
            else
              ..._logs.map((log) => Dismissible(
                    key: Key(log.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      await _deleteLog(log);
                      return false;
                    },
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.check_circle_outline,
                          color: Color(0xFF6A1B9A), size: 20),
                      title: Text(_dateFmt.format(log.date)),
                      trailing: Text(
                        '${_formatValue(log.value)} ${act.unit.label}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  )),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

// ─── Log Entry Form Sheet ──────────────────────────────────────────────────────

class _ActivityLogFormSheet extends StatefulWidget {
  final ClientActivity activity;
  const _ActivityLogFormSheet({required this.activity});

  @override
  State<_ActivityLogFormSheet> createState() => _ActivityLogFormSheetState();
}

class _ActivityLogFormSheetState extends State<_ActivityLogFormSheet> {
  final _valueCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;
  final _fmtShort = DateFormat('dd.MM.yyyy');

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final value = double.tryParse(_valueCtrl.text.trim().replaceAll(',', '.'));
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Введите значение больше нуля')));
      return;
    }
    setState(() => _saving = true);
    final api = context.read<AuthProvider>().api;
    try {
      await api.addClientActivityLog(widget.activity.id, value, date: _date);
      if (mounted) Navigator.of(context).pop(true);
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
    final unit = widget.activity.unit;
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
                  color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          Text('Записать: ${widget.activity.name}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Дата',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(_fmtShort.format(_date)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _valueCtrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: unit == ActivityUnit.km ? 'Сколько км' : 'Сколько раз',
              border: const OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

// ─── Activity Form Sheet (справочник) ─────────────────────────────────────────

class _ActivityFormSheet extends StatefulWidget {
  final ClientActivity? activity;
  final VoidCallback onSaved;
  final bool showDragHandle;

  const _ActivityFormSheet({
    this.activity,
    required this.onSaved,
    this.showDragHandle = true,
  });

  @override
  State<_ActivityFormSheet> createState() => _ActivityFormSheetState();
}

class _ActivityFormSheetState extends State<_ActivityFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _metCtrl;
  late final TextEditingController _descCtrl;
  late ActivityUnit _unit;
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
    _unit = widget.activity?.unit ?? ActivityUnit.times;
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
          unit: _unit,
        );
      } else {
        await api.createClientActivity(
          name: name,
          metValue: metValue,
          description: desc.isNotEmpty ? desc : null,
          unit: _unit,
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
          if (widget.showDragHandle) ...[
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
          ],
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
          const Text('Как считать выполнение',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          SegmentedButton<ActivityUnit>(
            segments: const [
              ButtonSegment(value: ActivityUnit.times, label: Text('Разы')),
              ButtonSegment(value: ActivityUnit.km, label: Text('Километры')),
            ],
            selected: {_unit},
            onSelectionChanged: (v) => setState(() => _unit = v.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _metCtrl,
            decoration: const InputDecoration(
              labelText: 'MET коэффициент',
              hintText: 'например 8.0 для бега',
              border: OutlineInputBorder(),
              helperText: 'Необязательно, для расчёта калорий',
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
