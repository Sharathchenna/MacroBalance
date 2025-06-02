import 'dart:math';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;

/// Service to provide exercise images and animations
/// Enhanced with ExerciseDB API integration and AI-powered recommendations
class ExerciseImageService {
  static final ExerciseImageService _instance =
      ExerciseImageService._internal();
  factory ExerciseImageService() => _instance;
  ExerciseImageService._internal();

  // ExerciseDB API configuration
  static const String _apiBaseUrl = 'https://exercisedb.p.rapidapi.com';
  static const String _apiHost = 'exercisedb.p.rapidapi.com';

  // You'll need to get your own API key from RapidAPI
  static const String _apiKey =
      'ec90356fe3mshe9ac9aef598adffp1224e4jsnec34fe7e063e'; // Your actual RapidAPI key

  // Configuration
  static const bool enableExerciseDbIntegration = true;
  static const int maxRequestsPerMinute = 50;
  static const Duration requestTimeout = Duration(seconds: 10);

  // Cache for API responses
  final Map<String, dynamic> _exerciseCache = {};
  final Map<String, List<dynamic>> _muscleGroupCache = {};
  DateTime? _lastRequestTime;
  int _requestCount = 0;

  /// Check if ExerciseDB API is properly configured
  static bool get isExerciseDbConfigured {
    return _apiKey != 'YOUR_RAPIDAPI_KEY' && _apiKey.isNotEmpty;
  }

  /// Get headers for ExerciseDB API requests
  static Map<String, String> get exerciseDbHeaders {
    return {
      'X-RapidAPI-Key': _apiKey,
      'X-RapidAPI-Host': _apiHost,
    };
  }

  /// Get exercise image URL based on exercise name
  /// Uses multi-tier fallback system: ExerciseDB API -> AI matching -> category fallback
  Future<String> getExerciseImageUrl(String exerciseName) async {
    final normalizedName = _normalizeExerciseName(exerciseName);

    // Try ExerciseDB API first (if configured)
    if (isExerciseDbConfigured) {
      final apiExercise = await _searchExerciseDB(exerciseName);
      if (apiExercise != null && apiExercise['gifUrl'] != null) {
        return apiExercise['gifUrl'];
      }
    }

    // Try exact match from local database
    final exactMatch = _getExactMatchImage(normalizedName);
    if (exactMatch != null) return exactMatch;

    // Try partial match
    final partialMatch = _getPartialMatchImage(normalizedName);
    if (partialMatch != null) return partialMatch;

    // Fall back to category-based image
    return _getCategoryImage(normalizedName);
  }

  /// Check rate limiting before making API requests
  bool _canMakeRequest() {
    final now = DateTime.now();

    // Reset counter every minute
    if (_lastRequestTime == null ||
        now.difference(_lastRequestTime!).inMinutes >= 1) {
      _requestCount = 0;
      _lastRequestTime = now;
    }

    return _requestCount < maxRequestsPerMinute;
  }

  /// Increment request counter
  void _incrementRequestCount() {
    _requestCount++;
  }

  /// Get comprehensive exercise data from ExerciseDB
  Future<Map<String, dynamic>?> getExerciseData(String exerciseName) async {
    if (!isExerciseDbConfigured) {
      dev.log('[ExerciseImageService] ExerciseDB API not configured');
      return null;
    }

    try {
      final exercise = await _searchExerciseDB(exerciseName);
      if (exercise != null) {
        return {
          'id': exercise['id'],
          'name': exercise['name'],
          'bodyPart': exercise['bodyPart'],
          'equipment': exercise['equipment'],
          'target': exercise['target'],
          'secondaryMuscles': exercise['secondaryMuscles'] ?? [],
          'instructions': exercise['instructions'] ?? [],
          'gifUrl': exercise['gifUrl'],
          'category': _mapBodyPartToCategory(exercise['bodyPart']),
          'difficulty':
              _inferDifficulty(exercise['equipment'], exercise['name']),
        };
      }
    } catch (e) {
      dev.log('[ExerciseImageService] Error getting exercise data: $e');
    }
    return null;
  }

