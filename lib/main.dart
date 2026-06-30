// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/services/auth_provider.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU', null);

  // Инициализация Firebase и уведомлений
  await NotificationService.init();

  final auth = AuthProvider();
  await auth.init();

  // Если пользователь уже залогинен — сохранить FCM токен
  if (auth.isLoggedIn) {
    await NotificationService.saveToken(auth.api);
  }

  runApp(
    ChangeNotifierProvider.value(
      value: auth,
      child: const TrainerApp(),
    ),
  );
}

class TrainerApp extends StatelessWidget {
  const TrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workout Assistant',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isLoggedIn) {
            return const DashboardScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
