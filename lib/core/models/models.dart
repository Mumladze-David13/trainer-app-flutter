// lib/core/models/models.dart
import 'dart:convert';

class Address {
  final String? country;
  final String? region;
  final String? city;
  final String? street;
  final String? building;
  final String? unit;

  Address({this.country, this.region, this.city, this.street, this.building, this.unit});

  factory Address.fromJson(Map<String, dynamic> json) => Address(
    country: json['country'],
    region: json['region'],
    city: json['city'],
    street: json['street'],
    building: json['building'],
    unit: json['unit'],
  );

  Map<String, dynamic> toJson() => {
    if (country != null) 'country': country,
    if (region != null) 'region': region,
    if (city != null) 'city': city,
    if (street != null) 'street': street,
    if (building != null) 'building': building,
    if (unit != null) 'unit': unit,
  };

  String get displayShort => [city, street, building].whereType<String>().join(', ');
  String get displayFull => [country, region, city, street, building, unit].whereType<String>().join(', ');
}

class Gym {
  final String id;
  final String name;
  final Address? address;
  final DateTime createdAt;
  final DateTime updatedAt;

  Gym({required this.id, required this.name, this.address, required this.createdAt, required this.updatedAt});

  factory Gym.fromJson(Map<String, dynamic> json) => Gym(
    id: json['id'],
    name: json['name'],
    address: json['address'] != null ? Address.fromJson(json['address']) : null,
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
  );
}

enum Role { trainer, client, trainerClient }

extension RoleExtension on Role {
  String get label {
    switch (this) {
      case Role.trainer: return 'Тренер';
      case Role.client: return 'Клиент';
      case Role.trainerClient: return 'Тренер-Клиент';
    }
  }

  String get name {
    switch (this) {
      case Role.trainer: return 'TRAINER';
      case Role.client: return 'CLIENT';
      case Role.trainerClient: return 'TRAINER_CLIENT';
    }
  }

  static Role fromString(String s) {
    switch (s) {
      case 'TRAINER': return Role.trainer;
      case 'CLIENT': return Role.client;
      default: return Role.trainerClient;
    }
  }
}

class User {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final Role role;
  final String? gymId;
  final Address? address;

  User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.gymId,
    this.address,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: j['id'] ?? '',
    email: j['email'] ?? '',
    firstName: j['firstName'] ?? '',
    lastName: j['lastName'] ?? '',
    role: RoleExtension.fromString(j['role'] ?? 'CLIENT'),
    gymId: j['gymId'],
    address: j['address'] != null ? Address.fromJson(j['address']) : null,
  );

  String get fullName => '$firstName $lastName';
  String get initials => '${firstName[0]}${lastName[0]}'.toUpperCase();
}

class Exercise {
  final String id;
  final String name;
  final String? description;
  final String weightType; // "WEIGHT_KG" | "BODYWEIGHT" | "MACHINE"
  final double? metValue;

  Exercise({
    required this.id,
    required this.name,
    this.description,
    this.weightType = 'WEIGHT_KG',
    this.metValue,
  });

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    description: j['description'],
    weightType: j['weightType'] ?? 'WEIGHT_KG',
    metValue: (j['metValue'] as num?)?.toDouble(),
  );
}

class WorkoutExercise {
  final String id;
  final String exerciseId;
  final Exercise exercise;
  final int sets;
  final int reps;
  final double? weight;
  final List<double?> setWeights; // веса по подходам
  final List<int> setReps;       // повторения по подходам
  final int order;
  final int? supersetGroup;
  final int? supersetOrder;
  final double? durationMinutes;
  bool isDone;

  WorkoutExercise({
    required this.id,
    required this.exerciseId,
    required this.exercise,
    required this.sets,
    required this.reps,
    this.weight,
    this.setWeights = const [],
    this.setReps = const [],
    required this.order,
    this.supersetGroup,
    this.supersetOrder,
    this.durationMinutes,
    this.isDone = false,
  });

  double? weightForSet(int setIndex) {
    if (setWeights.isNotEmpty && setIndex < setWeights.length) {
      return setWeights[setIndex];
    }
    return weight;
  }

