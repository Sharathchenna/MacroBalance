import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../models/workout_plan.dart';
import '../models/exercise.dart';
import '../services/workout_planning_service.dart';
import '../services/fitness_ai_service.dart';
import '../services/fitness_data_service.dart';
import '../services/storage_service.dart';
import '../models/user_preferences.dart';
import '../theme/app_theme.dart';
import '../theme/workout_colors.dart';
import 'package:uuid/uuid.dart';
import 'workout_execution_screen.dart';
import 'onboarding/onboarding_screen.dart';

class WorkoutPlanningScreen extends StatefulWidget {
  const WorkoutPlanningScreen({Key? key}) : super(key: key);

  @override
  State<WorkoutPlanningScreen> createState() => _WorkoutPlanningScreenState();
}

class _WorkoutPlanningScreenState extends State<WorkoutPlanningScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final WorkoutPlanningService _workoutService = WorkoutPlanningService();
  final FitnessAIService _aiService = FitnessAIService();
  final FitnessDataService _dataService = FitnessDataService();
  final StorageService _storageService = StorageService();
  final Uuid _uuid = const Uuid();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<WorkoutRoutine> _routines = [];
  List<WorkoutRoutine> _filteredRoutines = [];
  bool _isLoading = false;
  bool _aiAvailable = false;
  String? _error;
  String _selectedFilter = 'All';
  bool _isSearchFocused = false;

  // Animation controllers
  late AnimationController _mainAnimationController;
  late AnimationController _fabAnimationController;
  late AnimationController _searchAnimationController;
  late AnimationController _statsAnimationController;

  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fabScaleAnimation;
  late Animation<double> _searchBorderAnimation;
  late Animation<double> _statsSlideAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _setupListeners();
    _initializeAI();
    _loadWorkoutRoutines();
    _startInitialAnimations();
  }

  void _initializeAnimations() {
    _mainAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300), // Faster
      vsync: this,
    );

    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400), // Faster
      vsync: this,
    );

    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200), // Faster
      vsync: this,
    );

    _statsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300), // Faster
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainAnimationController,
        curve: Curves.easeOut, // Simpler curve
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1), // Less movement
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainAnimationController,
      curve: Curves.easeOut, // Simpler curve
    ));

    _fabScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: Curves.easeOut, // Simpler curve
      ),
    );

    _searchBorderAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      // Less dramatic
      CurvedAnimation(
        parent: _searchAnimationController,
        curve: Curves.easeOut,
      ),
    );

    _statsSlideAnimation = Tween<double>(begin: -0.5, end: 0.0).animate(
      // Less movement
      CurvedAnimation(
        parent: _statsAnimationController,
        curve: Curves.easeOut, // Simpler curve
      ),
    );
  }

  void _setupListeners() {
    _searchController.addListener(() {
      _filterRoutines();
      setState(() {});
    });
  }

  void _startInitialAnimations() {
    _mainAnimationController.forward();

    Future.delayed(const Duration(milliseconds: 100), () {
      // Faster
      if (mounted) {
        _statsAnimationController.forward();
      }
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      // Faster
      if (mounted) {
        _fabAnimationController.forward();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mainAnimationController.dispose();
    _fabAnimationController.dispose();
    _searchAnimationController.dispose();
    _statsAnimationController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _filterRoutines() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty && _selectedFilter == 'All') {
        _filteredRoutines = _routines;
      } else {
        _filteredRoutines = _routines.where((routine) {
          final matchesSearch = query.isEmpty ||
              routine.name.toLowerCase().contains(query) ||
              routine.description.toLowerCase().contains(query) ||
              routine.targetMuscles
                  .any((muscle) => muscle.toLowerCase().contains(query));

          final matchesFilter = _selectedFilter == 'All' ||
              _getWorkoutCategory(routine) == _selectedFilter;

          return matchesSearch && matchesFilter;
        }).toList();
      }
    });
  }

  String _getWorkoutCategory(WorkoutRoutine routine) {
    final name = routine.name.toLowerCase();
    if (name.contains('cardio') || name.contains('running')) return 'Cardio';
    if (name.contains('strength') || name.contains('weight')) return 'Strength';
    if (name.contains('yoga') || name.contains('flexibility'))
      return 'Flexibility';
    if (name.contains('hiit') || name.contains('interval')) return 'HIIT';
    return 'Strength'; // Default
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
        _filteredRoutines = routines;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load workout routines: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewWorkoutRoutine() async {
    HapticFeedback.mediumImpact();
    final result = await _showCreateWorkoutDialog();

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
            _filteredRoutines = [..._filteredRoutines, createdRoutine];
          });
          _showEnhancedSnackBar('Workout created successfully! 🎉', true);
        }
      } catch (e) {
        _showEnhancedSnackBar('Failed to create workout', false);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateWorkoutRoutine() async {
    HapticFeedback.heavyImpact();
    setState(() => _isLoading = true);

    try {
      if (_aiAvailable) {
        // Use AI generation
        await _generateAIWorkout();
      } else {
        // Fallback to basic generation
        await _generateBasicWorkout();
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateAIWorkout({
    String? specificMuscleGroup,
    int? customDuration,
  }) async {
    try {
      final fitnessProfile = await _dataService.getCurrentFitnessProfile();
      final macroData = await _dataService.getMacroData();

      final aiWorkout = await _aiService.generateWorkoutPlan(
        fitnessProfile: fitnessProfile,
        macroData: macroData,
        specificMuscleGroup: specificMuscleGroup,
        customDuration: customDuration,
      );

      // Convert AI workout to WorkoutRoutine
      final routine = _convertAIWorkoutToRoutine(aiWorkout);

      if (routine != null) {
        setState(() {
          _routines = [..._routines, routine];
          _filteredRoutines = [..._filteredRoutines, routine];
        });
        _showEnhancedSnackBar('AI workout generated successfully! 🤖✨', true);
      }
    } catch (e) {
      _showEnhancedSnackBar(
          'AI generation failed, using fallback workout', false);
      await _generateBasicWorkout();
    }
  }

  Future<void> _generateQuickAIWorkout(int minutes) async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      if (_aiAvailable) {
        final fitnessProfile = await _dataService.getCurrentFitnessProfile();

        final aiWorkout = await _aiService.generateQuickWorkout(
          fitnessProfile: fitnessProfile,
          availableMinutes: minutes,
          focusArea: 'full body',
        );

        final routine = _convertAIWorkoutToRoutine(aiWorkout, isQuick: true);

        if (routine != null) {
          setState(() {
            _routines = [..._routines, routine];
            _filteredRoutines = [..._filteredRoutines, routine];
          });
          _showEnhancedSnackBar('${minutes}-minute AI workout ready! ⚡', true);
        }
      } else {
        _showEnhancedSnackBar(
            'AI unavailable - complete fitness profile first', false);
      }
    } catch (e) {
      _showEnhancedSnackBar('Quick workout generation failed', false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateWeeklySchedule() async {
    HapticFeedback.heavyImpact();
    setState(() => _isLoading = true);

    try {
      if (_aiAvailable) {
        final fitnessProfile = await _dataService.getCurrentFitnessProfile();
        final macroData = await _dataService.getMacroData();

        final schedule = await _aiService.generateWeeklySchedule(
          fitnessProfile: fitnessProfile,
          macroData: macroData,
        );

        // Show weekly schedule dialog
        _showWeeklyScheduleDialog(schedule);
        _showEnhancedSnackBar('Weekly schedule generated! 📅', true);
      } else {
        _showEnhancedSnackBar('AI unavailable for weekly scheduling', false);
      }
    } catch (e) {
      _showEnhancedSnackBar('Weekly schedule generation failed', false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateBasicWorkout() async {
    // Original fallback method
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
      name: 'Basic Workout ${DateTime.now().toString().substring(0, 10)}',
      description: 'Template-based workout routine',
      targetMuscles: ['chest', 'back', 'legs'],
      durationMinutes: 45,
    );

    if (routine != null) {
      setState(() {
        _routines = [..._routines, routine];
        _filteredRoutines = [..._filteredRoutines, routine];
      });
      _showEnhancedSnackBar('Basic workout generated successfully! 💪', true);
    }
  }

  WorkoutRoutine? _convertAIWorkoutToRoutine(Map<String, dynamic> aiWorkout,
      {bool isQuick = false}) {
    try {
      // Convert AI workout format to WorkoutRoutine
      final exercises = <WorkoutExercise>[];

      // Add warm-up exercises
      if (aiWorkout['warm_up'] != null) {
        for (final warmUp in aiWorkout['warm_up']) {
          final exercise = Exercise(
            name: warmUp['exercise'] ?? 'Warm-up',
            description: warmUp['instructions'] ?? 'Warm-up exercise',
            primaryMuscles: ['warm-up'],
            equipment: ['bodyweight'],
            type: 'cardio',
            difficulty: 'beginner',
            instructions: [
              warmUp['instructions'] ?? 'Perform warm-up movement'
            ],
            isCompound: false,
            defaultDurationSeconds:
                _parseDurationFromString(warmUp['duration']),
          );

          exercises.add(WorkoutExercise(
            exerciseId: exercise.id,
            exercise: exercise,
            sets: [
              WorkoutSet(
                  reps: 1, durationSeconds: exercise.defaultDurationSeconds)
            ],
            restSeconds: 30,
          ));
        }
      }

      // Add main exercises
      if (aiWorkout['main_exercises'] != null) {
        for (final exerciseData in aiWorkout['main_exercises']) {
          final exercise = Exercise(
            name: exerciseData['exercise'] ?? 'Unknown Exercise',
            description: exerciseData['instructions'] ?? 'Exercise description',
            primaryMuscles:
                List<String>.from(exerciseData['muscle_groups'] ?? ['general']),
            equipment: List<String>.from(
                exerciseData['equipment_needed'] ?? ['bodyweight']),
            type: 'strength',
            difficulty: 'intermediate',
            instructions: [
              exerciseData['instructions'] ??
                  'Perform exercise with proper form'
            ],
            isCompound: true,
            defaultSets: exerciseData['sets'] ?? 3,
            defaultReps: _parseRepsFromString(exerciseData['reps']),
          );

          final sets = <WorkoutSet>[];
          final numSets = exerciseData['sets'] ?? 3;
          final reps = _parseRepsFromString(exerciseData['reps']);

          for (int i = 0; i < numSets; i++) {
            sets.add(WorkoutSet(reps: reps));
          }

          exercises.add(WorkoutExercise(
            exerciseId: exercise.id,
            exercise: exercise,
            sets: sets,
            restSeconds: _parseRestPeriod(exerciseData['rest']),
          ));
        }
      }

      // Add cool-down exercises
      if (aiWorkout['cool_down'] != null) {
        for (final coolDown in aiWorkout['cool_down']) {
          final exercise = Exercise(
            name: coolDown['exercise'] ?? 'Cool-down',
            description: coolDown['instructions'] ?? 'Cool-down stretch',
            primaryMuscles: ['flexibility'],
            equipment: ['bodyweight'],
            type: 'flexibility',
            difficulty: 'beginner',
            instructions: [
              coolDown['instructions'] ?? 'Hold stretch and breathe deeply'
            ],
            isCompound: false,
            defaultDurationSeconds:
                _parseDurationFromString(coolDown['duration']),
          );

          exercises.add(WorkoutExercise(
            exerciseId: exercise.id,
            exercise: exercise,
            sets: [
              WorkoutSet(
                  reps: 1, durationSeconds: exercise.defaultDurationSeconds)
            ],
            restSeconds: 15,
          ));
        }
      }

      return WorkoutRoutine(
        name:
            aiWorkout['workout_name'] ?? '${isQuick ? 'Quick ' : ''}AI Workout',
        description: aiWorkout['notes'] ?? 'AI-generated personalized workout',
        exercises: exercises,
        estimatedDurationMinutes: aiWorkout['estimated_duration'] ?? 45,
        difficulty: aiWorkout['difficulty_level'] ?? 'intermediate',
        targetMuscles:
            List<String>.from(aiWorkout['muscle_groups_targeted'] ?? []),
        requiredEquipment: _extractRequiredEquipment(exercises),
        isCustom: false, // Mark as AI-generated
      );
    } catch (e) {
      print('[AI Conversion] Error converting AI workout: $e');
      return null;
    }
  }

  int _parseRepsFromString(String? repsString) {
    if (repsString == null) return 10;
    final match = RegExp(r'(\d+)').firstMatch(repsString);
    return match != null ? int.parse(match.group(1)!) : 10;
  }

  int _parseDurationFromString(String? durationString) {
    if (durationString == null) return 30;
    final match = RegExp(r'(\d+)').firstMatch(durationString);
    return match != null
        ? int.parse(match.group(1)!) * 60
        : 30; // Convert minutes to seconds
  }

  int _parseRestPeriod(String? restString) {
    if (restString == null) return 60;
    final match = RegExp(r'(\d+)').firstMatch(restString);
    return match != null ? int.parse(match.group(1)!) : 60;
  }

  List<String> _extractRequiredEquipment(List<WorkoutExercise> exercises) {
    final equipment = <String>{};
    for (final workoutExercise in exercises) {
      if (workoutExercise.exercise != null) {
        equipment.addAll(workoutExercise.exercise!.equipment);
      }
    }
    return equipment.toList();
  }

  Future<void> _startWorkout(WorkoutRoutine routine) async {
    HapticFeedback.lightImpact();

    try {
      final result = await Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              WorkoutExecutionScreen(routine: routine),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOutCubic,
              )),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );

      if (result == true && mounted) {
        _showEnhancedSnackBar('Workout completed successfully! 💪', true);
      }
    } catch (e) {
      if (mounted) {
        _showEnhancedSnackBar('Failed to start workout', false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumColors.slate50,
      body: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          await _loadWorkoutRoutines();
        },
        color: PremiumColors.vibrantOrange,
        backgroundColor: Colors.white,
        strokeWidth: 3.0,
        displacement: 80.0,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            _buildEnhancedAppBar(),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildBody(),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildEnhancedFloatingActionButtons(),
    );
  }

  Widget _buildEnhancedAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E293B),
                Color(0xFF334155),
                Color(0xFF475569),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Workouts',
                              style: PremiumTypography.h1.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Transform your body, elevate your mind',
                              style: PremiumTypography.subtitle.copyWith(
                                color: Colors.white.withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildAppBarActions(),
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

  Widget _buildAppBarActions() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.lightImpact();
            _loadWorkoutRoutines();
          },
          child: const Icon(
            Icons.refresh_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildEnhancedLoadingState();
    }

    if (_error != null) {
      return _buildEnhancedErrorState();
    }

    if (_routines.isEmpty) {
      return _buildEnhancedEmptyState();
    }

    return Column(
      children: [
        _buildAIStatusBanner(),
        _buildStatsOverview(),
        _buildEnhancedSearchBar(),
        _buildFilterChips(),
        _buildWorkoutsList(),
      ],
    );
  }

  Widget _buildAIStatusBanner() {
    if (_aiAvailable) {
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              PremiumColors.vibrantOrange.withOpacity(0.1),
              PremiumColors.energeticBlue.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: PremiumColors.vibrantOrange.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    PremiumColors.vibrantOrange,
                    PremiumColors.energeticBlue
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Workouts Available',
                    style: PremiumTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: PremiumColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Get personalized workouts powered by Gemini AI',
                    style: PremiumTypography.bodyMedium.copyWith(
                      color: PremiumColors.slate600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: PremiumColors.successGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'ACTIVE',
                style: PremiumTypography.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        decoration: BoxDecoration(
          color: PremiumColors.pastelYellow.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: PremiumColors.pastelYellow.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: PremiumColors.pastelYellow,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Complete Fitness Profile',
                        style: PremiumTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: PremiumColors.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Complete onboarding to unlock AI-powered workouts',
                        style: PremiumTypography.bodyMedium.copyWith(
                          color: PremiumColors.slate600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      // Navigate to fitness profile setup
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const OnboardingScreen(),
                        ),
                      );

                      // Always refresh AI availability when user returns
                      if (mounted) {
                        print(
                            '[Navigation] Returned from onboarding, refreshing AI availability...');
                        await _ensureDataCompatibility();
                        await _checkAIAvailability();
                        if (_aiAvailable) {
                          _showEnhancedSnackBar(
                              'Fitness profile completed! AI features are now available 🤖',
                              true);
                        } else {
                          print(
                              '[Navigation] AI still not available after onboarding');
                          // Force refresh the data after a short delay
                          await Future.delayed(
                              const Duration(milliseconds: 1000));
                          await _ensureDataCompatibility();
                          await _checkAIAvailability();
                          if (_aiAvailable) {
                            _showEnhancedSnackBar(
                                'AI features are now ready! 🤖✨', true);
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PremiumColors.pastelYellow,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Complete Profile',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      await _fixMissingFields();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PremiumColors.successGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Quick Fix',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  Widget _buildStatsOverview() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(_statsSlideAnimation.value, 0),
        end: Offset.zero,
      ).animate(_statsAnimationController),
      child: Container(
        height: 120,
        margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total',
                '${_routines.length}',
                Icons.fitness_center,
                PremiumColors.slate600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'This Week',
                '3',
                Icons.calendar_today,
                PremiumColors.energeticBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Streak',
                '7 days',
                Icons.local_fire_department,
                PremiumColors.vibrantOrange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      // Remove heavy TweenAnimationBuilder
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text(
            value,
            style: PremiumTypography.h3.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: PremiumTypography.caption.copyWith(
              color: PremiumColors.slate500,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedSearchBar() {
    return AnimatedBuilder(
      animation: _searchBorderAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: AnimatedContainer(
            duration: WorkoutAnimations.normalAnimation,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isSearchFocused
                    ? PremiumColors.vibrantOrange
                    : PremiumColors.slate200,
                width: _isSearchFocused ? _searchBorderAnimation.value : 1,
              ),
              boxShadow: _isSearchFocused
                  ? [
                      BoxShadow(
                        color: PremiumColors.vibrantOrange.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: PremiumColors.slate900.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: TextField(
              controller: _searchController,
              onTap: () {
                setState(() => _isSearchFocused = true);
                _searchAnimationController.forward();
                HapticFeedback.selectionClick();
              },
              onEditingComplete: () {
                setState(() => _isSearchFocused = false);
                _searchAnimationController.reverse();
                FocusScope.of(context).unfocus();
              },
              style: PremiumTypography.bodyLarge.copyWith(
                color: PremiumColors.slate700,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search workouts...',
                prefixIcon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _searchController.text.isEmpty
                      ? Icon(
                          Icons.search_rounded,
                          color: PremiumColors.slate400,
                          size: 24,
                          key: const ValueKey('search'),
                        )
                      : Icon(
                          Icons.filter_list_rounded,
                          color: PremiumColors.vibrantOrange,
                          size: 24,
                          key: const ValueKey('filter'),
                        ),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: PremiumColors.slate400,
                          size: 20,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _searchController.clear();
                        },
                      )
                    : null,
                border: InputBorder.none,
                hintStyle: PremiumTypography.bodyMedium.copyWith(
                  color: PremiumColors.slate400,
                  fontWeight: FontWeight.w400,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Strength', 'Cardio', 'Flexibility', 'HIIT'];

    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;

          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedFilter = filter);
                  _filterRoutines();
                },
                child: AnimatedContainer(
                  duration: WorkoutAnimations.normalAnimation,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? PremiumColors.slate900 : Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isSelected
                          ? PremiumColors.slate900
                          : PremiumColors.slate300,
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: PremiumColors.slate900.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    filter,
                    style: PremiumTypography.bodyMedium.copyWith(
                      color: isSelected ? Colors.white : PremiumColors.slate600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkoutsList() {
    if (_filteredRoutines.isEmpty && _searchController.text.isNotEmpty) {
      return _buildEmptySearchResults();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _searchController.text.isEmpty
                    ? 'Your Routines'
                    : 'Search Results',
                style: PremiumTypography.h3.copyWith(
                  color: PremiumColors.slate900,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: PremiumColors.slate900,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_filteredRoutines.length}',
                  style: PremiumTypography.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredRoutines.length,
            itemBuilder: (context, index) => _buildEnhancedWorkoutCard(
              _filteredRoutines[index],
              index,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedLoadingState() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: PremiumColors.slate900,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: PremiumColors.slate900.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Loading workouts...',
              style: PremiumTypography.bodyLarge.copyWith(
                color: PremiumColors.slate500,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedErrorState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: PremiumColors.slate400.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.error_outline,
                size: 40,
                color: PremiumColors.slate500,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Something went wrong',
              style: PremiumTypography.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: PremiumTypography.bodyMedium.copyWith(
                color: PremiumColors.slate500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildPrimaryButton(
              onPressed: _loadWorkoutRoutines,
              text: 'Try Again',
              icon: Icons.refresh,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: PremiumColors.slate400.withOpacity(0.08),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(
                Icons.fitness_center,
                size: 60,
                color: PremiumColors.slate500,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Ready to begin?',
              style: PremiumTypography.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first workout or let AI design the perfect routine for you',
              style: PremiumTypography.bodyMedium.copyWith(
                color: PremiumColors.slate500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            Row(
              children: [
                Expanded(
                  child: _buildPrimaryButton(
                    onPressed: _createNewWorkoutRoutine,
                    text: 'Create Workout',
                    icon: Icons.add,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSecondaryButton(
                    onPressed: _generateWorkoutRoutine,
                    text: 'Generate AI Workout',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearchResults() {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: PremiumColors.slate400.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 40,
                color: PremiumColors.slate500,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No workouts found',
              style: PremiumTypography.h3.copyWith(
                color: PremiumColors.slate600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search terms or create a new workout routine',
              style: PremiumTypography.bodyMedium.copyWith(
                color: PremiumColors.slate500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildSecondaryButton(
              onPressed: () {
                _searchController.clear();
                HapticFeedback.lightImpact();
              },
              text: 'Clear Search',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedWorkoutCard(WorkoutRoutine routine, int index) {
    final workoutColor = WorkoutColors.getWorkoutCategoryColor(
        routine.name, routine.targetMuscles);

    return Container(
      // Remove heavy animation
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            HapticFeedback.lightImpact();
            _showWorkoutDetails(routine);
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: workoutColor.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: workoutColor.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: _buildCardContent(routine, workoutColor),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(WorkoutRoutine routine, Color workoutColor) {
    final isAIGenerated = !routine.isCustom && routine.name.contains('AI');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Color indicator
            Container(
              width: 4,
              height: 56,
              decoration: BoxDecoration(
                color: workoutColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            // Main content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          routine.name,
                          style: PremiumTypography.h3.copyWith(
                            color: PremiumColors.slate900,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // AI Badge
                      if (isAIGenerated)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                PremiumColors.vibrantOrange,
                                PremiumColors.energeticBlue,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                size: 10,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'AI',
                                style: PremiumTypography.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: workoutColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            routine.isCustom ? 'CUSTOM' : 'TEMPLATE',
                            style: PremiumTypography.caption.copyWith(
                              color: workoutColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildInfoChip(
                        routine.difficulty.toUpperCase(),
                        _getDifficultyColor(routine.difficulty),
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        '${routine.estimatedDurationMinutes}MIN',
                        PremiumColors.slate500,
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        '${routine.exercises.length} EX',
                        workoutColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Action button with enhanced styling for AI workouts
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: isAIGenerated
                    ? LinearGradient(
                        colors: [
                          PremiumColors.vibrantOrange,
                          PremiumColors.energeticBlue,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [workoutColor, workoutColor.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (isAIGenerated
                            ? PremiumColors.vibrantOrange
                            : workoutColor)
                        .withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _startWorkout(routine);
                  },
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          routine.description,
          style: PremiumTypography.bodyMedium.copyWith(
            color: PremiumColors.slate500,
            height: 1.5,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (routine.targetMuscles.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildWorkoutProgress(routine, workoutColor),
        ],
      ],
    );
  }

  Widget _buildInfoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        text,
        style: PremiumTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    return WorkoutColors.getDifficultyColor(difficulty);
  }

  Widget _buildWorkoutProgress(WorkoutRoutine routine, Color workoutColor) {
    final completionRate = 0.6; // Mock progress

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PremiumColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PremiumColors.slate200, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            Icons.trending_up,
            size: 16,
            color: workoutColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: PremiumTypography.caption.copyWith(
                        color: PremiumColors.slate600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${(completionRate * 100).toInt()}%',
                      style: PremiumTypography.caption.copyWith(
                        color: workoutColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: completionRate,
                    backgroundColor: PremiumColors.slate200,
                    valueColor: AlwaysStoppedAnimation(workoutColor),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedFloatingActionButtons() {
    return ScaleTransition(
      scale: _fabScaleAnimation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // AI Quick Workouts (only show when AI is available)
            if (_aiAvailable) ...[
              // 15-minute AI workout
              FloatingActionButton(
                heroTag: "ai_quick_15",
                onPressed: () => _generateQuickAIWorkout(15),
                backgroundColor: PremiumColors.energeticBlue,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '15',
                      style: PremiumTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 30-minute AI workout
              FloatingActionButton(
                heroTag: "ai_quick_30",
                onPressed: () => _generateQuickAIWorkout(30),
                backgroundColor: PremiumColors.desaturatedMagenta,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '30',
                      style: PremiumTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Weekly schedule generator
              FloatingActionButton(
                heroTag: "ai_weekly",
                onPressed: _generateWeeklySchedule,
                backgroundColor: PremiumColors.successGreen,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calendar_view_week,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Create custom workout FAB
            FloatingActionButton(
              heroTag: "create_custom",
              onPressed: () {
                HapticFeedback.lightImpact();
                _createNewWorkoutRoutine();
              },
              backgroundColor: Colors.white,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: PremiumColors.slate900.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.add,
                  color: PremiumColors.slate900,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Main AI generation FAB
            FloatingActionButton.extended(
              heroTag: "generate_ai",
              onPressed: () {
                HapticFeedback.mediumImpact();
                _generateWorkoutRoutine();
              },
              backgroundColor: _aiAvailable
                  ? PremiumColors.vibrantOrange
                  : PremiumColors.slate900,
              elevation: 16,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
              label: Text(
                _aiAvailable ? 'Generate AI Workout' : 'Generate Workout',
                style: PremiumTypography.button.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              icon: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _aiAvailable ? Icons.auto_awesome : Icons.fitness_center,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEnhancedSnackBar(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSuccess
                        ? [PremiumColors.successGreen, PremiumColors.emerald500]
                        : [PremiumColors.softRed, PremiumColors.red500],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSuccess ? Icons.check_rounded : Icons.close_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: PremiumTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: PremiumColors.slate800,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSuccess
                ? PremiumColors.successGreen.withOpacity(0.3)
                : PremiumColors.softRed.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        margin: const EdgeInsets.all(20),
        elevation: 16,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<Map<String, dynamic>?> _showCreateWorkoutDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierColor: PremiumColors.slate900.withOpacity(0.7),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        elevation: 24,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: PremiumColors.slate900.withOpacity(0.1),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: WorkoutColors.strengthGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.fitness_center,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      'Create Workout',
                      style: PremiumTypography.h2.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Form(
                key: formKey,
                child: Column(
                  children: [
                    _buildEnhancedTextField(
                      controller: nameController,
                      label: 'Workout Name',
                      hint: 'Upper Body Strength',
                      icon: Icons.title_outlined,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a workout name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildEnhancedTextField(
                      controller: descriptionController,
                      label: 'Description',
                      hint: 'Describe your workout goals',
                      icon: Icons.description_outlined,
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: _buildSecondaryButton(
                      onPressed: () => Navigator.pop(context),
                      text: 'Cancel',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPrimaryButton(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          Navigator.pop(context, {
                            'name': nameController.text,
                            'description': descriptionController.text,
                          });
                        }
                      },
                      text: 'Create',
                      icon: Icons.add,
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

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: PremiumTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: PremiumTypography.bodyLarge.copyWith(
            color: PremiumColors.slate700,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: PremiumColors.slate600, size: 22),
            filled: true,
            fillColor: PremiumColors.slate50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: PremiumColors.slate300, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: PremiumColors.slate900, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: PremiumColors.softRed, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: PremiumColors.softRed, width: 2),
            ),
            hintStyle: PremiumTypography.bodyMedium.copyWith(
              color: PremiumColors.slate400,
              fontWeight: FontWeight.w400,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required VoidCallback onPressed,
    required String text,
    IconData? icon,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: PremiumColors.slate900,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: PremiumColors.slate900.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: PremiumTypography.button.copyWith(
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required VoidCallback onPressed,
    required String text,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border.all(color: PremiumColors.slate300, width: 1.5),
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: Text(
                text,
                style: PremiumTypography.bodyMedium.copyWith(
                  color: PremiumColors.slate500,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showWorkoutDetails(WorkoutRoutine routine) {
    final workoutColor = WorkoutColors.getWorkoutCategoryColor(
        routine.name, routine.targetMuscles);

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: PremiumColors.slate900.withOpacity(0.7),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        elevation: 24,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: PremiumColors.slate900.withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: WorkoutColors.getWorkoutGradient(
                          routine.name, routine.targetMuscles),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      routine.isCustom
                          ? Icons.fitness_center
                          : Icons.auto_awesome,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routine.name,
                          style: PremiumTypography.h3.copyWith(
                            color: PremiumColors.slate900,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: workoutColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: workoutColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            routine.isCustom
                                ? 'CUSTOM WORKOUT'
                                : 'AI GENERATED',
                            style: PremiumTypography.caption.copyWith(
                              color: workoutColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                routine.description,
                style: PremiumTypography.bodyMedium.copyWith(
                  color: PremiumColors.slate500,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              _buildDetailRow(Icons.signal_cellular_alt, 'Difficulty',
                  routine.difficulty.toUpperCase()),
              _buildDetailRow(Icons.schedule_outlined, 'Duration',
                  '${routine.estimatedDurationMinutes} minutes'),
              _buildDetailRow(Icons.list_alt_outlined, 'Exercises',
                  '${routine.exercises.length} total'),
              if (routine.targetMuscles.isNotEmpty)
                _buildDetailRow(Icons.track_changes_outlined, 'Target Areas',
                    routine.targetMuscles.join(', ')),
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: _buildSecondaryButton(
                      onPressed: () => Navigator.pop(context),
                      text: 'Close',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: WorkoutColors.getWorkoutGradient(
                            routine.name, routine.targetMuscles),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: workoutColor.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.pop(context);
                            _startWorkout(routine);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.play_arrow,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Start Workout',
                                  style: PremiumTypography.button.copyWith(
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
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
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: PremiumColors.slate600),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: PremiumTypography.bodyMedium.copyWith(
              color: PremiumColors.slate900,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: PremiumTypography.bodyMedium.copyWith(
                color: PremiumColors.slate500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _initializeAI() async {
    _aiService.initialize();
    await _ensureDataCompatibility();
    await _checkAIAvailability();
  }

  Future<void> _checkAIAvailability() async {
    try {
      print('[AI Check] Starting AI availability check...');

      final profile = await _dataService.getCurrentFitnessProfile();
      final macroData = await _dataService.getMacroData();
      final isReady = await _dataService.isReadyForAIRecommendations();

      // Debug: Print what we have vs what we need
      print('=== AI AVAILABILITY DEBUG ===');
      print('Profile exists: ${profile != null}');
      if (profile != null) {
        print(
            'Fitness Level: "${profile.fitnessLevel}" (empty: ${profile.fitnessLevel.isEmpty})');
        print(
            'Workout Location: "${profile.workoutLocation}" (empty: ${profile.workoutLocation.isEmpty})');
        print(
            'Workout Space: "${profile.workoutSpace}" (empty: ${profile.workoutSpace.isEmpty})');
        print(
            'Workouts Per Week: ${profile.workoutsPerWeek} (>0: ${profile.workoutsPerWeek > 0})');
        print(
            'Max Duration: ${profile.maxWorkoutDuration} (>0: ${profile.maxWorkoutDuration > 0})');
        print('Basic Profile Complete: ${profile.isBasicProfileComplete}');
      }
      print('Macro data exists: ${macroData != null}');
      if (macroData != null) {
        print(
            'Has macro calories: ${macroData['target_calories'] != null} (value: ${macroData['target_calories']})');
        print(
            'Has goal type: ${macroData['goal_type'] != null} (value: ${macroData['goal_type']})');
      }
      print('AI Ready final result: $isReady');
      print('============================');

      if (mounted) {
        setState(() {
          _aiAvailable = isReady;
        });
        print('[AI Check] AI availability set to: $_aiAvailable');
      }
    } catch (e, stackTrace) {
      print('[AI Check] Error checking AI availability: $e');
      print('[AI Check] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _aiAvailable = false;
        });
      }
    }
  }

  void _showWeeklyScheduleDialog(List<Map<String, dynamic>> schedule) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: PremiumColors.slate900.withOpacity(0.7),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        elevation: 24,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: PremiumColors.slate900.withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          PremiumColors.vibrantOrange,
                          PremiumColors.energeticBlue
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.calendar_view_week,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      'Weekly Schedule',
                      style: PremiumTypography.h2.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 400,
                width: double.maxFinite,
                child: ListView.builder(
                  itemCount: schedule.length,
                  itemBuilder: (context, index) {
                    final day = schedule[index];
                    final isRestDay = day['rest_day'] == true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isRestDay ? PremiumColors.slate50 : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isRestDay
                              ? PremiumColors.slate200
                              : PremiumColors.energeticBlue.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isRestDay
                                  ? PremiumColors.slate300
                                  : PremiumColors.energeticBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isRestDay ? Icons.hotel : Icons.fitness_center,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${day['day']}: ${day['workout_type']}',
                                  style: PremiumTypography.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${day['primary_focus']} • ${day['estimated_duration']}min',
                                  style: PremiumTypography.bodyMedium.copyWith(
                                    color: PremiumColors.slate500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildSecondaryButton(
                      onPressed: () => Navigator.pop(context),
                      text: 'Close',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPrimaryButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // Could implement schedule saving here
                        _showEnhancedSnackBar('Schedule saved! 📅', true);
                      },
                      text: 'Save Schedule',
                      icon: Icons.save,
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

  Future<void> _fixMissingFields() async {
    try {
      final profile = await _dataService.getCurrentFitnessProfile();
      final macroData = await _dataService.getMacroData();

      print('[Fix] Current macro data: $macroData');

      // Update macro data with required fields
      final updatedMacroData = {
        'target_calories': macroData['target_calories'] ?? 2200,
        'protein_g': macroData['protein_g'] ?? 165,
        'carb_g': macroData['carb_g'] ?? 220,
        'fat_g': macroData['fat_g'] ?? 75,
        'goal_type': macroData['goal_type'] ?? 'muscle_gain',
        'current_weight_kg': macroData['current_weight_kg'] ?? 75,
        'goal_weight_kg': macroData['goal_weight_kg'] ?? 80,
      };

      // Ensure profile has all required fields
      final updatedProfileData = {
        'fitnessLevel': profile.fitnessLevel.isEmpty
            ? 'intermediate'
            : profile.fitnessLevel,
        'yearsOfExperience':
            profile.yearsOfExperience <= 0 ? 2 : profile.yearsOfExperience,
        'previousExerciseTypes': profile.previousExerciseTypes.isEmpty
            ? ['strength', 'cardio']
            : profile.previousExerciseTypes,
        'workoutLocation':
            profile.workoutLocation.isEmpty ? 'home' : profile.workoutLocation,
        'availableEquipment': profile.availableEquipment.isEmpty
            ? ['dumbbells', 'bodyweight']
            : profile.availableEquipment,
        'hasGymAccess': profile.hasGymAccess,
        'workoutSpace':
            profile.workoutSpace.isEmpty ? 'medium' : profile.workoutSpace,
        'workoutsPerWeek':
            profile.workoutsPerWeek <= 0 ? 4 : profile.workoutsPerWeek,
        'maxWorkoutDuration':
            profile.maxWorkoutDuration <= 0 ? 60 : profile.maxWorkoutDuration,
        'preferredTimeOfDay': profile.preferredTimeOfDay.isEmpty
            ? 'morning'
            : profile.preferredTimeOfDay,
        'preferredDays': profile.preferredDays.isEmpty
            ? ['monday', 'wednesday', 'friday', 'sunday']
            : profile.preferredDays,
      };

      // Store updated data
      await _storageService.put(
          'fitness_profile', json.encode(updatedProfileData));
      await _storageService.put('macro_results', json.encode(updatedMacroData));

      print('[Fix] Updated macro data: $updatedMacroData');
      print('[Fix] Updated fitness profile data');

      // Re-check AI availability
      await _checkAIAvailability();

      _showEnhancedSnackBar('AI data fixed! Check debug again 🤖✨', true);
    } catch (e) {
      print('[Fix] Error fixing missing fields: $e');
      _showEnhancedSnackBar('Failed to fix missing fields: $e', false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      print('[Lifecycle] App resumed, checking AI availability...');
      _checkAIAvailability();
    }
  }

  /// Ensures onboarding data is properly accessible for AI
  Future<void> _ensureDataCompatibility() async {
    try {
      print('[Compatibility] Checking data compatibility...');

      // Check if we have macro_results data but missing fitness_profile
      final macroResultsJson = await _storageService.get('macro_results');
      if (macroResultsJson != null) {
        final macroResults = json.decode(macroResultsJson);

        // If fitness_profile exists in macro_results, ensure it's also stored separately
        if (macroResults['fitness_profile'] != null) {
          await _storageService.put(
              'fitness_profile', json.encode(macroResults['fitness_profile']));
          print('[Compatibility] Copied fitness_profile from macro_results');
        }

        // Ensure macro data has the expected structure
        if (macroResults['target_calories'] == null &&
            macroResults['calories'] != null) {
          macroResults['target_calories'] = macroResults['calories'];
        }
        if (macroResults['goal_type'] == null) {
          macroResults['goal_type'] = 'maintain'; // Default value
        }

        await _storageService.put('macro_results', json.encode(macroResults));
        print('[Compatibility] Updated macro_results structure');
      }
    } catch (e) {
      print('[Compatibility] Error ensuring data compatibility: $e');
    }
  }
}
