// lib/features/solo/solo_gate_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/services/auth_provider.dart';
import 'solo_dashboard_screen.dart';
import 'solo_onboarding_screen.dart';

// Точка входа для роли SOLO (см. flutter-prompt-solo-mode-20260824.md):
// GET /solo/profile решает, показывать ли онбординг или главный SOLO-экран.
// Используется вместо обычного DashboardScreen, когда user.role == SOLO.
class SoloGateScreen extends StatefulWidget {
  const SoloGateScreen({super.key});

  @override
  State<SoloGateScreen> createState() => _SoloGateScreenState();
}

class _SoloGateScreenState extends State<SoloGateScreen> {
  bool _loading = true;
  SoloProfile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = context.read<AuthProvider>().api;
    try {
      final profile = await api.getSoloProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      // Не удалось загрузить профиль — покажем онбординг, пользователь
      // сможет заново сохранить данные.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_profile == null) {
      return SoloOnboardingScreen(onDone: _load);
    }
    if (!_profile!.hasAgreedToTerms) {
      return SoloOnboardingScreen(onDone: _load, initialStep: 2);
    }
    return const SoloDashboardScreen();
  }
}
