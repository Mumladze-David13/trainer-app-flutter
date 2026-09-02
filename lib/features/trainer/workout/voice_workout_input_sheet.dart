// lib/features/trainer/workout/voice_workout_input_sheet.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../core/models/models.dart';
import '../../../core/services/auth_provider.dart';

// Результат одной распознанной строки — уже готов к превращению в _ExRow
// в workout_editor_screen.dart.
class VoiceExerciseResult {
  String? exerciseId;
  String exerciseName;
  String weightType;
  int sets;
  int reps;
  double? weight;

  VoiceExerciseResult({
    this.exerciseId,
    required this.exerciseName,
    this.weightType = 'WEIGHT_KG',
    this.sets = 3,
    this.reps = 10,
    this.weight,
  });
}

// Показывает bottom sheet голосового набора тренировки. Возвращает список
// упражнений для вставки в редактор, либо null если тренер отменил —
// в обоих случаях сам редактор не меняется до этого момента, так что при
// любой ошибке внутри (нет микрофона, бэкенд недоступен и т.п.) остальной
// функционал экрана редактирования продолжает работать как раньше.
Future<List<VoiceExerciseResult>?> showVoiceWorkoutInputSheet(
  BuildContext context, {
  required List<Exercise> catalog,
}) {
  return showModalBottomSheet<List<VoiceExerciseResult>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _VoiceWorkoutInputSheet(catalog: catalog),
  );
}

enum _Stage { input, parsing, review, error }

class _VoiceWorkoutInputSheet extends StatefulWidget {
  final List<Exercise> catalog;
  const _VoiceWorkoutInputSheet({required this.catalog});

  @override
  State<_VoiceWorkoutInputSheet> createState() => _VoiceWorkoutInputSheetState();
}

class _VoiceWorkoutInputSheetState extends State<_VoiceWorkoutInputSheet> {
  final _speech = stt.SpeechToText();
  final _textCtrl = TextEditingController();

  bool _micAvailable = false;
  bool _micInitTried = false;
  bool _listening = false;

  _Stage _stage = _Stage.input;
  String _errorText = '';
  List<VoiceExerciseResult> _parsed = [];

  @override
  void initState() {
    super.initState();
    _initMic();
  }