  /// Get exercises by muscle group from ExerciseDB
  Future<List<Map<String, dynamic>>> getExercisesByMuscleGroup(
      String muscleGroup) async {
    if (!isExerciseDbConfigured || !_canMakeRequest()) {
      return [];
    }

    try {
      if (_muscleGroupCache.containsKey(muscleGroup)) {
        return _muscleGroupCache[muscleGroup]!.cast<Map<String, dynamic>>();
      }

      _incrementRequestCount();
      final response = await http
          .get(
            Uri.parse('$_apiBaseUrl/exercises/target/$muscleGroup'),
            headers: exerciseDbHeaders,
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> exercises = json.decode(response.body);
        _muscleGroupCache[muscleGroup] = exercises;

        return exercises
            .map((exercise) => {
                  'id': exercise['id'],
                  'name': exercise['name'],
                  'bodyPart': exercise['bodyPart'],
                  'equipment': exercise['equipment'],
                  'target': exercise['target'],
                  'gifUrl': exercise['gifUrl'],
                  'category': _mapBodyPartToCategory(exercise['bodyPart']),
                })
            .toList();
      }
    } catch (e) {
      dev.log(
          '[ExerciseImageService] Error getting exercises by muscle group: $e');
    }
    return [];
  }

  /// Get exercises by equipment from ExerciseDB
  Future<List<Map<String, dynamic>>> getExercisesByEquipment(
      String equipment) async {
    if (!isExerciseDbConfigured || !_canMakeRequest()) {
      return [];
    }

    try {
      _incrementRequestCount();
      final response = await http
          .get(
            Uri.parse(
                '$_apiBaseUrl/exercises/equipment/${Uri.encodeComponent(equipment)}'),
            headers: exerciseDbHeaders,
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> exercises = json.decode(response.body);

        return exercises
            .map((exercise) => {
                  'id': exercise['id'],
                  'name': exercise['name'],
                  'bodyPart': exercise['bodyPart'],
                  'equipment': exercise['equipment'],
                  'target': exercise['target'],
                  'gifUrl': exercise['gifUrl'],
                  'category': _mapBodyPartToCategory(exercise['bodyPart']),
                })
            .toList();
      }
    } catch (e) {
      dev.log(
          '[ExerciseImageService] Error getting exercises by equipment: $e');
    }
    return [];
  }

  /// Get AI-powered exercise recommendations
  Future<List<Map<String, dynamic>>> getAIExerciseRecommendations({
    required String fitnessLevel,
    required List<String> availableEquipment,
    required String targetMuscleGroup,
    int limit = 10,
  }) async {
    try {
      // Get exercises from ExerciseDB based on criteria
      List<Map<String, dynamic>> allExercises = [];

      // Get by muscle group
      if (targetMuscleGroup.isNotEmpty) {
        final muscleExercises =
            await getExercisesByMuscleGroup(targetMuscleGroup);
        allExercises.addAll(muscleExercises);
      }

      // Filter by available equipment
      if (availableEquipment.isNotEmpty) {
        allExercises = allExercises.where((exercise) {
          final exerciseEquipment =
              exercise['equipment']?.toString().toLowerCase() ?? '';
          return availableEquipment.any((equipment) =>
              exerciseEquipment.contains(equipment.toLowerCase()) ||
              equipment.toLowerCase() == 'body weight' &&
                  exerciseEquipment == 'body weight');
        }).toList();
      }

      // Apply AI-based filtering and ranking
      allExercises = _applyAIFiltering(allExercises, fitnessLevel);

      // Limit results
      if (allExercises.length > limit) {
        allExercises = allExercises.take(limit).toList();
      }

      return allExercises;
    } catch (e) {
      dev.log('[ExerciseImageService] Error getting AI recommendations: $e');
      return [];
    }
  }

