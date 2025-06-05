import 'dart:convert';
import 'dart:developer';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/fitness_profile.dart';
import '../services/storage_service.dart';
import '../services/exercise_image_service.dart';
import '../services/supabase_service.dart'; // Added SupabaseService import
import '../config/api_config.dart';
import '../models/workout_plan.dart';
import '../models/exercise.dart';

class FitnessAIService {
  static final FitnessAIService _instance = FitnessAIService._internal();
  factory FitnessAIService() => _instance;
  FitnessAIService._internal() {
    // Initialize Gemini in constructor
    if (ApiConfig.isGeminiConfigured) {
      final model = GenerativeModel(
        model: ApiConfig.geminiModel,
        apiKey: ApiConfig.geminiApiKey,
      );
      _model = model;
    }
  }

  GenerativeModel? _model;
  final StorageService _storage = StorageService();
  final ExerciseImageService _exerciseService = ExerciseImageService();
  final SupabaseService _supabaseService =
      SupabaseService(); // Added SupabaseService instance

  bool get isInitialized => _model != null;

  void _checkInitialization() {
    if (_model == null) {
      throw Exception(
          'Gemini AI is not initialized. Please configure API key in ApiConfig.');
    }
  }

  // ================== FITNESS PROFILE DATA (Supabase Integration) ==================

  Future<FitnessProfile?> getFitnessProfile(String userId) async {
    try {
      final response = await _supabaseService.supabaseClient
          .from('fitness_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null && response is Map<String, dynamic>) {
        return FitnessProfile.fromJson(response);
      }
      return null;
    } catch (e) {
      log('[FitnessAI] Error fetching fitness profile from Supabase: $e');
      return null;
    }
  }

  Future<void> saveFitnessProfile(String userId, FitnessProfile profile) async {
    try {
      final profileJson = profile.toJson();
      // Ensure user_id and lastUpdated are correctly set for Supabase
      profileJson['user_id'] = userId;
      profileJson['last_updated'] = DateTime.now().toIso8601String();
      // 'updated_at' is usually handled by Supabase default/trigger,
      // but 'last_updated' in the model should reflect app-side update time.
      // The table also has an 'updated_at' which Supabase might manage.
      // The model's 'lastUpdated' field maps to 'last_updated' in the table.

      await _supabaseService.supabaseClient
          .from('fitness_profiles')
          .upsert(profileJson);
      log('[FitnessAI] Fitness profile saved to Supabase for user $userId');
    } catch (e) {
      log('[FitnessAI] Error saving fitness profile to Supabase: $e');
      rethrow;
    }
  }

  // ================== ENHANCED WORKOUT RECOMMENDATIONS ==================

  Future<Map<String, dynamic>> generateEnhancedWorkoutPlan({
    required FitnessProfile fitnessProfile,
    required Map<String, dynamic> macroData,
    String? specificMuscleGroup,
    int? customDuration,
  }) async {
    log('[FitnessAI] Starting enhanced workout plan generation...');
    _checkInitialization();

    try {
      // Get exercise recommendations first
      log('[FitnessAI] Getting exercise recommendations...');
      final availableExercises = await _getAIExerciseRecommendations(
        fitnessProfile,
        specificMuscleGroup,
      );
      log('[FitnessAI] Found ${availableExercises.length} recommended exercises');

      // Build the prompt
      log('[FitnessAI] Building workout plan prompt...');
      final prompt = _buildEnhancedWorkoutPlanPrompt(
        fitnessProfile,
        macroData,
        specificMuscleGroup,
        customDuration,
        availableExercises,
      );
      log('[FitnessAI] Generated prompt length: ${prompt.length} characters');

      // Generate the workout
      log('[FitnessAI] Calling Gemini AI for workout generation...');
      final response = await _model!.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';
      log('[FitnessAI] Received response length: ${responseText.length} characters');

      // Parse and validate the response
      log('[FitnessAI] Parsing workout response...');
      final workoutData = _parseWorkoutResponse(responseText);
      log('[FitnessAI] Successfully parsed workout data');

      // Store the workout for future reference
      await _storeWorkoutPlan(workoutData);
      log('[FitnessAI] Workout plan stored successfully');

      return workoutData;
    } catch (e, stackTrace) {
      log('[FitnessAI] Error generating enhanced workout plan: $e');
      log('[FitnessAI] Stack trace: $stackTrace');
      log('[FitnessAI] Falling back to backup workout plan');
      return _getBackupWorkoutPlan(fitnessProfile);
    }
  }

  /// Get AI-powered exercise recommendations using ExerciseDB
  Future<List<Map<String, dynamic>>> _getAIExerciseRecommendations(
    FitnessProfile profile,
    String? targetMuscleGroup,
  ) async {
    try {
      // Map user's muscle group preference to ExerciseDB target
      final exerciseDbTarget = _mapMuscleGroupToExerciseDB(targetMuscleGroup);

      // Get personalized exercise recommendations
      final recommendations =
          await _exerciseService.getAIExerciseRecommendations(
        fitnessLevel: profile.fitnessLevel,
        availableEquipment: profile.availableEquipment,
        targetMuscleGroup: exerciseDbTarget,
        limit: 20,
      );

      log('[FitnessAI] Found ${recommendations.length} AI exercise recommendations');
      return recommendations;
    } catch (e) {
      log('[FitnessAI] Error getting AI exercise recommendations: $e');
      return [];
    }
  }

  /// Map muscle group to ExerciseDB target format
  String _mapMuscleGroupToExerciseDB(String? muscleGroup) {
    if (muscleGroup == null) return 'pectorals'; // Default to chest

    switch (muscleGroup.toLowerCase()) {
      case 'chest':
        return 'pectorals';
      case 'back':
        return 'lats';
      case 'shoulders':
        return 'delts';
      case 'arms':
      case 'biceps':
        return 'biceps';
      case 'triceps':
        return 'triceps';
      case 'legs':
      case 'quads':
        return 'quads';
      case 'hamstrings':
        return 'hamstrings';
      case 'glutes':
        return 'glutes';
      case 'calves':
        return 'calves';
      case 'core':
      case 'abs':
        return 'abs';
      default:
        return 'pectorals';
    }
  }

