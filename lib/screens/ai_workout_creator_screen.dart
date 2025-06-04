import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/workout_plan.dart';
import '../models/exercise.dart';

import '../models/fitness_profile.dart';
import '../services/fitness_ai_service.dart';
import '../services/fitness_data_service.dart';
import 'dart:developer';

class AIWorkoutCreatorScreen extends StatefulWidget {
  final FitnessProfile fitnessProfile; // Added fitnessProfile parameter

  const AIWorkoutCreatorScreen(
      {super.key, required this.fitnessProfile}); // Updated constructor

  @override
  State<AIWorkoutCreatorScreen> createState() => _AIWorkoutCreatorScreenState();
}

class _AIWorkoutCreatorScreenState extends State<AIWorkoutCreatorScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Form state
  String _selectedMuscleGroup = 'Full Body';
  int _selectedDuration = 30;
  String _selectedIntensity = 'Moderate';
  bool _isGenerating = false;

  // Fitness profile data is now passed via widget.fitnessProfile
  Map<String, dynamic>? _macroData;
  bool _isLoadingMacroData = true; // For macro data loading

  final List<String> _muscleGroups = [
    'Full Body',
    'Chest',
    'Back',
    'Shoulders',
    'Arms',
    'Legs',
    'Core',
  ];

  final List<String> _intensities = ['Light', 'Moderate', 'High', 'Extreme'];

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _loadMacroData(); // Load only macro data now

    // Set initial form values based on profile if available
    if (widget.fitnessProfile.isBasicProfileComplete) {
      _selectedDuration = widget.fitnessProfile.optimalWorkoutDuration;
      // Set intensity based on fitness level
      switch (widget.fitnessProfile.fitnessLevel.toLowerCase()) {
        case 'beginner':
          _selectedIntensity = 'Light';
          break;
        case 'intermediate':
          _selectedIntensity = 'Moderate';
          break;
        case 'advanced':
          _selectedIntensity = 'High';
          break;
        default:
          _selectedIntensity = 'Moderate';
      }
    }
  }

  Future<void> _loadMacroData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingMacroData = true;
    });
    try {
      _macroData = await FitnessDataService().getMacroData();
      log('[AIWorkoutCreator] Loaded macro data: $_macroData');
    } catch (e) {
      log('[AIWorkoutCreator] Error loading macro data: $e');
      if (mounted) {
        _showError('Could not load necessary data. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMacroData = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? PremiumColors.darkBackground : Colors.white,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(isDark),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(isDark),
                    const SizedBox(height: 32),
                    _buildMuscleGroupSelector(isDark),
                    const SizedBox(height: 24),
                    _buildDurationSelector(isDark),
                    const SizedBox(height: 24),
                    _buildIntensitySelector(isDark),
                    const SizedBox(height: 32),
                    _buildGenerateButton(isDark),
                    const SizedBox(height: 24),
                    _buildAIFeatures(isDark),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: isDark ? PremiumColors.darkBackground : Colors.white,
      foregroundColor: isDark ? Colors.white : Colors.black,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.sparkles,
              color: isDark ? Colors.white : Colors.black,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'AI Workout Creator',
              style: PremiumTypography.h1.copyWith(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 24,
              ),
            ),
          ],
        ),
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
      ),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: Icon(
            CupertinoIcons.back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create Your Perfect Workout',
          style: PremiumTypography.h2.copyWith(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Our AI will generate a personalized workout plan based on your preferences.',
          style: PremiumTypography.bodyLarge.copyWith(
            color: isDark
                ? PremiumColors.darkTextSecondary
                : PremiumColors.slate600,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildMuscleGroupSelector(bool isDark) {
    return _buildSection(
      'Target Muscle Group',
      'Select the primary focus area for your workout',
      isDark,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: _muscleGroups.map((group) {
          final isSelected = _selectedMuscleGroup == group;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedMuscleGroup = group;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.1)),
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? null
                    : Border.all(
                        color: isDark
                            ? PremiumColors.darkBorder
                            : PremiumColors.slate200,
                      ),
              ),
              child: Text(
                group,
                style: PremiumTypography.button.copyWith(
                  color: isSelected
                      ? (isDark ? Colors.black : Colors.white)
                      : (isDark ? Colors.white : Colors.black),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDurationSelector(bool isDark) {
    return _buildSection(
      'Workout Duration',
      'How much time do you have available?',
      isDark,
      child: Row(
        children: [
          Expanded(
            child: Slider(
              value: _selectedDuration.toDouble(),
              min: 15,
              max: 90,
              divisions:
                  5, // (90-15)/15 = 5 divisions for 15, 30, 45, 60, 75, 90
              activeColor: isDark ? Colors.white : Colors.black,
              inactiveColor: isDark
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.3),
              thumbColor: isDark ? Colors.white : Colors.black,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedDuration = value.round();
                });
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white : Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$_selectedDuration min',
              style: PremiumTypography.button.copyWith(
                color: isDark ? Colors.black : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntensitySelector(bool isDark) {
    return _buildSection(
      'Workout Intensity',
      'Choose your desired intensity level',
      isDark,
      child: Row(
        children: _intensities.map((intensity) {
          final isSelected = _selectedIntensity == intensity;
          final index = _intensities.indexOf(intensity);

          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedIntensity = intensity;
                });
              },
              child: Container(
                margin: EdgeInsets.only(
                  right: index < _intensities.length - 1 ? 8 : 0,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? null
                      : Border.all(
                          color: isDark
                              ? PremiumColors.darkBorder
                              : PremiumColors.slate200,
                        ),
                ),
                child: Text(
                  intensity,
                  textAlign: TextAlign.center,
                  style: PremiumTypography.button.copyWith(
                    color: isSelected
                        ? (isDark ? Colors.black : Colors.white)
                        : (isDark ? Colors.white : Colors.black),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGenerateButton(bool isDark) {
    return Container(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed:
            _isGenerating || _isLoadingMacroData ? null : _generateAIWorkout,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.white : Colors.black,
          foregroundColor: isDark ? Colors.black : Colors.white,
          disabledBackgroundColor: isDark
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.3),
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isGenerating
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Generating AI Workout...',
                    style: PremiumTypography.button.copyWith(
                      color: isDark ? Colors.black : Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.sparkles,
                    color: isDark ? Colors.black : Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Generate AI Workout',
                    style: PremiumTypography.button.copyWith(
                      color: isDark ? Colors.black : Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAIFeatures(bool isDark) {
    // Use widget.fitnessProfile directly
    final fitnessProfile = widget.fitnessProfile;

    if (_isLoadingMacroData) {
      // Check for macro data loading
      return Container(
        height: 120,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
      );
    }

    final hasUserData = fitnessProfile.isBasicProfileComplete;

    final features = hasUserData
        ? [
            {
              'icon': CupertinoIcons.person_crop_circle_fill,
              'title': 'Personalized for You',
              'description':
                  'Based on your ${fitnessProfile.fitnessLevel} fitness level and equipment',
            },
            {
              'icon': CupertinoIcons.location_solid,
              'title': 'Location Optimized',
              'description':
                  'Perfect for ${fitnessProfile.workoutLocation} workouts',
            },
            {
              'icon': CupertinoIcons.time,
              'title': 'Schedule Smart',
              'description':
                  'Matches your ${fitnessProfile.optimalWorkoutDuration}-minute sessions',
            },
          ]
        : [
            {
              'icon': CupertinoIcons.lightbulb,
              'title': 'Smart Exercise Selection',
              'description': 'AI selects exercises based on your preferences',
            },
            {
              'icon': CupertinoIcons.chart_bar_alt_fill,
              'title': 'Personalized Intensity',
              'description': 'Workouts adapt to your chosen intensity level',
            },
            {
              'icon': CupertinoIcons.time,
              'title': 'Time Optimized',
              'description': 'Perfect workout for your available time',
            },
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Features',
          style: PremiumTypography.h3.copyWith(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        ...features.map((feature) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? PremiumColors.darkBorder
                      : PremiumColors.slate200,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      feature['icon'] as IconData,
                      color: isDark ? Colors.white : Colors.black,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature['title'] as String,
                          style: PremiumTypography.bodyLarge.copyWith(
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          feature['description'] as String,
                          style: PremiumTypography.bodySmall.copyWith(
                            color: isDark
                                ? PremiumColors.darkTextSecondary
                                : PremiumColors.slate600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildSection(String title, String description, bool isDark,
      {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: PremiumTypography.h3.copyWith(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: PremiumTypography.bodyMedium.copyWith(
            color: isDark
                ? PremiumColors.darkTextSecondary
                : PremiumColors.slate600,
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Future<void> _generateAIWorkout() async {
    if (!mounted) return;
    setState(() {
      _isGenerating = true;
    });

    HapticFeedback.mediumImpact();

    try {
      WorkoutRoutine routine;

      // Use AI service if user data is available and macro data is loaded
      if (widget.fitnessProfile.isBasicProfileComplete && _macroData != null) {
        log('[AIWorkoutCreator] Generating AI workout with user profile: ${widget.fitnessProfile.fitnessLevel}');
        routine = await _generateIntelligentWorkout();
      } else {
        if (_macroData == null) {
          log('[AIWorkoutCreator] Macro data not loaded. Using fallback workout generation.');
        } else if (!widget.fitnessProfile.isBasicProfileComplete) {
          log('[AIWorkoutCreator] Fitness profile is not complete. Using fallback workout generation. Reason:');
          if (widget.fitnessProfile.fitnessLevel.isEmpty) {
            log('[AIWorkoutCreator] - Fitness level is empty.');
          }
          if (widget.fitnessProfile.workoutLocation.isEmpty) {
            log('[AIWorkoutCreator] - Workout location is empty.');
          }
          if (widget.fitnessProfile.workoutSpace.isEmpty) {
            log('[AIWorkoutCreator] - Workout space is empty.');
          }
          if (widget.fitnessProfile.workoutsPerWeek <= 0) {
            log('[AIWorkoutCreator] - Workouts per week is not positive.');
          }
          if (widget.fitnessProfile.maxWorkoutDuration <= 0) {
            log('[AIWorkoutCreator] - Max workout duration is not positive.');
          }
        }
        routine = _createSampleAIWorkout();
      }

      // Show success and navigate back
      HapticFeedback.lightImpact();

      if (mounted) {
        Navigator.pop(context, routine);
      }
    } catch (e) {
      log('[AIWorkoutCreator] Error generating workout: $e');
      // Fallback to sample workout on error
      try {
        final routine = _createSampleAIWorkout();
        if (mounted) {
          Navigator.pop(context, routine);
        }
      } catch (fallbackError) {
        if (mounted) {
          _showError('Failed to generate workout: ${fallbackError.toString()}');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<WorkoutRoutine> _generateIntelligentWorkout() async {
    final aiService = FitnessAIService();

    // Initialize AI service
    aiService.initialize();

    log('[AIWorkoutCreator] Generating enhanced workout: '
        'muscle=$_selectedMuscleGroup, duration=$_selectedDuration, '
        'intensity=$_selectedIntensity, level=${widget.fitnessProfile.fitnessLevel}');

    // Generate workout using AI service with user preferences
    final workoutData = await aiService.generateEnhancedWorkoutPlan(
      fitnessProfile: widget.fitnessProfile, // Use widget.fitnessProfile
      macroData: _macroData!,
      specificMuscleGroup:
          _selectedMuscleGroup == 'Full Body' ? null : _selectedMuscleGroup,
      customDuration: _selectedDuration,
    );

    log('[AIWorkoutCreator] AI service returned workout: ${workoutData['workout_name']}');

    // Convert AI service output to WorkoutRoutine
    return _convertAIWorkoutToRoutine(workoutData);
  }

  WorkoutRoutine _convertAIWorkoutToRoutine(Map<String, dynamic> workoutData) {
    final exercises = <WorkoutExercise>[];

    // Process main exercises from AI service
    if (workoutData['main_exercises'] != null) {
      final mainExercises = workoutData['main_exercises'] as List;

      for (int i = 0; i < mainExercises.length; i++) {
        final exerciseData = mainExercises[i];

        final exercise = Exercise(
          id: 'ai_exercise_$i',
          name: exerciseData['exercise'] ?? 'Exercise ${i + 1}',
          description: exerciseData['instructions'] ?? 'AI-generated exercise',
          primaryMuscles: List<String>.from(
              exerciseData['muscle_groups'] ?? [_selectedMuscleGroup]),
          type: 'strength',
          difficulty: widget.fitnessProfile.recommendedDifficulty ??
              'moderate', // Use widget.fitnessProfile
          instructions: [exerciseData['instructions'] ?? 'Follow proper form'],
          equipment: List<String>.from(exerciseData['equipment_needed'] ?? []),
          isCompound: () {
            final muscleGroups = exerciseData['muscle_groups'] as List?;
            return muscleGroups != null && muscleGroups.length > 1;
          }(),
        );

        final sets = <WorkoutSet>[];
        final numSets = exerciseData['sets'] ?? _getDefaultSets();
        final repsString = exerciseData['reps']?.toString() ?? '10-12';
        final reps = _parseReps(repsString);

        for (int j = 0; j < numSets; j++) {
          sets.add(WorkoutSet(
            reps: reps,
            durationSeconds: null,
          ));
        }

        final restParts = (exerciseData['rest'] ?? '60 seconds').split(' ');
        final restSeconds = int.tryParse(restParts[0]) ?? 60;

        exercises.add(WorkoutExercise(
          exerciseId: exercise.id,
          exercise: exercise,
          sets: sets,
          restSeconds: restSeconds,
        ));
      }
    }

    // Fallback if no exercises generated
    if (exercises.isEmpty) {
      return _createSampleAIWorkout();
    }

    return WorkoutRoutine(
      name: workoutData['workout_name'] ??
          'AI $_selectedIntensity $_selectedMuscleGroup Workout',
      description: _buildIntelligentDescription(),
      estimatedDurationMinutes:
          workoutData['estimated_duration'] ?? _selectedDuration,
      difficulty: workoutData['difficulty_level'] ?? _selectedIntensity,
      targetMuscles: List<String>.from(
          workoutData['muscle_groups_targeted'] ?? [_selectedMuscleGroup]),
      requiredEquipment: _getRequiredEquipment(exercises),
      exercises: exercises,
      isCustom: true,
    );
  }

  String _buildIntelligentDescription() {
    final profile = widget.fitnessProfile; // Use widget.fitnessProfile
    final equipmentText = profile.availableEquipment.isNotEmpty
        ? ' using ${profile.availableEquipment.take(2).join(', ')}'
        : ' with bodyweight exercises';

    return 'AI-generated $_selectedIntensity intensity workout for $_selectedMuscleGroup$equipmentText. '
        'Personalized for ${profile.fitnessLevel} level, optimized for ${profile.workoutLocation} training.';
  }

  List<String> _getRequiredEquipment(List<WorkoutExercise> exercises) {
    final equipment = <String>{};
    for (final workoutExercise in exercises) {
      if (workoutExercise.exercise != null) {
        equipment.addAll(workoutExercise.exercise!.equipment);
      }
    }
    return equipment.toList();
  }

  int _getDefaultSets() {
    switch (_selectedIntensity) {
      case 'Light':
        return 2;
      case 'Moderate':
        return 3;
      case 'High':
      case 'Extreme':
        return 4;
      default:
        return 3;
    }
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

  WorkoutRoutine _createSampleAIWorkout() {
    final exercises = <WorkoutExercise>[];
    final workoutName = 'AI $_selectedIntensity $_selectedMuscleGroup Workout';

    // Sample exercises based on muscle group
    final sampleExercises =
        _getSampleExercisesForMuscleGroup(_selectedMuscleGroup);

    for (int i = 0; i < sampleExercises.length; i++) {
      final exerciseData = sampleExercises[i];

      final exercise = Exercise(
        id: 'ai_exercise_$i',
        name: exerciseData['name'],
        description: exerciseData['description'],
        primaryMuscles: [_selectedMuscleGroup],
        type: 'strength',
        difficulty: 'beginner', // Sample workouts can have a default
        instructions: [exerciseData['instructions']],
        equipment: List<String>.from(exerciseData['equipment'] ?? []),
        isCompound: false,
      );

      final sets = <WorkoutSet>[];
      final numSets = _selectedIntensity == 'Light'
          ? 2
          : _selectedIntensity == 'Moderate'
              ? 3
              : 4;

      for (int j = 0; j < numSets; j++) {
        sets.add(WorkoutSet(
          reps: exerciseData['reps'] ?? 12,
          durationSeconds: exerciseData['duration'],
        ));
      }

      exercises.add(WorkoutExercise(
        exerciseId: exercise.id,
        exercise: exercise,
        sets: sets,
        restSeconds: _selectedIntensity == 'Light'
            ? 45
            : _selectedIntensity == 'Moderate'
                ? 60
                : 75,
      ));
    }

    return WorkoutRoutine(
      name: workoutName,
      description:
          'AI-generated $_selectedIntensity intensity workout focusing on $_selectedMuscleGroup. Perfect for $_selectedDuration minutes of training.',
      estimatedDurationMinutes: _selectedDuration,
      difficulty:
          _selectedIntensity, // Sample workout difficulty matches selected intensity
      targetMuscles: [_selectedMuscleGroup],
      requiredEquipment: [], // Simplified for sample
      exercises: exercises,
      isCustom: true,
    );
  }

  List<Map<String, dynamic>> _getSampleExercisesForMuscleGroup(
      String muscleGroup) {
    switch (muscleGroup.toLowerCase()) {
      case 'chest':
        return [
          {
            'name': 'Push-ups',
            'description': 'Classic bodyweight chest exercise',
            'instructions': 'Lower chest to ground, push back up',
            'equipment': [],
            'reps': 12
          },
          {
            'name': 'Chest Press',
            'description': 'Dumbbell chest press',
            'instructions': 'Press dumbbells up from chest',
            'equipment': ['Dumbbells'],
            'reps': 10
          },
          {
            'name': 'Chest Fly',
            'description': 'Chest fly exercise',
            'instructions': 'Open arms wide, bring together',
            'equipment': ['Dumbbells'],
            'reps': 12
          },
        ];
      case 'back':
        return [
          {
            'name': 'Pull-ups',
            'description': 'Bodyweight back exercise',
            'instructions': 'Pull body up to bar',
            'equipment': ['Pull-up bar'],
            'reps': 8
          },
          {
            'name': 'Bent-over Rows',
            'description': 'Dumbbell row exercise',
            'instructions': 'Row dumbbells to torso',
            'equipment': ['Dumbbells'],
            'reps': 12
          },
          {
            'name': 'Superman',
            'description': 'Bodyweight back exercise',
            'instructions': 'Lift chest and legs off ground',
            'equipment': [],
            'reps': 15
          },
        ];
      case 'legs':
        return [
          {
            'name': 'Squats',
            'description': 'Bodyweight leg exercise',
            'instructions': 'Lower hips back and down',
            'equipment': [],
            'reps': 15
          },
          {
            'name': 'Lunges',
            'description': 'Single leg exercise',
            'instructions': 'Step forward and lower',
            'equipment': [],
            'reps': 12
          },
          {
            'name': 'Calf Raises',
            'description': 'Calf strengthening',
            'instructions': 'Rise up on toes',
            'equipment': [],
            'reps': 20
          },
        ];
      case 'core':
        return [
          {
            'name': 'Plank',
            'description': 'Core stability exercise',
            'instructions': 'Hold straight body position',
            'equipment': [],
            'duration': 30
          },
          {
            'name': 'Crunches',
            'description': 'Abdominal exercise',
            'instructions': 'Lift shoulders off ground',
            'equipment': [],
            'reps': 20
          },
          {
            'name': 'Russian Twists',
            'description': 'Oblique exercise',
            'instructions': 'Rotate torso side to side',
            'equipment': [],
            'reps': 30
          },
        ];
      case 'shoulders':
        return [
          {
            'name': 'Shoulder Press',
            'description': 'Overhead pressing',
            'instructions': 'Press dumbbells overhead',
            'equipment': ['Dumbbells'],
            'reps': 12
          },
          {
            'name': 'Lateral Raises',
            'description': 'Side shoulder exercise',
            'instructions': 'Lift arms to sides',
            'equipment': ['Dumbbells'],
            'reps': 15
          },
          {
            'name': 'Pike Push-ups',
            'description': 'Bodyweight shoulder exercise',
            'instructions': 'Push up in downward dog position',
            'equipment': [],
            'reps': 10
          },
        ];
      case 'arms':
        return [
          {
            'name': 'Bicep Curls',
            'description': 'Bicep strengthening',
            'instructions': 'Curl dumbbells to shoulders',
            'equipment': ['Dumbbells'],
            'reps': 12
          },
          {
            'name': 'Tricep Dips',
            'description': 'Tricep exercise',
            'instructions': 'Lower and raise body using arms',
            'equipment': ['Bench'],
            'reps': 10
          },
          {
            'name': 'Diamond Push-ups',
            'description': 'Tricep-focused push-ups',
            'instructions': 'Push-ups with hands in diamond shape',
            'equipment': [],
            'reps': 8
          },
        ];
      default: // Full Body
        return [
          {
            'name': 'Burpees',
            'description': 'Full body exercise',
            'instructions': 'Squat, jump back, push-up, jump forward, jump up',
            'equipment': [],
            'reps': 10
          },
          {
            'name': 'Mountain Climbers',
            'description': 'Cardio and core exercise',
            'instructions': 'Alternate bringing knees to chest',
            'equipment': [],
            'reps': 20
          },
          {
            'name': 'Jumping Jacks',
            'description': 'Cardio exercise',
            'instructions': 'Jump feet apart while raising arms',
            'equipment': [],
            'reps': 25
          },
          {
            'name': 'High Knees',
            'description': 'Cardio exercise',
            'instructions': 'Run in place with high knees',
            'equipment': [],
            'duration': 30
          },
        ];
    }
  }

  void _showError(String message) {
    HapticFeedback.lightImpact();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
