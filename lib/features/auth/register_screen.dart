// lib/features/auth/register_screen.dart
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

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _selectedRole;
  bool _loading = false;
  bool _showPass = false;
  String? _error;

  final _roles = const [
    _RoleOption('TRAINER', 'Тренер', 'Веду клиентов', Icons.sports),
    _RoleOption('CLIENT', 'Клиент', 'Занимаюсь у тренера', Icons.person),
    _RoleOption('TRAINER_CLIENT', 'Тренер-клиент', 'Оба режима', Icons.swap_horiz),
  ];

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == null) {
      setState(() => _error = 'Выберите роль');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<AuthProvider>().register(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        role: _selectedRole!,
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _error = 'Ошибка регистрации. Возможно email уже занят.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72, height: 72,
                        decoration: const BoxDecoration(color: Color(0xFF8B0000), shape: BoxShape.circle),
                        child: const Icon(Icons.fitness_center, color: Colors.white, size: 36),
                      ),
                      const SizedBox(height: 16),
                      const Text('Регистрация',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      Row(children: [
                        Expanded(child: TextFormField(
                          controller: _firstNameCtrl,
                          decoration: const InputDecoration(labelText: 'Имя', border: OutlineInputBorder()),
                          validator: (v) => v == null || v.isEmpty ? 'Обязательно' : null,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(
                          controller: _lastNameCtrl,
                          decoration: const InputDecoration(labelText: 'Фамилия', border: OutlineInputBorder()),
                          validator: (v) => v == null || v.isEmpty ? 'Обязательно' : null,
                        )),
                      ]),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Введите email';
                          if (!v.contains('@')) return 'Некорректный email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: !_showPass,
                        decoration: InputDecoration(
                          labelText: 'Пароль',
                          prefixIcon: const Icon(Icons.lock),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _showPass = !_showPass),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Введите пароль';
                          if (v.length < 6) return 'Минимум 6 символов';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Выберите роль', style: TextStyle(fontSize: 14, color: Colors.grey)),
                      ),
                      const SizedBox(height: 8),
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
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Зарегистрироваться', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Уже есть аккаунт?'),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Войти'),
                          ),
                        ],
                      ),
                    ],
                  ),
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