  /// Enhance workout data with real exercise information from ExerciseDB
  Future<Map<String, dynamic>> _enhanceWorkoutWithExerciseDB(
      Map<String, dynamic> workoutData) async {
    try {
      // Enhance main exercises
      if (workoutData['main_exercises'] != null) {
        final List<dynamic> mainExercises = workoutData['main_exercises'];

        for (int i = 0; i < mainExercises.length; i++) {
          final exercise = mainExercises[i];
          if (exercise['exercise'] != null) {
            final exerciseData =
                await _exerciseService.getExerciseData(exercise['exercise']);

            if (exerciseData != null) {
              // Enhance with real data
              exercise['enhanced_data'] = {
                'gif_url': exerciseData['gifUrl'],
                'instructions': exerciseData['instructions'],
                'target_muscle': exerciseData['target'],
                'secondary_muscles': exerciseData['secondaryMuscles'],
                'equipment': exerciseData['equipment'],
                'body_part': exerciseData['bodyPart'],
                'difficulty': exerciseData['difficulty'],
              };

              // Update exercise image
              exercise['image_url'] = exerciseData['gifUrl'];
            }
          }
        }
      }

      workoutData['enhanced_with_exercisedb'] = true;
      workoutData['enhancement_timestamp'] = DateTime.now().toIso8601String();

      return workoutData;
    } catch (e) {
      log('[FitnessAI] Error enhancing workout with ExerciseDB: $e');
      return workoutData;
    }
  }

  /// Generate alternative exercises using ExerciseDB
  Future<List<Map<String, dynamic>>> getSmartExerciseAlternatives({
    required String exerciseName,
    required FitnessProfile fitnessProfile,
    String? reason,
  }) async {
    try {
      // Get exercise data first
      final exerciseData = await _exerciseService.getExerciseData(exerciseName);

      if (exerciseData != null) {
        // Get alternatives based on target muscle and equipment
        final alternatives = await _exerciseService
            .getExercisesByMuscleGroup(exerciseData['target']);

        // Filter and score alternatives using AI
        final filteredAlternatives = alternatives
            .where((alt) => alt['name'] != exerciseName)
            .where((alt) => _isEquipmentAvailable(
                alt['equipment'], fitnessProfile.availableEquipment))
            .take(5)
            .toList();

        // Enhance with AI scoring
        return _scoreAlternativeExercises(
            filteredAlternatives, fitnessProfile, reason);
      }

      // Fallback to original method
      return await getExerciseAlternatives(
        exerciseName: exerciseName,
        fitnessProfile: fitnessProfile,
        reason: reason,
      );
    } catch (e) {
      log('[FitnessAI] Error getting smart exercise alternatives: $e');
      return [];
    }
  }

  /// Score alternative exercises based on user profile and context
  List<Map<String, dynamic>> _scoreAlternativeExercises(
    List<Map<String, dynamic>> alternatives,
    FitnessProfile profile,
    String? reason,
  ) {
    for (var alt in alternatives) {
      double score = 50.0; // Base score

      // Equipment availability bonus
      if (_isEquipmentAvailable(alt['equipment'], profile.availableEquipment)) {
        score += 20.0;
      }

      // Fitness level appropriateness
      final difficulty =
          _inferExerciseDifficulty(alt['equipment'], alt['name']);
      if (_isDifficultyAppropriate(difficulty, profile.fitnessLevel)) {
        score += 15.0;
      }

      // Reason-specific scoring
      if (reason != null) {
        switch (reason.toLowerCase()) {
          case 'injury':
            if (alt['equipment'] == 'body weight') score += 10.0;
            break;
          case 'equipment':
            if (alt['equipment'] == 'body weight') score += 15.0;
            break;
          case 'difficulty':
            // Already handled in fitness level check
            break;
        }
      }

      alt['ai_score'] = score;
    }

    // Sort by score
    alternatives
        .sort((a, b) => (b['ai_score'] ?? 0.0).compareTo(a['ai_score'] ?? 0.0));

    return alternatives
        .map((alt) => {
              'exercise_name': alt['name'],
              'difficulty_level':
                  _inferExerciseDifficulty(alt['equipment'], alt['name']),
              'equipment_needed': [alt['equipment']],
              'muscle_groups': [alt['target']],
              'instructions': 'Enhanced exercise from ExerciseDB',
              'why_good_alternative':
                  'AI-selected based on muscle targeting and equipment compatibility',
              'gif_url': alt['gifUrl'],
              'ai_score': alt['ai_score'],
            })
        .toList();
  }

  /// Check if required equipment is available
  bool _isEquipmentAvailable(
      String? requiredEquipment, List<String> availableEquipment) {
    if (requiredEquipment == null) return true;
    if (requiredEquipment.toLowerCase() == 'body weight') return true;

    return availableEquipment.any((available) =>
        available.toLowerCase().contains(requiredEquipment.toLowerCase()) ||
        requiredEquipment.toLowerCase().contains(available.toLowerCase()));
  }

  /// Infer exercise difficulty
  String _inferExerciseDifficulty(String? equipment, String? name) {
    final exerciseName = name?.toLowerCase() ?? '';
    final equipmentType = equipment?.toLowerCase() ?? '';

    if (exerciseName.contains('advanced') ||
        equipmentType.contains('olympic')) {
      return 'Advanced';
    }
    if (equipmentType.contains('barbell') ||
        exerciseName.contains('weighted')) {
      return 'Intermediate';
    }
    return 'Beginner';
  }

  /// Check if difficulty is appropriate for fitness level
  bool _isDifficultyAppropriate(String difficulty, String fitnessLevel) {
    switch (fitnessLevel.toLowerCase()) {
      case 'beginner':
        return difficulty == 'Beginner';
      case 'intermediate':
        return difficulty == 'Beginner' || difficulty == 'Intermediate';
      case 'advanced':
        return true; // Can handle all difficulties
      default:
        return difficulty == 'Beginner';
    }
  }

