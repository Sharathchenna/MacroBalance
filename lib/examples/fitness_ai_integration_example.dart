import 'package:flutter/material.dart';
import 'dart:developer';
import '../services/fitness_ai_service.dart';
import '../services/fitness_data_service.dart';

/// Example integration of Gemini Flash AI for fitness recommendations
/// This shows how to integrate the AI service with your existing workout planning screen
class FitnessAIIntegrationExample extends StatefulWidget {
  const FitnessAIIntegrationExample({super.key});

  @override
  State<FitnessAIIntegrationExample> createState() =>
      _FitnessAIIntegrationExampleState();
}

class _FitnessAIIntegrationExampleState
    extends State<FitnessAIIntegrationExample> {
  final FitnessAIService _aiService = FitnessAIService();
  final FitnessDataService _dataService = FitnessDataService();

  bool _isLoading = false;
  Map<String, dynamic>? _currentWorkout;
  List<Map<String, dynamic>>? _weeklySchedule;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // _aiService.initialize(); // Removed as FitnessAIService initializes in its constructor
    _checkAIReadiness();
  }

  Future<void> _checkAIReadiness() async {
    final isReady = await _dataService.isReadyForAIRecommendations();
    if (!isReady) {
      setState(() {
        _errorMessage =
            'Complete your fitness profile in onboarding to get AI recommendations';
      });
    }
  }

  // =================== AI WORKOUT GENERATION ===================

  Future<void> _generateTodaysWorkout() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get user data
      final fitnessProfile = await _dataService.getCurrentFitnessProfile();
      final macroData = await _dataService.getMacroData();

      // Validate data
      if (!fitnessProfile.isBasicProfileComplete) {
        throw Exception(
            'Incomplete fitness profile - please complete onboarding');
      }

      // Generate workout with AI
      final workout = await _aiService.generateWorkoutPlan(
        fitnessProfile: fitnessProfile,
        macroData: macroData,
        // Optional: specify focus area
        // specificMuscleGroup: 'upper body',
        // customDuration: 30,
      );

      setState(() {
        _currentWorkout = workout;
        _isLoading = false;
      });

      log('[AI Integration] Generated workout: ${workout['workout_name']}');
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to generate workout: $e';
        _isLoading = false;
      });
      log('[AI Integration] Error generating workout: $e');
    }
  }

  Future<void> _generateWeeklySchedule() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fitnessProfile = await _dataService.getCurrentFitnessProfile();
      final macroData = await _dataService.getMacroData();

      final schedule = await _aiService.generateWeeklySchedule(
        fitnessProfile: fitnessProfile,
        macroData: macroData,
      );

      setState(() {
        _weeklySchedule = schedule;
        _isLoading = false;
      });

      log('[AI Integration] Generated ${schedule.length} day schedule');
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to generate schedule: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _generateQuickWorkout(int minutes) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fitnessProfile = await _dataService.getCurrentFitnessProfile();

      final workout = await _aiService.generateQuickWorkout(
        fitnessProfile: fitnessProfile,
        availableMinutes: minutes,
        focusArea: 'full body', // or 'cardio', 'strength', etc.
      );

      setState(() {
        _currentWorkout = workout;
        _isLoading = false;
      });

      log('[AI Integration] Generated $minutes-minute quick workout');
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to generate quick workout: $e';
        _isLoading = false;
      });
    }
  }

  // =================== AI EXERCISE GUIDANCE ===================

  Future<void> _getExerciseAlternatives(String exerciseName) async {
    try {
      final fitnessProfile = await _dataService.getCurrentFitnessProfile();

      final alternatives = await _aiService.getExerciseAlternatives(
        exerciseName: exerciseName,
        fitnessProfile: fitnessProfile,
        reason: 'equipment', // or 'injury', 'difficulty'
      );

      // Show alternatives in a dialog or bottom sheet
      if (mounted) {
        _showExerciseAlternativesDialog(exerciseName, alternatives);
      }
    } catch (e) {
      log('[AI Integration] Error getting alternatives: $e');
    }
  }

  Future<void> _getExerciseGuidance(String exerciseName) async {
    try {
      final fitnessProfile = await _dataService.getCurrentFitnessProfile();

      final guidance = await _aiService.getExerciseGuidance(
        exerciseName: exerciseName,
        fitnessProfile: fitnessProfile,
      );

      if (mounted) {
        _showExerciseGuidanceDialog(guidance);
      }
    } catch (e) {
      log('[AI Integration] Error getting exercise guidance: $e');
    }
  }

  // =================== AI PROGRESS ANALYSIS ===================

  Future<void> _analyzeProgress() async {
    try {
      final fitnessProfile = await _dataService.getCurrentFitnessProfile();
      final workoutHistory =
          await _dataService.getWorkoutHistory(limitDays: 28);
      final performanceData =
          await _dataService.getPerformanceData(lastDays: 28);

      final analysis = await _aiService.analyzeProgressAndAdapt(
        fitnessProfile: fitnessProfile,
        workoutHistory: workoutHistory,
        performanceData: performanceData,
      );

      if (mounted) {
        _showProgressAnalysisDialog(analysis);
      }
    } catch (e) {
      log('[AI Integration] Error analyzing progress: $e');
    }
  }

  // =================== UI HELPERS ===================

  void _showExerciseAlternativesDialog(
      String originalExercise, List<Map<String, dynamic>> alternatives) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Alternatives to $originalExercise'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: alternatives.length,
            itemBuilder: (context, index) {
              final alt = alternatives[index];
              return Card(
                child: ListTile(
                  title: Text(alt['exercise_name'] ?? 'Unknown Exercise'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Difficulty: ${alt['difficulty_level'] ?? 'Unknown'}'),
                      Text(
                          'Equipment: ${alt['equipment_needed']?.join(', ') ?? 'None'}'),
                      Text('Why: ${alt['why_good_alternative'] ?? ''}'),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showExerciseGuidanceDialog(Map<String, dynamic> guidance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(guidance['exercise_name'] ?? 'Exercise Guidance'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGuidanceSection('Proper Form', guidance['proper_form']),
              _buildGuidanceSection(
                  'Safety Tips', guidance['safety_tips']?.join('\n')),
              _buildGuidanceSection(
                  'Common Mistakes', guidance['common_mistakes']?.join('\n')),
              _buildGuidanceSection(
                  'Sets & Reps', guidance['recommended_sets_reps']),
              _buildGuidanceSection('Breathing', guidance['breathing_pattern']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidanceSection(String title, String? content) {
    if (content == null || content.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(content),
        ],
      ),
    );
  }

  void _showProgressAnalysisDialog(Map<String, dynamic> analysis) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Progress Analysis'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Summary',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(analysis['progress_summary'] ?? 'No analysis available'),
              const SizedBox(height: 16),
              _buildAnalysisSection('Strengths', analysis['strengths']),
              _buildAnalysisSection(
                  'Areas for Improvement', analysis['areas_for_improvement']),
              _buildAnalysisSection(
                  'Motivation Tips', analysis['motivation_tips']),
              _buildAnalysisSection(
                  'Next Week Goals', analysis['next_week_goals']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisSection(String title, List<dynamic>? items) {
    if (items == null || items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 2),
                child: Text('• $item'),
              )),
        ],
      ),
    );
  }

  // =================== BUILD UI ===================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Fitness Integration'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),

            // Loading indicator
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),

            // Action buttons
            ElevatedButton(
              onPressed: _isLoading ? null : _generateTodaysWorkout,
              child: const Text('Generate Today\'s Workout'),
            ),
            const SizedBox(height: 8),

            ElevatedButton(
              onPressed: _isLoading ? null : _generateWeeklySchedule,
              child: const Text('Generate Weekly Schedule'),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _isLoading ? null : () => _generateQuickWorkout(15),
                    child: const Text('15-min Quick'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _isLoading ? null : () => _generateQuickWorkout(30),
                    child: const Text('30-min Quick'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ElevatedButton(
              onPressed: _isLoading ? null : _analyzeProgress,
              child: const Text('Analyze My Progress'),
            ),
            const SizedBox(height: 16),

            // Current workout display
            if (_currentWorkout != null) ...[
              const Text(
                'Current Workout',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildWorkoutCard(_currentWorkout!),
                ),
              ),
            ],

            // Weekly schedule display
            if (_weeklySchedule != null) ...[
              const Text(
                'Weekly Schedule',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _weeklySchedule!.length,
                  itemBuilder: (context, index) {
                    final day = _weeklySchedule![index];
                    return Card(
                      child: ListTile(
                        title: Text('${day['day']}: ${day['workout_type']}'),
                        subtitle: Text(
                          '${day['primary_focus']} • ${day['estimated_duration']}min',
                        ),
                        trailing: day['rest_day'] == true
                            ? const Icon(Icons.hotel)
                            : const Icon(Icons.fitness_center),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutCard(Map<String, dynamic> workout) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              workout['workout_name'] ?? 'Unnamed Workout',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Text('Duration: ${workout['estimated_duration']} minutes'),
            Text('Difficulty: ${workout['difficulty_level']}'),
            Text('Calories: ~${workout['calories_burned_estimate']}'),
            const SizedBox(height: 16),

            // Main exercises
            if (workout['main_exercises'] != null) ...[
              const Text(
                'Exercises',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...workout['main_exercises'].map<Widget>((exercise) {
                return Card(
                  color: Colors.grey.shade50,
                  child: ListTile(
                    title: Text(exercise['exercise'] ?? 'Unknown Exercise'),
                    subtitle: Text(
                      '${exercise['sets']} sets × ${exercise['reps']} reps\n'
                      'Rest: ${exercise['rest']}\n'
                      '${exercise['instructions'] ?? ''}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'alternatives':
                            _getExerciseAlternatives(exercise['exercise']);
                            break;
                          case 'guidance':
                            _getExerciseGuidance(exercise['exercise']);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'alternatives',
                          child: Text('Get Alternatives'),
                        ),
                        const PopupMenuItem(
                          value: 'guidance',
                          child: Text('Exercise Guidance'),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],

            // Notes
            if (workout['notes'] != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Notes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(workout['notes']),
            ],
          ],
        ),
      ),
    );
  }
}

// =================== INTEGRATION TIPS ===================

/// HOW TO INTEGRATE THIS INTO YOUR WORKOUT PLANNING SCREEN:
/// 
/// 1. Import the services:
///    ```dart
///    import '../services/fitness_ai_service.dart';
///    import '../services/fitness_data_service.dart';
///    ```
/// 
/// 2. Initialize in your screen:
///    ```dart
///    final FitnessAIService _aiService = FitnessAIService();
///    final FitnessDataService _dataService = FitnessDataService();
///    
///    @override
///    void initState() {
///      super.initState();
///      // _aiService.initialize(); // Removed as FitnessAIService initializes in its constructor
///    }
///    ```
/// 
/// 3. Add AI workout generation buttons:
///    ```dart
///    ElevatedButton(
///      onPressed: () async {
///        final profile = await _dataService.getCurrentFitnessProfile();
///        final macroData = await _dataService.getMacroData();
///        
///        final workout = await _aiService.generateWorkoutPlan(
///          fitnessProfile: profile,
///          macroData: macroData,
///        );
///        
///        // Use the workout data to update your UI
///        setState(() {
///          _currentWorkout = workout;
///        });
///      },
///      child: Text('Generate AI Workout'),
///    )
///    ```
/// 
/// 4. Handle exercise interactions:
///    ```dart
///    // In your exercise list item
///    PopupMenuButton<String>(
///      onSelected: (value) {
///        if (value == 'alternatives') {
///          _aiService.getExerciseAlternatives(
///            exerciseName: exerciseName,
///            fitnessProfile: profile,
///            reason: 'equipment', // or 'injury', 'difficulty'
///          ).then((alternatives) {
///            // Show alternatives in dialog
///          });
///        }
///      },
///      itemBuilder: (context) => [
///        PopupMenuItem(value: 'alternatives', child: Text('Get Alternatives')),
///        PopupMenuItem(value: 'guidance', child: Text('Exercise Help')),
///      ],
///    )
///    ```
/// 
/// 5. Track workout completions:
///    ```dart
///    // When user completes a workout
///    await _dataService.recordWorkoutCompletion(
///      workoutType: 'Full Body Strength',
///      actualDuration: 45,
///      completedAt: DateTime.now(),
///      additionalData: {
///        'generated_by_ai': true,
///        'difficulty_rating': 'moderate',
///        'user_rating': 4,
///      },
///    );
///    ```
/// 
/// 6. Error handling:
///    ```dart
///    try {
///      final workout = await _aiService.generateWorkoutPlan(...);
///      // Success - use workout
///    } catch (e) {
///      // Show error message or fallback to pre-defined workouts
///      ScaffoldMessenger.of(context).showSnackBar(
///        SnackBar(content: Text('AI unavailable, using fallback workout')),
///      );
///    }
///    ```
/// 
/// PERFORMANCE TIPS:
/// - Cache frequently requested data
/// - Show loading indicators for AI requests
/// - Provide fallback workouts when AI fails
/// - Validate user data before AI calls
/// - Use background processing for weekly schedule generation 