// lib/features/ai/pose_session_summary.dart
//
// Итог подхода по повторениям — общий для живого анализа (после "Остановить
// анализ") и для анализа сохранённого видео.
import 'package:flutter/material.dart';
import '../../core/models/pose_analysis.dart';

Color poseScoreColor(double score) {
  if (score >= 80) return Colors.green;
  if (score >= 60) return Colors.orange;
  return Colors.red;
}

class PoseSessionSummary extends StatelessWidget {
  final List<RepRecord> reps;
  // Показывается, когда ни одного повтора не засчитано.
  final String emptyMessage;
  // Тап по повтору (например, перемотать видео к нему).
  final void Function(int repListIndex)? onRepTap;

  const PoseSessionSummary({
    super.key,
    required this.reps,
    required this.emptyMessage,
    this.onRepTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reps.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(emptyMessage,
            style: const TextStyle(color: Colors.orange, fontSize: 13)),
      );
    }

    final avg = reps.map((r) => r.score).reduce((a, b) => a + b) / reps.length;
    // Проблема -> в скольких повторах встретилась.
    final issueReps = <String, int>{};
    final issueTips = <String, String>{};
    for (final rep in reps) {
      for (var i = 0; i < rep.issues.length; i++) {
        final issue = _stripNumbers(rep.issues[i]);
        issueReps[issue] = (issueReps[issue] ?? 0) + 1;
        if (i < rep.tips.length) issueTips[issue] = rep.tips[i];
      }
    }
    final topIssues = issueReps.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Повторений: ',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text('${reps.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              const Text('Техника: ',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text('${avg.round()}%',
                  style: TextStyle(
                      color: poseScoreColor(avg),
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          if (topIssues.isEmpty)
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 6),
                Text('Ошибок не найдено — отличная техника!',
                    style: TextStyle(color: Colors.green, fontSize: 13)),
              ],
            )
          else ...[
            const Text('Главные ошибки:',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            ...topIssues.take(4).map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber,
                          color: Colors.orange, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${e.key} — в ${e.value} из ${reps.length} повт.',
                                style: const TextStyle(
                                    color: Colors.orange, fontSize: 13)),
                            if (issueTips[e.key] != null)
                              Text(issueTips[e.key]!,
                                  style: const TextStyle(
                                      color: Colors.yellow, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          const SizedBox(height: 8),
          const Text('По повторениям:',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          ...List.generate(reps.length, (i) {
            final rep = reps[i];
            return InkWell(
              onTap: onRepTap == null ? null : () => onRepTap!(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text('#${rep.index}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text('${rep.score.round()}%',
                          style: TextStyle(
                              color: poseScoreColor(rep.score),
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: Text(
                        rep.issues.isEmpty ? 'без ошибок' : rep.issues.join('; '),
                        style: TextStyle(
                            color: rep.issues.isEmpty
                                ? Colors.green
                                : Colors.white70,
                            fontSize: 12),
                      ),
                    ),
                    if (onRepTap != null)
                      const Icon(Icons.play_circle_outline,
                          color: Colors.white38, size: 16),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // "Недостаточная глубина (колено 118°, нужно ≤100°)" -> "Недостаточная
  // глубина", чтобы одинаковые ошибки разных повторов группировались.
  static String _stripNumbers(String issue) {
    final i = issue.indexOf(' (');
    return i > 0 ? issue.substring(0, i) : issue;
  }
}