  /// Generate personalized workout schedule using ExerciseDB data
  Future<List<Map<String, dynamic>>> generateSmartWeeklySchedule({
    required FitnessProfile fitnessProfile,
    required Map<String, dynamic> macroData,
  }) async {
    try {
      // Get exercise recommendations for different muscle groups
      final exercisesByMuscleGroup = <String, List<Map<String, dynamic>>>{};
      final muscleGroups = [
        'pectorals',
        'lats',
        'delts',
        'biceps',
        'triceps',
        'quads',
        'hamstrings',
        'abs'
      ];

      for (final muscleGroup in muscleGroups) {
        final exercises =
            await _exerciseService.getExercisesByMuscleGroup(muscleGroup);
        if (exercises.isNotEmpty) {
          exercisesByMuscleGroup[muscleGroup] = exercises
              .where((ex) => _isEquipmentAvailable(
                  ex['equipment'], fitnessProfile.availableEquipment))
              .take(5)
              .toList();
        }
      }

      // Generate AI-optimized schedule
      final prompt = _buildSmartWeeklySchedulePrompt(
          fitnessProfile, macroData, exercisesByMuscleGroup);

      final response = await _model!.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';

      final scheduleData = _parseWeeklyScheduleResponse(responseText);
      await _storeWeeklySchedule(scheduleData);

      return scheduleData;
    } catch (e) {
      log('[FitnessAI] Error generating smart weekly schedule: $e');
      return await generateWeeklySchedule(
        fitnessProfile: fitnessProfile,
        macroData: macroData,
      );
    }
  }

  // ================== ORIGINAL METHODS (kept for backward compatibility) ==================

  Future<Map<String, dynamic>> generateWorkoutPlan({
    required FitnessProfile fitnessProfile,
    required Map<String, dynamic> macroData,
    String? specificMuscleGroup,
    int? customDuration,
  }) async {
    // Redirect to enhanced version
    return await generateEnhancedWorkoutPlan(
      fitnessProfile: fitnessProfile,
      macroData: macroData,
      specificMuscleGroup: specificMuscleGroup,
      customDuration: customDuration,
    );
  }

  Future<List<Map<String, dynamic>>> generateWeeklySchedule({
    required FitnessProfile fitnessProfile,
    required Map<String, dynamic> macroData,
  }) async {
    try {
      final prompt = '''
Create a personalized weekly workout schedule with the following specifications:

USER PROFILE:
- Fitness Level: ${fitnessProfile.fitnessLevel}
- Workouts per week: ${fitnessProfile.workoutsPerWeek}
- Available Equipment: ${fitnessProfile.availableEquipment.join(', ')}
- Workout Location: ${fitnessProfile.workoutLocation}
- Max Duration per Session: ${fitnessProfile.maxWorkoutDuration} minutes
- Preferred Days: ${fitnessProfile.preferredDays.join(', ')}
- Preferred Time: ${fitnessProfile.preferredTimeOfDay}

REQUIREMENTS:
1. Create a balanced weekly schedule that targets all major muscle groups
2. Account for proper rest and recovery between muscle groups
3. Only include exercises that can be done with available equipment
4. Match workout intensity to user's fitness level
5. Include variety to maintain engagement
6. Consider user's time preferences

RESPONSE FORMAT:
Return a JSON array of workout days:
[
  {
    "day": "Monday",
    "workout_focus": "Muscle group focus",
    "estimated_duration": "Duration in minutes",
    "exercises": [
      {
        "exercise": "Exercise name",
        "sets": "Number of sets",
        "reps": "Rep range",
        "rest": "Rest period in seconds",
        "equipment_needed": ["Required equipment"],
        "instructions": "Form instructions"
      }
    ],
    "notes": "Any special instructions or tips"
  }
]

Ensure proper exercise selection and rest periods between workouts targeting the same muscle groups.
''';

      log('[FitnessAI] Generating weekly schedule for ${fitnessProfile.workoutsPerWeek} workouts');

      final response = await _model!.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';

      final scheduleData = _parseWeeklyScheduleResponse(responseText);
      await _storeWeeklySchedule(scheduleData);

      return scheduleData;
    } catch (e) {
      log('[FitnessAI] Error generating weekly schedule: $e');
      return _getBackupWeeklySchedule(fitnessProfile);
    }
  }

  Future<Map<String, dynamic>> generateQuickWorkout({
    required FitnessProfile fitnessProfile,
    required int availableMinutes,
    String? focusArea,
  }) async {
    try {
      final prompt = '''
Create a quick, effective workout for limited time with these specifications:

USER PROFILE:
- Fitness Level: ${fitnessProfile.fitnessLevel}
- Available Time: $availableMinutes minutes
- Focus Area: ${focusArea ?? 'Full Body'}
- Available Equipment: ${fitnessProfile.availableEquipment.join(', ')}
- Workout Location: ${fitnessProfile.workoutLocation}

REQUIREMENTS:
1. Create a time-efficient workout that can be completed in ${availableMinutes} minutes
2. Focus on ${focusArea ?? 'full body'} exercises
3. Include only exercises possible with available equipment
4. Match intensity to user's fitness level
5. Minimize rest periods while maintaining safety
6. Include brief warm-up and cool-down

RESPONSE FORMAT:
Return a valid JSON object with this structure:
{
  "workout_name": "Quick workout name",
  "estimated_duration": $availableMinutes,
  "difficulty_level": "${fitnessProfile.fitnessLevel}",
  "calories_burned_estimate": "Estimated calories",
  "muscle_groups_targeted": ["target muscles"],
  "warm_up": [
    {
      "exercise": "Name",
      "duration": "Time in minutes",
      "instructions": "Brief instructions"
    }
  ],
  "main_exercises": [
    {
      "exercise": "Name",
      "sets": "Number",
      "reps": "Range or fixed",
      "rest": "Rest in seconds",
      "instructions": "Form guide",
      "equipment_needed": ["Required equipment"]
    }
  ],
  "cool_down": [
    {
      "exercise": "Name",
      "duration": "Time in minutes",
      "instructions": "Brief instructions"
    }
  ]
}

Ensure the workout can be completed within the time limit while being effective.
''';

      log('[FitnessAI] Generating $availableMinutes-minute quick workout');

      final response = await _model!.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';

      return _parseWorkoutResponse(responseText);
    } catch (e) {
      log('[FitnessAI] Error generating quick workout: $e');
      return _getBackupQuickWorkout(fitnessProfile, availableMinutes);
    }
  }

