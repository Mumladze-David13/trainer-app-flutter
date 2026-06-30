// lib/features/trainer/clients/clients_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/models.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/widgets/app_scaffold.dart';
import 'client_detail_screen.dart';

class ClientsListScreen extends StatefulWidget {
  const ClientsListScreen({super.key});

  @override
  State<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends State<ClientsListScreen> {
  List<dynamic> _clients = [];
  List<User> _allUsers = [];
  bool _loading = true;
  bool _showAddForm = false;
  String? _selectedUserId;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = context.read<AuthProvider>().api;
    try {
      final clients = await api.getMyClients();
      final trainers = await api.getTrainers();
      setState(() {
        _clients = clients;
        _allUsers = trainers;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addClient() async {
    if (_selectedUserId == null) return;
    setState(() => _adding = true);
    final api = context.read<AuthProvider>().api;
    try {
      await api.addClient(_selectedUserId!);
      setState(() { _showAddForm = false; _selectedUserId = null; });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Клиент добавлен')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка или клиент уже добавлен')));
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().user?.id;

    return AppScaffold(
      title: 'Клиенты',
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _showAddForm = !_showAddForm),
        child: Icon(_showAddForm ? Icons.close : Icons.person_add),
      ),
      body: Column(
        children: [
          if (_showAddForm) _buildAddForm(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _clients.isEmpty
                    ? const Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('Нет клиентов', style: TextStyle(color: Colors.grey)),
                        ],
                      ))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _clients.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final item = _clients[i];
                            final client = User.fromJson(item['client']);
                            final isSelf = client.id == currentUserId;
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF8B0000),
                                  child: Text(client.initials,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                                title: Row(
                                  children: [
                                    Text(client.fullName, style: const TextStyle(fontWeight: FontWeight.w500)),
                                    if (isSelf) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF57C00),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Text('Я', style: TextStyle(color: Colors.white, fontSize: 10)),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(client.email),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ClientDetailScreen(clientId: client.id),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddForm() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Добавить клиента', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedUserId,
              decoration: const InputDecoration(labelText: 'Выберите пользователя', border: OutlineInputBorder()),
              items: _allUsers.map((u) => DropdownMenuItem(
                value: u.id,
                child: Text('${u.fullName} (${u.email})'),
              )).toList(),
              onChanged: (v) => setState(() => _selectedUserId = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => setState(() => _showAddForm = false),
                  child: const Text('Отмена'),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: _selectedUserId == null || _adding ? null : _addClient,
                  child: _adding
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Добавить'),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
