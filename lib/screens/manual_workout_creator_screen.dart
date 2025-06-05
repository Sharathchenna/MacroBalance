import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/exercise.dart';
import '../models/workout_plan.dart';
import '../data/exercise_database.dart';

class ManualWorkoutCreatorScreen extends StatefulWidget {
  const ManualWorkoutCreatorScreen({super.key});

  @override
  State<ManualWorkoutCreatorScreen> createState() =>
      _ManualWorkoutCreatorScreenState();
}

class _ManualWorkoutCreatorScreenState extends State<ManualWorkoutCreatorScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _workoutNameController = TextEditingController();
  final TextEditingController _workoutDescriptionController =
      TextEditingController();

  List<Exercise> _filteredExercises = [];
  List<WorkoutExercise> _selectedExercises = [];
  String _selectedMuscleGroup = 'All';
  String _selectedEquipment = 'All';
  String _selectedDifficulty = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _filteredExercises = ExerciseDatabase.getAllExercises();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    _searchController.dispose();
    _workoutNameController.dispose();
    _workoutDescriptionController.dispose();
    super.dispose();
  }

  void _filterExercises() {
    setState(() {
      _filteredExercises = ExerciseDatabase.getAllExercises();

      // Apply search filter
      if (_searchController.text.isNotEmpty) {
        _filteredExercises =
            ExerciseDatabase.searchExercises(_searchController.text);
      }

      // Apply muscle group filter
      if (_selectedMuscleGroup != 'All') {
        _filteredExercises = _filteredExercises
            .where((exercise) =>
                exercise.primaryMuscles
                    .contains(_selectedMuscleGroup.toLowerCase()) ||
                exercise.secondaryMuscles
                    .contains(_selectedMuscleGroup.toLowerCase()))
            .toList();
      }

      // Apply equipment filter
      if (_selectedEquipment != 'All') {
        _filteredExercises = _filteredExercises
            .where((exercise) =>
                exercise.equipment.contains(_selectedEquipment.toLowerCase()))
            .toList();
      }

      // Apply difficulty filter
      if (_selectedDifficulty != 'All') {
        _filteredExercises = _filteredExercises
            .where((exercise) =>
                exercise.difficulty.toLowerCase() ==
                _selectedDifficulty.toLowerCase())
            .toList();
      }
    });
  }

  void _addExerciseToWorkout(Exercise exercise) {
    HapticFeedback.lightImpact();

    setState(() {
      _selectedExercises.add(WorkoutExercise(
        exerciseId: exercise.id,
        exercise: exercise,
        sets: List.generate(
            exercise.defaultSets ?? 3,
            (index) => WorkoutSet(
                  reps: exercise.defaultReps ?? 10,
                  durationSeconds: exercise.defaultDurationSeconds,
                )),
      ));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${exercise.name} added to workout'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _removeExerciseFromWorkout(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedExercises.removeAt(index);
    });
  }

  void _saveWorkout() {
    if (_workoutNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a workout name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one exercise'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Calculate estimated duration (assuming 1 minute per set + rest time)
    final totalSets =
        _selectedExercises.fold(0, (sum, ex) => sum + ex.sets.length);
    final estimatedDuration =
        totalSets * 2; // 2 minutes per set (including rest)

    // Get unique muscle groups
    final targetMuscles = <String>{};
    for (final exercise in _selectedExercises) {
      if (exercise.exercise != null) {
        targetMuscles.addAll(exercise.exercise!.primaryMuscles);
      }
    }

    // Get required equipment
    final requiredEquipment = <String>{};
    for (final exercise in _selectedExercises) {
      if (exercise.exercise != null) {
        requiredEquipment.addAll(exercise.exercise!.equipment);
      }
    }

    final workout = WorkoutRoutine(
      name: _workoutNameController.text,
      description: _workoutDescriptionController.text.isEmpty
          ? 'Custom workout with ${_selectedExercises.length} exercises'
          : _workoutDescriptionController.text,
      exercises: _selectedExercises,
      estimatedDurationMinutes: estimatedDuration,
      difficulty: _getDominantDifficulty(),
      targetMuscles: targetMuscles.toList(),
      requiredEquipment: requiredEquipment.toList(),
      isCustom: true,
    );

    Navigator.pop(context, workout);
  }

  String _getDominantDifficulty() {
    final difficulties = _selectedExercises
        .map((ex) => ex.exercise?.difficulty ?? 'beginner')
        .toList();

    if (difficulties.any((d) => d == 'advanced')) return 'advanced';
    if (difficulties.any((d) => d == 'intermediate')) return 'intermediate';
    return 'beginner';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? PremiumColors.darkBackground : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? PremiumColors.darkBackground : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        title: Text(
          'Create Workout',
          style: PremiumTypography.h2.copyWith(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saveWorkout,
            child: Text(
              'Save',
              style: PremiumTypography.button.copyWith(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? Colors.white : Colors.black,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
          indicatorColor: isDark ? Colors.white : Colors.black,
          tabs: const [
            Tab(text: 'Browse Exercises'),
            Tab(text: 'My Workout'),
          ],
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildExerciseBrowserTab(isDark),
            _buildWorkoutBuilderTab(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseBrowserTab(bool isDark) {
    return Column(
      children: [
        _buildSearchAndFilters(isDark),
        Expanded(
          child: _filteredExercises.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredExercises.length,
                  itemBuilder: (context, index) {
                    final exercise = _filteredExercises[index];
                    return _buildExerciseCard(exercise, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? PremiumColors.darkCard : PremiumColors.slate50,
        border: isDark
            ? const Border(bottom: BorderSide(color: PremiumColors.darkBorder))
            : null,
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            onChanged: (_) => _filterExercises(),
            decoration: InputDecoration(
              hintText: 'Search exercises...',
              prefixIcon: Icon(
                CupertinoIcons.search,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              filled: true,
              fillColor: isDark ? PremiumColors.darkContainer : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              hintStyle: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          // Filter chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              children: [
                _buildFilterChip(
                    'Muscle Group',
                    _selectedMuscleGroup,
                    [
                      'All',
                      'Chest',
                      'Back',
                      'Shoulders',
                      'Biceps',
                      'Triceps',
                      'Quadriceps',
                      'Hamstrings',
                      'Glutes',
                      'Calves',
                      'Abs'
                    ],
                    (value) => setState(() {
                          _selectedMuscleGroup = value;
                          _filterExercises();
                        }),
                    isDark),
                const SizedBox(width: 8),
                _buildFilterChip(
                    'Equipment',
                    _selectedEquipment,
                    [
                      'All',
                      'Bodyweight',
                      'Dumbbells',
                      'Barbell',
                      'Kettlebell',
                      'Bench'
                    ],
                    (value) => setState(() {
                          _selectedEquipment = value;
                          _filterExercises();
                        }),
                    isDark),
                const SizedBox(width: 8),
                _buildFilterChip(
                    'Difficulty',
                    _selectedDifficulty,
                    ['All', 'Beginner', 'Intermediate', 'Advanced'],
                    (value) => setState(() {
                          _selectedDifficulty = value;
                          _filterExercises();
                        }),
                    isDark),
                const SizedBox(width: 16), // Extra padding at the end
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String selectedValue,
      List<String> options, Function(String) onSelected, bool isDark) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) => options
          .map((option) => PopupMenuItem(
                value: option,
                child: Text(option),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? PremiumColors.darkContainer : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? PremiumColors.darkBorder : PremiumColors.slate300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: $selectedValue',
              style: PremiumTypography.caption.copyWith(
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              CupertinoIcons.chevron_down,
              size: 14,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseCard(Exercise exercise, bool isDark) {
    final isAdded =
        _selectedExercises.any((ex) => ex.exerciseId == exercise.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? PremiumColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: PremiumColors.darkBorder) : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: PremiumTypography.h4.copyWith(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        exercise.description,
                        style: PremiumTypography.bodySmall.copyWith(
                          color: isDark
                              ? PremiumColors.darkTextSecondary
                              : PremiumColors.slate500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed:
                      isAdded ? null : () => _addExerciseToWorkout(exercise),
                  icon: Icon(
                    isAdded
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.plus_circle,
                    color: isAdded
                        ? Colors.green
                        : (isDark ? Colors.white : Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildInfoTag(exercise.difficulty.toUpperCase(), isDark),
                _buildInfoTag(exercise.type.toUpperCase(), isDark),
                if (exercise.equipment.isNotEmpty)
                  _buildInfoTag(exercise.equipment.first.toUpperCase(), isDark),
                if (exercise.defaultSets != null)
                  _buildInfoTag('${exercise.defaultSets} SETS', isDark),
                if (exercise.defaultReps != null)
                  _buildInfoTag('${exercise.defaultReps} REPS', isDark),
                if (exercise.estimatedCaloriesBurnedPerMinute != null)
                  _buildCalorieTag(
                      exercise.estimatedCaloriesBurnedPerMinute! * 30, isDark),
              ],
            ),
            if (exercise.primaryMuscles.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Targets: ${exercise.primaryMuscles.map((m) => m.toUpperCase()).join(', ')}',
                style: PremiumTypography.caption.copyWith(
                  color: isDark
                      ? PremiumColors.darkTextSecondary
                      : PremiumColors.slate400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTag(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? PremiumColors.darkContainer : PremiumColors.slate100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: PremiumTypography.caption.copyWith(
          color:
              isDark ? PremiumColors.darkTextSecondary : PremiumColors.slate600,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCalorieTag(double caloriesPer30Min, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.orange.withValues(alpha: 0.2)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.flame,
            size: 12,
            color: Colors.orange,
          ),
          const SizedBox(width: 2),
          Text(
            '${caloriesPer30Min.round()} CAL/30MIN',
            style: PremiumTypography.caption.copyWith(
              color: Colors.orange,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutBuilderTab(bool isDark) {
    return Column(
      children: [
        _buildWorkoutDetailsSection(isDark),
        Expanded(
          child: _selectedExercises.isEmpty
              ? _buildEmptyWorkoutState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _selectedExercises.length,
                  itemBuilder: (context, index) {
                    final workoutExercise = _selectedExercises[index];
                    return _buildWorkoutExerciseCard(
                        workoutExercise, index, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWorkoutDetailsSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? PremiumColors.darkCard : PremiumColors.slate50,
        border: isDark
            ? const Border(bottom: BorderSide(color: PremiumColors.darkBorder))
            : null,
      ),
      child: Column(
        children: [
          TextField(
            controller: _workoutNameController,
            decoration: InputDecoration(
              labelText: 'Workout Name *',
              hintText: 'e.g., Upper Body Strength',
              filled: true,
              fillColor: isDark ? PremiumColors.darkContainer : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              labelStyle: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _workoutDescriptionController,
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'Describe your workout...',
              filled: true,
              fillColor: isDark ? PremiumColors.darkContainer : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              labelStyle: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutExerciseCard(
      WorkoutExercise workoutExercise, int index, bool isDark) {
    final exercise = workoutExercise.exercise;
    if (exercise == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? PremiumColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: PremiumColors.darkBorder) : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${index + 1}.',
                  style: PremiumTypography.h4.copyWith(
                    color: isDark
                        ? PremiumColors.darkTextSecondary
                        : PremiumColors.slate400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    exercise.name,
                    style: PremiumTypography.h4.copyWith(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _removeExerciseFromWorkout(index),
                  icon: const Icon(
                    CupertinoIcons.trash,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${workoutExercise.sets.length} sets × ${workoutExercise.sets.first.reps} reps',
                    style: PremiumTypography.bodyMedium.copyWith(
                      color: isDark
                          ? PremiumColors.darkTextSecondary
                          : PremiumColors.slate500,
                    ),
                  ),
                ),
                if (exercise.estimatedCaloriesBurnedPerMinute != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.orange.withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.flame,
                          size: 12,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(exercise.estimatedCaloriesBurnedPerMinute! * 30).round()} cal/30min',
                          style: PremiumTypography.caption.copyWith(
                            color: Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.search,
            size: 64,
            color: isDark
                ? PremiumColors.darkTextSecondary
                : PremiumColors.slate400,
          ),
          const SizedBox(height: 16),
          Text(
            'No exercises found',
            style: PremiumTypography.h3.copyWith(
              color: isDark
                  ? PremiumColors.darkTextSecondary
                  : PremiumColors.slate500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: PremiumTypography.bodyMedium.copyWith(
              color: isDark
                  ? PremiumColors.darkTextSecondary
                  : PremiumColors.slate400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWorkoutState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.plus_circle,
            size: 64,
            color: isDark
                ? PremiumColors.darkTextSecondary
                : PremiumColors.slate400,
          ),
          const SizedBox(height: 16),
          Text(
            'No exercises added yet',
            style: PremiumTypography.h3.copyWith(
              color: isDark
                  ? PremiumColors.darkTextSecondary
                  : PremiumColors.slate500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Go to Browse Exercises to add some',
            style: PremiumTypography.bodyMedium.copyWith(
              color: isDark
                  ? PremiumColors.darkTextSecondary
                  : PremiumColors.slate400,
            ),
          ),
        ],
      ),
    );
  }
}
