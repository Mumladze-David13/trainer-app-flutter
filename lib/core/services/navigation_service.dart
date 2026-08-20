// lib/core/services/navigation_service.dart
import 'package:flutter/material.dart';

/// Глобальный navigatorKey — позволяет переходить между экранами
/// из мест без BuildContext (например, из обработчика push-уведомлений).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