  int repsForSet(int setIndex) {
    if (setReps.isNotEmpty && setIndex < setReps.length) {
      return setReps[setIndex];
    }
    return reps;
  }

  bool get hasSetWeights => setWeights.isNotEmpty;
  bool get hasSetReps => setReps.isNotEmpty;

  factory WorkoutExercise.fromJson(Map<String, dynamic> j) {
    List<double?> weights = [];
    if (j['setWeights'] != null) {
      try {
        final parsed = j['setWeights'] is String
            ? jsonDecode(j['setWeights'])
            : j['setWeights'];
        weights = (parsed as List)
            .map((e) => e != null ? (e as num).toDouble() : null)
            .toList();
      } catch (_) {}
    }

    List<int> repsPerSet = [];
    if (j['setReps'] != null) {
      try {
        final parsed = j['setReps'] is String
            ? jsonDecode(j['setReps'])
            : j['setReps'];
        repsPerSet = (parsed as List).map((e) => (e as num).toInt()).toList();
      } catch (_) {}
    }

    return WorkoutExercise(
      id: j['id'] ?? '',
      exerciseId: j['exerciseId'] ?? '',
      exercise: Exercise.fromJson(j['exercise'] ?? {}),
      sets: j['sets'] ?? 1,
      reps: j['reps'] ?? 1,
      weight: j['weight']?.toDouble(),
      setWeights: weights,
      setReps: repsPerSet,
      order: j['order'] ?? 0,
      supersetGroup: j['supersetGroup'],
      supersetOrder: j['supersetOrder'],
      durationMinutes: (j['durationMinutes'] as num?)?.toDouble(),
      isDone: j['isDone'] ?? false,
    );
  }
}

class Workout {
  final String id;
  final String seasonId;
  final DateTime date;
  final String? notes;
  final bool isCompleted;
  final List<WorkoutExercise> workoutExercises;

  Workout({
    required this.id,
    required this.seasonId,
    required this.date,
    this.notes,
    required this.isCompleted,
    required this.workoutExercises,
  });

  factory Workout.fromJson(Map<String, dynamic> j) => Workout(
    id: j['id'] ?? '',
    seasonId: j['seasonId'] ?? '',
    date: j['date'] != null ? DateTime.parse(j['date']) : DateTime.now(),
    notes: j['notes'],
    isCompleted: j['isCompleted'] ?? false,
    workoutExercises: (j['workoutExercises'] as List? ?? [])
        .map((e) => WorkoutExercise.fromJson(e))
        .toList(),
  );

  int get doneCount => workoutExercises.where((e) => e.isDone).length;
  int get totalCount => workoutExercises.length;
  double get donePercent => totalCount > 0 ? doneCount / totalCount : 0;
  bool get canComplete => donePercent >= 0.5;

  // Группировка по супер-сетам
  Map<int, List<WorkoutExercise>> get supersets {
    final Map<int, List<WorkoutExercise>> groups = {};
    for (final ex in workoutExercises) {
      if (ex.supersetGroup != null) {
        groups.putIfAbsent(ex.supersetGroup!, () => []).add(ex);
      }
    }
    return groups;
  }
}

class Season {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final List<Workout> workouts;

  Season({
    required this.id,
    required this.name,
    required this.startDate,
    this.endDate,
    required this.isActive,
    required this.workouts,
  });

  factory Season.fromJson(Map<String, dynamic> j) => Season(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    startDate: j['startDate'] != null ? DateTime.parse(j['startDate']) : DateTime.now(),
    endDate: j['endDate'] != null ? DateTime.parse(j['endDate']) : null,
    isActive: j['isActive'] ?? true,
    workouts: (j['workouts'] as List? ?? [])
        .map((e) => Workout.fromJson(e))
        .toList(),
  );

  int get completedCount => workouts.where((w) => w.isCompleted).length;
}

class ClientWithSeasons {
  final User client;
  final List<Season> seasons;
  final int sessionsPerSeason;

  ClientWithSeasons({
    required this.client,
    required this.seasons,
    required this.sessionsPerSeason,
  });

