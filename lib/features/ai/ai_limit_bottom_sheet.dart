// lib/features/ai/ai_limit_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'ai_usage_screen.dart';

/// Shown when an AI request comes back with 403 (monthly token limit reached).
/// Mirrors the bottom sheet used by GenerateProgramScreen.
void showAiLimitBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning, color: Colors.orange, size: 48),
          const SizedBox(height: 12),
          const Text('Лимит токенов исчерпан',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Перейдите на тариф выше для продолжения',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AiUsageScreen()));
            },
            child: const Text('Посмотреть тарифы'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
