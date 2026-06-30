// lib/core/services/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/models.dart';
import 'api_service.dart';

enum ActiveMode { trainer, client }

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
