// lib/features/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/services/auth_provider.dart';
import '../../core/widgets/app_scaffold.dart';
import '../trainer/exercises/exercises_screen.dart';
import '../trainer/clients/clients_list_screen.dart';
import '../client/seasons/client_seasons_screen.dart';
import '../client/activities/client_activities_screen.dart';
import '../client/reports/client_reports_screen.dart';
import '../settings/settings_screen.dart';
import '../nutrition/nutrition_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;

    return AppScaffold(
      title: 'Workout Assistant',
      isDashboard: true,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Добро пожаловать, ${user.firstName}!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(_roleDesc(auth), style: TextStyle(color: Colors.grey[600])),

          if (auth.isTrainerClient) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                border: Border.all(color: const Color(0xFFEF9A9A)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.swap_horiz, color: Color(0xFF8B0000), size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Активный режим: ${auth.activeMode == ActiveMode.trainer ? "Тренер" : "Клиент"} — переключайте в меню',
                  style: const TextStyle(color: Color(0xFF8B0000), fontSize: 13),
                )),
              ]),
            ),
          ],

          const SizedBox(height: 20),

          Builder(builder: (context) {
            final cards = [
              if (auth.showTrainerMenu) ...[
                _Card('Упражнения', 'Справочник упражнений', Icons.list,
                    const Color(0xFF8B0000), () => const ExercisesScreen()),
                _Card('Клиенты', 'Управление клиентами', Icons.group,
                    const Color(0xFFC62828), () => const ClientsListScreen()),
              ],
              if (auth.showClientMenu) ...[
                _Card('Мои занятия', 'Сезоны и тренировки', Icons.event_note,
                    const Color(0xFFBF360C), () => const ClientSeasonsScreen()),
                _NutritionCard(userId: user.id),
                _Card('Мои активности', 'Бег, ходьба, велосипед...', Icons.directions_run,
                    const Color(0xFF6A1B9A), () => const ClientActivitiesScreen()),
                _Card('Отчёты', 'Статистика и прогресс', Icons.bar_chart,
                    const Color(0xFF1565C0), () => const ClientReportsScreen()),
              ],
              _Card('Настройки', 'Профиль и параметры', Icons.settings,
                  const Color(0xFF6D0000), () => const SettingsScreen()),
            ];
            return LayoutBuilder(builder: (context, constraints) {
              final cols = (constraints.maxWidth / 180).floor().clamp(2, 5);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 130,
                ),
                itemCount: cards.length,
                itemBuilder: (context, i) => cards[i],
              );
            });
          }),
        ],
      ),
    );
  }

  String _roleDesc(AuthProvider auth) {
    if (auth.user?.role == Role.trainer) return 'Вы работаете в режиме тренера';
    if (auth.user?.role == Role.client) return 'Вы работаете в режиме клиента';
    return 'Переключайтесь между режимами тренера и клиента';
  }
}

class _NutritionCard extends StatelessWidget {
  final String userId;
  const _NutritionCard({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NutritionScreen(clientId: userId),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF6D0000),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restaurant_menu,
                    color: Colors.white, size: 24),
              ),
              const Spacer(),
              const Text('Питание',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text('Дневник и КБЖУ',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  final Widget Function() screenBuilder;
  const _Card(this.title, this.desc, this.icon, this.color, this.screenBuilder);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => screenBuilder())),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const Spacer(),
              Text(title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }
}