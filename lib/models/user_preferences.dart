import 'package:uuid/uuid.dart';

class DietaryPreferences {
  final List<String> preferences;
  final List<String> allergies;
  final List<String> dislikedFoods;
  final bool isVegetarian;
  final bool isVegan;
  final bool isGlutenFree;
  final bool isDairyFree;
  final bool isKeto;
  final bool isPaleo;
  final int mealsPerDay;
  final int snacksPerDay;
  final Map<String, dynamic> customPreferences;

  DietaryPreferences({
    List<String>? preferences,
    List<String>? allergies,
    List<String>? dislikedFoods,
    this.isVegetarian = false,
    this.isVegan = false,
    this.isGlutenFree = false,
    this.isDairyFree = false,
    this.isKeto = false,
    this.isPaleo = false,
    this.mealsPerDay = 3,
    this.snacksPerDay = 2,
    Map<String, dynamic>? customPreferences,
  })  : preferences = preferences ?? [],
        allergies = allergies ?? [],
        dislikedFoods = dislikedFoods ?? [],
        customPreferences = customPreferences ?? {};

  List<String> get dietaryTags {
    final tags = <String>[];
    if (isVegetarian) tags.add('vegetarian');
    if (isVegan) tags.add('vegan');
    if (isGlutenFree) tags.add('gluten-free');
    if (isDairyFree) tags.add('dairy-free');
    if (isKeto) tags.add('keto');
    if (isPaleo) tags.add('paleo');
    tags.addAll(preferences);
    return tags;
  }

  DietaryPreferences copyWith({
    List<String>? preferences,
    List<String>? allergies,
    List<String>? dislikedFoods,
    bool? isVegetarian,
    bool? isVegan,
    bool? isGlutenFree,
    bool? isDairyFree,
    bool? isKeto,
    bool? isPaleo,
    int? mealsPerDay,
    int? snacksPerDay,
    Map<String, dynamic>? customPreferences,
  }) {
    return DietaryPreferences(
      preferences: preferences ?? this.preferences,
      allergies: allergies ?? this.allergies,
      dislikedFoods: dislikedFoods ?? this.dislikedFoods,
      isVegetarian: isVegetarian ?? this.isVegetarian,
      isVegan: isVegan ?? this.isVegan,
      isGlutenFree: isGlutenFree ?? this.isGlutenFree,
      isDairyFree: isDairyFree ?? this.isDairyFree,
      isKeto: isKeto ?? this.isKeto,
      isPaleo: isPaleo ?? this.isPaleo,
      mealsPerDay: mealsPerDay ?? this.mealsPerDay,
      snacksPerDay: snacksPerDay ?? this.snacksPerDay,
      customPreferences: customPreferences ?? this.customPreferences,
    );
  }

  factory DietaryPreferences.fromJson(Map<String, dynamic> json) {
    return DietaryPreferences(
      preferences: List<String>.from(json['preferences'] ?? []),
      allergies: List<String>.from(json['allergies'] ?? []),
      dislikedFoods: List<String>.from(json['disliked_foods'] ?? []),
      isVegetarian: json['is_vegetarian'] ?? false,
      isVegan: json['is_vegan'] ?? false,
      isGlutenFree: json['is_gluten_free'] ?? false,
      isDairyFree: json['is_dairy_free'] ?? false,
      isKeto: json['is_keto'] ?? false,
      isPaleo: json['is_paleo'] ?? false,
      mealsPerDay: json['meals_per_day'] ?? 3,
      snacksPerDay: json['snacks_per_day'] ?? 2,
      customPreferences: json['custom_preferences'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preferences': preferences,
      'allergies': allergies,
      'disliked_foods': dislikedFoods,
      'is_vegetarian': isVegetarian,
      'is_vegan': isVegan,
      'is_gluten_free': isGlutenFree,
      'is_dairy_free': isDairyFree,
      'is_keto': isKeto,
      'is_paleo': isPaleo,
      'meals_per_day': mealsPerDay,
      'snacks_per_day': snacksPerDay,
      'custom_preferences': customPreferences,
    };
  }
}

class FitnessGoals {
  final String primary;
  final List<String> secondary;
  final int workoutsPerWeek;
  final int minutesPerWorkout;
  final bool trackStrength;
  final bool trackCardio;
  final bool trackFlexibility;
  final Map<String, dynamic> customGoals;

  FitnessGoals({
    required this.primary,
    List<String>? secondary,
    this.workoutsPerWeek = 3,
    this.minutesPerWorkout = 45,
    this.trackStrength = true,
    this.trackCardio = true,
    this.trackFlexibility = false,
    Map<String, dynamic>? customGoals,
  })  : secondary = secondary ?? [],
        customGoals = customGoals ?? {};

