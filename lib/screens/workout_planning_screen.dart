import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // For User
import 'package:hive_flutter/hive_flutter.dart'; // Added for Hive
import '../theme/app_theme.dart';
import '../models/workout_plan.dart';
import '../models/fitness_profile.dart'; // Import FitnessProfile
import '../services/fitness_ai_service.dart'; // Import FitnessAIService
import '../screens/workout_details_screen.dart';
import '../widgets/workout_creation_modal.dart';
import '../data/exercise_database.dart';

class WorkoutPlanningScreen extends StatefulWidget {
  const WorkoutPlanningScreen({super.key});

  @override
  State<WorkoutPlanningScreen> createState() => _WorkoutPlanningScreenState();
}

class _WorkoutPlanningScreenState extends State<WorkoutPlanningScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  final FitnessAIService _fitnessAIService =
      FitnessAIService(); // Add service instance
  FitnessProfile? _currentProfile;
  bool _isLoadingProfile = true;
  bool _isLoadingFromSupabase =
      false; // To manage Supabase loading state separately

  List<WorkoutRoutine> _customRoutines = [];
  List<WorkoutRoutine> _sampleRoutines = [];

  // Mock stats
  int get totalCustomRoutines => _customRoutines.length;
  int thisWeekWorkouts = 0;
  int streakDays = 0;
  bool _isRefreshing = false;

  // Hive Box Names
  static const String _fitnessProfileBoxName = 'fitnessProfileBox';
  static const String _workoutRoutinesBoxName = 'workoutRoutinesBox';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _loadFitnessProfileAndData();

    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _scaleController.forward();
    });
  }

  Future<void> _loadFitnessProfileAndData({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      setState(() {
        _isLoadingProfile = true;
      });
    } else {
      setState(() {
        _isRefreshing = true;
      });
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoadingProfile = false;
        _isRefreshing = false;
        _customRoutines = [];
        _sampleRoutines = [];
        _currentProfile = null;
      });
      return;
    }

    bool loadedFromCache = false;

    // --- Try loading from Hive first ---
    if (!forceRefresh) {
      try {
        final profileBox =
            await Hive.openBox<FitnessProfile>(_fitnessProfileBoxName);
        // The box will store WorkoutRoutine objects, but we'll retrieve a List for a user
        final routinesBox = await Hive.openBox<List<dynamic>>(
            _workoutRoutinesBoxName); // Store list of routines

        final cachedProfile = profileBox.get(user.id);
        final dynamic cachedRoutinesDynamic = routinesBox.get(user.id);
        List<WorkoutRoutine>? cachedCustomRoutines;

        if (cachedRoutinesDynamic is List) {
          cachedCustomRoutines =
              cachedRoutinesDynamic.whereType<WorkoutRoutine>().toList();
        }

        if (cachedProfile != null && cachedCustomRoutines != null) {
          setState(() {
            _currentProfile = cachedProfile;
            _customRoutines = cachedCustomRoutines!
                .toList(); // Create a new list using toList()
            // _sampleRoutines = ...; // TODO: Decide if sample routines are cached
            _isLoadingProfile = false; // Loaded from cache, UI can update
            loadedFromCache = true;
            print('Data loaded from Hive cache.');
          });
        }
      } catch (e) {
        print('Error loading data from Hive: $e');
        // Proceed to load from Supabase if Hive fails
      }
    }

    // --- Load from Supabase (always, to refresh cache or if cache miss) ---
    // Only show full loading indicator if not already loaded from cache
    if (!loadedFromCache && !forceRefresh) {
      // Already set if !forceRefresh
    } else if (forceRefresh) {
      // _isRefreshing is already true
    }

    setState(() {
      _isLoadingFromSupabase = true;
    });

    try {
      // Load fitness profile from Supabase
      final supabaseProfile =
          await _fitnessAIService.getFitnessProfile(user.id);

      // Load workouts from Supabase
      final supabase = Supabase.instance.client;
      final routinesData = await supabase
          .from('workout_routines')
          .select()
          .eq('created_by', user.id);

      final List<WorkoutRoutine> newCustomRoutines = [];
      final List<WorkoutRoutine> newSampleRoutines = [];

      for (final routineData in routinesData) {
        final routine = WorkoutRoutine.fromJson(routineData);
        if (routine.isCustom) {
          newCustomRoutines.add(routine);
        } else {
          newSampleRoutines.add(routine);
        }
      }

      // Update state with Supabase data
      setState(() {
        _currentProfile = supabaseProfile;
        _customRoutines = newCustomRoutines;
        _sampleRoutines = newSampleRoutines; // Update sample routines as well
        if (!loadedFromCache || forceRefresh) {
          // Only turn off main loader if it was on
          _isLoadingProfile = false;
        }
        print('Data loaded from Supabase.');
      });

      // Save to Hive
      try {
        final profileBox =
            await Hive.openBox<FitnessProfile>(_fitnessProfileBoxName);
        if (supabaseProfile != null) {
          await profileBox.put(user.id, supabaseProfile);
        }

        final routinesBox =
            await Hive.openBox<List<dynamic>>(_workoutRoutinesBoxName);
        // Store the list of custom routines.
        await routinesBox.put(user.id, newCustomRoutines);
        // TODO: Decide if/how to cache sample routines if they are user-specific or change often.
        // For now, only caching custom routines.

        print('Data saved to Hive cache.');
      } catch (e) {
        print('Error saving data to Hive: $e');
      }
    } catch (error) {
      print('Error loading data from Supabase: $error');
      if (!loadedFromCache) {
        // If cache didn't load, show error state
        setState(() {
          _customRoutines = [];
          _sampleRoutines = [];
          _currentProfile = null;
          _isLoadingProfile = false; // Ensure loader stops on error
        });
      }
    } finally {
      setState(() {
        _isLoadingFromSupabase = false;
        if (forceRefresh) {
          _isRefreshing = false;
        }
        // Ensure isLoadingProfile is false if it somehow remained true
        if (_isLoadingProfile && !loadedFromCache) {
          _isLoadingProfile = false;
        }
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
      body: _isLoadingProfile
          ? Center(
              child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? Colors.white : Colors.black),
            ))
          : FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(context, isDark),
                  SliverToBoxAdapter(
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        children: [
                          _buildStatsSection(context, isDark),
                          _buildRoutinesSection(context, isDark),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: _buildFloatingActionButton(context, isDark),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
      foregroundColor: isDark ? Colors.white : Colors.black,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'My Workouts',
          style: PremiumTypography.h1.copyWith(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 28,
          ),
        ),
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
      ),
      actions: [
        IconButton(
          onPressed: () => _refreshWorkouts(),
          icon: Icon(
            CupertinoIcons.refresh,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildStatsSection(BuildContext context, bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    final shouldStack = screenWidth < 400;

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isDark
            ? Border.all(color: const Color(0xFF3A3A43), width: 1)
            : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: shouldStack
          ? _buildStackedStats(context, isDark)
          : _buildRowStats(context, isDark),
    );
  }

  Widget _buildRowStats(BuildContext context, bool isDark) {
    return Row(
      children: [
        _buildStatItem(
          context,
          isDark,
          CupertinoIcons.folder_fill,
          totalCustomRoutines.toString(),
          'Custom Routines',
          isDark ? Colors.white : Colors.black,
        ),
        const SizedBox(width: 24),
        _buildStatItem(
          context,
          isDark,
          CupertinoIcons.calendar,
          thisWeekWorkouts.toString(),
          'This Week',
          isDark ? Colors.white : Colors.black,
        ),
        const SizedBox(width: 24),
        _buildStatItem(
          context,
          isDark,
          CupertinoIcons.flame_fill,
          '$streakDays days',
          'Streak',
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStackedStats(BuildContext context, bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            _buildStatItem(
              context,
              isDark,
              CupertinoIcons.folder_fill,
              _customRoutines.length.toString(),
              'Custom Routines',
              isDark ? Colors.white : Colors.black,
            ),
            const SizedBox(width: 16),
            _buildStatItem(
              context,
              isDark,
              CupertinoIcons.calendar,
              '0',
              'This Week',
              isDark ? Colors.white : Colors.black,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildStatItem(
          context,
          isDark,
          CupertinoIcons.flame_fill,
          '0 days',
          'Streak',
          Colors.orange,
          shouldExpand: false,
        ),
      ],
    );
  }

  Widget _buildStatItem(BuildContext context, bool isDark, IconData icon,
      String value, String label, Color accentColor,
      {bool shouldExpand = true}) {
    final child = Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: accentColor,
            size: 24,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: PremiumTypography.h3.copyWith(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: PremiumTypography.caption.copyWith(
            color: isDark
                ? PremiumColors.darkTextSecondary
                : PremiumColors.slate500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );

    return shouldExpand ? Expanded(child: child) : child;
  }

  Widget _buildRoutinesSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Custom Routines Section
        if (_customRoutines.isNotEmpty) ...[
          _buildSectionHeader(context, isDark, 'Your Custom Routines', true),
          const SizedBox(height: 16),
          ..._customRoutines.asMap().entries.map((entry) {
            final index = entry.key;
            final routine = entry.value;
            return AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset:
                      Offset(0, (1 - _scaleAnimation.value) * 20 * (index + 1)),
                  child: Opacity(
                    opacity: _scaleAnimation.value.clamp(0.0, 1.0),
                    child: _buildWorkoutCard(context, routine, isDark),
                  ),
                );
              },
            );
          }),
          const SizedBox(height: 32),
        ],

        const SizedBox(height: 100), // Space for FAB
      ],
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, bool isDark, String title, bool showRefresh) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: PremiumTypography.h3.copyWith(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (showRefresh || _isRefreshing)
            _isRefreshing
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark
                            ? PremiumColors.darkTextSecondary
                            : PremiumColors.slate500,
                      ),
                    ),
                  )
                : TextButton.icon(
                    onPressed: () => _refreshWorkouts(),
                    icon: Icon(
                      CupertinoIcons.refresh,
                      size: 16,
                      color: isDark
                          ? PremiumColors.darkTextSecondary
                          : PremiumColors.slate500,
                    ),
                    label: Text(
                      'Refresh',
                      style: PremiumTypography.caption.copyWith(
                        color: isDark
                            ? PremiumColors.darkTextSecondary
                            : PremiumColors.slate500,
                      ),
                    ),
                  ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, String message) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark
            ? Border.all(color: const Color(0xFF3A3A43), width: 1)
            : null,
      ),
      child: Column(
        children: [
          Icon(
            CupertinoIcons.doc_text,
            size: 48,
            color: isDark
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.black.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: PremiumTypography.bodyMedium.copyWith(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.black.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(
      BuildContext context, WorkoutRoutine routine, bool isDark) {
    final difficultyColor = _getDifficultyColor(routine.difficulty);
    final completionPercentage = _getWorkoutCompletionPercentage(routine);

    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
      child: Dismissible(
        key: Key(routine.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          return await _showDeleteConfirmation(context, routine, isDark);
        },
        onDismissed: (direction) {
          _deleteWorkout(routine);
        },
        background: _buildDismissBackground(isDark),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF3A3A43)
                  : difficultyColor.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: difficultyColor.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                // Progress bar if workout has been started
                if (completionPercentage > 0)
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.1),
                    ),
                    child: LinearProgressIndicator(
                      value: completionPercentage / 100,
                      backgroundColor: Colors.transparent,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(difficultyColor),
                    ),
                  ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openWorkoutDetails(routine),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          _buildWorkoutIcon(difficultyColor, routine),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildWorkoutInfo(
                                context, routine, isDark, difficultyColor),
                          ),
                          _buildPlayButton(isDark, difficultyColor),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  double _getWorkoutCompletionPercentage(WorkoutRoutine routine) {
    if (routine.exercises.isEmpty) return 0;
    final completedExercises =
        routine.exercises.where((e) => e.isCompleted).length;
    return (completedExercises / routine.exercises.length) * 100;
  }

  Widget _buildWorkoutIcon(Color accentColor, WorkoutRoutine routine) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconData =
        routine.isCustom ? CupertinoIcons.star_fill : CupertinoIcons.flame_fill;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        iconData,
        color: accentColor,
        size: 28,
      ),
    );
  }

  Widget _buildWorkoutInfo(BuildContext context, WorkoutRoutine routine,
      bool isDark, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                routine.name,
                style: PremiumTypography.h4.copyWith(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (routine.isCustom)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'CUSTOM',
                  style: PremiumTypography.caption.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          routine.description,
          style: PremiumTypography.bodySmall.copyWith(
            color: isDark
                ? PremiumColors.darkTextSecondary
                : PremiumColors.slate500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildInfoChip(
              routine.difficulty.toUpperCase(),
              accentColor,
              isDark,
            ),
            const SizedBox(width: 8),
            _buildInfoChip(
              '${routine.estimatedDurationMinutes} MIN',
              isDark ? PremiumColors.darkTextSecondary : PremiumColors.slate500,
              isDark,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ...routine.targetMuscles.take(2).map((muscle) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildMuscleChip(muscle, isDark),
                )),
            if (routine.targetMuscles.length > 2)
              Flexible(
                child: Text(
                  '+${routine.targetMuscles.length - 2} more',
                  style: PremiumTypography.caption.copyWith(
                    color: isDark
                        ? PremiumColors.darkTextSecondary
                        : PremiumColors.slate400,
                  ),
                  overflow:
                      TextOverflow.ellipsis, // Ensure text truncates nicely
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              CupertinoIcons.checkmark_circle_fill,
              size: 16,
              color: accentColor.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 4),
            Text(
              '${routine.exercises.length} exercises',
              style: PremiumTypography.caption.copyWith(
                color: isDark
                    ? PremiumColors.darkTextSecondary
                    : PremiumColors.slate400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoChip(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: PremiumTypography.caption.copyWith(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildMuscleChip(String muscle, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        muscle.toUpperCase(),
        style: PremiumTypography.caption.copyWith(
          color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPlayButton(bool isDark, Color accentColor) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        CupertinoIcons.play_fill,
        color: accentColor,
        size: 20,
      ),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context, bool isDark) {
    return FloatingActionButton.extended(
      onPressed: () => _showWorkoutCreationOptions(),
      backgroundColor: isDark ? Colors.white : Colors.black,
      foregroundColor: isDark ? Colors.black : Colors.white,
      elevation: 8,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.plus,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Add Workout',
            style: PremiumTypography.button.copyWith(
              color: isDark ? Colors.black : Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _refreshWorkouts() async {
    HapticFeedback.lightImpact();

    // No need to set _isRefreshing here, _loadFitnessProfileAndData handles it
    await _loadFitnessProfileAndData(forceRefresh: true);
  }

  void _openWorkoutDetails(WorkoutRoutine routine) {
    // Add haptic feedback
    HapticFeedback.selectionClick();

    // Navigate to workout details
    print('Opening workout: ${routine.name}');
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => WorkoutDetailsScreen(routine: routine)));
  }

  void _showWorkoutCreationOptions() async {
    HapticFeedback.lightImpact();

    // Check if fitness profile exists
    if (_currentProfile == null) {
      // Show dialog directing to settings for onboarding reset
      final shouldGoToSettings = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            title: Text(
              'Fitness Profile Required',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            content: Text(
              'To create personalized workouts, you need to complete the onboarding process which includes creating your fitness profile. Would you like to go to Settings to reset onboarding?',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Not Now',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                ),
                child: Text(
                  'Go to Settings',
                  style: TextStyle(
                    color: isDark ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      );

      if (shouldGoToSettings == true) {
        // Navigate to settings screen
        Navigator.pushNamed(context, '/settings');

        // Show a snackbar with instructions
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Go to "Reset App Data" and select "Reset Onboarding" to set up your fitness profile'),
            duration: Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      } else {
        // User chose not to go to settings
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'You can set up your fitness profile later through Settings > Reset Onboarding'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    // Continue with normal workout creation if profile exists
    final result = await showWorkoutCreationModal(
      context,
      fitnessProfile: _currentProfile,
    );

    if (result != null && result is WorkoutRoutine) {
      setState(() {
        if (result.isCustom) {
          _customRoutines.insert(0, result);
        } else {
          _sampleRoutines.insert(0, result);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.name} created successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildDismissBackground(bool isDark) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 32),
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.trash_fill,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            'Delete',
            style: PremiumTypography.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(
      BuildContext context, WorkoutRoutine routine, bool isDark) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Delete Workout',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${routine.name}"? This action cannot be undone.',
            style: TextStyle(
              fontSize: 15,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.black.withValues(alpha: 0.6),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.black.withValues(alpha: 0.6),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteWorkout(WorkoutRoutine routine) async {
    HapticFeedback.mediumImpact();

    // Optimistically remove from UI
    setState(() {
      if (routine.isCustom) {
        _customRoutines.removeWhere((r) => r.id == routine.id);
      } else {
        _sampleRoutines.removeWhere((r) => r.id == routine.id);
      }
    });

    try {
      // Delete from Supabase for all workouts
      final supabase = Supabase.instance.client;
      await supabase.from('workouts').delete().match({'id': routine.id});

      print('Deleted workout: ${routine.name}');
    } catch (error) {
      // If deletion fails, restore the workout in UI
      setState(() {
        if (routine.isCustom) {
          _customRoutines.add(routine);
        } else {
          _sampleRoutines.add(routine);
        }
      });
      print('Error deleting workout: $error');
    }
  }
}
