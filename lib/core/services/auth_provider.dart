// lib/core/services/auth_provider.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/models.dart';
import 'api_service.dart';

enum ActiveMode { trainer, client }

// Must match the intent-filter scheme in AndroidManifest.xml and the redirect
// target the backend uses for `platform=mobile` OAuth logins.
const String kOAuthCallbackUrlScheme = 'trainerapp';

class AuthProvider extends ChangeNotifier {
  User? _user;
  String? _token;
  ActiveMode _activeMode = ActiveMode.trainer;
  final ApiService api = ApiService();

  User? get user => _user;
  String? get token => _token;
  ActiveMode get activeMode => _activeMode;
  bool get isLoggedIn => _user != null;
  bool get isTrainer =>
      _user?.role == Role.trainer || _user?.role == Role.trainerClient;
  bool get isClient =>
      _user?.role == Role.client || _user?.role == Role.trainerClient;
  bool get isTrainerClient => _user?.role == Role.trainerClient;

  bool get showTrainerMenu {
    if (_user?.role == Role.trainer) return true;
    if (_user?.role == Role.trainerClient) return _activeMode == ActiveMode.trainer;
    return false;
  }

  bool get showClientMenu {
    if (_user?.role == Role.client) return true;
    if (_user?.role == Role.trainerClient) return _activeMode == ActiveMode.client;
    return false;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    final userStr = prefs.getString('user');
    if (userStr != null) {
      try {
        _user = User.fromJson(jsonDecode(userStr));
        _setDefaultMode();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final res = await api.login(email, password);
    await _handleAuth(res);
  }

  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    final res = await api.register(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      role: role,
    );
    await _handleAuth(res);
  }

  // Logs in (or auto-registers, on first use) via Google/VK/Mail.ru through the
  // system browser. Returns true if this created a brand-new account, so the
  // caller can send the user to pick a role.
  Future<bool> loginWithOAuth(String provider) async {
    final result = await FlutterWebAuth2.authenticate(
      url: '$baseUrl/auth/$provider?platform=${kIsWeb ? 'web' : 'mobile'}',
      callbackUrlScheme: kOAuthCallbackUrlScheme,
    );
    final uri = Uri.parse(result);
    final error = uri.queryParameters['error'];
    if (error != null) throw Exception(error);
    final code = uri.queryParameters['code'];
    if (code == null) throw Exception('Не получен код авторизации');
    final res = await api.exchangeOAuthCode(code);
    await _handleAuth(res);
    return res['isNewUser'] == true;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    _user = null;
    _token = null;
    notifyListeners();
  }

  Future<void> updateUserFromResponse(Map<String, dynamic> userData) async {
    _user = User.fromJson(userData);
    _setDefaultMode();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(userData));
    notifyListeners();
  }

  void setActiveMode(ActiveMode mode) {
    _activeMode = mode;
    notifyListeners();
  }

  Future<void> _handleAuth(Map<String, dynamic> res) async {
    _token = res['token'];
    _user = User.fromJson(res['user']);
    _setDefaultMode();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', _token!);
    await prefs.setString('user', jsonEncode(res['user']));
    notifyListeners();
  }

  void _setDefaultMode() {
    if (_user?.role == Role.client) {
      _activeMode = ActiveMode.client;
    } else {
      _activeMode = ActiveMode.trainer;
    }
  }
}
