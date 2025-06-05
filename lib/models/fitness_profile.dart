import 'package:hive/hive.dart';

part 'fitness_profile.g.dart';

@HiveType(typeId: 4)
class FitnessProfile extends HiveObject {
  // Fitness Level & Experience
  @HiveField(0)
  final String fitnessLevel; // 'beginner', 'intermediate', 'advanced'
  @HiveField(1)
  final int yearsOfExperience;
  @HiveField(2)
  final List<String> previousExerciseTypes;

  // Equipment & Environment
  @HiveField(3)
  final String workoutLocation; // 'home', 'gym', 'outdoor', 'mixed'
  @HiveField(4)
  final List<String> availableEquipment;
  @HiveField(5)
  final bool hasGymAccess;
  @HiveField(6)
  final String workoutSpace; // 'small', 'medium', 'large'

  // Schedule & Preferences
  @HiveField(7)
  final int workoutsPerWeek;
  @HiveField(8)
  final int maxWorkoutDuration; // in minutes
  @HiveField(9)
  final String
      preferredTimeOfDay; // 'morning', 'afternoon', 'evening', 'flexible'
  @HiveField(10)
  final List<String> preferredDays;

  // Health & Limitations (to be collected in future)
  @HiveField(11)
  final List<String>? injuries;
  @HiveField(12)
  final List<String>? limitations;
  @HiveField(13)
  final String?
      primaryGoal; // 'weight_loss', 'muscle_gain', 'endurance', 'flexibility', 'general_fitness'
  @HiveField(14)
  final List<String>? secondaryGoals;

  // AI Personalization Data
  @HiveField(15)
  final Map<String, dynamic>? aiPreferences;
  @HiveField(16)
  final DateTime? lastUpdated;

  FitnessProfile({
    required this.fitnessLevel,
    required this.yearsOfExperience,
    required this.previousExerciseTypes,
    required this.workoutLocation,
    required this.availableEquipment,
    required this.hasGymAccess,
    required this.workoutSpace,
    required this.workoutsPerWeek,
    required this.maxWorkoutDuration,
    required this.preferredTimeOfDay,
    required this.preferredDays,
    this.injuries,
    this.limitations,
    this.primaryGoal,
    this.secondaryGoals,
    this.aiPreferences,
    this.lastUpdated,
  });

  // Empty constructor for initial state
  static final empty = FitnessProfile(
    fitnessLevel: '',
    yearsOfExperience: 0,
    previousExerciseTypes: [],
    workoutLocation: '',
    availableEquipment: [],
    hasGymAccess: false,
    workoutSpace: '',
    workoutsPerWeek: 3,
    maxWorkoutDuration: 30,
    preferredTimeOfDay: '',
    preferredDays: [],
  );

  // Check if profile is complete enough for basic recommendations
  bool get isBasicProfileComplete {
    return fitnessLevel.isNotEmpty &&
        workoutLocation.isNotEmpty &&
        workoutSpace.isNotEmpty &&
        workoutsPerWeek > 0 &&
        maxWorkoutDuration > 0;
  }

  // Check if profile is complete for advanced AI recommendations
  bool get isAdvancedProfileComplete {
    return isBasicProfileComplete &&
        preferredTimeOfDay.isNotEmpty &&
        preferredDays.isNotEmpty &&
        availableEquipment.isNotEmpty;
  }

  // Get difficulty level for workouts based on fitness level and experience
  String get recommendedDifficulty {
    switch (fitnessLevel) {
      case 'beginner':
        return yearsOfExperience <= 1 ? 'easy' : 'easy-moderate';
      case 'intermediate':
        return yearsOfExperience <= 3 ? 'moderate' : 'moderate-hard';
      case 'advanced':
        return yearsOfExperience <= 5 ? 'hard' : 'expert';
      default:
        return 'moderate';
    }
  }

  // Get recommended workout types based on experience and preferences
  List<String> get recommendedWorkoutTypes {
    final types = <String>[];

    // Based on fitness level
    if (fitnessLevel == 'beginner') {
      types.addAll(['bodyweight', 'light_cardio', 'flexibility']);
    } else if (fitnessLevel == 'intermediate') {
      types.addAll(['strength', 'cardio', 'circuit', 'flexibility']);
    } else if (fitnessLevel == 'advanced') {
      types.addAll(['strength', 'hiit', 'circuit', 'endurance']);
    }

    // Based on available equipment
    if (availableEquipment.contains('Full Gym') || hasGymAccess) {
      types.addAll(['weight_training', 'machine_exercises']);
    }
    if (availableEquipment.contains('Dumbbells') ||
        availableEquipment.contains('Kettlebells')) {
      types.add('free_weights');
    }
    if (availableEquipment.contains('Resistance Bands')) {
      types.add('resistance_training');
    }
    if (availableEquipment.contains('Yoga Mat')) {
      types.addAll(['yoga', 'pilates', 'core']);
    }

    // Based on location
    if (workoutLocation == 'outdoor') {
      types.addAll(['running', 'hiking', 'outdoor_bodyweight']);
    }

    return types.toSet().toList(); // Remove duplicates
  }

  // Get optimal workout duration based on preferences and fitness level
  int get optimalWorkoutDuration {
    if (maxWorkoutDuration <= 15) return 15;
    if (maxWorkoutDuration <= 30) return 25;
    if (maxWorkoutDuration <= 45) return 40;
    return 55;
  }

