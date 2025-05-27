import 'package:flutter/material.dart';
import '../models/workout_plan.dart';
import '../models/exercise.dart';
import '../services/workout_planning_service.dart';
import '../models/user_preferences.dart';
import 'package:flutter/cupertino.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../services/storage_service.dart';
import '../config/api_config.dart';
import 'workout_execution_screen.dart';

class WorkoutPlanningScreen extends StatefulWidget {
  const WorkoutPlanningScreen({Key? key}) : super(key: key);

  @override
  State<WorkoutPlanningScreen> createState() => _WorkoutPlanningScreenState();
}

class _WorkoutPlanningScreenState extends State<WorkoutPlanningScreen>
    with TickerProviderStateMixin {
  final WorkoutPlanningService _workoutService = WorkoutPlanningService();
  final Uuid _uuid = const Uuid();
  List<WorkoutRoutine> _routines = [];
  bool _isLoading = false;
  String? _error;
  late AnimationController _fabAnimationController;
  late AnimationController _listAnimationController;

  // Personalization state variables
  Map<String, dynamic>? _personalizedRecommendations;
  GenerativeModel? _model;
  UserPreferences? _userPreferences;
  bool _showPersonalizedSection = false;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _listAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Initialize Gemini model with error handling
    try {
      _model = GenerativeModel(
        model: 'gemini-2.5-flash-preview-05-20',
        apiKey: ApiConfig.geminiApiKey,
      );
    } catch (e) {
      debugPrint('Failed to initialize Gemini model: $e');
    }

    // Load user preferences
    _userPreferences = StorageService().getUserPreferences();
    _showPersonalizedSection = _userPreferences != null;

    _loadWorkoutRoutines();

    // Auto-generate recommendations if user has preferences and model is available
    if (_showPersonalizedSection && _model != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _generatePersonalizedRecommendations();
      });
    }
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _listAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkoutRoutines() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final routines = await _workoutService.getWorkoutRoutines();
      setState(() {
        _routines = routines;
        _isLoading = false;
      });
      _listAnimationController.forward();
      _fabAnimationController.forward();
    } catch (e) {
      setState(() {
        _error = 'Failed to load workout routines: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewWorkoutRoutine() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CreateWorkoutBottomSheet(),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        final routine = WorkoutRoutine(
          name: result['name'],
          description: result['description'],
          exercises: [],
          estimatedDurationMinutes: 45,
          difficulty: 'beginner',
          targetMuscles: [],
          requiredEquipment: [],
          isCustom: true,
        );

        final createdRoutine =
            await _workoutService.createWorkoutRoutine(routine);
        if (createdRoutine != null) {
          setState(() {
            _routines = [..._routines, createdRoutine];
          });
          _showSuccessSnackBar('Workout created successfully!');
        }
      } catch (e) {
        _showErrorSnackBar('Failed to create workout: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateWorkoutRoutine() async {
    setState(() => _isLoading = true);
    try {
      final userPrefs = UserPreferences(
        userId: _uuid.v4(),
        targetCalories: 2000,
        targetProtein: 150,
        targetCarbohydrates: 200,
        targetFat: 65,
        equipment: EquipmentAvailability(
          available: ['Dumbbells', 'Bodyweight'],
          hasHomeEquipment: true,
        ),
        fitnessGoals: FitnessGoals(
          primary: 'general_fitness',
          secondary: ['strength', 'endurance'],
          workoutsPerWeek: 3,
        ),
        dietaryPreferences: DietaryPreferences(
          preferences: [],
          allergies: [],
          dislikedFoods: [],
          mealsPerDay: 3,
        ),
      );

      final routine = await _workoutService.generateWorkoutRoutine(
        userPreferences: userPrefs,
        name: 'AI Workout ${DateTime.now().toString().substring(0, 10)}',
        description: 'Personalized AI-generated workout routine',
        targetMuscles: ['chest', 'back', 'legs'],
        durationMinutes: 45,
      );

      if (routine != null) {
        setState(() {
          _routines = [..._routines, routine];
        });
        _showSuccessSnackBar('AI workout generated successfully!');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to generate workout: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startWorkout(WorkoutRoutine routine) async {
    try {
      // Navigate to workout execution screen
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => WorkoutExecutionScreen(routine: routine),
        ),
      );

      // If workout was completed, show success message
      if (result == true && mounted) {
        _showSuccessSnackBar('Workout completed! Great job! 🎉');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to start workout: $e');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
        elevation: 8,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
        elevation: 8,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showLoadingSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _generatePersonalizedRecommendations() async {
    if (_model == null) return;

    setState(() => _isLoading = true);

    try {
      // Get user preferences
      final userPrefs =
          _userPreferences ?? StorageService().getUserPreferencesWithDefaults();

      // Create personalized prompt
      final prompt = '''
Based on the following user profile, recommend 4 specific exercises they should focus on today:

USER PROFILE:
- Fitness Goal: ${userPrefs.fitnessGoals.primary}
- Secondary Goals: ${userPrefs.fitnessGoals.secondary.join(', ')}
- Workouts per week: ${userPrefs.fitnessGoals.workoutsPerWeek}
- Available Equipment: ${userPrefs.equipment.available.join(', ')}
- Has Gym Access: ${userPrefs.equipment.hasGym}
- Home Equipment: ${userPrefs.equipment.hasHomeEquipment}

INSTRUCTIONS:
1. Recommend exercises that match their equipment and goals
2. Consider their fitness level and workout frequency
3. Provide variety to keep workouts interesting
4. Include proper progression suggestions
5. Format as JSON with exercise details

Return JSON format:
{
  "personalizedMessage": "A motivational message based on their goals (max 25 words)",
  "todaysRecommendations": [
    {
      "exerciseName": "Exercise name",
      "targetMuscles": ["muscle1", "muscle2"],
      "sets": "3-4",
      "reps": "8-12",
      "restTime": "60-90 seconds",
      "difficulty": "beginner/intermediate/advanced",
      "equipment": ["required equipment"],
      "benefits": "Why this exercise is perfect for them (max 15 words)",
      "progression": "How to make it harder as they improve (max 15 words)"
    }
  ],
  "weeklyGoalProgress": "Assessment of their current week (max 20 words)",
  "nextWorkoutSuggestion": "When and what type of workout to do next (max 20 words)"
}
''';

      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);

      final jsonStr = response.text?.trim() ?? '';
      debugPrint('Personalized recommendations response: $jsonStr');

      // Parse the response
      final cleanJson =
          jsonStr.replaceAll('```json', '').replaceAll('```', '').trim();
      final recommendations = json.decode(cleanJson);

      // Store recommendations for display
      setState(() {
        _personalizedRecommendations = recommendations;
        _isLoading = false;
      });

      _showSuccessSnackBar('Personalized recommendations ready! 🎯');
    } catch (e) {
      debugPrint('Error generating personalized recommendations: $e');
      _showErrorSnackBar('Failed to generate recommendations');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generatePersonalizedWorkout() async {
    setState(() => _isLoading = true);

    try {
      final userPrefs =
          _userPreferences ?? StorageService().getUserPreferencesWithDefaults();

      final prompt = '''
Create a complete personalized workout routine based on this user profile:

USER PROFILE:
- Primary Fitness Goal: ${userPrefs.fitnessGoals.primary}
- Secondary Goals: ${userPrefs.fitnessGoals.secondary.join(', ')}
- Workouts per week: ${userPrefs.fitnessGoals.workoutsPerWeek}
- Preferred workout duration: ${userPrefs.fitnessGoals.minutesPerWorkout} minutes
- Available Equipment: ${userPrefs.equipment.available.join(', ')}
- Has Gym: ${userPrefs.equipment.hasGym}
- Home Setup: ${userPrefs.equipment.hasHomeEquipment}

WORKOUT REQUIREMENTS:
- Duration: ${userPrefs.fitnessGoals.minutesPerWorkout} minutes
- Match their fitness goals and equipment
- Include warm-up and cool-down
- Progressive difficulty
- Engaging and motivational

Create a JSON response with:
{
  "workoutName": "Descriptive name based on their goals",
  "description": "Motivational description explaining why this workout is perfect for them",
  "totalDuration": ${userPrefs.fitnessGoals.minutesPerWorkout},
  "difficulty": "appropriate level",
  "targetMuscles": ["primary", "secondary", "muscle groups"],
  "exercises": [
    {
      "name": "Exercise name",
      "sets": 3,
      "reps_or_duration": "8-12 reps or time",
      "rest_period_between_sets": "60 seconds",
      "instructions": "Clear instructions",
      "targetMuscles": ["muscles worked"],
      "equipment": ["equipment needed"]
    }
  ],
  "personalizedTips": [
    "Tip 1 based on their goals",
    "Tip 2 for their equipment setup"
  ]
}
''';

      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);

      final jsonStr = response.text?.trim() ?? '';
      debugPrint('Personalized workout response: $jsonStr');

      final cleanJson =
          jsonStr.replaceAll('```json', '').replaceAll('```', '').trim();
      final workoutData = json.decode(cleanJson);

      // Process exercises using the same logic as the main workout service
      final exercises = workoutData['exercises'] as List<dynamic>? ?? [];
      final workoutExercises = <WorkoutExercise>[];

      for (final exerciseData in exercises) {
        final exerciseName = exerciseData['name']?.toString();
        if (exerciseName == null || exerciseName.isEmpty) {
          debugPrint('Skipping exercise with no name: $exerciseData');
          continue;
        }

        // Generate a unique exercise ID using UUID
        final exerciseId = _uuid.v4();

        // Create a simple exercise object for this workout
        final exercise = Exercise(
          id: exerciseId,
          name: exerciseName,
          description: exerciseData['instructions']?.toString() ??
              'No description available',
          primaryMuscles:
              List<String>.from(exerciseData['targetMuscles'] ?? []),
          equipment: List<String>.from(
              exerciseData['equipment'] ?? userPrefs.equipment.available),
          type: 'strength',
          difficulty: workoutData['difficulty'] ?? 'intermediate',
          instructions: [],
          isCompound:
              ((exerciseData['targetMuscles'] as List?)?.length ?? 0) > 1,
          defaultSets: _parseIntSafely(exerciseData['sets'], 3),
          defaultReps:
              _parseRepsFromString(exerciseData['reps_or_duration'], 10),
          defaultDurationSeconds: null,
        );

        // Create workout sets
        final sets = <WorkoutSet>[];
        final numSets = _parseIntSafely(exerciseData['sets'], 3);
        final reps = _parseRepsFromString(exerciseData['reps_or_duration'], 10);
        final durationSeconds =
            _parseDurationFromString(exerciseData['reps_or_duration']);

        for (int i = 0; i < numSets; i++) {
          sets.add(WorkoutSet(
            reps: reps,
            durationSeconds: durationSeconds,
          ));
        }

        // Parse rest time
        final restSeconds =
            _parseRestFromString(exerciseData['rest_period_between_sets']) ??
                60;

        // Add exercise to workout
        workoutExercises.add(WorkoutExercise(
          exerciseId: exerciseId,
          exercise: exercise,
          sets: sets,
          restSeconds: restSeconds,
        ));
      }

      // Create workout routine from the AI response with proper exercises
      final routine = WorkoutRoutine(
        name: workoutData['workoutName'] ?? 'Personalized AI Workout',
        description: workoutData['description'] ??
            'Custom workout designed for your goals',
        exercises: workoutExercises,
        estimatedDurationMinutes: workoutData['totalDuration'] ??
            userPrefs.fitnessGoals.minutesPerWorkout,
        difficulty: workoutData['difficulty'] ?? 'intermediate',
        targetMuscles: List<String>.from(workoutData['targetMuscles'] ?? []),
        requiredEquipment: userPrefs.equipment.available,
        isCustom: true,
      );

      final createdRoutine =
          await _workoutService.createWorkoutRoutine(routine);
      if (createdRoutine != null) {
        setState(() {
          _routines = [..._routines, createdRoutine];
        });
        _showSuccessSnackBar('🎯 Personalized workout created just for you!');
      }
    } catch (e) {
      debugPrint('Error generating personalized workout: $e');
      _showErrorSnackBar('Failed to create personalized workout');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Helper methods for parsing AI-generated data (copied from workout service)
  int _parseIntSafely(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? defaultValue;
    }
    return defaultValue;
  }

  int _parseRepsFromString(String? value, int defaultValue) {
    if (value == null) return defaultValue;

    // Handle formats like "10-12 reps", "8-10 reps per leg", "AMRAP", "5 minutes"
    final lowerValue = value.toLowerCase();

    // Check for time-based exercises
    if (lowerValue.contains('minute') || lowerValue.contains('min')) {
      return 1; // For time-based exercises, use 1 rep
    }

    // Check for AMRAP (as many reps as possible)
    if (lowerValue.contains('amrap')) {
      // Extract the max number if present, e.g., "AMRAP (up to 10-15)"
      final match = RegExp(r'(\d+)').firstMatch(value);
      return match != null
          ? int.tryParse(match.group(1)!) ?? defaultValue
          : defaultValue;
    }

    // Extract first number from range like "10-12" or "8-10"
    final match = RegExp(r'(\d+)').firstMatch(value);
    return match != null
        ? int.tryParse(match.group(1)!) ?? defaultValue
        : defaultValue;
  }

  int? _parseDurationFromString(String? value) {
    if (value == null) return null;

    final lowerValue = value.toLowerCase();

    // Handle formats like "5 minutes", "30 seconds"
    if (lowerValue.contains('minute') || lowerValue.contains('min')) {
      final match = RegExp(r'(\d+)').firstMatch(value);
      if (match != null) {
        final minutes = int.tryParse(match.group(1)!);
        return minutes != null ? minutes * 60 : null; // Convert to seconds
      }
    }

    if (lowerValue.contains('second') || lowerValue.contains('sec')) {
      final match = RegExp(r'(\d+)').firstMatch(value);
      if (match != null) {
        return int.tryParse(match.group(1)!);
      }
    }

    return null;
  }

  int? _parseRestFromString(String? value) {
    if (value == null) return null;

    final lowerValue = value.toLowerCase();

    // Handle formats like "60 seconds", "1-2 minutes", "90 sec"
    if (lowerValue.contains('minute') || lowerValue.contains('min')) {
      final match = RegExp(r'(\d+)').firstMatch(value);
      if (match != null) {
        final minutes = int.tryParse(match.group(1)!);
        return minutes != null ? minutes * 60 : null; // Convert to seconds
      }
    }

    if (lowerValue.contains('second') || lowerValue.contains('sec')) {
      final match = RegExp(r'(\d+)').firstMatch(value);
      if (match != null) {
        return int.tryParse(match.group(1)!);
      }
    }

    // If no unit specified, assume seconds
    final match = RegExp(r'(\d+)').firstMatch(value);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  void _refreshRecommendations() {
    if (_showPersonalizedSection) {
      _generatePersonalizedRecommendations();
    }
  }

  void _showPreferencesSetup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PreferencesSetupBottomSheet(
        onPreferencesSet: (preferences) {
          setState(() {
            _userPreferences = preferences;
            _showPersonalizedSection = true;
          });
          StorageService().saveUserPreferences(preferences);
          _generatePersonalizedRecommendations();
        },
      ),
    );
  }

  Widget _buildPersonalizedSection() {
    if (!_showPersonalizedSection || _personalizedRecommendations == null) {
      return const SizedBox.shrink();
    }

    final recommendations = _personalizedRecommendations!;
    final todaysRecommendations =
        recommendations['todaysRecommendations'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6366F1),
            const Color(0xFF8B5CF6),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Just for You',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      recommendations['personalizedMessage'] ??
                          'Personalized recommendations ready!',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _refreshRecommendations,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Today's Recommendations
          Text(
            'Today\'s Focus',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: todaysRecommendations.length,
              itemBuilder: (context, index) {
                final exercise = todaysRecommendations[index];
                return Container(
                  width: 280,
                  margin: EdgeInsets.only(
                      right: index < todaysRecommendations.length - 1 ? 16 : 0),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              exercise['exerciseName'] ?? 'Exercise',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              exercise['difficulty'] ?? 'Medium',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${exercise['sets']} sets • ${exercise['reps']} reps',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        exercise['benefits'] ?? 'Great for your fitness goals',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.fitness_center_rounded,
                            color: Colors.white.withOpacity(0.6),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (exercise['equipment'] as List<dynamic>? ?? [])
                                  .join(', '),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _generatePersonalizedWorkout,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text(
                    'Create Full Workout',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),

          if (recommendations['nextWorkoutSuggestion'] != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: Colors.white.withOpacity(0.8),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      recommendations['nextWorkoutSuggestion'],
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1E293B),
                      const Color(0xFF334155),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hello there! 👋',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'My Workouts',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 28,
                                    letterSpacing: -0.8,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.15),
                                  width: 1,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: _createNewWorkoutRoutine,
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    child: const Icon(
                                      Icons.add_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              collapseMode: CollapseMode.pin,
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(0),
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey.shade200,
                      Colors.grey.shade100,
                      Colors.grey.shade200,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickStatsCard(theme),
                  const SizedBox(height: 32),

                  // Add personalized section here
                  if (_showPersonalizedSection) _buildPersonalizedSection(),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Routines',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          letterSpacing: -0.5,
                          fontFamily: 'SF Pro Display',
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _loadWorkoutRoutines,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.black.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                  color: Colors.black,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Refresh',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: _LoadingWidget()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: _ErrorWidget(
                error: _error!,
                onRetry: _loadWorkoutRoutines,
              ),
            )
          else if (_routines.isEmpty)
            SliverFillRemaining(
              child: _EmptyStateWidget(
                onCreateWorkout: _createNewWorkoutRoutine,
                onGenerateWorkout: _generateWorkoutRoutine,
                onSetupPreferences:
                    !_showPersonalizedSection ? _showPreferencesSetup : null,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return AnimatedBuilder(
                      animation: _listAnimationController,
                      builder: (context, child) {
                        final animationValue = Curves.easeOutBack
                            .transform(
                              (_listAnimationController.value - (index * 0.1))
                                  .clamp(0.0, 1.0),
                            )
                            .clamp(0.0, 1.0);
                        return Transform.translate(
                          offset: Offset(0, 50 * (1 - animationValue)),
                          child: Opacity(
                            opacity: animationValue,
                            child: _buildWorkoutCard(_routines[index], index),
                          ),
                        );
                      },
                    );
                  },
                  childCount: _routines.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 100), // Space for FAB
          ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimationController,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: _showPersonalizedSection
                ? _generatePersonalizedWorkout
                : _generateWorkoutRoutine,
            icon: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 20),
            ),
            label: Text(
              _showPersonalizedSection ? 'Personal AI' : 'AI Workout',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                letterSpacing: -0.2,
              ),
            ),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatsCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 40,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              'Total Routines',
              '${_routines.length}',
              Icons.fitness_center_rounded,
              Colors.black,
              Colors.grey.shade100,
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.grey.shade200,
          ),
          Expanded(
            child: _buildStatItem(
              'This Week',
              '3',
              Icons.calendar_today_rounded,
              Colors.black,
              Colors.grey.shade100,
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.grey.shade200,
          ),
          Expanded(
            child: _buildStatItem(
              'Streak',
              '7 days',
              Icons.local_fire_department_rounded,
              Colors.black,
              Colors.grey.shade100,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color,
      Color backgroundColor) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWorkoutCard(WorkoutRoutine routine, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 40,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => _showWorkoutDetails(routine),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.fitness_center_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              routine.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                                letterSpacing: -0.3,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _buildInfoChip(
                                  routine.difficulty,
                                  _getDifficultyColor(routine.difficulty),
                                  _getDifficultyTextColor(routine.difficulty),
                                ),
                                const SizedBox(width: 10),
                                _buildInfoChip(
                                  '${routine.estimatedDurationMinutes} min',
                                  Colors.grey.shade200,
                                  Colors.black,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _startWorkout(routine),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    routine.description,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 15,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (routine.targetMuscles.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: routine.targetMuscles.take(3).map((muscle) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            muscle.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.group_work_rounded,
                          size: 16,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${routine.exercises.length} exercises',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (routine.isCustom)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'CUSTOM',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, Color backgroundColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: textColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return Colors.grey.shade100;
      case 'intermediate':
        return Colors.grey.shade200;
      case 'advanced':
        return Colors.grey.shade300;
      default:
        return Colors.grey.shade100;
    }
  }

  Color _getDifficultyTextColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return Colors.grey.shade600;
      case 'intermediate':
        return Colors.grey.shade700;
      case 'advanced':
        return Colors.black;
      default:
        return Colors.grey.shade600;
    }
  }

  void _showWorkoutDetails(WorkoutRoutine routine) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WorkoutDetailsBottomSheet(routine: routine),
    );
  }
}

class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 25,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 50,
                offset: const Offset(0, 16),
              ),
            ],
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Loading your workouts...',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Preparing your fitness journey',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorWidget({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text(
                  'Try Again',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateWidget extends StatelessWidget {
  final VoidCallback onCreateWorkout;
  final VoidCallback onGenerateWorkout;
  final VoidCallback? onSetupPreferences;

  const _EmptyStateWidget({
    required this.onCreateWorkout,
    required this.onGenerateWorkout,
    this.onSetupPreferences,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.fitness_center_rounded,
                  size: 70,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Ready to Start Your\nFitness Journey?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Create your first workout routine or let our AI\ngenerate one tailored to your goals.',
                style: TextStyle(
                  color: const Color(0xFF64748B),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.6,
                  letterSpacing: 0.1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Column(
                children: [
                  if (onSetupPreferences != null) ...[
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: onSetupPreferences,
                        icon: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.tune_rounded, size: 18),
                        ),
                        label: const Text(
                          'Get Personalized Workouts',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            letterSpacing: -0.1,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: onGenerateWorkout,
                      icon: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, size: 18),
                      ),
                      label: const Text(
                        'Generate AI Workout',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          letterSpacing: -0.1,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: onSetupPreferences != null
                            ? Colors.grey.shade700
                            : const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onCreateWorkout,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'Create Custom Workout',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          letterSpacing: -0.1,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(
                          color: const Color(0xFF6366F1),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateWorkoutBottomSheet extends StatefulWidget {
  const _CreateWorkoutBottomSheet();

  @override
  _CreateWorkoutBottomSheetState createState() =>
      _CreateWorkoutBottomSheetState();
}

class _CreateWorkoutBottomSheetState extends State<_CreateWorkoutBottomSheet> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.add_circle_outline,
                            color: Theme.of(context).primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create New Workout',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                'Build your custom routine',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Workout Name',
                        hintText: 'e.g., Upper Body Strength',
                        prefixIcon: const Icon(Icons.fitness_center),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a workout name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe your workout goals and focus areas',
                        prefixIcon: const Icon(Icons.description),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    const Spacer(),
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                Navigator.pop(context, {
                                  'name': _nameController.text,
                                  'description': _descriptionController.text,
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Create Workout',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

class _WorkoutDetailsBottomSheet extends StatelessWidget {
  final WorkoutRoutine routine;

  const _WorkoutDetailsBottomSheet({required this.routine});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).primaryColor,
                              Theme.of(context).primaryColor.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.fitness_center,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              routine.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              '${routine.difficulty} • ${routine.estimatedDurationMinutes} min',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    routine.description,
                    style: const TextStyle(
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),
                  if (routine.targetMuscles.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Target Muscles',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: routine.targetMuscles.map((muscle) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            muscle.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  if (routine.exercises.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Exercises (${routine.exercises.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: routine.exercises.length,
                        itemBuilder: (context, index) {
                          final exercise = routine.exercises[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        exercise.exercise?.name ??
                                            'Unknown Exercise',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        '${exercise.sets.length} sets • ${exercise.restSeconds}s rest',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (exercise.isCompleted)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // Start workout logic would go here
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Workout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferencesSetupBottomSheet extends StatefulWidget {
  final Function(UserPreferences) onPreferencesSet;

  const _PreferencesSetupBottomSheet({required this.onPreferencesSet});

  @override
  _PreferencesSetupBottomSheetState createState() =>
      _PreferencesSetupBottomSheetState();
}

class _PreferencesSetupBottomSheetState
    extends State<_PreferencesSetupBottomSheet> {
  String _primaryGoal = 'general_fitness';
  List<String> _equipment = ['bodyweight'];
  int _workoutsPerWeek = 3;
  bool _hasGym = false;

  final List<Map<String, dynamic>> _goals = [
    {'id': 'weight_loss', 'name': 'Weight Loss', 'icon': Icons.trending_down},
    {'id': 'muscle_gain', 'name': 'Muscle Gain', 'icon': Icons.fitness_center},
    {
      'id': 'general_fitness',
      'name': 'General Fitness',
      'icon': Icons.favorite
    },
    {'id': 'endurance', 'name': 'Endurance', 'icon': Icons.directions_run},
  ];

  final List<String> _equipmentOptions = [
    'bodyweight',
    'dumbbells',
    'resistance_bands',
    'barbell',
    'pull_up_bar',
    'kettlebell',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF6366F1),
                              const Color(0xFF8B5CF6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Get Personalized Workouts',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'Tell us about your fitness goals',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Fitness Goal Selection
                  const Text(
                    'What\'s your main fitness goal?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _goals.map((goal) {
                      final isSelected = _primaryGoal == goal['id'];
                      return GestureDetector(
                        onTap: () => setState(() => _primaryGoal = goal['id']),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF6366F1)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF6366F1)
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                goal['icon'],
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey.shade600,
                                size: 24,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                goal['name'],
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 32),

                  // Workouts per week
                  Text(
                    'How many times per week? ($_workoutsPerWeek times)',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: _workoutsPerWeek.toDouble(),
                    min: 1,
                    max: 7,
                    divisions: 6,
                    activeColor: const Color(0xFF6366F1),
                    onChanged: (value) =>
                        setState(() => _workoutsPerWeek = value.round()),
                  ),

                  const SizedBox(height: 24),

                  // Equipment
                  const Text(
                    'Available Equipment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Gym Access
                  Row(
                    children: [
                      Checkbox(
                        value: _hasGym,
                        onChanged: (value) =>
                            setState(() => _hasGym = value ?? false),
                        activeColor: const Color(0xFF6366F1),
                      ),
                      const Text('I have gym access'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Equipment options
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _equipmentOptions.map((equipment) {
                      final isSelected = _equipment.contains(equipment);
                      return FilterChip(
                        label: Text(
                          equipment.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _equipment.add(equipment);
                            } else {
                              _equipment.remove(equipment);
                            }
                          });
                        },
                        selectedColor: const Color(0xFF6366F1),
                        backgroundColor: Colors.grey.shade100,
                        side: BorderSide(color: Colors.grey.shade300),
                      );
                    }).toList(),
                  ),

                  const Spacer(),

                  // Create button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final preferences = UserPreferences(
                          userId: const Uuid().v4(),
                          fitnessGoals: FitnessGoals(
                            primary: _primaryGoal,
                            workoutsPerWeek: _workoutsPerWeek,
                            minutesPerWorkout: 45,
                          ),
                          equipment: EquipmentAvailability(
                            available: _equipment,
                            hasGym: _hasGym,
                            hasHomeEquipment: true,
                          ),
                          targetCalories: 2000,
                          targetProtein: 150,
                          targetCarbohydrates: 200,
                          targetFat: 65,
                        );

                        Navigator.pop(context);
                        widget.onPreferencesSet(preferences);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Get Personalized Workouts',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
