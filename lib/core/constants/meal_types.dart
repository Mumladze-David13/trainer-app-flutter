// lib/core/constants/meal_types.dart
import 'package:flutter/material.dart';

const Map<String, String> mealTypeLabels = {
  'breakfast': 'Завтрак',
  'lunch': 'Обед',
  'dinner': 'Ужин',
  'snack': 'Перекус',
};

const Map<String, IconData> mealTypeIcons = {
  'breakfast': Icons.wb_sunny_outlined,
  'lunch': Icons.wb_cloudy_outlined,
  'dinner': Icons.nights_stay_outlined,
  'snack': Icons.coffee_outlined,
};

/// Guesses a meal type from the time of day, for defaulting form fields.
String guessMealTypeForHour(int hour) {
  if (hour < 11) return 'breakfast';
  if (hour < 16) return 'lunch';
  if (hour < 21) return 'dinner';
  return 'snack';
}
