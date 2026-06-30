// lib/core/services/notification_service.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

const FirebaseOptions _firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyBB_A9FpEh30xrYUkUc2l4ifMuFfcu_9oE',
  appId: '1:791323526773:android:0475ec203ac231edb49a3c',
  messagingSenderId: '791323526773',
  projectId: 'workout-assistant-8cc4d',
  storageBucket: 'workout-assistant-8cc4d.firebasestorage.app',
);

// Обработчик фоновых уведомлений — должен быть вне класса
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: _firebaseOptions);
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    await Firebase.initializeApp(options: _firebaseOptions);

    // Запрос разрешения на уведомления
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Настройка локальных уведомлений (для показа когда приложение открыто)
    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings),
    );

    // Создать канал уведомлений для Android
    const channel = AndroidNotificationChannel(
      'trainer_app_channel',
      'Уведомления',
      description: 'Уведомления о занятиях и сообщениях',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Обработчик фоновых сообщений
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Показывать уведомление когда приложение открыто (foreground)
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'trainer_app_channel',
              'Уведомления',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    });
  }

  // Получить токен и сохранить на сервере
  static Future<void> saveToken(ApiService api) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await api.saveFcmToken(token);
      }

      // Обновлять токен при его обновлении Firebase
      _messaging.onTokenRefresh.listen((newToken) async {
        try {
          await api.saveFcmToken(newToken);
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('FCM token error: $e');
    }
  }
}