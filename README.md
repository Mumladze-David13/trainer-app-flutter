# Помощник тренера — Flutter

Мобильное приложение для Android (и iOS) на Flutter.
Работает с тем же backend что и web-версия.

## Требования
- Flutter SDK 3.10+
- Dart 3.0+
- Android Studio или VS Code с Flutter плагином

## Установка Flutter
```bash
# Скачайте Flutter SDK с flutter.dev
# Добавьте в PATH
flutter doctor  # проверка установки
```

## Запуск проекта
```bash
cd trainer-flutter
flutter pub get
flutter run
```

## Сборка APK для Android
```bash
# Debug APK (для тестирования)
flutter build apk --debug

# Release APK
flutter build apk --release

# APK будет в: build/app/outputs/flutter-apk/app-release.apk
```

## Изменить URL backend
Откройте `lib/core/services/api_service.dart` и замените:
```dart
const String baseUrl = 'http://144.31.189.154:3000/api';
```

## Структура проекта
```
lib/
├── main.dart                    # Точка входа
├── core/
│   ├── models/models.dart       # Модели данных
│   ├── services/
│   │   ├── api_service.dart     # HTTP запросы (Dio)
│   │   └── auth_provider.dart   # Состояние авторизации
│   ├── theme/app_theme.dart     # Тема приложения
│   ├── router.dart              # Навигация (GoRouter)
│   └── widgets/app_scaffold.dart # Общие виджеты
└── features/
    ├── auth/                    # Логин, Регистрация
    ├── dashboard/               # Главная
    ├── trainer/
    │   ├── exercises/           # Справочник упражнений
    │   ├── clients/             # Клиенты и сезоны
    │   └── workout/             # Редактор занятия
    ├── client/
    │   ├── seasons/             # Список сезонов
    │   └── workout/             # Просмотр занятия
    └── settings/                # Настройки
```

## Функционал
- Регистрация с выбором роли (Тренер / Клиент / Тренер-Клиент)
- JWT авторизация с сохранением сессии
- Тренер: управление упражнениями, клиентами, сезонами, занятиями
- Клиент: просмотр занятий, отметка выполненных упражнений
- Завершение занятия при ≥50% выполненных упражнений
- Переключение режимов для роли Тренер-Клиент
