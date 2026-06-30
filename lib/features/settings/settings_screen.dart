// lib/features/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/services/auth_provider.dart';
import '../../core/widgets/app_scaffold.dart';
import '../ai/ai_usage_screen.dart';
import '../trainer/gyms/gyms_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _selectedTrainerId;
  List<User> _trainers = [];
  bool _loadingTrainer = true;
  bool _loadingClient = true;
  bool _savingTrainer = false;
  bool _savingClient = false;
  bool _savingRole = false;
  String? _selectedRole;
  final _sessionsCtrl = TextEditingController();

  final _roleOptions = const [
    _RoleOption('TRAINER', 'Тренер', 'Веду клиентов', Icons.sports),
    _RoleOption('CLIENT', 'Клиент', 'Занимаюсь у тренера', Icons.person),
    _RoleOption('TRAINER_CLIENT', 'Тренер-клиент', 'Оба режима', Icons.swap_horiz),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sessionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final api = auth.api;

    setState(() => _selectedRole = auth.user?.role.name);

    if (auth.isTrainer) {
      try {
        final s = await api.getTrainerSettings();
        setState(() {
          _sessionsCtrl.text = s.sessionsPerSeason.toString();
          _loadingTrainer = false;
        });
      } catch (_) {
        setState(() => _loadingTrainer = false);
      }
    } else {
      setState(() => _loadingTrainer = false);
    }

    // Load trainers for client settings always (needed for TRAINER_CLIENT too)
    try {
      final trainers = await api.getTrainers();
      setState(() => _trainers = trainers);
    } catch (_) {}

    if (auth.isClient) {
      try {
        final settings = await api.getClientSettings();
        setState(() {
          _selectedTrainerId = settings['trainerId'];
          _loadingClient = false;
        });
      } catch (_) {
        setState(() => _loadingClient = false);
      }
    } else {
      setState(() => _loadingClient = false);
    }
  }

  Future<void> _saveTrainerSettings() async {
    final sessions = int.tryParse(_sessionsCtrl.text);
    if (sessions == null || sessions < 1) return;
    setState(() => _savingTrainer = true);
    final api = context.read<AuthProvider>().api;
    try {
      await api.updateTrainerSettings(sessions);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Настройки сохранены')));
      }
    } finally {
      if (mounted) setState(() => _savingTrainer = false);
    }
  }

  Future<void> _saveClientSettings() async {
    setState(() => _savingClient = true);
    final api = context.read<AuthProvider>().api;
    try {
      await api.setClientTrainer(_selectedTrainerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Тренер сохранён')));
      }
    } finally {
      if (mounted) setState(() => _savingClient = false);
    }
  }

  Future<void> _saveRole() async {
    if (_selectedRole == null) return;
    final currentRole = context.read<AuthProvider>().user?.role.name;
    if (_selectedRole == currentRole) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Роль не изменилась')));
      return;
    }
    setState(() => _savingRole = true);
    final auth = context.read<AuthProvider>();
    try {
      final res = await auth.api.updateRole(_selectedRole!);
      await auth.updateUserFromResponse(res);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Роль изменена')));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка изменения роли')));
      }
    } finally {
      if (mounted) setState(() => _savingRole = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;

    return AppScaffold(
      title: 'Настройки',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Профиль',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _InfoRow('Имя', user.fullName),
                  _InfoRow('Email', user.email),
                  _InfoRow('Роль', user.role.label),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Role change card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.manage_accounts, color: Color(0xFF8B0000)),
                    SizedBox(width: 8),
                    Text('Изменить роль',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 4),
                  Text('Текущая роль: ${user.role.label}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 16),
                  Column(
                    children: _roleOptions.map((option) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => setState(() => _selectedRole = option.value),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _selectedRole == option.value
                                  ? const Color(0xFF8B0000)
                                  : Colors.grey[300]!,
                              width: _selectedRole == option.value ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: _selectedRole == option.value
                                ? const Color(0xFFFFEBEE) : null,
                          ),
                          child: Row(
                            children: [
                              Icon(option.icon, color: const Color(0xFF8B0000)),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(option.label,
                                      style: const TextStyle(fontWeight: FontWeight.w500)),
                                  Text(option.description,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                ],
                              )),
                              if (_selectedRole == option.value)
                                const Icon(Icons.check_circle, color: Color(0xFF8B0000)),
                            ],
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _savingRole ? null : _saveRole,
                      child: _savingRole
                          ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                          : const Text('Сохранить роль'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Trainer settings
          if (auth.isTrainer) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.fitness_center, color: Color(0xFF8B0000)),
                title: const Text('Мои залы'),
                subtitle: const Text('Управление залами тренировок'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GymsScreen()),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.sports, color: Color(0xFF8B0000)),
                      SizedBox(width: 8),
                      Text('Настройки тренера',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 4),
                    Text('Параметры тренировочного процесса',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    const SizedBox(height: 16),
                    if (_loadingTrainer)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      TextField(
                        controller: _sessionsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Занятий в сезоне',
                          border: OutlineInputBorder(),
                          helperText: 'Максимальное количество занятий в одном сезоне',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _savingTrainer ? null : _saveTrainerSettings,
                          child: _savingTrainer
                              ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                              : const Text('Сохранить'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Client settings
          if (auth.isClient) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.person, color: Color(0xFF8B0000)),
                      SizedBox(width: 8),
                      Text('Мой тренер',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 4),
                    Text('Выберите основного тренера',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    const SizedBox(height: 16),
                    if (_loadingClient)
                      const Center(child: CircularProgressIndicator())
                    else if (_trainers.isEmpty)
                      const Text('Нет доступных тренеров',
                          style: TextStyle(color: Colors.grey))
                    else ...[
                        DropdownButtonFormField<String?>(
                          value: _selectedTrainerId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Тренер',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('— Без тренера —')),
                            ..._trainers.map((t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(
                                t.fullName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                          ],
                          onChanged: (v) => setState(() => _selectedTrainerId = v),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _savingClient ? null : _saveClientSettings,
                            child: _savingClient
                                ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                                : const Text('Сохранить'),
                          ),
                        ),
                      ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Mode switcher for TRAINER_CLIENT
          if (auth.isTrainerClient) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.swap_horiz, color: Color(0xFF8B0000)),
                      SizedBox(width: 8),
                      Text('Режим интерфейса',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () => auth.setActiveMode(ActiveMode.trainer),
                        icon: const Icon(Icons.sports),
                        label: const Text('Тренер'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: auth.activeMode == ActiveMode.trainer
                              ? const Color(0xFFFFEBEE) : null,
                        ),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () => auth.setActiveMode(ActiveMode.client),
                        icon: const Icon(Icons.person),
                        label: const Text('Клиент'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: auth.activeMode == ActiveMode.client
                              ? const Color(0xFFFFEBEE) : null,
                        ),
                      )),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // AI usage
          Card(
            child: ListTile(
              leading: const Icon(Icons.smart_toy, color: Color(0xFF8B0000)),
              title: const Text('Использование AI'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiUsageScreen()),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Logout
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Выйти', style: TextStyle(color: Colors.red)),
              onTap: () => auth.logout(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleOption {
  final String value;
  final String label;
  final String description;
  final IconData icon;
  const _RoleOption(this.value, this.label, this.description, this.icon);
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
              width: 80,
              child: Text(label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}