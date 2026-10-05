import 'package:dio/dio.dart';

/// Короткая техническая расшифровка ошибки AI-запроса для показа в UI:
/// HTTP-код + сообщение бэкенда, либо тип сетевой ошибки. Нужна, чтобы по
/// скриншоту было видно реальную причину (500 от провайдера, 404 — эндпоинт
/// не задеплоен, таймаут и т.п.), а не только общее «Ошибка генерации».
String aiErrorDetail(Object error) {
  if (error is! DioException) return error.toString();

  final res = error.response;
  if (res != null) {
    final data = res.data;
    String? message;
    if (data is Map) {
      final m = data['message'] ?? data['error'];
      message = m is List ? m.join(', ') : m?.toString();
    } else if (data is String && data.isNotEmpty) {
      message = data.length > 200 ? '${data.substring(0, 200)}…' : data;
    }
    return message == null || message.isEmpty
        ? 'HTTP ${res.statusCode}'
        : 'HTTP ${res.statusCode}: $message';
  }

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Таймаут: сервер не ответил вовремя';
    case DioExceptionType.connectionError:
      return 'Нет соединения с сервером';
    default:
      return error.message ?? error.type.name;
  }
}
