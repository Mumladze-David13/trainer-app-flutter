// lib/core/widgets/app_scaffold.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../features/trainer/exercises/exercises_screen.dart';
import '../../features/trainer/clients/clients_list_screen.dart';
import '../../features/client/seasons/client_seasons_screen.dart';
import '../../features/client/activities/client_activities_screen.dart';
import '../../features/client/reports/client_reports_screen.dart';
import '../../features/nutrition/nutrition_screen.dart';
import '../../features/settings/settings_screen.dart';

const double _kWideBreakpoint = 700;
const double _kContentMaxWidth = 600;
const double _kSidebarWidth = 220;

bool _isWide(BuildContext context) =>
    kIsWeb && MediaQuery.of(context).size.width >= _kWideBreakpoint;

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;
  final bool showDrawer;
  final bool isDashboard;
  final VoidCallback? onBack;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.actions,
    this.showDrawer = true,
    this.isDashboard = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return _isWide(context)
        ? _buildWide(context)
        : _buildMobile(context);
  }

  // ── Мобильный layout (без изменений) ──────────────────────────────────────
  Widget _buildMobile(BuildContext context) {
    final scaffold = Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        automaticallyImplyLeading: false,
        leading: isDashboard
            ? Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack ?? () => Navigator.of(context).pop(),
              ),
      ),
      drawer: showDrawer ? const AppDrawer() : null,
      body: body,
      floatingActionButton: floatingActionButton,
    );

    if (isDashboard) {
      return PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Выйти из приложения?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Выйти', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
          if (shouldExit == true) SystemNavigator.pop();
        },
        child: scaffold,
      );
    }

    return scaffold;
  }

  // ── Web wide layout ────────────────────────────────────────────────────────
  Widget _buildWide(BuildContext context) {
    final scaffold = Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        automaticallyImplyLeading: false,
        leading: isDashboard
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack ?? () => Navigator.of(context).pop(),
              ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: _kSidebarWidth, child: _WebSidebar()),
          Container(width: 1, color: Colors.grey.shade200),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );

    if (isDashboard) {
      return PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Выйти из приложения?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Выйти', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
          if (shouldExit == true) SystemNavigator.pop();
        },
        child: scaffold,
      );
    }

    return scaffold;
  }
}

// ── Web sidebar ───────────────────────────────────────────────────────────────
class _WebSidebar extends StatelessWidget {
  const _WebSidebar();

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;

    return Material(
      color: Colors.white,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: const Color(0xFF8B0000),
            child: Row(
              children: [
                const Icon(Icons.fitness_center, color: Colors.white, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Workout Assistant',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                      Text(user.fullName,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Mode switcher for TRAINER_CLIENT
          if (auth.isTrainerClient) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
              child: Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => auth.setActiveMode(ActiveMode.trainer),
                    style: TextButton.styleFrom(
                      backgroundColor: auth.activeMode == ActiveMode.trainer
                          ? const Color(0xFFFFEBEE)
                          : null,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      textStyle: const TextStyle(fontSize: 11),
                      minimumSize: const Size(0, 28),
                    ),
                    child: const Text('Тренер'),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextButton(
                    onPressed: () => auth.setActiveMode(ActiveMode.client),
                    style: TextButton.styleFrom(
                      backgroundColor: auth.activeMode == ActiveMode.client
                          ? const Color(0xFFFFEBEE)
                          : null,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      textStyle: const TextStyle(fontSize: 11),
                      minimumSize: const Size(0, 28),
                    ),
                    child: const Text('Клиент'),
                  ),
                ),
              ]),
            ),
            const Divider(height: 1),
          ],

          // Nav items
          _SidebarTile(
            icon: Icons.dashboard,
            label: 'Главная',
            onTap: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),

          if (auth.showTrainerMenu) ...[
            const _SidebarLabel('ТРЕНЕР'),
            _SidebarTile(
              icon: Icons.list,
              label: 'Упражнения',
              onTap: () => _push(context, const ExercisesScreen()),
            ),
            _SidebarTile(
              icon: Icons.group,
              label: 'Клиенты',
              onTap: () => _push(context, const ClientsListScreen()),
            ),
          ],

          if (auth.showClientMenu) ...[
            const _SidebarLabel('КЛИЕНТ'),
            _SidebarTile(
              icon: Icons.event_note,
              label: 'Мои занятия',
              onTap: () => _push(context, const ClientSeasonsScreen()),
            ),
            _SidebarTile(
              icon: Icons.restaurant_menu,
              label: 'Питание',
              onTap: () => _push(context, NutritionScreen(clientId: context.read<AuthProvider>().user!.id)),
            ),
            _SidebarTile(
              icon: Icons.directions_run,
              label: 'Мои активности',
              onTap: () => _push(context, const ClientActivitiesScreen()),
            ),
            _SidebarTile(
              icon: Icons.bar_chart,
              label: 'Отчёты',
              onTap: () => _push(context, const ClientReportsScreen()),
            ),
          ],

          const Divider(height: 1),
          _SidebarTile(
            icon: Icons.settings,
            label: 'Настройки',
            onTap: () => _push(context, const SettingsScreen()),
          ),

          const Spacer(),
          const Divider(height: 1),
          _SidebarTile(
            icon: Icons.logout,
            label: 'Выйти',
            color: Colors.red,
            onTap: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SidebarLabel extends StatelessWidget {
  final String text;
  const _SidebarLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
        child: Text(text,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.2)),
      );
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: -4, vertical: -3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Icon(icon, size: 18, color: color),
        title: Text(label,
            style: TextStyle(fontSize: 13, color: color)),
        onTap: onTap,
      );
}

// ── Существующие виджеты (AppDrawer, UserAvatar, EmptyState) ─────────────────

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context, rootNavigator: false).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF8B0000)),
            child: Row(
              children: [
                const Icon(Icons.fitness_center, color: Colors.white, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Workout Assistant',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text(user.fullName,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (auth.isTrainerClient) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => auth.setActiveMode(ActiveMode.trainer),
                      icon: const Icon(Icons.sports, size: 16),
                      label: const Text('Тренер'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: auth.activeMode == ActiveMode.trainer
                            ? const Color(0xFFE3F2FD)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => auth.setActiveMode(ActiveMode.client),
                      icon: const Icon(Icons.person, size: 16),
                      label: const Text('Клиент'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: auth.activeMode == ActiveMode.client
                            ? const Color(0xFFE3F2FD)
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
          ],

          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Главная'),
            onTap: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),

          if (auth.showTrainerMenu) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
              child: Text('ТРЕНЕР',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Упражнения'),
              onTap: () {
                final ctx = context;
                Navigator.pop(context);
                _push(ctx, const ExercisesScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Клиенты'),
              onTap: () {
                final ctx = context;
                Navigator.pop(context);
                _push(ctx, const ClientsListScreen());
              },
            ),
          ],

          if (auth.showClientMenu) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
              child: Text('КЛИЕНТ',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
            ),
            ListTile(
              leading: const Icon(Icons.event_note),
              title: const Text('Мои занятия'),
              onTap: () {
                final ctx = context;
                Navigator.pop(context);
                _push(ctx, const ClientSeasonsScreen());
              },
            ),
          ],

          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Настройки'),
            onTap: () {
              final ctx = context;
              Navigator.pop(context);
              _push(ctx, const SettingsScreen());
            },
          ),

          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Выйти', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(context);
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class UserAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final Color? color;

  const UserAvatar(
      {super.key, required this.initials, this.size = 48, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? const Color(0xFF8B0000),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(initials,
            style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.35,
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        ],
      ),
    );
  }
}
