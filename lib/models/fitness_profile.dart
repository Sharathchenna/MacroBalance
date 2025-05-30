class FitnessProfile {
  // Fitness Level & Experience
  final String fitnessLevel; // 'beginner', 'intermediate', 'advanced'
  final int yearsOfExperience;
  final List<String> previousExerciseTypes;

  // Equipment & Environment
  final String workoutLocation; // 'home', 'gym', 'outdoor', 'mixed'
  final List<String> availableEquipment;
  final bool hasGymAccess;
  final String workoutSpace; // 'small', 'medium', 'large'

  // Schedule & Preferences
  final int workoutsPerWeek;
  final int maxWorkoutDuration; // in minutes
  final String
      preferredTimeOfDay; // 'morning', 'afternoon', 'evening', 'flexible'
  final List<String> preferredDays;

  // Health & Limitations (to be collected in future)
  final List<String>? injuries;
  final List<String>? limitations;
  final String?
      primaryGoal; // 'weight_loss', 'muscle_gain', 'endurance', 'flexibility', 'general_fitness'
  final List<String>? secondaryGoals;

  // AI Personalization Data
  final Map<String, dynamic>? aiPreferences;
  final DateTime? lastUpdated;

  const FitnessProfile({
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
  static const empty = FitnessProfile(
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
      fitnessLevel: json['fitnessLevel'] ?? '',
      yearsOfExperience: json['yearsOfExperience'] ?? 0,
      previousExerciseTypes:
          List<String>.from(json['previousExerciseTypes'] ?? []),
      workoutLocation: json['workoutLocation'] ?? '',
      availableEquipment: List<String>.from(json['availableEquipment'] ?? []),
      hasGymAccess: json['hasGymAccess'] ?? false,
      workoutSpace: json['workoutSpace'] ?? '',
      workoutsPerWeek: json['workoutsPerWeek'] ?? 3,
      maxWorkoutDuration: json['maxWorkoutDuration'] ?? 30,
      preferredTimeOfDay: json['preferredTimeOfDay'] ?? '',
      preferredDays: List<String>.from(json['preferredDays'] ?? []),
      injuries:
          json['injuries'] != null ? List<String>.from(json['injuries']) : null,
      limitations: json['limitations'] != null
          ? List<String>.from(json['limitations'])
          : null,
      primaryGoal: json['primaryGoal'],
      secondaryGoals: json['secondaryGoals'] != null
          ? List<String>.from(json['secondaryGoals'])
          : null,
      aiPreferences: json['aiPreferences'],
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
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
