// lib/core/models/nutrition_models.dart

class NutritionProfile {
  final String clientId;
  final String gender;
  final int age;
  final double weightKg;
  final double heightCm;
  final String activityLevel;
  final String goal;
  final double? targetWeeklyChange;

  NutritionProfile({
    required this.clientId,
    required this.gender,
    required this.age,
    required this.weightKg,
    required this.heightCm,
    required this.activityLevel,
    required this.goal,
    this.targetWeeklyChange,
  });

  factory NutritionProfile.fromJson(Map<String, dynamic> j) => NutritionProfile(
        clientId: j['clientId'] ?? '',
        gender: j['gender'] ?? 'male',
        age: (j['age'] as num?)?.toInt() ?? 25,
        weightKg: (j['weightKg'] as num?)?.toDouble() ?? 70.0,
        heightCm: (j['heightCm'] as num?)?.toDouble() ?? 170.0,
        activityLevel: j['activityLevel'] ?? 'moderate',
        goal: j['goal'] ?? 'maintain',
        targetWeeklyChange: (j['targetWeeklyChange'] as num?)?.toDouble(),
      );
}

class MacroNutrients {
  final double protein;
  final double fat;
  final double carbs;

  MacroNutrients({required this.protein, required this.fat, required this.carbs});

  factory MacroNutrients.fromJson(Map<String, dynamic> j) => MacroNutrients(
        protein: (j['protein'] as num?)?.toDouble() ?? 0,
        fat: (j['fat'] as num?)?.toDouble() ?? 0,
        carbs: (j['carbs'] as num?)?.toDouble() ?? 0,
      );
}

class NutritionCalculations {
  final double bmr;
  final double tdee;
  final double targetCalories;
  final MacroNutrients macros;

  NutritionCalculations({
    required this.bmr,
    required this.tdee,
    required this.targetCalories,
    required this.macros,
  });

  factory NutritionCalculations.fromJson(Map<String, dynamic> j) => NutritionCalculations(
        bmr: (j['bmr'] as num?)?.toDouble() ?? 0,
        tdee: (j['tdee'] as num?)?.toDouble() ?? 0,
        targetCalories: (j['targetCalories'] as num?)?.toDouble() ?? 0,
        macros: MacroNutrients.fromJson(j['macros'] as Map<String, dynamic>? ?? {}),
      );
}

class NutritionProfileData {
  final NutritionProfile profile;
  final NutritionCalculations calculations;

  NutritionProfileData({required this.profile, required this.calculations});

  factory NutritionProfileData.fromJson(Map<String, dynamic> j) => NutritionProfileData(
        profile: NutritionProfile.fromJson(j['profile'] as Map<String, dynamic>? ?? {}),
        calculations:
            NutritionCalculations.fromJson(j['calculations'] as Map<String, dynamic>? ?? {}),
      );
}

class FoodItem {
  final String id;
  final String name;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final String? category;

  FoodItem({
    required this.id,
    required this.name,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.category,
  });

  factory FoodItem.fromJson(Map<String, dynamic> j) => FoodItem(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        caloriesPer100g: (j['caloriesPer100g'] as num?)?.toDouble() ?? 0,
        proteinPer100g: (j['proteinPer100g'] as num?)?.toDouble() ?? 0,
        carbsPer100g: (j['carbsPer100g'] as num?)?.toDouble() ?? 0,
        fatPer100g: (j['fatPer100g'] as num?)?.toDouble() ?? 0,
        category: j['category'],
      );
}

class MealItemData {
  final String id;
  final double amountGrams;
  final FoodItem foodItem;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  MealItemData({
    required this.id,
    required this.amountGrams,
    required this.foodItem,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory MealItemData.fromJson(Map<String, dynamic> j) {
    final computed = j['computed'] as Map<String, dynamic>? ?? {};
    return MealItemData(
      id: j['id'] ?? '',
      amountGrams: (j['amountGrams'] as num?)?.toDouble() ?? 0,
      foodItem: FoodItem.fromJson(j['foodItem'] as Map<String, dynamic>? ?? {}),
      calories: (computed['calories'] as num?)?.toDouble() ?? 0,
      protein: (computed['protein'] as num?)?.toDouble() ?? 0,
      carbs: (computed['carbs'] as num?)?.toDouble() ?? 0,
      fat: (computed['fat'] as num?)?.toDouble() ?? 0,
    );
  }
}

class MealData {
  final String id;
  final String type;
  final String? time;
  final String? notes;
  final double subtotalCalories;
  final double subtotalProtein;
  final double subtotalCarbs;
  final double subtotalFat;
  final List<MealItemData> items;

  MealData({
    required this.id,
    required this.type,
    this.time,
    this.notes,
    required this.subtotalCalories,
    required this.subtotalProtein,
    required this.subtotalCarbs,
    required this.subtotalFat,
    required this.items,
  });

  factory MealData.fromJson(Map<String, dynamic> j) {
    final sub = j['subtotal'] as Map<String, dynamic>? ?? {};
    return MealData(
      id: j['id'] ?? '',
      type: j['type'] ?? 'snack',
      time: j['time'],
      notes: j['notes'],
      subtotalCalories: (sub['calories'] as num?)?.toDouble() ?? 0,
      subtotalProtein: (sub['protein'] as num?)?.toDouble() ?? 0,
      subtotalCarbs: (sub['carbs'] as num?)?.toDouble() ?? 0,
      subtotalFat: (sub['fat'] as num?)?.toDouble() ?? 0,
      items: (j['items'] as List? ?? []).map((e) => MealItemData.fromJson(e)).toList(),
    );
  }
}

class NutritionSummary {
  final double targetCalories;
  final double targetProtein;
  final double targetCarbs;
  final double targetFat;
  final double consumedCalories;
  final double consumedProtein;
  final double consumedCarbs;
  final double consumedFat;
  final double percentCalories;
  final List<MealData> meals;

  NutritionSummary({
    required this.targetCalories,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
    required this.consumedCalories,
    required this.consumedProtein,
    required this.consumedCarbs,
    required this.consumedFat,
    required this.percentCalories,
    required this.meals,
  });

  factory NutritionSummary.fromJson(Map<String, dynamic> j) => NutritionSummary(
        targetCalories: (j['targetCalories'] as num?)?.toDouble() ?? 0,
        targetProtein: (j['targetProtein'] as num?)?.toDouble() ?? 0,
        targetCarbs: (j['targetCarbs'] as num?)?.toDouble() ?? 0,
        targetFat: (j['targetFat'] as num?)?.toDouble() ?? 0,
        consumedCalories: (j['consumedCalories'] as num?)?.toDouble() ?? 0,
        consumedProtein: (j['consumedProtein'] as num?)?.toDouble() ?? 0,
        consumedCarbs: (j['consumedCarbs'] as num?)?.toDouble() ?? 0,
        consumedFat: (j['consumedFat'] as num?)?.toDouble() ?? 0,
        percentCalories: (j['percentCalories'] as num?)?.toDouble() ?? 0,
        meals: (j['meals'] as List? ?? []).map((e) => MealData.fromJson(e)).toList(),
      );
}
