/// API configuration for external services
class ApiConfig {
  // Gemini AI Configuration
  static const String geminiApiKey = 'AIzaSyByTeEKI6tRFR1aHY48GZCAa0W6gHcMSRY';
  static const String geminiModel = 'gemini-2.5-flash-preview-05-20';

  // Image Service Configuration
  static const String fallbackImageService = 'https://placehold.co';
  static const String unsplashBaseUrl = 'https://images.unsplash.com';

  // API Rate Limiting
  static const int maxRequestsPerMinute = 50;
  static const Duration requestTimeout = Duration(seconds: 10);

  /// Check if Gemini AI is properly configured
  static bool get isGeminiConfigured {
    return geminiApiKey != 'YOUR_GEMINI_API_KEY' && geminiApiKey.isNotEmpty;
  }

  /// Available muscle groups for workout generation
  static const List<String> muscleGroups = [
    'chest',
    'back',
    'shoulders',
    'biceps',
    'triceps',
    'legs',
    'core',
    'full body'
  ];

  /// Available equipment types
  static const List<String> equipmentTypes = [
    'none',
    'dumbbells',
    'barbell',
    'resistance bands',
    'kettlebell',
    'pull-up bar',
    'bench',
    'yoga mat'
  ];

  /// Available workout locations
  static const List<String> workoutLocations = [
    'home',
    'gym',
    'outdoors',
    'hotel',
    'office'
  ];

  /// Available fitness levels
  static const List<String> fitnessLevels = [
    'beginner',
    'intermediate',
    'advanced'
  ];
}
