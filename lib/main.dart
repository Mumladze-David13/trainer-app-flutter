// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/services/auth_provider.dart';
import 'core/services/navigation_service.dart';
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

  // Переход на нужный экран по тапу на уведомление (app в foreground/фоне)
  NotificationService.listenForMessageTaps(auth);

  runApp(
    ChangeNotifierProvider.value(
      value: auth,
      child: TrainerApp(auth: auth),
    ),
  );
}

class TrainerApp extends StatefulWidget {
  final AuthProvider auth;
  const TrainerApp({super.key, required this.auth});

  @override
  State<TrainerApp> createState() => _TrainerAppState();
}

class _TrainerAppState extends State<TrainerApp> {
  @override
  void initState() {
    super.initState();
    // Приложение могло быть запущено тапом по уведомлению (terminated-состояние).
    // Ждём первый кадр, чтобы navigatorKey был примонтирован.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.checkInitialMessage(widget.auth);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workout Assistant',
      navigatorKey: navigatorKey,
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      // Русская локаль нужна прежде всего для showDatePicker — с ней
      // календарь показывает русские названия месяцев и начинает неделю
      // с понедельника (это берётся из CLDR-данных для 'ru' в Flutter).
      locale: const Locale('ru', 'RU'),
      supportedLocales: const [Locale('ru', 'RU')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