  factory ClientWithSeasons.fromJson(Map<String, dynamic> j) =>
      ClientWithSeasons(
        client: User.fromJson(j['client']),
        seasons: (j['seasons'] as List? ?? [])
            .map((e) => Season.fromJson(e))
            .toList(),
        sessionsPerSeason: j['sessionsPerSeason'] ?? 30,
      );
}

class TrainerSettings {
  final String trainerId;
  int sessionsPerSeason;

  TrainerSettings({required this.trainerId, required this.sessionsPerSeason});

  factory TrainerSettings.fromJson(Map<String, dynamic> j) => TrainerSettings(
    trainerId: j['trainerId'] ?? '',
    sessionsPerSeason: j['sessionsPerSeason'] ?? 30,
  );
}

class WeightLog {
  final String id;
  final String? clientId;
  final double weightKg;
  final DateTime date;
  final String? notes;

  WeightLog({
    required this.id,
    this.clientId,
    required this.weightKg,
    required this.date,
    this.notes,
  });

  factory WeightLog.fromJson(Map<String, dynamic> j) => WeightLog(
    id: j['id'] ?? '',
    clientId: j['clientId'],
    weightKg: (j['weightKg'] as num?)?.toDouble() ?? 0.0,
    date: j['date'] != null ? DateTime.parse(j['date']) : DateTime.now(),
    notes: j['notes'],
  );
}

class WeightStats {
  final double firstWeight;
  final double lastWeight;
  final double totalChange;
  final double weeklyRate;
  final int periodDays;
  final int entriesCount;

  WeightStats({
    required this.firstWeight,
    required this.lastWeight,
    required this.totalChange,
    required this.weeklyRate,
    required this.periodDays,
    required this.entriesCount,
  });

  factory WeightStats.fromJson(Map<String, dynamic> j) => WeightStats(
    firstWeight: (j['firstWeight'] as num?)?.toDouble() ?? 0.0,
    lastWeight: (j['lastWeight'] as num?)?.toDouble() ?? 0.0,
    totalChange: (j['totalChange'] as num?)?.toDouble() ?? 0.0,
    weeklyRate: (j['weeklyRate'] as num?)?.toDouble() ?? 0.0,
    periodDays: j['periodDays'] ?? 0,
    entriesCount: j['entriesCount'] ?? 0,
  );
}

class WeightAnalysis {
  final List<WeightLog> logs;
  final WeightStats? stats;
  final String analysis;

  WeightAnalysis({
    required this.logs,
    this.stats,
    required this.analysis,
  });

  factory WeightAnalysis.fromJson(Map<String, dynamic> j) => WeightAnalysis(
    logs: (j['logs'] as List? ?? [])
        .map((e) => WeightLog.fromJson(e))
        .toList(),
    stats: j['stats'] != null ? WeightStats.fromJson(j['stats']) : null,
    analysis: j['analysis'] ?? '',
  );
}

class ClientSessionExercise {
  final String id;
  final String sessionId;
  final String? exerciseId;
  final String? clientActivityId;
  final int? sets;
  final int? reps;
  final double? weight;
  final double? durationMinutes;
  final int order;
  final Exercise? exercise;
  final ClientActivity? clientActivity;

  ClientSessionExercise({
    required this.id,
    required this.sessionId,
    this.exerciseId,
    this.clientActivityId,
    this.sets,
    this.reps,
    this.weight,
    this.durationMinutes,
    required this.order,
    this.exercise,
    this.clientActivity,
  });

  factory ClientSessionExercise.fromJson(Map<String, dynamic> j) =>
      ClientSessionExercise(
        id: j['id'] ?? '',
        sessionId: j['sessionId'] ?? '',
        exerciseId: j['exerciseId'],
        clientActivityId: j['clientActivityId'],
        sets: j['sets'] as int?,
        reps: j['reps'] as int?,
        weight: (j['weight'] as num?)?.toDouble(),
        durationMinutes: (j['durationMinutes'] as num?)?.toDouble(),
        order: j['order'] ?? 0,
        exercise: j['exercise'] != null ? Exercise.fromJson(j['exercise']) : null,
        clientActivity: j['clientActivity'] != null
            ? ClientActivity.fromJson(j['clientActivity'])
            : null,
      );

