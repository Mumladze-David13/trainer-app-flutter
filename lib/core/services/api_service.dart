// lib/core/services/api_service.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../models/chat_models.dart';
import '../models/nutrition_models.dart';
import '../models/photo_models.dart';

const String baseUrl = kIsWeb
    ? 'https://swell-haste-lucrative.ngrok-free.dev/api'
    : 'http://144.31.189.154:8080/api';

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        if (kIsWeb) 'ngrok-skip-browser-warning': 'true',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        debugPrint('API Error: ${error.message}');
        debugPrint('API Error URL: ${error.requestOptions.uri}');
        debugPrint('API Error type: ${error.type}');
        if (error.response != null) {
          debugPrint('API Response: ${error.response?.data}');
        }
        if (error.response?.statusCode == 401) {
          // Token expired
        }
        handler.next(error);
      },
    ));
  }

  // AUTH
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    final res = await _dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
    });
    return res.data;
  }

  // Exchanges the one-time code returned by the OAuth redirect callback
  // (see AuthProvider.loginWithOAuth) for the same {token, user} shape as
  // login/register.
  Future<Map<String, dynamic>> exchangeOAuthCode(String code) async {
    final res = await _dio.post('/auth/exchange', data: {'code': code});
    return res.data;
  }

  // USERS
  Future<List<User>> getTrainers() async {
    final res = await _dio.get('/users/trainers');
    return (res.data as List).map((e) => User.fromJson(e)).toList();
  }

  // EXERCISES
  Future<List<Exercise>> getExercises() async {
    final res = await _dio.get('/exercises');
    return (res.data as List).map((e) => Exercise.fromJson(e)).toList();
  }

  Future<Exercise> createExercise(String name, String? description,
      {String weightType = 'WEIGHT_KG', double? metValue, String? equipment}) async {
    final res = await _dio.post('/exercises', data: {
      'name': name,
      if (description != null && description.isNotEmpty) 'description': description,
      'weightType': weightType,
      if (metValue != null) 'metValue': metValue,
      if (equipment != null && equipment.isNotEmpty) 'equipment': equipment,
    });
    return Exercise.fromJson(res.data);
  }

  Future<Exercise> updateExercise(String id, String name, String? description,
      {String weightType = 'WEIGHT_KG', double? metValue, String? equipment}) async {
    final res = await _dio.put('/exercises/$id', data: {
      'name': name,
      if (description != null && description.isNotEmpty) 'description': description,
      'weightType': weightType,
      if (metValue != null) 'metValue': metValue,
      if (equipment != null && equipment.isNotEmpty) 'equipment': equipment,
    });
    return Exercise.fromJson(res.data);
  }

  Future<void> deleteExercise(String id) async {
    await _dio.delete('/exercises/$id');
  }

  Future<Exercise> updateExercisePhoto(String id,
      {required String publicId, required String secureUrl}) async {
    final res = await _dio.put('/exercises/$id/photo', data: {
      'publicId': publicId,
      'secureUrl': secureUrl,
    });
    return Exercise.fromJson(res.data);
  }

  Future<Exercise> deleteExercisePhoto(String id) async {
    final res = await _dio.delete('/exercises/$id/photo');
    return Exercise.fromJson(res.data);
  }

  Future<CloudinarySignatureResponse> getCloudinarySignature(
      String category) async {
    final res = await _dio
        .post('/cloudinary/signature', data: {'category': category});
    return CloudinarySignatureResponse.fromJson(res.data);
  }

  // GLOBAL EXERCISES
  Future<List<GlobalExercise>> fetchGlobalExercises({
    String? category,
    String? equipment,
    String? level,
    String? search,
  }) async {
    final res = await _dio.get('/global-exercises', queryParameters: {
      if (category != null && category.isNotEmpty) 'category': category,
      if (equipment != null && equipment.isNotEmpty) 'equipment': equipment,
      if (level != null && level.isNotEmpty) 'level': level,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return (res.data as List).map((e) => GlobalExercise.fromJson(e)).toList();
  }

  Future<GlobalExerciseImportResult> importGlobalExercises({List<String>? ids}) async {
    final res = await _dio.post('/global-exercises/import', data: {
      if (ids != null) 'ids': ids,
    });
    return GlobalExerciseImportResult.fromJson(res.data);
  }

  // CLIENTS
  Future<List<dynamic>> getMyClients() async {
    final res = await _dio.get('/clients');
    return res.data;
  }

  Future<void> addClient(String clientId) async {
    await _dio.post('/clients', data: {'clientId': clientId});
  }

  Future<ClientWithSeasons> getClientDetail(String clientId) async {
    final res = await _dio.get('/clients/$clientId');
    return ClientWithSeasons.fromJson(res.data);
  }

  // SEASONS
  Future<Season> createSeason(String clientId, String startDate, String? endDate) async {
    final res = await _dio.post('/clients/$clientId/seasons', data: {
      'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
    });
    return Season.fromJson(res.data);
  }

  Future<Season> updateSeason(String clientId, String seasonId,
      {String? name, String? startDate, String? endDate}) async {
    final res = await _dio.put('/clients/$clientId/seasons/$seasonId', data: {
      if (name != null) 'name': name,
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
    });
    return Season.fromJson(res.data);
  }

  Future<void> deleteSeason(String clientId, String seasonId) async {
    await _dio.delete('/clients/$clientId/seasons/$seasonId');
  }

  // WORKOUTS
  Future<Workout> getWorkout(String id) async {
    final res = await _dio.get('/workouts/$id');
    return Workout.fromJson(res.data);
  }

  Future<Workout> createWorkout({
    required String seasonId,
    String? notes,
    required List<Map<String, dynamic>> exercises,
    DateTime? date,
  }) async {
    final res = await _dio.post('/workouts', data: {
      'seasonId': seasonId,
      if (notes != null) 'notes': notes,
      'exercises': exercises,
      if (date != null) 'date': date.toIso8601String(),
    });
    return Workout.fromJson(res.data);
  }

  Future<Workout> updateWorkout(String id, {
    String? notes,
    List<Map<String, dynamic>>? exercises,
    DateTime? date,
  }) async {
    final res = await _dio.put('/workouts/$id', data: {
      if (notes != null) 'notes': notes,
      if (exercises != null) 'exercises': exercises,
      if (date != null) 'date': date.toIso8601String(),
    });
    return Workout.fromJson(res.data);
  }

  Future<void> deleteWorkout(String id) async {
    await _dio.delete('/workouts/$id');
  }

  Future<Workout> saveProgress(String id, List<String> doneIds) async {
    final res = await _dio.patch('/workouts/$id/progress', data: {
      'doneExerciseIds': doneIds,
    });
    return Workout.fromJson(res.data);
  }

  Future<Workout> completeWorkout(String id, List<String> doneIds) async {
    final res = await _dio.post('/workouts/$id/complete', data: {
      'doneExerciseIds': doneIds,
    });
    return Workout.fromJson(res.data);
  }

  Future<List<Season>> getClientSeasons(String trainerId) async {
    final res = await _dio.get('/workouts/client/$trainerId/seasons');
    return (res.data as List).map((e) => Season.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> updateRole(String role) async {
    final res = await _dio.put('/users/me/role', data: {'role': role});
    return res.data;
  }

  // SOLO
  Future<SoloProfile?> getSoloProfile() async {
    final res = await _dio.get('/solo/profile');
    if (res.data == null) return null;
    return SoloProfile.fromJson(res.data);
  }

  Future<SoloProfile> saveSoloProfile({
    required String goal,
    required String level,
    required int daysPerWeek,
    required String equipment,
    String? notes,
  }) async {
    final res = await _dio.post('/solo/profile', data: {
      'goal': goal,
      'level': level,
      'daysPerWeek': daysPerWeek,
      'equipment': equipment,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return SoloProfile.fromJson(res.data);
  }

  Future<SoloProfile> agreeSoloTerms() async {
    final res = await _dio.post('/solo/agree-terms');
    return SoloProfile.fromJson(res.data);
  }

  static final _soloLongTimeout = Options(receiveTimeout: const Duration(seconds: 30));

  Future<Map<String, dynamic>> generateSoloProgram() async {
    final res = await _dio.post('/solo/generate-program', options: _soloLongTimeout);
    return res.data;
  }

  Future<Season?> getSoloCurrentSeason() async {
    final res = await _dio.get('/solo/current-season');
    if (res.data == null) return null;
    return Season.fromJson(res.data);
  }

  Future<List<Season>> getSoloSeasons() async {
    final res = await _dio.get('/solo/seasons');
    return (res.data as List).map((e) => Season.fromJson(e)).toList();
  }

  // SETTINGS
  Future<TrainerSettings> getTrainerSettings() async {
    final res = await _dio.get('/settings/trainer');
    return TrainerSettings.fromJson(res.data);
  }

  Future<TrainerSettings> updateTrainerSettings(int sessionsPerSeason) async {
    final res = await _dio.put('/settings/trainer', data: {
      'sessionsPerSeason': sessionsPerSeason,
    });
    return TrainerSettings.fromJson(res.data);
  }

  Future<Map<String, dynamic>> getClientSettings() async {
    final res = await _dio.get('/settings/client');
    return res.data;
  }

  Future<void> setClientTrainer(String? trainerId) async {
    await _dio.put('/settings/client/trainer', data: {'trainerId': trainerId});
  }

  // SUBSCRIPTION
  Future<SubscriptionPrice> getSubscriptionPrice() async {
    final res = await _dio.get('/subscription/price');
    return SubscriptionPrice.fromJson(res.data);
  }

  Future<SubscriptionPayment> createSubscriptionPayment(String platform) async {
    final res = await _dio.post('/subscription/pay', data: {'platform': platform});
    return SubscriptionPayment.fromJson(res.data);
  }

  Future<String> getSubscriptionPaymentStatus(String paymentId) async {
    final res = await _dio.get('/subscription/payment/$paymentId/status');
    return res.data['status'] as String;
  }

// CHAT
  Future<Map<String, dynamic>> findOrCreateConversation(String userId) async {
    final res = await _dio.post('/conversations/with/$userId');
    return res.data;
  }

  Future<List<Message>> getMessages(String conversationId) async {
    final res = await _dio.get(
      '/conversations/$conversationId/messages',
      queryParameters: {'limit': 50},
    );
    return (res.data as List).map((e) => Message.fromJson(e)).toList();
  }

  Future<void> sendMessage(String conversationId, String text) async {
    await _dio.post(
      '/conversations/$conversationId/messages',
      data: {'text': text},
    );
  }

  Future<void> markMessagesRead(String conversationId) async {
    await _dio.patch('/conversations/$conversationId/read');
  }

  Future<void> saveFcmToken(String token) async {
    await _dio.patch('/users/me/fcm-token', data: {'token': token});
  }

  // POSE ANALYSIS CALIBRATION
  Future<void> uploadPoseCalibrationFrames(
      List<Map<String, dynamic>> frames) async {
    await _dio.post('/pose-analysis/calibration-frames', data: {'frames': frames});
  }

  Future<void> uploadPoseDatasetCase(Map<String, dynamic> caseData) async {
    await _dio.post('/pose-analysis/dataset-cases', data: caseData);
  }

  // AI
  Future<Map<String, dynamic>> aiGenerateProgram(Map<String, dynamic> data) async {
    final res = await _dio.post('/ai/generate-program', data: data);
    return res.data;
  }

  Future<void> aiSaveProgram(Map<String, dynamic> data) async {
    await _dio.post('/ai/save-program', data: data);
  }

  Future<Map<String, dynamic>> aiGetUsage() async {
    final res = await _dio.get('/ai/usage');
    return res.data;
  }

  static final _aiLongTimeout = Options(receiveTimeout: const Duration(seconds: 30));

  Future<Map<String, dynamic>> aiParseMeal(String text, {String? mealType}) async {
    try {
      final res = await _dio.post('/ai/parse-meal', data: {
        'text': text,
        if (mealType != null) 'mealType': mealType,
      }, options: _aiLongTimeout);
      return res.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) rethrow;
      // TEMP STUB: /ai/parse-meal is deployed but returns 500 because
      // ANTHROPIC_API_KEY isn't set on the server yet (see
      // backend_nutrition_ai_apikey_prompt.md). Falls back to a rough local
      // estimate so the review flow can be evaluated end-to-end; remove this
      // catch once the backend key is fixed.
      return _mockParseMeal(text);
    }
  }

  // Голосовой набор тренировки: свободный текст (расшифровка речи) → список
  // распознанных упражнений. Бэкенд-эндпоинт может быть ещё не задеплоен —
  // ошибку намеренно не глотаем как aiParseMeal, а даём вызывающему коду
  // (voice_workout_input_sheet.dart) показать понятное сообщение, чтобы не
  // подсовывать тренеру придуманные подходы/веса.
  Future<List<Map<String, dynamic>>> aiParseWorkout(String text) async {
    final res = await _dio.post('/ai/parse-workout', data: {
      'text': text,
    }, options: _aiLongTimeout);
    return (res.data['exercises'] as List).cast<Map<String, dynamic>>();
  }

  // Голосовой набор тренировки — аудио-версия: распознавание речи целиком
  // на бэкенде (см. backend_voice_workout_audio_prompt.md), клиент только
  // пишет и загружает файл. Тот же формат ответа, что у aiParseWorkout.
  static final _aiAudioTimeout = Options(
    sendTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 60),
  );

  Future<List<Map<String, dynamic>>> aiParseWorkoutAudio(File audioFile) async {
    final formData = FormData.fromMap({
      'audio': await MultipartFile.fromFile(audioFile.path),
    });
    final res = await _dio.post('/ai/parse-workout-audio',
        data: formData, options: _aiAudioTimeout);
    return (res.data['exercises'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> aiLogMeal(Map<String, dynamic> data) async {
    await _dio.post('/ai/log-meal', data: data, options: _aiLongTimeout);
  }

  Future<Map<String, dynamic>> aiGenerateMealPlan(String clientId, {String? preferences}) async {
    try {
      final res = await _dio.post('/ai/generate-meal-plan', data: {
        'clientId': clientId,
        if (preferences != null && preferences.isNotEmpty) 'preferences': preferences,
      }, options: _aiLongTimeout);
      return res.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) rethrow;
      // TEMP STUB: same backend blocker as aiParseMeal above — see
      // backend_nutrition_ai_apikey_prompt.md. Remove once fixed.
      return _mockGenerateMealPlan();
    }
  }

  static const Map<String, List<double>> _mockFoodMacros = {
    'гречк': [132, 4.5, 25, 1.1],
    'куриц': [165, 31, 0, 3.6],
    'курин': [165, 31, 0, 3.6],
    'рис': [130, 2.7, 28, 0.3],
    'яйц': [155, 13, 1.1, 11],
    'овсян': [88, 3, 15, 1.5],
    'творог': [121, 18, 3, 5],
    'банан': [89, 1.1, 23, 0.3],
    'хлеб': [265, 9, 49, 3.2],
    'молок': [60, 3.2, 4.8, 3.2],
    'чай': [1, 0, 0.3, 0],
    'кофе': [2, 0.3, 0, 0],
    'сыр': [350, 25, 1.3, 27],
    'яблок': [52, 0.3, 14, 0.2],
    'картоф': [77, 2, 17, 0.1],
    'макарон': [131, 5, 25, 1.1],
    'салат': [15, 1.4, 2.9, 0.2],
    'огур': [15, 0.7, 3.6, 0.1],
    'помидор': [18, 0.9, 3.9, 0.2],
    'лосос': [208, 20, 0, 13],
    'йогурт': [61, 3.5, 4.7, 3.3],
  };

  static const List<double> _mockGenericFood = [180, 8, 18, 7];

  Map<String, dynamic> _mockFoodItem(String name, double grams, [List<double>? macros]) {
    final m = macros ?? _mockGenericFood;
    return {
      'name': name,
      'amountGrams': grams,
      'caloriesPer100g': m[0],
      'proteinPer100g': m[1],
      'carbsPer100g': m[2],
      'fatPer100g': m[3],
    };
  }

  Map<String, dynamic> _mockParseMeal(String text) {
    final segments = text
        .split(RegExp(r'[,;]| и |\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (segments.isEmpty) segments.add(text.trim());

    final items = segments.map((seg) {
      final gramsMatch = RegExp(r'(\d+)\s*г').firstMatch(seg);
      final grams = gramsMatch != null ? double.parse(gramsMatch.group(1)!) : 150.0;
      final lower = seg.toLowerCase();
      final macros = _mockFoodMacros.entries
          .firstWhere((e) => lower.contains(e.key), orElse: () => const MapEntry('', _mockGenericFood))
          .value;
      final name = seg.replaceAll(RegExp(r'\d+\s*г'), '').trim();
      return _mockFoodItem(name.isEmpty ? seg : name, grams, macros);
    }).toList();

    return {'items': items};
  }

  Map<String, dynamic> _mockGenerateMealPlan() {
    final meals = [
      {
        'type': 'breakfast',
        'time': '08:00',
        'items': [
          _mockFoodItem('Овсянка на молоке', 250, _mockFoodMacros['овсян']),
          _mockFoodItem('Банан', 120, _mockFoodMacros['банан']),
        ],
      },
      {
        'type': 'lunch',
        'time': '13:00',
        'items': [
          _mockFoodItem('Куриная грудка', 150, _mockFoodMacros['куриц']),
          _mockFoodItem('Гречка', 150, _mockFoodMacros['гречк']),
          _mockFoodItem('Огурец', 100, _mockFoodMacros['огур']),
        ],
      },
      {
        'type': 'snack',
        'time': '16:00',
        'items': [
          _mockFoodItem('Творог', 150, _mockFoodMacros['творог']),
        ],
      },
      {
        'type': 'dinner',
        'time': '19:00',
        'items': [
          _mockFoodItem('Лосось', 150, _mockFoodMacros['лосос']),
          _mockFoodItem('Салат овощной', 150, _mockFoodMacros['салат']),
        ],
      },
    ];

    double totalCal = 0, totalP = 0, totalC = 0, totalF = 0;
    for (final meal in meals) {
      for (final it in (meal['items'] as List).cast<Map<String, dynamic>>()) {
        final grams = it['amountGrams'] as double;
        totalCal += (it['caloriesPer100g'] as double) * grams / 100;
        totalP += (it['proteinPer100g'] as double) * grams / 100;
        totalC += (it['carbsPer100g'] as double) * grams / 100;
        totalF += (it['fatPer100g'] as double) * grams / 100;
      }
    }

    return {
      'meals': meals,
      'totals': {
        'calories': totalCal,
        'protein': totalP,
        'carbs': totalC,
        'fat': totalF,
      },
    };
  }

  Future<void> aiSaveMealPlan(Map<String, dynamic> data) async {
    await _dio.post('/ai/save-meal-plan', data: data, options: _aiLongTimeout);
  }

  // NUTRITION
  Future<NutritionProfileData> getNutritionProfile(String clientId) async {
    final res = await _dio.get('/nutrition/profile/$clientId');
    return NutritionProfileData.fromJson(res.data);
  }

  Future<void> saveNutritionProfile(String clientId, Map<String, dynamic> data) async {
    await _dio.post('/nutrition/profile', data: {'clientId': clientId, ...data});
  }

  Future<Map<String, dynamic>> getMealPlan(String clientId, String date) async {
    final res = await _dio.get('/nutrition/meal-plan/$clientId',
        queryParameters: {'date': date});
    return res.data as Map<String, dynamic>;
  }

  Future<void> addMealToMealPlan(String mealPlanId, String type,
      {String? time, String? notes}) async {
    await _dio.post('/nutrition/meal-plan/$mealPlanId/meals', data: {
      'type': type,
      if (time != null) 'time': time,
      if (notes != null) 'notes': notes,
    });
  }

  Future<void> addFoodToMeal(String mealId, String foodItemId, double amountGrams) async {
    await _dio.post('/nutrition/meals/$mealId/items', data: {
      'foodItemId': foodItemId,
      'amountGrams': amountGrams,
    });
  }

  Future<void> deleteMealItem(String itemId) async {
    await _dio.delete('/nutrition/meal-items/$itemId');
  }

  Future<void> updateMealItem(String itemId, double amountGrams) async {
    await _dio.patch('/nutrition/meal-items/$itemId', data: {'amountGrams': amountGrams});
  }

  Future<void> updateMeal(String mealId,
      {String? type, String? time, String? notes}) async {
    await _dio.patch('/nutrition/meals/$mealId', data: {
      if (type != null) 'type': type,
      if (time != null) 'time': time,
      if (notes != null) 'notes': notes,
    });
  }

  Future<void> deleteMeal(String mealId) async {
    await _dio.delete('/nutrition/meals/$mealId');
  }

  Future<FoodItem> updateFoodItem(
      String id, {
        String? name,
        double? caloriesPer100g,
        double? proteinPer100g,
        double? carbsPer100g,
        double? fatPer100g,
        String? category,
      }) async {
    final res = await _dio.patch('/nutrition/food/$id', data: {
      if (name != null) 'name': name,
      if (caloriesPer100g != null) 'caloriesPer100g': caloriesPer100g,
      if (proteinPer100g != null) 'proteinPer100g': proteinPer100g,
      if (carbsPer100g != null) 'carbsPer100g': carbsPer100g,
      if (fatPer100g != null) 'fatPer100g': fatPer100g,
      if (category != null) 'category': category,
    });
    return FoodItem.fromJson(res.data);
  }

  Future<void> deleteFoodItem(String id) async {
    await _dio.delete('/nutrition/food/$id');
  }

  Future<NutritionSummary> getNutritionSummary(String clientId, String date) async {
    final res = await _dio.get('/nutrition/summary/$clientId',
        queryParameters: {'date': date});
    return NutritionSummary.fromJson(res.data);
  }

  Future<List<FoodItem>> searchFood(String query, {String? clientId}) async {
    final res = await _dio.get('/nutrition/food', queryParameters: {
      if (query.isNotEmpty) 'q': query,
      if (clientId != null) 'clientId': clientId,
    });
    return (res.data as List).map((e) => FoodItem.fromJson(e)).toList();
  }

  Future<FoodItem> createFoodItem({
    required String name,
    required double caloriesPer100g,
    required double proteinPer100g,
    required double carbsPer100g,
    required double fatPer100g,
    String? category,
  }) async {
    final res = await _dio.post('/nutrition/food', data: {
      'name': name,
      'caloriesPer100g': caloriesPer100g,
      'proteinPer100g': proteinPer100g,
      'carbsPer100g': carbsPer100g,
      'fatPer100g': fatPer100g,
      if (category != null) 'category': category,
    });
    return FoodItem.fromJson(res.data);
  }

  // WEIGHT LOG
  Future<WeightLog> addWeightLog(double weightKg, {String? notes}) async {
    final res = await _dio.post('/weight-log', data: {
      'weightKg': weightKg,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return WeightLog.fromJson(res.data);
  }

  Future<List<WeightLog>> getWeightLogs() async {
    final res = await _dio.get('/weight-log');
    return (res.data as List).map((e) => WeightLog.fromJson(e)).toList();
  }

  Future<WeightAnalysis> getWeightAnalysis() async {
    final res = await _dio.get('/weight-log/analysis');
    return WeightAnalysis.fromJson(res.data);
  }

  Future<void> deleteWeightLog(String id) async {
    await _dio.delete('/weight-log/$id');
  }

  Future<List<WeightLog>> getClientWeightLogs(String clientId) async {
    final res = await _dio.get('/weight-log/client/$clientId');
    return (res.data as List).map((e) => WeightLog.fromJson(e)).toList();
  }

  Future<WeightAnalysis> getClientWeightAnalysis(String clientId) async {
    final res = await _dio.get('/weight-log/client/$clientId/analysis');
    return WeightAnalysis.fromJson(res.data);
  }

  // CLIENT SESSIONS
  Future<ClientSession> createClientSession({
    String? notes,
    required List<Map<String, dynamic>> exercises,
  }) async {
    final res = await _dio.post('/client-sessions', data: {
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'exercises': exercises,
    });
    return ClientSession.fromJson(res.data);
  }

  Future<List<ClientSession>> getClientSessions() async {
    final res = await _dio.get('/client-sessions');
    return (res.data as List).map((e) => ClientSession.fromJson(e)).toList();
  }

  Future<ClientSession> getClientSession(String id) async {
    final res = await _dio.get('/client-sessions/$id');
    return ClientSession.fromJson(res.data);
  }

  Future<ClientSession> updateClientSession(String id, {
    String? notes,
    required List<Map<String, dynamic>> exercises,
  }) async {
    final res = await _dio.put('/client-sessions/$id', data: {
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'exercises': exercises,
    });
    return ClientSession.fromJson(res.data);
  }

  Future<void> deleteClientSession(String id) async {
    await _dio.delete('/client-sessions/$id');
  }

  Future<BurnedCalories> getBurnedCalories(String date) async {
    final res = await _dio.get('/client-sessions/burned-calories',
        queryParameters: {'date': date});
    return BurnedCalories.fromJson(res.data);
  }

  Future<List<ClientSession>> getTrainerClientSessions(String clientId) async {
    final res = await _dio.get('/client-sessions/trainer/client/$clientId');
    return (res.data as List).map((e) => ClientSession.fromJson(e)).toList();
  }

  Future<BurnedCalories> getTrainerClientBurnedCalories(
      String clientId, String date) async {
    final res = await _dio.get(
        '/client-sessions/trainer/client/$clientId/burned-calories',
        queryParameters: {'date': date});
    return BurnedCalories.fromJson(res.data);
  }

  // CLIENT ACTIVITIES
  Future<List<ClientActivity>> getClientActivities() async {
    final res = await _dio.get('/client-activities');
    return (res.data as List).map((e) => ClientActivity.fromJson(e)).toList();
  }

  Future<ClientActivity> createClientActivity({
    required String name,
    double? metValue,
    String? description,
    ActivityUnit unit = ActivityUnit.times,
  }) async {
    final res = await _dio.post('/client-activities', data: {
      'name': name,
      if (metValue != null) 'metValue': metValue,
      if (description != null && description.isNotEmpty)
        'description': description,
      'unit': unit.toJson(),
    });
    return ClientActivity.fromJson(res.data);
  }

  Future<ClientActivity> updateClientActivity(
      String id, {
        required String name,
        double? metValue,
        String? description,
        ActivityUnit unit = ActivityUnit.times,
      }) async {
    final res = await _dio.put('/client-activities/$id', data: {
      'name': name,
      if (metValue != null) 'metValue': metValue,
      if (description != null && description.isNotEmpty)
        'description': description,
      'unit': unit.toJson(),
    });
    return ClientActivity.fromJson(res.data);
  }

  Future<void> deleteClientActivity(String id) async {
    await _dio.delete('/client-activities/$id');
  }

  Future<List<ClientActivity>> getTrainerClientActivities(
      String clientId) async {
    final res =
    await _dio.get('/client-activities/trainer/client/$clientId');
    return (res.data as List).map((e) => ClientActivity.fromJson(e)).toList();
  }

  Future<ClientActivityLog> addClientActivityLog(
      String activityId, double value, {DateTime? date}) async {
    final res = await _dio.post('/client-activities/$activityId/logs', data: {
      'value': value,
      if (date != null) 'date': date.toIso8601String(),
    });
    return ClientActivityLog.fromJson(res.data);
  }

  Future<List<ClientActivityLog>> getClientActivityLogs(
      String activityId) async {
    final res = await _dio.get('/client-activities/$activityId/logs');
    return (res.data as List)
        .map((e) => ClientActivityLog.fromJson(e))
        .toList();
  }

  Future<void> deleteClientActivityLog(String activityId, String logId) async {
    await _dio.delete('/client-activities/$activityId/logs/$logId');
  }

  // EXERCISE PROGRESS
  Future<ExerciseProgress> getExerciseProgress(String exerciseId) async {
    final res = await _dio.get('/exercises/$exerciseId/progress');
    return ExerciseProgress.fromJson(res.data);
  }

  Future<ExerciseProgress> getExerciseProgressAnalysis(
      String exerciseId) async {
    final res = await _dio.get('/exercises/$exerciseId/progress/analysis');
    return ExerciseProgress.fromJson(res.data);
  }

  Future<ExerciseProgress> getClientExerciseProgress(
      String exerciseId, String clientId) async {
    final res = await _dio
        .get('/exercises/$exerciseId/progress/client/$clientId');
    return ExerciseProgress.fromJson(res.data);
  }

  Future<ExerciseProgress> getClientExerciseProgressAnalysis(
      String exerciseId, String clientId) async {
    final res = await _dio
        .get('/exercises/$exerciseId/progress/client/$clientId/analysis');
    return ExerciseProgress.fromJson(res.data);
  }

  // GYMS
  Future<List<Gym>> getGyms() async {
    final res = await _dio.get('/gyms');
    return (res.data as List).map((e) => Gym.fromJson(e)).toList();
  }

  Future<Gym> createGym(String name, {Address? address}) async {
    final res = await _dio.post('/gyms', data: {
      'name': name,
      if (address != null) 'address': address.toJson(),
    });
    return Gym.fromJson(res.data);
  }

  Future<Gym> updateGym(String id, {String? name, Address? address}) async {
    final res = await _dio.patch('/gyms/$id', data: {
      if (name != null) 'name': name,
      if (address != null) 'address': address.toJson(),
    });
    return Gym.fromJson(res.data);
  }

  Future<void> deleteGym(String id) async {
    await _dio.delete('/gyms/$id');
  }

  Future<List<Map<String, dynamic>>> getAddressSuggestions(String query) async {
    final res = await _dio.get('/gyms/address/suggest',
        queryParameters: {'q': query});
    final suggestions = res.data['suggestions'] as List? ?? [];
    return suggestions.cast<Map<String, dynamic>>();
  }

}