  /// Search ExerciseDB for specific exercise
  Future<Map<String, dynamic>?> _searchExerciseDB(String exerciseName) async {
    try {
      final cacheKey = exerciseName.toLowerCase();
      if (_exerciseCache.containsKey(cacheKey)) {
        return _exerciseCache[cacheKey];
      }

      // Get all exercises and search locally (ExerciseDB doesn't have search endpoint)
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/exercises')
            .replace(queryParameters: {'limit': '1500'}),
        headers: {
          'X-RapidAPI-Key': _apiKey,
          'X-RapidAPI-Host': _apiHost,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> exercises = json.decode(response.body);

        // Search for best match
        final normalizedSearch = _normalizeExerciseName(exerciseName);

        // Exact name match
        var bestMatch = exercises.firstWhere(
          (exercise) =>
              _normalizeExerciseName(exercise['name']) == normalizedSearch,
          orElse: () => null,
        );

        // Partial name match if no exact match
        bestMatch ??= exercises.firstWhere(
            (exercise) =>
                _normalizeExerciseName(exercise['name'])
                    .contains(normalizedSearch) ||
                normalizedSearch
                    .contains(_normalizeExerciseName(exercise['name'])),
            orElse: () => null,
          );

        // Keyword match if no partial match
        if (bestMatch == null) {
          final keywords = normalizedSearch.split('_');
          bestMatch = exercises.firstWhere(
            (exercise) => keywords.any((keyword) =>
                _normalizeExerciseName(exercise['name']).contains(keyword) &&
                keyword.length > 2),
            orElse: () => null,
          );
        }

        if (bestMatch != null) {
          _exerciseCache[cacheKey] = bestMatch;
          return bestMatch;
        }
      }
    } catch (e) {
      dev.log('[ExerciseImageService] Error searching ExerciseDB: $e');
    }
    return null;
  }

  /// Apply AI-based filtering and ranking to exercises
  List<Map<String, dynamic>> _applyAIFiltering(
      List<Map<String, dynamic>> exercises, String fitnessLevel) {
    // Score each exercise based on fitness level and other factors
    for (var exercise in exercises) {
      double score = 0.0;

      // Base score
      score += 50.0;

      // Equipment accessibility score
      final equipment = exercise['equipment']?.toString().toLowerCase() ?? '';
      if (equipment == 'body weight') {
        score += 20.0; // Highly accessible
      } else if (equipment.contains('dumbbell') ||
          equipment.contains('barbell')) {
        score += 15.0; // Common equipment
      } else if (equipment.contains('machine')) {
        score += 10.0; // Gym equipment
      }

      // Fitness level appropriateness
      final exerciseName = exercise['name']?.toString().toLowerCase() ?? '';
      switch (fitnessLevel.toLowerCase()) {
        case 'beginner':
          if (exerciseName.contains('basic') ||
              exerciseName.contains('assisted') ||
              equipment == 'body weight') {
            score += 25.0;
          }
          if (exerciseName.contains('advanced') ||
              exerciseName.contains('weighted')) {
            score -= 15.0;
          }
          break;
        case 'intermediate':
          if (exerciseName.contains('weighted') ||
              equipment.contains('dumbbell')) {
            score += 20.0;
          }
          break;
        case 'advanced':
          if (exerciseName.contains('weighted') ||
              exerciseName.contains('complex')) {
            score += 25.0;
          }
          if (exerciseName.contains('basic') ||
              exerciseName.contains('assisted')) {
            score -= 10.0;
          }
          break;
      }

      // Compound vs isolation preference (compound generally better)
      if (_isCompoundExercise(exerciseName)) {
        score += 15.0;
      }

      exercise['ai_score'] = score;
    }

    // Sort by AI score
    exercises
        .sort((a, b) => (b['ai_score'] ?? 0.0).compareTo(a['ai_score'] ?? 0.0));

    return exercises;
  }

