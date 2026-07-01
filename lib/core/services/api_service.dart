// lib/core/services/api_service.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../models/chat_models.dart';
import '../models/nutrition_models.dart';

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
      {String weightType = 'WEIGHT_KG', double? metValue}) async {
    final res = await _dio.post('/exercises', data: {
      'name': name,
      if (description != null && description.isNotEmpty) 'description': description,
      'weightType': weightType,
      if (metValue != null) 'metValue': metValue,
    });
    return Exercise.fromJson(res.data);
  }

  Future<Exercise> updateExercise(String id, String name, String? description,
      {String weightType = 'WEIGHT_KG', double? metValue}) async {
    final res = await _dio.put('/exercises/$id', data: {
      'name': name,
      if (description != null && description.isNotEmpty) 'description': description,
      'weightType': weightType,
      if (metValue != null) 'metValue': metValue,
    });
    return Exercise.fromJson(res.data);
  }

  Future<void> deleteExercise(String id) async {
    await _dio.delete('/exercises/$id');
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

  // WORKOUTS
  Future<Workout> getWorkout(String id) async {
    final res = await _dio.get('/workouts/$id');
    return Workout.fromJson(res.data);
  }

  Future<Workout> createWorkout({
    required String seasonId,
    String? notes,
    required List<Map<String, dynamic>> exercises,
  }) async {
    final res = await _dio.post('/workouts', data: {
      'seasonId': seasonId,
      if (notes != null) 'notes': notes,
      'exercises': exercises,
    });
    return Workout.fromJson(res.data);
  }

  Future<Workout> updateWorkout(String id, {
    String? notes,
    List<Map<String, dynamic>>? exercises,
  }) async {
    final res = await _dio.put('/workouts/$id', data: {
      if (notes != null) 'notes': notes,
      if (exercises != null) 'exercises': exercises,
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
  }) async {
    final res = await _dio.post('/client-activities', data: {
      'name': name,
      if (metValue != null) 'metValue': metValue,
      if (description != null && description.isNotEmpty)
        'description': description,
    });
    return ClientActivity.fromJson(res.data);
  }

  Future<ClientActivity> updateClientActivity(
      String id, {
        required String name,
        double? metValue,
        String? description,
      }) async {
    final res = await _dio.put('/client-activities/$id', data: {
      'name': name,
      if (metValue != null) 'metValue': metValue,
      if (description != null && description.isNotEmpty)
        'description': description,
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