  String get displayName => exercise?.name ?? clientActivity?.name ?? 'Активность';
}

class ClientSession {
  final String id;
  final String clientId;
  final DateTime date;
  final String? notes;
  final List<ClientSessionExercise> exercises;

  ClientSession({
    required this.id,
    required this.clientId,
    required this.date,
    this.notes,
    required this.exercises,
  });

  factory ClientSession.fromJson(Map<String, dynamic> j) => ClientSession(
    id: j['id'] ?? '',
    clientId: j['clientId'] ?? '',
    date: j['date'] != null ? DateTime.parse(j['date']) : DateTime.now(),
    notes: j['notes'],
    exercises: (j['exercises'] as List? ?? [])
        .map((e) => ClientSessionExercise.fromJson(e))
        .toList(),
  );
}

class BurnedCalories {
  final String date;
  final double burnedCalories;

  BurnedCalories({required this.date, required this.burnedCalories});

  factory BurnedCalories.fromJson(Map<String, dynamic> j) => BurnedCalories(
    date: j['date'] ?? '',
    burnedCalories: (j['burnedCalories'] as num?)?.toDouble() ?? 0.0,
  );
}

class ClientActivity {
  final String id;
  final String clientId;
  final String name;
  final double? metValue;
  final String? description;

  const ClientActivity({
    required this.id,
    required this.clientId,
    required this.name,
    this.metValue,
    this.description,
  });

  factory ClientActivity.fromJson(Map<String, dynamic> j) => ClientActivity(
    id: j['id'] ?? '',
    clientId: j['clientId'] ?? '',
    name: j['name'] ?? '',
    metValue: (j['metValue'] as num?)?.toDouble(),
    description: j['description'],
  );
}

class ExerciseProgressEntry {
  final DateTime date;
  final String workoutId;
  final double? weight;
  final int? sets;
  final int? reps;
  final List<double>? setWeights;
  final List<int>? setReps;

  ExerciseProgressEntry({
    required this.date,
    required this.workoutId,
    this.weight,
    this.sets,
    this.reps,
    this.setWeights,
    this.setReps,
  });

  factory ExerciseProgressEntry.fromJson(Map<String, dynamic> j) =>
      ExerciseProgressEntry(
        date: DateTime.parse(j['date']),
        workoutId: j['workoutId'] ?? '',
        weight: (j['weight'] as num?)?.toDouble(),
        sets: j['sets'] as int?,
        reps: j['reps'] as int?,
        setWeights: (j['setWeights'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList(),
        setReps: (j['setReps'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList(),
      );
}

class ExerciseProgressStats {
  final double? firstWeight;
  final double? lastWeight;
  final double totalGain;
  final int periodDays;
  final int sessionsCount;

  ExerciseProgressStats({
    this.firstWeight,
    this.lastWeight,
    required this.totalGain,
    required this.periodDays,
    required this.sessionsCount,
  });

  factory ExerciseProgressStats.fromJson(Map<String, dynamic> j) =>
      ExerciseProgressStats(
        firstWeight: (j['firstWeight'] as num?)?.toDouble(),
        lastWeight: (j['lastWeight'] as num?)?.toDouble(),
        totalGain: (j['totalGain'] as num?)?.toDouble() ?? 0.0,
        periodDays: j['periodDays'] ?? 0,
        sessionsCount: j['sessionsCount'] ?? 0,
      );
}

class ExerciseProgress {
  final Exercise exercise;
  final List<ExerciseProgressEntry> history;
  final ExerciseProgressStats? stats;
  final String? analysis;

  ExerciseProgress({
    required this.exercise,
    required this.history,
    this.stats,
    this.analysis,
  });

  factory ExerciseProgress.fromJson(Map<String, dynamic> j) => ExerciseProgress(
    exercise: Exercise.fromJson(j['exercise'] ?? {}),
    history: (j['history'] as List? ?? [])
        .map((e) => ExerciseProgressEntry.fromJson(e))
        .toList(),
    stats: j['stats'] != null
        ? ExerciseProgressStats.fromJson(j['stats'])
        : null,
    analysis: j['analysis'],
  );
}
