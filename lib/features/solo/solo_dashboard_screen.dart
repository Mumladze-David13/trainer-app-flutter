// lib/features/solo/solo_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_provider.dart';
import '../../core/widgets/app_scaffold.dart';
import '../trainer/exercises/exercises_screen.dart';
import '../client/activities/client_activities_screen.dart';
import '../client/reports/client_reports_screen.dart';
import '../nutrition/nutrition_screen.dart';
import '../ai/pose_analysis_screen.dart';
import '../settings/settings_screen.dart';
import 'solo_seasons_screen.dart';

// Главный экран SOLO: сам себе тренер и клиент (self-relation на бэке), без
// собственных клиентов — поэтому здесь и тренерская карточка "Упражнения", и
// весь клиентский набор (Занятия/Питание/Активности/Отчёты/Анализ техники),
// как в режиме TRAINER_CLIENT, но без выбора клиента.
class SoloDashboardScreen extends StatelessWidget {
  const SoloDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().user!.id;

    return AppScaffold(
      title: 'Workout Assistant',
      isDashboard: true,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Тренируетесь самостоятельно',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('Сами себе тренер — программа, занятия и прогресс в одном месте',
              style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, constraints) {
            final cards = [
              _Card('Упражнения', 'Справочник упражнений', Icons.list,
                  const Color(0xFF8B0000), () => const ExercisesScreen()),
              _Card('Занятия', 'Сезоны и тренировки', Icons.event_note,
                  const Color(0xFFBF360C), () => const SoloSeasonsScreen()),
              _NutritionCard(userId: userId),
              _Card('Мои активности', 'Бег, ходьба, велосипед...', Icons.directions_run,
                  const Color(0xFF6A1B9A), () => const ClientActivitiesScreen()),
              _Card('Отчёты', 'Статистика и прогресс', Icons.bar_chart,
                  const Color(0xFF1565C0), () => const ClientReportsScreen()),
              _Card('Анализ техники', 'AI проверит правильность', Icons.camera_alt,
                  Colors.teal, () => const PoseAnalysisScreen()),
              _Card('Настройки', 'Профиль и параметры', Icons.settings,
                  const Color(0xFF6D0000), () => const SettingsScreen()),
            ];
            final cols = (constraints.maxWidth / 180).floor().clamp(2, 5);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 150,
              ),
              itemCount: cards.length,
              itemBuilder: (context, i) => cards[i],
            );
          }),
        ],
      ),
    );
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
          MaterialPageRoute(builder: (_) => NutritionScreen(clientId: userId)),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF6D0000),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 24),
              ),
              const Spacer(),
              const Text('Питание',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text('Дневник и КБЖУ',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
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
        onTap: () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => screenBuilder())),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const Spacer(),
              Text(title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(desc,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }
}