  /// Check if exercise is a compound movement
  bool _isCompoundExercise(String exerciseName) {
    final compoundKeywords = [
      'squat',
      'deadlift',
      'press',
      'row',
      'pull',
      'push',
      'lunge',
      'thruster',
      'clean',
      'snatch',
      'burpee'
    ];
    return compoundKeywords.any((keyword) => exerciseName.contains(keyword));
  }

  /// Map ExerciseDB body parts to our categories
  String _mapBodyPartToCategory(String? bodyPart) {
    if (bodyPart == null) return 'Strength';

    switch (bodyPart.toLowerCase()) {
      case 'chest':
        return 'Chest';
      case 'back':
        return 'Back';
      case 'shoulders':
        return 'Shoulders';
      case 'upper arms':
      case 'lower arms':
        return 'Arms';
      case 'upper legs':
      case 'lower legs':
        return 'Legs';
      case 'waist':
      case 'core':
        return 'Core';
      case 'cardio':
        return 'Cardio';
      default:
        return 'Strength';
    }
  }

  /// Infer difficulty based on equipment and exercise name
  String _inferDifficulty(String? equipment, String? name) {
    final exerciseName = name?.toLowerCase() ?? '';
    final equipmentType = equipment?.toLowerCase() ?? '';

    if (exerciseName.contains('advanced') ||
        exerciseName.contains('olympic') ||
        exerciseName.contains('pistol') ||
        exerciseName.contains('one arm')) {
      return 'Advanced';
    }

    if (equipmentType == 'body weight' &&
        (exerciseName.contains('push') || exerciseName.contains('pull'))) {
      return 'Intermediate';
    }

    if (equipmentType == 'body weight') {
      return 'Beginner';
    }

    if (equipmentType.contains('barbell') ||
        equipmentType.contains('olympic')) {
      return 'Intermediate';
    }

    return 'Beginner';
  }

  /// Get exercise GIF URL for animated demonstrations
  String? getExerciseGifUrl(String exerciseName) {
    final normalizedName = _normalizeExerciseName(exerciseName);
    return _exerciseGifMap[normalizedName];
  }

  /// Check if exercise has available media
  bool hasExerciseMedia(String exerciseName) {
    final normalizedName = _normalizeExerciseName(exerciseName);
    return _exerciseImageMap.containsKey(normalizedName) ||
        _partialMatchExists(normalizedName);
  }

  /// Get exercise category for the given exercise
  String getExerciseCategory(String exerciseName) {
    final normalizedName = _normalizeExerciseName(exerciseName);
    return _determineExerciseCategory(normalizedName);
  }

  /// Get a random exercise suggestion with image
  Map<String, dynamic> getRandomExerciseWithImage() {
    final exercises = _exerciseImageMap.keys.toList();
    final random = Random();
    final randomExercise = exercises[random.nextInt(exercises.length)];
    final category = _determineExerciseCategory(randomExercise);

    return {
      'name': _formatExerciseName(randomExercise),
      'image': _exerciseImageMap[randomExercise]!,
      'gif': _exerciseGifMap[randomExercise],
      'category': category,
      'difficulty': _getExerciseDifficulty(randomExercise),
    };
  }

  // Private helper methods

  String _normalizeExerciseName(String exerciseName) {
    return exerciseName
        .toLowerCase()
        .trim()
        .replaceAll(
            RegExp(r'[^\w\s]'), '') // Remove special chars but keep spaces
        .replaceAll(RegExp(r'\s+'), '_'); // Replace spaces with underscores
  }

