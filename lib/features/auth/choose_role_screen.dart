// lib/features/auth/choose_role_screen.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_provider.dart';
import '../dashboard/dashboard_screen.dart';

class _RoleOption {
  final String value;
  final String label;
  final String description;
  final IconData icon;
  const _RoleOption(this.value, this.label, this.description, this.icon);
}

// Shown once, right after a brand-new user's first Google/VK/Mail.ru login
// (the backend defaults such accounts to CLIENT). Role choice reuses the same
// PUT /users/me/role endpoint as the settings screen.
class ChooseRoleScreen extends StatefulWidget {
  const ChooseRoleScreen({super.key});

  @override
  State<ChooseRoleScreen> createState() => _ChooseRoleScreenState();
}

class _ChooseRoleScreenState extends State<ChooseRoleScreen> {
  String? _selectedRole;
  bool _loading = false;
  String? _error;

  final _roles = const [
    _RoleOption('TRAINER', 'Тренер', 'Веду клиентов', Icons.sports),
    _RoleOption('CLIENT', 'Клиент', 'Занимаюсь у тренера', Icons.person),
    _RoleOption('TRAINER_CLIENT', 'Тренер-клиент', 'Оба режима', Icons.swap_horiz),
    _RoleOption('SOLO', 'Соло', 'Тренируюсь сам с AI-помощником', Icons.self_improvement),
  ];

  Future<void> _continue() async {
    if (_selectedRole == null) {
      _goToDashboard();
      return;
    }
    setState(() { _loading = true; _error = null; });
    final auth = context.read<AuthProvider>();
    try {
      final res = await auth.api.updateRole(_selectedRole!);
      await auth.updateUserFromResponse(res);
      _goToDashboard();
    } catch (e) {
      if (mounted) setState(() => _error = 'Не удалось сохранить роль');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToDashboard() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: kIsWeb ? 480 : double.infinity),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72, height: 72,
                        decoration: const BoxDecoration(color: Color(0xFF8B0000), shape: BoxShape.circle),
                        child: const Icon(Icons.fitness_center, color: Colors.white, size: 36),
                      ),
                      const SizedBox(height: 16),
                      const Text('Добро пожаловать!',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Выберите, как вы будете пользоваться приложением',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 20),
                      Column(
                        children: _roles.map((role) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () => setState(() => _selectedRole = role.value),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _selectedRole == role.value
                                      ? const Color(0xFF8B0000) : Colors.grey[300]!,
                                  width: _selectedRole == role.value ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color: _selectedRole == role.value ? const Color(0xFFE3F2FD) : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(role.icon, color: const Color(0xFF8B0000)),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(role.label, style: const TextStyle(fontWeight: FontWeight.w500)),
                                      Text(role.description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                    ],
                                  )),
                                  if (_selectedRole == role.value)
                                    const Icon(Icons.check_circle, color: Color(0xFF8B0000)),
                                ],
                              ),
                            ),
                          ),
                        )).toList(),
                      ),
                      if (_selectedRole == 'TRAINER_CLIENT') ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Планируете тренироваться только сами, без своих клиентов? '
                                  'Выберите режим «Соло» — это дешевле (от 250 ₽/мес против '
                                  '2000 ₽/мес за «Тренер-клиент»).',
                                  style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                          child: Text(_error!, style: const TextStyle(color: Colors.red)),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity, height: 48,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _continue,
                          child: _loading
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Продолжить', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading ? null : _goToDashboard,
                        child: const Text('Пропустить'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