  Future<void> _initMic() async {
    bool available = false;
    try {
      available = await _speech.initialize(
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            if (mounted) setState(() => _listening = false);
          }
        },
      );
    } catch (_) {
      // Пакет недоступен на этой платформе/устройстве — просто не
      // показываем кнопку микрофона, текстовое поле остаётся рабочим.
      available = false;
    }
    if (mounted) {
      setState(() {
        _micAvailable = available;
        _micInitTried = true;
      });
    }
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    try {
      await _speech.listen(
        localeId: 'ru_RU',
        onResult: (result) {
          setState(() => _textCtrl.text = result.recognizedWords);
        },
      );
    } catch (_) {
      setState(() => _listening = false);
    }
  }

  Future<void> _recognize() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final api = context.read<AuthProvider>().api;
    if (_listening) await _speech.stop();
    if (!mounted) return;

    setState(() {
      _stage = _Stage.parsing;
      _listening = false;
    });

    try {
      final items = await api.aiParseWorkout(text);
      final results = items.map((item) {
        final name = (item['name'] as String? ?? '').trim();
        // Бэкенд получает каталог упражнений тренера в промт и по возможности
        // сам возвращает exerciseId (как в /ai/generate-program) — доверяем
        // ему, если id реально есть в каталоге; иначе — локальный фаззи-матч
        // по названию как подстраховка.
        final backendId = item['exerciseId'] as String?;
        Exercise? match;
        if (backendId != null) {
          for (final ex in widget.catalog) {
            if (ex.id == backendId) { match = ex; break; }
          }
        }
        match ??= _matchExercise(name);
        return VoiceExerciseResult(
          exerciseId: match?.id,
          exerciseName: match?.name ?? name,
          weightType: match?.weightType ?? 'WEIGHT_KG',
          sets: (item['sets'] as num?)?.toInt() ?? 3,
          reps: (item['reps'] as num?)?.toInt() ?? 10,
          weight: (item['weight'] as num?)?.toDouble(),
        );
      }).where((r) => r.exerciseName.isNotEmpty).toList();

      if (results.isEmpty) {
        setState(() {
          _stage = _Stage.error;
          _errorText = 'Не удалось распознать ни одного упражнения в тексте. '
              'Попробуйте переформулировать или добавьте вручную.';
        });
        return;
      }

      setState(() {
        _parsed = results;
        _stage = _Stage.review;
      });
    } on DioException catch (e) {
      setState(() {
        _stage = _Stage.error;
        _errorText = e.response?.statusCode == 403
            ? 'Исчерпан лимит AI-запросов на этот месяц.'
            : 'Сервер сейчас не может распознать текст. '
                'Добавьте упражнения вручную кнопкой «Добавить».';
      });
    } catch (_) {
      setState(() {
        _stage = _Stage.error;
        _errorText = 'Не удалось связаться с сервером. Проверьте интернет '
            'и добавьте упражнения вручную, если не получится снова.';
      });
    }
  }

  // Простой фаззи-матч распознанного названия на каталог упражнений тренера:
  // сперва точное совпадение без учёта регистра, потом — по вхождению строк
  // друг в друга. Ничего не найдено — вернём null, тренер выберет вручную
  // в списке проверки.
  Exercise? _matchExercise(String name) {
    if (name.isEmpty) return null;
    final needle = name.toLowerCase().trim();
    for (final ex in widget.catalog) {
      if (ex.name.toLowerCase().trim() == needle) return ex;
    }
    for (final ex in widget.catalog) {
      final hay = ex.name.toLowerCase().trim();
      if (hay.contains(needle) || needle.contains(hay)) return ex;
    }
    return null;
  }

  @override
  void dispose() {
    _speech.stop();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mic, color: Color(0xFF8B0000)),
                const SizedBox(width: 8),
                const Text('Голосовой набор тренировки',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 20),
            Flexible(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_stage) {
      case _Stage.input:
        return _buildInputStage();
      case _Stage.parsing:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Распознаём упражнения…'),
              ],
            ),
          ),
        );
      case _Stage.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_errorText, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _stage = _Stage.input),
                  child: const Text('Назад к тексту'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Закрыть'),
                ),
              ],
            ),
          ],
        );
      case _Stage.review:
        return _buildReviewStage();
    }
  }

  Widget _buildInputStage() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_micInitTried && !_micAvailable)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Голосовой ввод недоступен на этом устройстве/браузере — '
              'но можно напечатать текст и распознать его так же.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        TextField(
          controller: _textCtrl,
          maxLines: 5,
          minLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Например: жим лёжа три подхода по десять на восьмидесяти, '
                'потом присед сто на пять раз четыре подхода',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (_micAvailable)
              OutlinedButton.icon(
                onPressed: _toggleListening,
                icon: Icon(_listening ? Icons.stop : Icons.mic,
                    color: _listening ? Colors.red : null),
                label: Text(_listening ? 'Стоп' : 'Говорить'),
              ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _textCtrl.text.trim().isEmpty ? null : _recognize,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B0000)),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Распознать'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewStage() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Проверьте перед добавлением:',
            style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _parsed.length,
            separatorBuilder: (_, __) => const Divider(height: 16),
            itemBuilder: (_, i) => _ReviewRow(
              item: _parsed[i],
              catalog: widget.catalog,
              onRemove: () => setState(() => _parsed.removeAt(i)),
              onChanged: () => setState(() {}),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _parsed.isEmpty
                ? null
                : () => Navigator.of(context).pop(_parsed),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B0000)),
            child: Text('Добавить в тренировку (${_parsed.length})'),
          ),
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final VoiceExerciseResult item;
  final List<Exercise> catalog;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ReviewRow({
    required this.item,
    required this.catalog,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: item.exerciseId,
                decoration: InputDecoration(
                  labelText: item.exerciseId == null
                      ? 'Не найдено — выберите: "${item.exerciseName}"'
                      : 'Упражнение',
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: item.exerciseId == null ? Colors.orange[800] : null,
                  ),
                  isDense: true,
                ),
                items: catalog
                    .map((ex) => DropdownMenuItem(value: ex.id, child: Text(ex.name)))
                    .toList(),
                onChanged: (id) {
                  final ex = catalog.firstWhere((e) => e.id == id);
                  item.exerciseId = ex.id;
                  item.exerciseName = ex.name;
                  item.weightType = ex.weightType;
                  onChanged();
                },
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: item.sets.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Подходы', isDense: true),
                      onChanged: (v) => item.sets = int.tryParse(v) ?? item.sets,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: item.reps.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Повторы', isDense: true),
                      onChanged: (v) => item.reps = int.tryParse(v) ?? item.reps,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: item.weight?.toString() ?? '',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Вес', isDense: true),
                      onChanged: (v) => item.weight = double.tryParse(v),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
          onPressed: onRemove,
        ),
      ],
    );
  }
}