  String _formatExerciseName(String normalizedName) {
    return normalizedName
        .split('_')
        .map((word) =>
            word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
        .join(' ');
  }

  String? _getExactMatchImage(String normalizedName) {
    return _exerciseImageMap[normalizedName];
  }

  String? _getPartialMatchImage(String normalizedName) {
    // Look for partial matches in exercise names
    for (final exerciseKey in _exerciseImageMap.keys) {
      if (exerciseKey.contains(normalizedName) ||
          normalizedName.contains(exerciseKey)) {
        return _exerciseImageMap[exerciseKey];
      }
    }

    // Check for keyword matches
    for (final keyword in _getKeywords(normalizedName)) {
      for (final exerciseKey in _exerciseImageMap.keys) {
        if (exerciseKey.contains(keyword)) {
          return _exerciseImageMap[exerciseKey];
        }
      }
    }

    return null;
  }

  bool _partialMatchExists(String normalizedName) {
    return _getPartialMatchImage(normalizedName) != null;
  }

  List<String> _getKeywords(String normalizedName) {
    final words = normalizedName.split('_');
    final keywords = <String>[];

    // Add individual words
    keywords.addAll(words.where((word) => word.length > 2));

    // Add common exercise variations
    if (normalizedName.contains('dumbbell')) keywords.add('dumbbell');
    if (normalizedName.contains('barbell')) keywords.add('barbell');
    if (normalizedName.contains('cable')) keywords.add('cable');
    if (normalizedName.contains('machine')) keywords.add('machine');

    return keywords;
  }

  String _getCategoryImage(String normalizedName) {
    final category = _determineExerciseCategory(normalizedName);
    final categoryData = _categoryImageMap[category]!;

    // Use a reliable placeholder service with better formatting
    final encodedText =
        Uri.encodeComponent('${categoryData['icon']} $category');
    return 'https://placehold.co/400x300/${categoryData['color']}/ffffff/png?text=$encodedText&font=opensans';
  }

  String _determineExerciseCategory(String normalizedName) {
    // Check specific exercise mappings first
    final specificCategory = _exerciseCategoryMap[normalizedName];
    if (specificCategory != null) return specificCategory;

    // Chest exercises
    if (_containsAny(normalizedName,
        ['chest', 'bench', 'press', 'fly', 'flye', 'push_up', 'pushup'])) {
      return 'Chest';
    }

    // Back exercises
    if (_containsAny(normalizedName,
        ['back', 'row', 'pull_up', 'pullup', 'lat', 'deadlift'])) {
      return 'Back';
    }

    // Shoulder exercises
    if (_containsAny(
        normalizedName, ['shoulder', 'deltoid', 'raise', 'press', 'shrug'])) {
      return 'Shoulders';
    }

    // Arm exercises
    if (_containsAny(
        normalizedName, ['bicep', 'tricep', 'curl', 'extension', 'dip'])) {
      return 'Arms';
    }

    // Leg exercises
    if (_containsAny(normalizedName,
        ['squat', 'lunge', 'leg', 'quad', 'hamstring', 'calf', 'glute'])) {
      return 'Legs';
    }

    // Core exercises
    if (_containsAny(normalizedName,
        ['ab', 'core', 'plank', 'crunch', 'sit_up', 'russian'])) {
      return 'Core';
    }

    // Cardio exercises
    if (_containsAny(normalizedName,
        ['run', 'jump', 'burpee', 'cardio', 'hiit', 'sprint'])) {
      return 'Cardio';
    }

    // Full body exercises
    if (_containsAny(
        normalizedName, ['deadlift', 'clean', 'snatch', 'thruster'])) {
      return 'Full Body';
    }

    return 'Strength'; // Default category
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  String _getExerciseDifficulty(String normalizedName) {
    if (_containsAny(
        normalizedName, ['advanced', 'olympic', 'snatch', 'clean'])) {
      return 'Advanced';
    }
    if (_containsAny(normalizedName, ['intermediate', 'weighted', 'barbell'])) {
      return 'Intermediate';
    }
    return 'Beginner';
  }

  // Fallback exercise image mappings (when ExerciseDB is unavailable)
  static const Map<String, String> _exerciseImageMap = {
    // Push-ups and variations - Using reliable Unsplash fitness images
    'push_up':
        'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=300&fit=crop&q=80',
    'push_ups':
        'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=300&fit=crop&q=80',
    'pushup':
        'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=300&fit=crop&q=80',
    'pushups':
        'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=300&fit=crop&q=80',

    // Squats and variations
    'squat':
        'https://images.unsplash.com/photo-1566241440091-ec10de8db2e1?w=400&h=300&fit=crop&q=80',
    'squats':
        'https://images.unsplash.com/photo-1566241440091-ec10de8db2e1?w=400&h=300&fit=crop&q=80',
    'dumbbell_squat':
        'https://images.unsplash.com/photo-1566241440091-ec10de8db2e1?w=400&h=300&fit=crop&q=80',
    'dumbbell_squats':
        'https://images.unsplash.com/photo-1566241440091-ec10de8db2e1?w=400&h=300&fit=crop&q=80',

    // Lunges
    'lunge':
        'https://images.unsplash.com/photo-1518611012118-696072aa579a?w=400&h=300&fit=crop&q=80',
    'lunges':
        'https://images.unsplash.com/photo-1518611012118-696072aa579a?w=400&h=300&fit=crop&q=80',

    // Core exercises
    'plank':
        'https://images.unsplash.com/photo-1506629905607-eb7bfe0b9e81?w=400&h=300&fit=crop&q=80',
    'planks':
        'https://images.unsplash.com/photo-1506629905607-eb7bfe0b9e81?w=400&h=300&fit=crop&q=80',

    // Pull-ups
    'pull_up':
        'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?w=400&h=300&fit=crop&q=80',
    'pull_ups':
        'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?w=400&h=300&fit=crop&q=80',

    // Weight training
    'deadlift':
        'https://images.unsplash.com/photo-1434682881908-b43d0467b798?w=400&h=300&fit=crop&q=80',
    'deadlifts':
        'https://images.unsplash.com/photo-1434682881908-b43d0467b798?w=400&h=300&fit=crop&q=80',
    'bench_press':
        'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=400&h=300&fit=crop&q=80',
  };

  // Optional GIF mappings for animated demonstrations
  static const Map<String, String> _exerciseGifMap = {
    // Keep minimal since ExerciseDB provides GIFs
  };

  // Specific exercise category mappings for precise categorization
  static const Map<String, String> _exerciseCategoryMap = {
    'deadlift': 'Full Body',
    'deadlifts': 'Full Body',
    'clean_and_jerk': 'Full Body',
    'snatch': 'Full Body',
    'thruster': 'Full Body',
    'turkish_getup': 'Full Body',
  };

  // Category image configurations
  static const Map<String, Map<String, String>> _categoryImageMap = {
    'Chest': {'color': '3B82F6', 'icon': '💪'},
    'Back': {'color': '10B981', 'icon': '🏋️'},
    'Shoulders': {'color': 'F59E0B', 'icon': '💪'},
    'Arms': {'color': '06B6D4', 'icon': '💪'},
    'Legs': {'color': '8B5CF6', 'icon': '🦵'},
    'Core': {'color': 'F59E0B', 'icon': '🎯'},
    'Cardio': {'color': 'EF4444', 'icon': '❤️'},
    'Full Body': {'color': '059669', 'icon': '⚡'},
    'Strength': {'color': '64748B', 'icon': '💪'},
  };
}

/// Extension to get exercise media URLs directly from exercise name
extension ExerciseImageExtension on String {
  Future<String> get exerciseImageUrl =>
      ExerciseImageService().getExerciseImageUrl(this);
  String? get exerciseGifUrl => ExerciseImageService().getExerciseGifUrl(this);
  bool get hasExerciseMedia => ExerciseImageService().hasExerciseMedia(this);
  String get exerciseCategory =>
      ExerciseImageService().getExerciseCategory(this);
  Future<Map<String, dynamic>?> get exerciseData =>
      ExerciseImageService().getExerciseData(this);
}
