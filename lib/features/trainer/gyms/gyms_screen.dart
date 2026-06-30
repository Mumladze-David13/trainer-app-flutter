import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/models.dart';
import '../../../core/services/auth_provider.dart';
import 'address_search_field.dart';

class GymsScreen extends StatefulWidget {
  const GymsScreen({super.key});

  @override
  State<GymsScreen> createState() => _GymsScreenState();
}

class _GymsScreenState extends State<GymsScreen> {
  List<Gym> _gyms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AuthProvider>().api;
      final gyms = await api.getGyms();
      if (mounted) setState(() { _gyms = gyms; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(Gym gym) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить зал?'),
        content: Text('«${gym.name}» будет удалён.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<AuthProvider>().api.deleteGym(gym.id);
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка удаления')));
      }
    }
  }

  void _openForm({Gym? gym}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _GymFormSheet(gym: gym),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои залы'),
        backgroundColor: const Color(0xFF8B0000),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: const Color(0xFF8B0000),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _gyms.isEmpty
              ? const Center(
                  child: Text('Нет залов. Нажмите «+» чтобы добавить.',
                      style: TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: _gyms.length,
                    itemBuilder: (context, i) {
                      final gym = _gyms[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Dismissible(
                          key: ValueKey(gym.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (_) async {
                            await _delete(gym);
                            return false;
                          },
                          child: _GymCard(
                            gym: gym,
                            onEdit: () => _openForm(gym: gym),
                            onDelete: () => _delete(gym),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _GymCard extends StatelessWidget {
  final Gym gym;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GymCard({required this.gym, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFFEBEE),
          child: Icon(Icons.fitness_center, color: Color(0xFF8B0000)),
        ),
        title: Text(gym.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: gym.address != null
            ? Text(gym.address!.displayShort,
                style: TextStyle(color: Colors.grey[600], fontSize: 13))
            : null,
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Row(
              children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Редактировать')],
            )),
            const PopupMenuItem(value: 'delete', child: Row(
              children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8),
                Text('Удалить', style: TextStyle(color: Colors.red))],
            )),
          ],
        ),
      ),
    );
  }
}

class _GymFormSheet extends StatefulWidget {
  final Gym? gym;
  const _GymFormSheet({this.gym});

  @override
  State<_GymFormSheet> createState() => _GymFormSheetState();
}

class _GymFormSheetState extends State<_GymFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  Address? _address;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.gym != null) {
      _nameCtrl.text = widget.gym!.name;
      _address = widget.gym!.address;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final api = context.read<AuthProvider>().api;
    try {
      if (widget.gym == null) {
        await api.createGym(_nameCtrl.text.trim(), address: _address);
      } else {
        await api.updateGym(widget.gym!.id,
            name: _nameCtrl.text.trim(), address: _address);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('409')
            ? 'Зал с таким названием уже существует'
            : 'Ошибка сохранения';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.gym != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(isEdit ? 'Редактировать зал' : 'Новый зал',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Название зала *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите название' : null,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            AddressSearchField(
              initialValue: _address,
              onSelected: (a) => setState(() => _address = a),
              onClear: () => setState(() => _address = null),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B0000),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(isEdit ? 'Сохранить' : 'Создать'),
            ),
          ],
        ),
      ),
    );
  }
}