  FitnessGoals copyWith({
    String? primary,
    List<String>? secondary,
    int? workoutsPerWeek,
    int? minutesPerWorkout,
    bool? trackStrength,
    bool? trackCardio,
    bool? trackFlexibility,
    Map<String, dynamic>? customGoals,
  }) {
    return FitnessGoals(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      workoutsPerWeek: workoutsPerWeek ?? this.workoutsPerWeek,
      minutesPerWorkout: minutesPerWorkout ?? this.minutesPerWorkout,
      trackStrength: trackStrength ?? this.trackStrength,
      trackCardio: trackCardio ?? this.trackCardio,
      trackFlexibility: trackFlexibility ?? this.trackFlexibility,
      customGoals: customGoals ?? this.customGoals,
    );
  }

  factory FitnessGoals.fromJson(Map<String, dynamic> json) {
    return FitnessGoals(
      primary: json['primary'] ?? 'general_fitness',
      secondary: List<String>.from(json['secondary'] ?? []),
      workoutsPerWeek: json['workouts_per_week'] ?? 3,
      minutesPerWorkout: json['minutes_per_workout'] ?? 45,
      trackStrength: json['track_strength'] ?? true,
      trackCardio: json['track_cardio'] ?? true,
      trackFlexibility: json['track_flexibility'] ?? false,
      customGoals: json['custom_goals'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'primary': primary,
      'secondary': secondary,
      'workouts_per_week': workoutsPerWeek,
      'minutes_per_workout': minutesPerWorkout,
      'track_strength': trackStrength,
      'track_cardio': trackCardio,
      'track_flexibility': trackFlexibility,
      'custom_goals': customGoals,
    };
  }
}

class EquipmentAvailability {
  final List<String> available;
  final bool hasGym;
  final bool hasHomeEquipment;
  final Map<String, dynamic> customEquipment;

  EquipmentAvailability({
    List<String>? available,
    this.hasGym = false,
    this.hasHomeEquipment = true,
    Map<String, dynamic>? customEquipment,
  })  : available = available ?? ['bodyweight'],
        customEquipment = customEquipment ?? {};

  EquipmentAvailability copyWith({
    List<String>? available,
    bool? hasGym,
    bool? hasHomeEquipment,
    Map<String, dynamic>? customEquipment,
  }) {
    return EquipmentAvailability(
      available: available ?? this.available,
      hasGym: hasGym ?? this.hasGym,
      hasHomeEquipment: hasHomeEquipment ?? this.hasHomeEquipment,
      customEquipment: customEquipment ?? this.customEquipment,
    );
  }

  factory EquipmentAvailability.fromJson(Map<String, dynamic> json) {
    return EquipmentAvailability(
      available: List<String>.from(json['available'] ?? ['bodyweight']),
      hasGym: json['has_gym'] ?? false,
      hasHomeEquipment: json['has_home_equipment'] ?? true,
      customEquipment: json['custom_equipment'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'available': available,
      'has_gym': hasGym,
      'has_home_equipment': hasHomeEquipment,
      'custom_equipment': customEquipment,
    };
  }
}

class NotificationSettings {
  final bool enableMealReminders;
  final bool enableWorkoutReminders;
  final bool enableProgressUpdates;
  final Map<String, List<int>> mealReminderTimes;
  final Map<String, List<int>> workoutReminderTimes;
  final Map<String, dynamic> customSettings;

  NotificationSettings({
    this.enableMealReminders = true,
    this.enableWorkoutReminders = true,
    this.enableProgressUpdates = true,
    Map<String, List<int>>? mealReminderTimes,
    Map<String, List<int>>? workoutReminderTimes,
    Map<String, dynamic>? customSettings,
  })  : mealReminderTimes = mealReminderTimes ?? {},
        workoutReminderTimes = workoutReminderTimes ?? {},
        customSettings = customSettings ?? {};

