import 'dart:convert';
import 'dart:developer';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import '../models/fitness_profile.dart';
import '../services/storage_service.dart';

class FitnessAIService {
  static final FitnessAIService _instance = FitnessAIService._internal();
  factory FitnessAIService() => _instance;
  FitnessAIService._internal();

  late final GenerativeModel _model;
  final StorageService _storage = StorageService();

  void initialize() {
    _model = FirebaseVertexAI.instance.generativeModel(
      model: 'gemini-2.0-flash',
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 2048,
      ),
    );
  }

  // ================== WORKOUT RECOMMENDATIONS ==================

  Future<Map<String, dynamic>> generateWorkoutPlan({
    required FitnessProfile fitnessProfile,
    required Map<String, dynamic> macroData,
    String? specificMuscleGroup,
    int? customDuration,
  }) async {
    try {
      final prompt = _buildWorkoutPlanPrompt(
        fitnessProfile,
        macroData,
        specificMuscleGroup,
        customDuration,
      );

      log('[FitnessAI] Generating workout plan for ${fitnessProfile.fitnessLevel} user');

      final response = await _model.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';

      // Parse and validate the JSON response
      final workoutData = _parseWorkoutResponse(responseText);

      // Store the workout for future reference
      await _storeWorkoutPlan(workoutData);

      return workoutData;
    } catch (e) {
      log('[FitnessAI] Error generating workout plan: $e');
      return _getBackupWorkoutPlan(fitnessProfile);
    }
  }

  Future<List<Map<String, dynamic>>> generateWeeklySchedule({
    required FitnessProfile fitnessProfile,
    required Map<String, dynamic> macroData,
  }) async {
    try {
      final prompt = _buildWeeklySchedulePrompt(fitnessProfile, macroData);

      log('[FitnessAI] Generating weekly schedule for ${fitnessProfile.workoutsPerWeek} workouts');

      final response = await _model.generateContent([Content.text(prompt)]);
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
      final prompt = _buildQuickWorkoutPrompt(
        fitnessProfile,
        availableMinutes,
        focusArea,
      );

      log('[FitnessAI] Generating ${availableMinutes}-minute quick workout');

      final response = await _model.generateContent([Content.text(prompt)]);
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

      final response = await _model.generateContent([Content.text(prompt)]);
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

      final response = await _model.generateContent([Content.text(prompt)]);
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

      final response = await _model.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';

      return _parseProgressAnalysisResponse(responseText);
    } catch (e) {
      log('[FitnessAI] Error analyzing progress: $e');
      return {};
    }
  }

  // ================== PROMPT BUILDERS ==================

  String _buildWorkoutPlanPrompt(
    FitnessProfile profile,
    Map<String, dynamic> macroData,
    String? specificMuscleGroup,
    int? customDuration,
  ) {
    final duration = customDuration ?? profile.optimalWorkoutDuration;
    final muscleGroupFocus = specificMuscleGroup != null
        ? 'Focus specifically on: $specificMuscleGroup'
        : 'Provide a balanced workout';

    return '''
You are an expert fitness trainer and exercise physiologist. Create a personalized workout plan based on the following user profile:

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
- Appropriate for ${profile.workoutSpace} space
- Match ${profile.fitnessLevel} fitness level

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
      "exercise": "Exercise name",
      "duration": "2 minutes",
      "instructions": "Brief instructions",
      "modifications": "Easier/harder options"
    }
  ],
  "main_exercises": [
    {
      "exercise": "Exercise name",
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
  "progression_tips": "How to advance this workout"
}

Ensure all exercises are safe, effective, and match the user's fitness level and available equipment.
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
Create a high-efficiency ${availableMinutes}-minute workout for:

PROFILE:
- Fitness Level: ${profile.fitnessLevel}
- Location: ${profile.workoutLocation}
- Equipment: ${profile.availableEquipment.join(', ')}
- Space: ${profile.workoutSpace}

REQUIREMENTS:
- Exactly ${availableMinutes} minutes including warm-up and cool-down
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

  Map<String, dynamic> _parseWorkoutResponse(String response) {
    try {
      // Clean the response to extract JSON
      final cleanResponse = _extractJsonFromResponse(response);
      return json.decode(cleanResponse);
    } catch (e) {
      log('[FitnessAI] Error parsing workout response: $e');
      return {};
    }
  }

  List<Map<String, dynamic>> _parseWeeklyScheduleResponse(String response) {
    try {
      final cleanResponse = _extractJsonFromResponse(response);
      final List<dynamic> scheduleList = json.decode(cleanResponse);
      return scheduleList.cast<Map<String, dynamic>>();
    } catch (e) {
      log('[FitnessAI] Error parsing weekly schedule: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _parseExerciseAlternativesResponse(
      String response) {
    try {
      final cleanResponse = _extractJsonFromResponse(response);
      final List<dynamic> alternatives = json.decode(cleanResponse);
      return alternatives.cast<Map<String, dynamic>>();
    } catch (e) {
      log('[FitnessAI] Error parsing exercise alternatives: $e');
      return [];
    }
  }

  Map<String, dynamic> _parseExerciseGuidanceResponse(String response) {
    try {
      final cleanResponse = _extractJsonFromResponse(response);
      return json.decode(cleanResponse);
    } catch (e) {
      log('[FitnessAI] Error parsing exercise guidance: $e');
      return {};
    }
  }

  Map<String, dynamic> _parseProgressAnalysisResponse(String response) {
    try {
      final cleanResponse = _extractJsonFromResponse(response);
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

  Future<void> _storeWorkoutPlan(Map<String, dynamic> workout) async {
    try {
      final workoutHistory = await _getWorkoutHistory();
      workoutHistory.add({
        ...workout,
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

  Future<void> _storeWeeklySchedule(List<Map<String, dynamic>> schedule) async {
    try {
      await _storage.put(
          'current_weekly_schedule',
          json.encode({
            'schedule': schedule,
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
    // Provide a basic backup workout when AI fails
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
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final schedule = <Map<String, dynamic>>[];

    int workoutCount = 0;
    for (final day in days) {
      if (workoutCount < profile.workoutsPerWeek) {
        schedule.add({
          'day': day,
          'workout_type': 'Full Body',
          'primary_focus': 'General Fitness',
          'estimated_duration': profile.optimalWorkoutDuration,
          'intensity': 'moderate',
          'equipment_needed': profile.availableEquipment,
          'key_exercises': ['Squats', 'Push-ups', 'Stretching'],
          'rest_day': false
        });
        workoutCount++;
      } else {
        schedule.add({
          'day': day,
          'workout_type': 'Rest Day',
          'primary_focus': 'Recovery',
          'estimated_duration': 0,
          'intensity': 'low',
          'equipment_needed': [],
          'key_exercises': ['Light stretching', 'Walking'],
          'rest_day': true
        });
      }
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
}
