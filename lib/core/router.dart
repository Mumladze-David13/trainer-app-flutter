// lib/core/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'services/auth_provider.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/trainer/exercises/exercises_screen.dart';
import '../features/trainer/clients/clients_list_screen.dart';
import '../features/trainer/clients/client_detail_screen.dart';
import '../features/trainer/workout/workout_editor_screen.dart';
import '../features/client/seasons/client_seasons_screen.dart';
import '../features/client/workout/client_workout_screen.dart';
import '../features/settings/settings_screen.dart';

GoRouter createRouter(AuthProvider auth) => GoRouter(
  initialLocation: '/dashboard',
  redirect: (context, state) {
    final isLoggedIn = auth.isLoggedIn;
    final isAuthRoute = state.matchedLocation.startsWith('/auth');
    if (!isLoggedIn && !isAuthRoute) return '/auth/login';
    if (isLoggedIn && isAuthRoute) return '/dashboard';
    return null;
  },
  refreshListenable: auth,
  routes: [
    GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/auth/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
    GoRoute(path: '/trainer/exercises', builder: (_, __) => const ExercisesScreen()),
    GoRoute(path: '/trainer/clients', builder: (_, __) => const ClientsListScreen()),
    GoRoute(
      path: '/trainer/clients/:clientId',
      builder: (_, state) => ClientDetailScreen(
        clientId: state.pathParameters['clientId']!,
      ),
    ),
    GoRoute(
      path: '/trainer/clients/:clientId/workout/new/:seasonId',
      builder: (_, state) => WorkoutEditorScreen(
        clientId: state.pathParameters['clientId']!,
        seasonId: state.pathParameters['seasonId']!,
      ),
    ),
    GoRoute(
      path: '/trainer/clients/:clientId/workout/:workoutId',
      builder: (_, state) => WorkoutEditorScreen(
        clientId: state.pathParameters['clientId']!,
        workoutId: state.pathParameters['workoutId']!,
      ),
    ),
    GoRoute(path: '/client/seasons', builder: (_, __) => const ClientSeasonsScreen()),
    GoRoute(
      path: '/client/workout/:workoutId',
      builder: (_, state) => ClientWorkoutScreen(
        workoutId: state.pathParameters['workoutId']!,
      ),
    ),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
  ],
);

// Helper extension for push navigation
extension NavigatorExtension on BuildContext {
  void pushScreen(Widget screen) {
    Navigator.of(this).push(MaterialPageRoute(builder: (_) => screen));
  }
}