  // ================== EXERCISE RECOMMENDATIONS ==================

  Future<List<Map<String, dynamic>>> getExerciseAlternatives({
    required String exerciseName,
    required FitnessProfile fitnessProfile,
    String? reason, // 'injury', 'equipment', 'difficulty'
  }) async {
    try {
      final prompt = _buildExerciseAlternativesPrompt(
        exerciseName,
        fitnessProfile,
        reason,
      );

      if (_model == null) {
        log('[FitnessAI] Error: GenerativeModel not initialized.');
        throw Exception(
            'FitnessAIService not initialized. Call initialize() first.');
      }
      final response = await _model!.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';

      return _parseExerciseAlternativesResponse(responseText);
    } catch (e) {
      log('[FitnessAI] Error getting exercise alternatives: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getExerciseGuidance({
    required String exerciseName,
    required FitnessProfile fitnessProfile,
  }) async {
    try {
      final prompt = _buildExerciseGuidancePrompt(exerciseName, fitnessProfile);

      final response = await _model!.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';

      return _parseExerciseGuidanceResponse(responseText);
    } catch (e) {
      log('[FitnessAI] Error getting exercise guidance: $e');
      return {};
    }
  }

  // ================== PROGRESS & ADAPTATION ==================

  Future<Map<String, dynamic>> analyzeProgressAndAdapt({
    required FitnessProfile fitnessProfile,
    required List<Map<String, dynamic>> workoutHistory,
    required Map<String, dynamic> performanceData,
  }) async {
    try {
      final prompt = _buildProgressAnalysisPrompt(
        fitnessProfile,
        workoutHistory,
        performanceData,
      );

      final response = await _model!.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';

      return _parseProgressAnalysisResponse(responseText);
    } catch (e) {
      log('[FitnessAI] Error analyzing progress: $e');
      return {};
    }
  }

  // ================== PROMPT BUILDERS ==================

  String _buildEnhancedWorkoutPlanPrompt(
    FitnessProfile profile,
    Map<String, dynamic> macroData,
    String? specificMuscleGroup,
    int? customDuration,
    List<Map<String, dynamic>> availableExercises,
  ) {
    final duration = customDuration ?? profile.optimalWorkoutDuration;
    final muscleGroupFocus = specificMuscleGroup != null
        ? 'Focus specifically on: $specificMuscleGroup'
        : 'Provide a balanced workout';

    // Format available exercises for the prompt
    final exerciseList = availableExercises
        .take(10)
        .map((ex) =>
            '${ex['name']} (${ex['equipment']}, targets: ${ex['target']})')
        .join('\n');

    return '''
You are an expert fitness trainer and exercise physiologist. Create a personalized workout plan using REAL exercises from the ExerciseDB database.

FITNESS PROFILE:
- Fitness Level: ${profile.fitnessLevel}
- Experience: ${profile.yearsOfExperience} years
- Previous Exercise Types: ${profile.previousExerciseTypes.join(', ')}
- Workout Location: ${profile.workoutLocation}
- Available Equipment: ${profile.availableEquipment.join(', ')}
- Workout Space: ${profile.workoutSpace}
- Target Duration: $duration minutes
- Recommended Difficulty: ${profile.recommendedDifficulty}

NUTRITIONAL CONTEXT:
- Daily Calories: ${macroData['target_calories'] ?? 'N/A'}
- Goal: ${macroData['goal_type'] ?? 'general fitness'}
- Current Weight: ${macroData['current_weight_kg'] ?? 'N/A'}kg

WORKOUT REQUIREMENTS:
$muscleGroupFocus
- Must be suitable for ${profile.workoutLocation} environment
- Use only available equipment: ${profile.availableEquipment.join(', ')}
- IMPORTANT: Select exercises ONLY from the list below:

AVAILABLE EXERCISES FROM EXERCISEDB:
$exerciseList

RESPONSE FORMAT:
Return ONLY a valid JSON object with this exact structure:

{
  "workout_name": "Descriptive workout name",
  "estimated_duration": $duration,
  "difficulty_level": "${profile.recommendedDifficulty}",
  "calories_burned_estimate": 200,
  "muscle_groups_targeted": ["primary", "secondary"],
  "warm_up": [
    {
      "exercise": "Exercise name from the list above",
      "duration": "2 minutes",
      "instructions": "Brief instructions",
      "modifications": "Easier/harder options"
    }
  ],
  "main_exercises": [
    {
      "exercise": "Exercise name from the list above",
      "sets": 3,
      "reps": "8-12",
      "rest": "60 seconds",
      "instructions": "Detailed form instructions",
      "muscle_groups": ["primary", "secondary"],
      "modifications": "Easier/harder variations",
      "equipment_needed": ["specific equipment"]
    }
  ],
  "cool_down": [
    {
      "exercise": "Stretch name",
      "duration": "30 seconds",
      "instructions": "Stretch instructions"
    }
  ],
  "notes": "Additional tips or considerations",
  "progression_tips": "How to advance this workout",
  "exercise_source": "ExerciseDB"
}

IMPORTANT: Only use exercise names exactly as listed above. This ensures we can provide proper GIF demonstrations and detailed instructions.
''';
  }

  String _buildSmartWeeklySchedulePrompt(
    FitnessProfile profile,
    Map<String, dynamic> macroData,
    Map<String, List<Map<String, dynamic>>> exercisesByMuscleGroup,
  ) {
    // Format exercises by muscle group
    final exerciseGroupsText = exercisesByMuscleGroup.entries.map((entry) {
      final exercises = entry.value.take(3).map((ex) => ex['name']).join(', ');
      return '${entry.key}: $exercises';
    }).join('\n');

    return '''
Create a comprehensive weekly workout schedule using REAL exercises from ExerciseDB for optimal results:

PROFILE:
- Fitness Level: ${profile.fitnessLevel}
- Workouts per week: ${profile.workoutsPerWeek}
- Max duration per session: ${profile.maxWorkoutDuration} minutes
- Preferred days: ${profile.preferredDays.join(', ')}
- Preferred time: ${profile.preferredTimeOfDay}
- Location: ${profile.workoutLocation}
- Equipment: ${profile.availableEquipment.join(', ')}
- Goal: ${macroData['goal_type'] ?? 'general fitness'}

AVAILABLE EXERCISES BY MUSCLE GROUP:
$exerciseGroupsText

REQUIREMENTS:
- Distribute workouts across the week for optimal recovery
- Vary workout types to prevent boredom and plateaus
- Consider muscle group rotation for proper recovery
- Include both strength and cardio elements if appropriate
- Match user's preferred days when possible
- Use exercises from the muscle groups listed above

RESPONSE FORMAT:
Return ONLY a valid JSON array with this structure:

[
  {
    "day": "Monday",
    "workout_type": "Upper Body Strength",
    "primary_focus": "Chest, Shoulders, Triceps",
    "estimated_duration": 45,
    "intensity": "moderate",
    "equipment_needed": ["Dumbbells", "Bench"],
    "key_exercises": ["Exercise names from the available list"],
    "rest_day": false,
    "muscle_groups_targeted": ["pectorals", "delts", "triceps"]
  },
  {
    "day": "Tuesday",
    "workout_type": "Active Recovery",
    "primary_focus": "Mobility and Light Cardio",
    "estimated_duration": 30,
    "intensity": "low",
    "equipment_needed": ["Yoga Mat"],
    "key_exercises": ["Walking", "Stretching", "Light Movement"],
    "rest_day": true,
    "muscle_groups_targeted": []
  }
]

Create a balanced schedule that promotes consistency, progressive overload, and sustainable progress using the available exercises.
''';
  }

  String _buildWeeklySchedulePrompt(
    FitnessProfile profile,
    Map<String, dynamic> macroData,
  ) {
    return '''
Create a comprehensive weekly workout schedule for the following user:

PROFILE:
- Fitness Level: ${profile.fitnessLevel}
- Workouts per week: ${profile.workoutsPerWeek}
- Max duration per session: ${profile.maxWorkoutDuration} minutes
- Preferred days: ${profile.preferredDays.join(', ')}
- Preferred time: ${profile.preferredTimeOfDay}
- Location: ${profile.workoutLocation}
- Equipment: ${profile.availableEquipment.join(', ')}
- Goal: ${macroData['goal_type'] ?? 'general fitness'}

REQUIREMENTS:
- Distribute workouts across the week for optimal recovery
- Vary workout types to prevent boredom and plateaus
- Consider muscle group rotation for proper recovery
- Include both strength and cardio elements if appropriate
- Match user's preferred days when possible

RESPONSE FORMAT:
Return ONLY a valid JSON array with this structure:

[
  {
    "day": "Monday",
    "workout_type": "Upper Body Strength",
    "primary_focus": "Chest, Shoulders, Triceps",
    "estimated_duration": 45,
    "intensity": "moderate",
    "equipment_needed": ["Dumbbells", "Bench"],
    "key_exercises": ["Push-ups", "Dumbbell Press", "Shoulder Press"],
    "rest_day": false
  },
  {
    "day": "Tuesday",
    "workout_type": "Active Recovery",
    "primary_focus": "Mobility and Light Cardio",
    "estimated_duration": 30,
    "intensity": "low",
    "equipment_needed": ["Yoga Mat"],
    "key_exercises": ["Walking", "Stretching", "Yoga"],
    "rest_day": true
  }
]

Create a balanced schedule that promotes consistency and sustainable progress.
''';
  }

  String _buildQuickWorkoutPrompt(
    FitnessProfile profile,
    int availableMinutes,
    String? focusArea,
  ) {
    final focus = focusArea ?? 'full body';

    return '''
Create a high-efficiency $availableMinutes-minute workout for:

PROFILE:
- Fitness Level: ${profile.fitnessLevel}
- Location: ${profile.workoutLocation}
- Equipment: ${profile.availableEquipment.join(', ')}
- Space: ${profile.workoutSpace}

REQUIREMENTS:
- Exactly $availableMinutes minutes including warm-up and cool-down
- Focus area: $focus
- High time efficiency - maximum results in minimum time
- No equipment transitions if possible
- Suitable for current fitness level

Use the same JSON format as the workout plan but optimized for time efficiency.
Maximum 6 exercises in main workout, minimal rest periods, compound movements preferred.
''';
  }

  String _buildExerciseAlternativesPrompt(
    String exerciseName,
    FitnessProfile profile,
    String? reason,
  ) {
    final contextReason = reason != null
        ? 'User needs alternatives due to: $reason'
        : 'User wants exercise variations';

    return '''
Provide alternative exercises for: $exerciseName

CONTEXT:
$contextReason
- User fitness level: ${profile.fitnessLevel}
- Available equipment: ${profile.availableEquipment.join(', ')}
- Workout location: ${profile.workoutLocation}

RESPONSE FORMAT:
Return ONLY a valid JSON array:

[
  {
    "exercise_name": "Alternative exercise name",
    "difficulty_level": "easier/same/harder",
    "equipment_needed": ["equipment list"],
    "muscle_groups": ["primary", "secondary"],
    "instructions": "Brief form instructions",
    "why_good_alternative": "Explanation of why this works as substitute"
  }
]

Provide 3-5 alternatives that target similar muscle groups with available equipment.
''';
  }

  String _buildExerciseGuidancePrompt(
      String exerciseName, FitnessProfile profile) {
    return '''
Provide comprehensive guidance for: $exerciseName

For user with:
- Fitness Level: ${profile.fitnessLevel}
- Experience: ${profile.yearsOfExperience} years

RESPONSE FORMAT:
Return ONLY a valid JSON object:

{
  "exercise_name": "$exerciseName",
  "muscle_groups_primary": ["primary muscles"],
  "muscle_groups_secondary": ["secondary muscles"],
  "proper_form": "Detailed step-by-step instructions",
  "common_mistakes": ["mistake 1", "mistake 2"],
  "safety_tips": ["tip 1", "tip 2"],
  "beginner_modifications": "Easier variations",
  "advanced_progressions": "Harder variations",
  "recommended_sets_reps": "Sets x reps based on fitness level",
  "breathing_pattern": "How to breathe during exercise",
  "equipment_alternatives": ["if no equipment available"]
}

Tailor advice to user's fitness level.
''';
  }

  String _buildProgressAnalysisPrompt(
    FitnessProfile profile,
    List<Map<String, dynamic>> workoutHistory,
    Map<String, dynamic> performanceData,
  ) {
    return '''
Analyze fitness progress and provide personalized recommendations:

CURRENT PROFILE:
- Fitness Level: ${profile.fitnessLevel}
- Weekly Workout Goal: ${profile.workoutsPerWeek} sessions

WORKOUT HISTORY (last 4 weeks):
${workoutHistory.map((w) => '- ${w['date']}: ${w['type']} (${w['duration']}min)').join('\n')}

PERFORMANCE DATA:
- Completed workouts: ${performanceData['completed_workouts'] ?? 0}
- Average duration: ${performanceData['avg_duration'] ?? 0} minutes
- Consistency: ${performanceData['consistency_percentage'] ?? 0}%

RESPONSE FORMAT:
Return ONLY a valid JSON object:

{
  "progress_summary": "Overall assessment of progress",
  "strengths": ["what user is doing well"],
  "areas_for_improvement": ["what needs work"],
  "fitness_level_progression": "should_advance/maintain/regress",
  "recommended_adjustments": {
    "frequency": "increase/decrease/maintain workout frequency",
    "intensity": "increase/decrease/maintain difficulty",
    "duration": "suggested session length changes",
    "focus_areas": ["areas to prioritize"]
  },
  "motivation_tips": ["personalized encouragement"],
  "next_week_goals": ["specific achievable goals"]
}

Provide actionable, encouraging feedback based on data.
''';
  }

  // ================== RESPONSE PARSERS ==================

  Map<String, dynamic> _parseWorkoutResponse(String responseText) {
    try {
      // Extract JSON from the response if needed
      final jsonMatch =
          RegExp(r'\{.*\}', dotAll: true).firstMatch(responseText);
      final jsonData = jsonMatch != null ? jsonMatch.group(0) : responseText;

      if (jsonData == null || jsonData.isEmpty) {
        throw Exception('No JSON data found in response');
      }

      return json.decode(jsonData);
    } catch (e) {
      log('[FitnessAI] Error parsing workout response: $e');
      throw Exception('Failed to parse workout data: $e');
    }
  }

  List<Map<String, dynamic>> _parseWeeklyScheduleResponse(String responseText) {
    try {
      // Extract JSON from the response if needed
      final jsonMatch =
          RegExp(r'\[.*\]', dotAll: true).firstMatch(responseText);
      final jsonData = jsonMatch != null ? jsonMatch.group(0) : responseText;

      if (jsonData == null || jsonData.isEmpty) {
        throw Exception('No JSON data found in response');
      }

      final List<dynamic> decoded = json.decode(jsonData);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      log('[FitnessAI] Error parsing weekly schedule response: $e');
      throw Exception('Failed to parse weekly schedule data: $e');
    }
  }

  List<Map<String, dynamic>> _parseExerciseAlternativesResponse(
      String responseText) {
    try {
      final cleanResponse = _extractJsonFromResponse(responseText);
      final List<dynamic> alternatives = json.decode(cleanResponse);
      return alternatives.cast<Map<String, dynamic>>();
    } catch (e) {
      log('[FitnessAI] Error parsing exercise alternatives: $e');
      return [];
    }
  }

  Map<String, dynamic> _parseExerciseGuidanceResponse(String responseText) {
    try {
      final cleanResponse = _extractJsonFromResponse(responseText);
      return json.decode(cleanResponse);
    } catch (e) {
      log('[FitnessAI] Error parsing exercise guidance: $e');
      return {};
    }
  }

  Map<String, dynamic> _parseProgressAnalysisResponse(String responseText) {
    try {
      final cleanResponse = _extractJsonFromResponse(responseText);
      return json.decode(cleanResponse);
    } catch (e) {
      log('[FitnessAI] Error parsing progress analysis: $e');
      return {};
    }
  }

  String _extractJsonFromResponse(String response) {
    // Remove markdown code blocks if present
    String cleaned = response.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    }
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    return cleaned.trim();
  }