  // Copy with method for updates
  FitnessProfile copyWith({
    String? fitnessLevel,
    int? yearsOfExperience,
    List<String>? previousExerciseTypes,
    String? workoutLocation,
    List<String>? availableEquipment,
    bool? hasGymAccess,
    String? workoutSpace,
    int? workoutsPerWeek,
    int? maxWorkoutDuration,
    String? preferredTimeOfDay,
    List<String>? preferredDays,
    List<String>? injuries,
    List<String>? limitations,
    String? primaryGoal,
    List<String>? secondaryGoals,
    Map<String, dynamic>? aiPreferences,
    DateTime? lastUpdated,
  }) {
    return FitnessProfile(
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      previousExerciseTypes:
          previousExerciseTypes ?? this.previousExerciseTypes,
      workoutLocation: workoutLocation ?? this.workoutLocation,
      availableEquipment: availableEquipment ?? this.availableEquipment,
      hasGymAccess: hasGymAccess ?? this.hasGymAccess,
      workoutSpace: workoutSpace ?? this.workoutSpace,
      workoutsPerWeek: workoutsPerWeek ?? this.workoutsPerWeek,
      maxWorkoutDuration: maxWorkoutDuration ?? this.maxWorkoutDuration,
      preferredTimeOfDay: preferredTimeOfDay ?? this.preferredTimeOfDay,
      preferredDays: preferredDays ?? this.preferredDays,
      injuries: injuries ?? this.injuries,
      limitations: limitations ?? this.limitations,
      primaryGoal: primaryGoal ?? this.primaryGoal,
      secondaryGoals: secondaryGoals ?? this.secondaryGoals,
      aiPreferences: aiPreferences ?? this.aiPreferences,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'fitnessLevel': fitnessLevel,
      'yearsOfExperience': yearsOfExperience,
      'previousExerciseTypes': previousExerciseTypes,
      'workoutLocation': workoutLocation,
      'availableEquipment': availableEquipment,
      'hasGymAccess': hasGymAccess,
      'workoutSpace': workoutSpace,
      'workoutsPerWeek': workoutsPerWeek,
      'maxWorkoutDuration': maxWorkoutDuration,
      'preferredTimeOfDay': preferredTimeOfDay,
      'preferredDays': preferredDays,
      'injuries': injuries,
      'limitations': limitations,
      'primaryGoal': primaryGoal,
      'secondaryGoals': secondaryGoals,
      'aiPreferences': aiPreferences,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  // Create from JSON
  factory FitnessProfile.fromJson(Map<String, dynamic> json) {
    return FitnessProfile(
      fitnessLevel: json['fitnessLevel'] ?? json['fitness_level'] ?? '',
      yearsOfExperience:
          json['yearsOfExperience'] ?? json['years_of_experience'] ?? 0,
      previousExerciseTypes: List<String>.from(json['previousExerciseTypes'] ??
          json['previous_exercise_types'] ??
          []),
      workoutLocation:
          json['workoutLocation'] ?? json['workout_location'] ?? '',
      availableEquipment: List<String>.from(
          json['availableEquipment'] ?? json['available_equipment'] ?? []),
      hasGymAccess: json['hasGymAccess'] ?? json['has_gym_access'] ?? false,
      workoutSpace: json['workoutSpace'] ?? json['workout_space'] ?? '',
      workoutsPerWeek:
          json['workoutsPerWeek'] ?? json['workouts_per_week'] ?? 3,
      maxWorkoutDuration:
          json['maxWorkoutDuration'] ?? json['max_workout_duration'] ?? 30,
      preferredTimeOfDay:
          json['preferredTimeOfDay'] ?? json['preferred_time_of_day'] ?? '',
      preferredDays: List<String>.from(
          json['preferredDays'] ?? json['preferred_days'] ?? []),
      injuries:
          json['injuries'] != null ? List<String>.from(json['injuries']) : null,
      limitations: json['limitations'] != null
          ? List<String>.from(json['limitations'])
          : null,
      primaryGoal: json['primaryGoal'] ?? json['primary_goal'],
      secondaryGoals: json['secondaryGoals'] != null
          ? List<String>.from(json['secondaryGoals'])
          : json['secondary_goals'] != null
              ? List<String>.from(json['secondary_goals'])
              : null,
      aiPreferences: json['aiPreferences'] ?? json['ai_preferences'],
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : json['last_updated'] != null
              ? DateTime.parse(json['last_updated'])
              : null,
    );
  }

  @override
  String toString() {
    return 'FitnessProfile(fitnessLevel: $fitnessLevel, yearsOfExperience: $yearsOfExperience, workoutLocation: $workoutLocation, workoutsPerWeek: $workoutsPerWeek)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FitnessProfile &&
        other.fitnessLevel == fitnessLevel &&
        other.yearsOfExperience == yearsOfExperience &&
        other.workoutLocation == workoutLocation &&
        other.workoutsPerWeek == workoutsPerWeek &&
        other.maxWorkoutDuration == maxWorkoutDuration;
  }

  @override
  int get hashCode {
    return fitnessLevel.hashCode ^
        yearsOfExperience.hashCode ^
        workoutLocation.hashCode ^
        workoutsPerWeek.hashCode ^
        maxWorkoutDuration.hashCode;
  }
}
