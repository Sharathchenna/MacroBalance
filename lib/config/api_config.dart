/// API configuration for external services
class ApiConfig {
  // ExerciseDB API Configuration
  static const String exerciseDbBaseUrl = 'https://exercisedb.p.rapidapi.com';
  static const String exerciseDbHost = 'exercisedb.p.rapidapi.com';

  static const String exerciseDbApiKey =
      'ec90356fe3mshe9ac9aef598adffp1224e4jsnec34fe7e063e';

  // Gemini AI Configuration
  // This would typically be configured through Firebase/Vertex AI
  static const String geminiApiKey =
      ''; // Leave empty for Firebase/Vertex AI integration

  // Fitness AI Configuration
  static const bool enableExerciseDbIntegration = true;
  static const int exerciseDbCacheTimeoutMinutes = 60;
  static const int maxExercisesPerRequest = 1500;

  // Image Service Configuration
  static const String fallbackImageService = 'https://placehold.co';
  static const String unsplashBaseUrl = 'https://images.unsplash.com';

  // API Rate Limiting
  static const int maxRequestsPerMinute = 50;
  static const Duration requestTimeout = Duration(seconds: 10);

  /// Check if ExerciseDB API is properly configured
  static bool get isExerciseDbConfigured {
    return exerciseDbApiKey != 'YOUR_RAPIDAPI_KEY_HERE' &&
        exerciseDbApiKey.isNotEmpty;
  }

  /// Get headers for ExerciseDB API requests
  static Map<String, String> get exerciseDbHeaders {
    return {
      'X-RapidAPI-Key': exerciseDbApiKey,
      'X-RapidAPI-Host': exerciseDbHost,
    };
  }

  /// Available muscle groups for ExerciseDB
  static const List<String> exerciseDbMuscleGroups = [
    'abductors',
    'abs',
    'adductors',
    'biceps',
    'calves',
    'cardiovascular system',
    'delts',
    'forearms',
    'glutes',
    'hamstrings',
    'lats',
    'levator scapulae',
    'pectorals',
    'quads',
    'serratus anterior',
    'spine',
    'traps',
    'triceps',
    'upper back',
  ];

  /// Available equipment types for ExerciseDB
  static const List<String> exerciseDbEquipmentTypes = [
    'assisted',
    'band',
    'barbell',
    'body weight',
    'bosu ball',
    'cable',
    'dumbbell',
    'elliptical machine',
    'ez barbell',
    'hammer',
    'kettlebell',
    'leverage machine',
    'medicine ball',
    'olympic barbell',
    'resistance band',
    'roller',
    'rope',
    'skierg machine',
    'sled machine',
    'smith machine',
    'stability ball',
    'stationary bike',
    'stepmill machine',
    'tire',
    'trap bar',
    'upper body ergometer',
    'weighted',
    'wheel roller',
  ];
}