  // ================== STORAGE METHODS ==================

  Future<void> _storeWorkoutPlan(Map<String, dynamic> workoutData) async {
    try {
      final workoutHistory = await _getWorkoutHistory();
      workoutHistory.add({
        ...workoutData,
        'generated_at': DateTime.now().toIso8601String(),
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
      });

      // Keep only last 50 workouts
      if (workoutHistory.length > 50) {
        workoutHistory.removeRange(0, workoutHistory.length - 50);
      }

      await _storage.put('workout_history', json.encode(workoutHistory));
    } catch (e) {
      log('[FitnessAI] Error storing workout plan: $e');
    }
  }

  Future<void> _storeWeeklySchedule(
      List<Map<String, dynamic>> scheduleData) async {
    try {
      await _storage.put(
          'current_weekly_schedule',
          json.encode({
            'schedule': scheduleData,
            'generated_at': DateTime.now().toIso8601String(),
            'week_of': _getCurrentWeekStart().toIso8601String(),
          }));
    } catch (e) {
      log('[FitnessAI] Error storing weekly schedule: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getWorkoutHistory() async {
    try {
      final historyJson = await _storage.get('workout_history');
      if (historyJson != null) {
        final List<dynamic> history = json.decode(historyJson);
        return history.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      log('[FitnessAI] Error getting workout history: $e');
    }
    return [];
  }

  DateTime _getCurrentWeekStart() {
    final now = DateTime.now();
    final daysFromMonday = now.weekday - 1;
    return now.subtract(Duration(days: daysFromMonday));
  }

  // ================== BACKUP METHODS ==================

  Map<String, dynamic> _getBackupWorkoutPlan(FitnessProfile profile) {
    return {
      'workout_name': 'Basic ${profile.fitnessLevel} Workout',
      'estimated_duration': profile.optimalWorkoutDuration,
      'difficulty_level': profile.recommendedDifficulty,
      'calories_burned_estimate': 150,
      'muscle_groups_targeted': ['full body'],
      'warm_up': [
        {
          'exercise': 'Light cardio',
          'duration': '5 minutes',
          'instructions': 'Walk in place or do light movements',
          'modifications': 'Adjust intensity as needed'
        }
      ],
      'main_exercises': [
        {
          'exercise': 'Bodyweight squats',
          'sets': 3,
          'reps': '10-15',
          'rest': '60 seconds',
          'instructions': 'Keep chest up, knees behind toes',
          'muscle_groups': ['legs', 'glutes'],
          'modifications': 'Use chair for support if needed',
          'equipment_needed': ['none']
        },
        {
          'exercise': 'Push-ups',
          'sets': 3,
          'reps': '5-12',
          'rest': '60 seconds',
          'instructions': 'Keep body straight, full range of motion',
          'muscle_groups': ['chest', 'shoulders', 'triceps'],
          'modifications': 'Knee push-ups or wall push-ups',
          'equipment_needed': ['none']
        }
      ],
      'cool_down': [
        {
          'exercise': 'Forward fold stretch',
          'duration': '30 seconds',
          'instructions': 'Reach toward toes, breathe deeply'
        }
      ],
      'notes': 'Backup workout - listen to your body',
      'progression_tips': 'Increase reps as you get stronger'
    };
  }

  List<Map<String, dynamic>> _getBackupWeeklySchedule(FitnessProfile profile) {
    final workoutsPerWeek = profile.workoutsPerWeek;
    final schedule = <Map<String, dynamic>>[];

    final workoutTypes = [
      'Full Body',
      'Upper Body',
      'Lower Body',
      'Core',
      'Cardio'
    ];

    for (var i = 0; i < workoutsPerWeek; i++) {
      schedule.add({
        'day': _getDayName(i),
        'workout_focus': workoutTypes[i % workoutTypes.length],
        'estimated_duration': profile.optimalWorkoutDuration,
        'exercises': [
          {
            'exercise':
                'Basic ${workoutTypes[i % workoutTypes.length]} Exercise',
            'sets': 3,
            'reps': '10-12',
            'rest': '60',
            'equipment_needed': ['bodyweight'],
            'instructions': 'Perform with proper form'
          }
        ],
        'notes': 'Backup workout - adjust as needed'
      });
    }

    return schedule;
  }

  Map<String, dynamic> _getBackupQuickWorkout(
      FitnessProfile profile, int minutes) {
    return {
      'workout_name': '$minutes-Minute Quick Workout',
      'estimated_duration': minutes,
      'difficulty_level': profile.recommendedDifficulty,
      'calories_burned_estimate': (minutes * 2.5).round(),
      'muscle_groups_targeted': ['full body'],
      'warm_up': [
        {
          'exercise': 'Arm circles and marching',
          'duration': '2 minutes',
          'instructions': 'Light movements to warm up',
          'modifications': 'Go at your own pace'
        }
      ],
      'main_exercises': [
        {
          'exercise': 'Jumping jacks or step touches',
          'sets': 1,
          'reps': '${minutes - 4} repetitions',
          'rest': '0 seconds',
          'instructions': 'Keep moving for the full time',
          'muscle_groups': ['full body'],
          'modifications': 'Step in place if jumping is too intense',
          'equipment_needed': ['none']
        }
      ],
      'cool_down': [
        {
          'exercise': 'Deep breathing and stretching',
          'duration': '2 minutes',
          'instructions': 'Slow, controlled stretches'
        }
      ],
      'notes': 'Quick backup workout for time constraints',
      'progression_tips': 'Try to increase intensity gradually'
    };
  }

  String _getDayName(int index) {
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[index % 7];
  }

  // Add this new method for simplified workout generation
  Future<WorkoutRoutine> generateWorkout(
      FitnessProfile profile, Map<String, dynamic> macroData) async {
    log('[FitnessAI] Starting workout generation...');
    log('[FitnessAI] Profile data: fitness level=${profile.fitnessLevel}, '
        'workouts/week=${profile.workoutsPerWeek}, '
        'equipment=${profile.availableEquipment.join(", ")}');

    try {
      // Check initialization
      if (!isInitialized) {
        log('[FitnessAI] Error: Gemini AI not initialized. API Key status: ${ApiConfig.isGeminiConfigured}');
        throw Exception(
            'Gemini AI is not initialized. Please check your API configuration.');
      }

      // Determine optimal workout parameters based on user profile
      final duration = profile.optimalWorkoutDuration;
      final intensity = _determineIntensityFromProfile(profile);

      log('[FitnessAI] Generating workout with parameters: '
          'duration=$duration minutes, intensity=$intensity');

      // Generate workout plan
      log('[FitnessAI] Calling generateEnhancedWorkoutPlan...');
      final workoutData = await generateEnhancedWorkoutPlan(
        fitnessProfile: profile,
        macroData: macroData,
        customDuration: duration,
      );

      log('[FitnessAI] Received workout data: ${json.encode(workoutData)}');

      // Convert to WorkoutRoutine
      final routine = WorkoutRoutine(
        name: workoutData['workout_name'] ?? 'AI Generated Workout',
        description: workoutData['description'] ??
            'Personalized workout based on your fitness profile',
        estimatedDurationMinutes: workoutData['estimated_duration'] ?? duration,
        difficulty: _mapDifficultyToEnum(workoutData['difficulty_level']?.toString()) ?? _mapDifficultyToEnum(intensity),
        targetMuscles: List<String>.from(
            workoutData['muscle_groups_targeted'] ?? ['full body']),
        requiredEquipment:
            List<String>.from(workoutData['required_equipment'] ?? []),
        exercises: _convertExercises(workoutData['main_exercises'] ?? []),
        isCustom: true,
      );

      log('[FitnessAI] Successfully created workout routine: ${routine.name} '
          'with ${routine.exercises.length} exercises');
      return routine;
    } catch (e, stackTrace) {
      log('[FitnessAI] Error generating workout: $e');
      log('[FitnessAI] Stack trace: $stackTrace');
      // Return a basic backup workout
      log('[FitnessAI] Falling back to basic workout');
      return _createBasicWorkout(profile);
    }
  }

  String _determineIntensityFromProfile(FitnessProfile profile) {
    switch (profile.fitnessLevel.toLowerCase()) {
      case 'beginner':
        return 'Light';
      case 'intermediate':
        return 'Moderate';
      case 'advanced':
        return 'High';
      default:
        return 'Moderate';
    }
  }

// Helper function to map difficulty strings to DB enum values
String _mapDifficultyToEnum(String? rawDifficulty) {
  final lowerDifficulty = rawDifficulty?.toLowerCase().trim();
  switch (lowerDifficulty) {
    case 'easy':
    case 'beginner':
      return 'beginner';
    case 'medium':
    case 'intermediate':
    case 'moderate':
      return 'intermediate';
    case 'hard':
    case 'advanced':
      return 'advanced';
    default:
      // Default to 'beginner' if mapping is unclear.
      // Log a warning if an unexpected value is encountered.
      if (rawDifficulty != null) {
        log('[FitnessAI] Unknown difficulty value "$rawDifficulty" received, defaulting to "beginner".');
      }
      return 'beginner';
  }
}

  List<WorkoutExercise> _convertExercises(List<dynamic> exerciseData) {
    log('[FitnessAI] Converting ${exerciseData.length} exercises to WorkoutExercise objects');

    return exerciseData.asMap().entries.map((entry) {
      final i = entry.key;
      final data = entry.value;

      log('[FitnessAI] Converting exercise ${i + 1}: ${data['exercise'] ?? 'unnamed'}');

      final exercise = Exercise(
        id: 'ai_exercise_$i',
        name: data['exercise'] ?? 'Exercise ${i + 1}',
        description: data['instructions'] ?? 'AI-generated exercise',
        primaryMuscles:
            List<String>.from(data['muscle_groups'] ?? ['full body']),
        type: 'strength',
        difficulty: _mapDifficultyToEnum(data['difficulty']?.toString()),
        instructions: [data['instructions'] ?? 'Follow proper form'],
        equipment: List<String>.from(data['equipment_needed'] ?? []),
        isCompound: ((data['muscle_groups'] as List?)?.length ?? 0) > 1,
      );

      final sets = List.generate(
        data['sets'] ?? 3,
        (_) => WorkoutSet(
          reps: _parseReps(data['reps']?.toString() ?? '10-12'),
          durationSeconds: null,
        ),
      );

      log('[FitnessAI] Created exercise: ${exercise.name} with ${sets.length} sets');

      return WorkoutExercise(
        exerciseId: exercise.id,
        exercise: exercise,
        sets: sets,
        restSeconds: _parseRestSeconds(data['rest']),
      );
    }).toList();
  }

  int _parseRestSeconds(dynamic rest) {
    if (rest == null) return 60;
    final parts = rest.toString().split(' ');
    return int.tryParse(parts[0]) ?? 60;
  }

  int _parseReps(String repsString) {
    // Parse reps like "8-12" or "10"
    if (repsString.contains('-')) {
      final parts = repsString.split('-');
      final min = int.tryParse(parts[0]) ?? 10;
      final max = int.tryParse(parts[1]) ?? 12;
      return ((min + max) / 2).round();
    }
    return int.tryParse(repsString) ?? 10;
  }

  WorkoutRoutine _createBasicWorkout(FitnessProfile profile) {
    // Create a simple bodyweight workout as fallback
    final exercises = [
      _createBasicExercise('Push-ups', 3, 10),
      _createBasicExercise('Squats', 3, 12),
      _createBasicExercise('Plank', 3, 0, durationSeconds: 30),
    ];

    return WorkoutRoutine(
      name: 'Basic ${profile.fitnessLevel} Workout',
      description:
          'A simple bodyweight workout suitable for your fitness level',
      estimatedDurationMinutes: profile.optimalWorkoutDuration,
      difficulty: profile.fitnessLevel,
      targetMuscles: ['full body'],
      requiredEquipment: [],
      exercises: exercises,
      isCustom: true,
    );
  }

  WorkoutExercise _createBasicExercise(String name, int sets, int reps,
      {int? durationSeconds}) {
    final exercise = Exercise(
      id: name.toLowerCase().replaceAll(' ', '_'),
      name: name,
      description: 'Basic bodyweight exercise',
      primaryMuscles: ['full body'],
      type: 'strength',
      difficulty: 'beginner',
      instructions: ['Perform with proper form'],
      equipment: [],
      isCompound: false,
    );

    return WorkoutExercise(
      exerciseId: exercise.id,
      exercise: exercise,
      sets: List.generate(
        sets,
        (_) => WorkoutSet(reps: reps, durationSeconds: durationSeconds),
      ),
      restSeconds: 60,
    );
  }
}