  NotificationSettings copyWith({
    bool? enableMealReminders,
    bool? enableWorkoutReminders,
    bool? enableProgressUpdates,
    Map<String, List<int>>? mealReminderTimes,
    Map<String, List<int>>? workoutReminderTimes,
    Map<String, dynamic>? customSettings,
  }) {
    return NotificationSettings(
      enableMealReminders: enableMealReminders ?? this.enableMealReminders,
      enableWorkoutReminders:
          enableWorkoutReminders ?? this.enableWorkoutReminders,
      enableProgressUpdates:
          enableProgressUpdates ?? this.enableProgressUpdates,
      mealReminderTimes: mealReminderTimes ?? this.mealReminderTimes,
      workoutReminderTimes: workoutReminderTimes ?? this.workoutReminderTimes,
      customSettings: customSettings ?? this.customSettings,
    );
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    final mealTimes = <String, List<int>>{};
    final workoutTimes = <String, List<int>>{};

    if (json['meal_reminder_times'] != null) {
      json['meal_reminder_times'].forEach((key, value) {
        mealTimes[key] = List<int>.from(value);
      });
    }

    if (json['workout_reminder_times'] != null) {
      json['workout_reminder_times'].forEach((key, value) {
        workoutTimes[key] = List<int>.from(value);
      });
    }

    return NotificationSettings(
      enableMealReminders: json['enable_meal_reminders'] ?? true,
      enableWorkoutReminders: json['enable_workout_reminders'] ?? true,
      enableProgressUpdates: json['enable_progress_updates'] ?? true,
      mealReminderTimes: mealTimes,
      workoutReminderTimes: workoutTimes,
      customSettings: json['custom_settings'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enable_meal_reminders': enableMealReminders,
      'enable_workout_reminders': enableWorkoutReminders,
      'enable_progress_updates': enableProgressUpdates,
      'meal_reminder_times': mealReminderTimes,
      'workout_reminder_times': workoutReminderTimes,
      'custom_settings': customSettings,
    };
  }
}

class UserPreferences {
  final String id;
  final String userId;
  final DietaryPreferences dietaryPreferences;
  final FitnessGoals fitnessGoals;
  final EquipmentAvailability equipment;
  final double targetCalories;
  final double targetProtein;
  final double targetCarbohydrates;
  final double targetFat;
  final bool autoGenerateMealPlans;
  final bool autoSuggestWorkouts;
  final NotificationSettings notificationSettings;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserPreferences({
    String? id,
    required this.userId,
    DietaryPreferences? dietaryPreferences,
    FitnessGoals? fitnessGoals,
    EquipmentAvailability? equipment,
    this.targetCalories = 2000,
    this.targetProtein = 150,
    this.targetCarbohydrates = 200,
    this.targetFat = 65,
    this.autoGenerateMealPlans = false,
    this.autoSuggestWorkouts = false,
    NotificationSettings? notificationSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        dietaryPreferences = dietaryPreferences ?? DietaryPreferences(),
        fitnessGoals = fitnessGoals ?? FitnessGoals(primary: 'general_fitness'),
        equipment = equipment ?? EquipmentAvailability(),
        notificationSettings = notificationSettings ?? NotificationSettings(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  UserPreferences copyWith({
    String? id,
    String? userId,
    DietaryPreferences? dietaryPreferences,
    FitnessGoals? fitnessGoals,
    EquipmentAvailability? equipment,
    double? targetCalories,
    double? targetProtein,
    double? targetCarbohydrates,
    double? targetFat,
    bool? autoGenerateMealPlans,
    bool? autoSuggestWorkouts,
    NotificationSettings? notificationSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserPreferences(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      fitnessGoals: fitnessGoals ?? this.fitnessGoals,
      equipment: equipment ?? this.equipment,
      targetCalories: targetCalories ?? this.targetCalories,
      targetProtein: targetProtein ?? this.targetProtein,
      targetCarbohydrates: targetCarbohydrates ?? this.targetCarbohydrates,
      targetFat: targetFat ?? this.targetFat,
      autoGenerateMealPlans:
          autoGenerateMealPlans ?? this.autoGenerateMealPlans,
      autoSuggestWorkouts: autoSuggestWorkouts ?? this.autoSuggestWorkouts,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      id: json['id'],
      userId: json['user_id'] ?? '',
      dietaryPreferences: json['dietary_preferences'] != null
          ? DietaryPreferences.fromJson(json['dietary_preferences'])
          : null,
      fitnessGoals: json['fitness_goals'] != null
          ? FitnessGoals.fromJson(json['fitness_goals'])
          : null,
      equipment: json['equipment'] != null
          ? EquipmentAvailability.fromJson(json['equipment'])
          : null,
      targetCalories: (json['target_calories'] ?? 2000).toDouble(),
      targetProtein: (json['target_protein'] ?? 150).toDouble(),
      targetCarbohydrates: (json['target_carbohydrates'] ?? 200).toDouble(),
      targetFat: (json['target_fat'] ?? 65).toDouble(),
      autoGenerateMealPlans: json['auto_generate_meal_plans'] ?? false,
      autoSuggestWorkouts: json['auto_suggest_workouts'] ?? false,
      notificationSettings: json['notification_settings'] != null
          ? NotificationSettings.fromJson(json['notification_settings'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'dietary_preferences': dietaryPreferences.toJson(),
      'fitness_goals': fitnessGoals.toJson(),
      'equipment': equipment.toJson(),
      'target_calories': targetCalories,
      'target_protein': targetProtein,
      'target_carbohydrates': targetCarbohydrates,
      'target_fat': targetFat,
      'auto_generate_meal_plans': autoGenerateMealPlans,
      'auto_suggest_workouts': autoSuggestWorkouts,
      'notification_settings': notificationSettings.toJson(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Calculate daily calorie needs based on activity level and goals
  double calculateDailyCalorieNeeds(double bmr) {
    double activityMultiplier;
    switch (fitnessGoals.primary) {
      case 'weight_loss':
        activityMultiplier = 0.8;
        break;
      case 'muscle_gain':
        activityMultiplier = 1.1;
        break;
      default:
        activityMultiplier = 1.0;
    }

    double tdee = bmr * activityMultiplier;

    return tdee;
  }
}
