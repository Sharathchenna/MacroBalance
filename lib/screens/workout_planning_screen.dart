import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // For User
import '../theme/app_theme.dart';
import '../theme/workout_colors.dart';
import '../models/workout_plan.dart';
import '../models/fitness_profile.dart'; // Import FitnessProfile
import '../services/fitness_ai_service.dart'; // Import FitnessAIService
import '../screens/workout_details_screen.dart';
import '../screens/ai_workout_creator_screen.dart';

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

  // Sample data - in real app this would come from a provider/service
  List<WorkoutRoutine> _sampleRoutines = [
    WorkoutRoutine(
      name: 'Beginner Bodyweight Workout',
      description: 'A complete bodyweight workout perfect for beginners',
      estimatedDurationMinutes: 25,
      difficulty: 'Beginner',
      targetMuscles: ['Chest', 'Arms'],
      requiredEquipment: [],
      isCustom: false,
    ),
    WorkoutRoutine(
      name: 'HIIT Cardio Blast',
      description: 'High-intensity interval training for maximum burn',
      estimatedDurationMinutes: 30,
      difficulty: 'Intermediate',
      targetMuscles: ['Full Body'],
      requiredEquipment: [],
      isCustom: false,
    ),
  ];

  // Mock stats
  int totalRoutines = 0; // Start with 0 AI workouts
  int thisWeekWorkouts = 3;
  int streakDays = 7;

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

    _loadFitnessProfileAndData(); // Load profile and then data

    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _scaleController.forward();
    });
  }

  Future<void> _loadFitnessProfileAndData() async {
    setState(() {
      _isLoadingProfile = true;
    });
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _currentProfile = await _fitnessAIService.getFitnessProfile(user.id);
      // TODO: Once workout plans are stored in Supabase, fetch them here
      // For now, we'll keep using sample routines if profile is loaded
      // or clear them if profile loading fails (or no profile)
      if (_currentProfile != null) {
        // Potentially update totalRoutines based on profile or fetched routines
        // For now, just log that profile was loaded.
        print('Fitness profile loaded for user: ${user.id}');
      } else {
        print(
            'No fitness profile found for user: ${user.id} or error loading.');
        // _sampleRoutines = []; // Optionally clear routines if no profile
      }
    } else {
      print('User not logged in. Cannot load fitness profile.');
      // _sampleRoutines = []; // Optionally clear routines if no user
    }
    setState(() {
      _isLoadingProfile = false;
      // Update totalRoutines based on actual data if available
      totalRoutines = _sampleRoutines.where((r) => r.isCustom).length;
    });
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
      backgroundColor: isDark ? PremiumColors.darkBackground : Colors.white,
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
      backgroundColor: isDark ? PremiumColors.darkBackground : Colors.white,
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
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? PremiumColors.darkCard : PremiumColors.slate50,
        borderRadius: BorderRadius.circular(24),
        border: isDark
            ? Border.all(color: PremiumColors.darkBorder, width: 1)
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
      child: Row(
        children: [
          _buildStatItem(
            context,
            isDark,
            CupertinoIcons.chart_bar_alt_fill,
            totalRoutines.toString(),
            'Total Routines',
            isDark ? Colors.white : Colors.black,
          ),
          const SizedBox(width: 32),
          _buildStatItem(
            context,
            isDark,
            CupertinoIcons.calendar,
            thisWeekWorkouts.toString(),
            'This Week',
            isDark ? Colors.white : Colors.black,
          ),
          const SizedBox(width: 32),
          _buildStatItem(
            context,
            isDark,
            CupertinoIcons.flame_fill,
            '$streakDays days',
            'Streak',
            isDark ? Colors.white : Colors.black,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    bool isDark,
    IconData icon,
    String value,
    String label,
    Color accentColor,
  ) {
    return Expanded(
      child: Column(
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
              color: isDark ? Colors.white : Colors.black,
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
      ),
    );
  }

  Widget _buildRoutinesSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Routines',
                style: PremiumTypography.h3.copyWith(
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              TextButton.icon(
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
        ),
        const SizedBox(height: 16),
        ..._sampleRoutines.asMap().entries.map((entry) {
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
        const SizedBox(height: 100), // Space for FAB
      ],
    );
  }

  Widget _buildWorkoutCard(
      BuildContext context, WorkoutRoutine routine, bool isDark) {
    final accentColor = isDark ? Colors.white : Colors.black;

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
            color: isDark ? PremiumColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isDark
                ? Border.all(color: PremiumColors.darkBorder, width: 1)
                : null,
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openWorkoutDetails(routine),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      _buildWorkoutIcon(accentColor),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildWorkoutInfo(context, routine, isDark),
                      ),
                      _buildPlayButton(isDark),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutIcon(Color accentColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        CupertinoIcons.flame_fill,
        color: isDark ? Colors.white : Colors.black,
        size: 28,
      ),
    );
  }

  Widget _buildWorkoutInfo(
      BuildContext context, WorkoutRoutine routine, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          routine.name,
          style: PremiumTypography.h4.copyWith(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
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
              isDark ? Colors.white : Colors.black,
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
              Text(
                '+${routine.targetMuscles.length - 2} more',
                style: PremiumTypography.caption.copyWith(
                  color: isDark
                      ? PremiumColors.darkTextSecondary
                      : PremiumColors.slate400,
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
              color: isDark
                  ? PremiumColors.darkTextSecondary
                  : PremiumColors.slate400,
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
        color: isDark ? PremiumColors.darkContainer : PremiumColors.slate100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        muscle.toUpperCase(),
        style: PremiumTypography.caption.copyWith(
          color:
              isDark ? PremiumColors.darkTextSecondary : PremiumColors.slate600,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPlayButton(bool isDark) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? PremiumColors.darkContainer : PremiumColors.slate100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        CupertinoIcons.play_fill,
        color: isDark ? Colors.white : Colors.black,
        size: 20,
      ),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context, bool isDark) {
    return FloatingActionButton.extended(
      onPressed: () => _createAIWorkout(),
      backgroundColor: isDark ? Colors.white : Colors.black,
      foregroundColor: isDark ? Colors.black : Colors.white,
      elevation: 8,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.sparkles,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'AI Workout',
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
    // Add haptic feedback
    HapticFeedback.lightImpact();

    // Show loading state briefly
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshing workouts...'),
        duration: Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
        backgroundColor: PremiumColors.slate700,
      ),
    );

    // Reload profile and data
    await _loadFitnessProfileAndData();
    // In a real app, this would re-fetch workout routines from Supabase
    // For now, it re-evaluates _sampleRoutines or clears them based on profile status

    // If still using sample data after profile load, reset it here or fetch from Supabase
    // This part needs to be adapted once workout routines are stored in Supabase
    if (_currentProfile != null) {
      // TODO: Fetch actual routines from Supabase based on _currentProfile
      // For now, resetting to sample if needed, or ideally, routines are fetched in _loadFitnessProfileAndData
      setState(() {
        // This is a placeholder. Actual routines should come from Supabase.
        _sampleRoutines = [
          WorkoutRoutine(
            name: 'Beginner Bodyweight Workout (Refreshed)',
            description: 'A complete bodyweight workout perfect for beginners',
            estimatedDurationMinutes: 25,
            difficulty: 'Beginner',
            targetMuscles: ['Chest', 'Arms'],
            requiredEquipment: [],
            isCustom: false,
          ),
          WorkoutRoutine(
            name: 'HIIT Cardio Blast (Refreshed)',
            description: 'High-intensity interval training for maximum burn',
            estimatedDurationMinutes: 30,
            difficulty: 'Intermediate',
            targetMuscles: ['Full Body'],
            requiredEquipment: [],
            isCustom: false,
          ),
        ];
        totalRoutines = _sampleRoutines.where((r) => r.isCustom).length;
      });
      print(
          'Refreshed workouts - ideally from Supabase, currently sample data reloaded.');
    } else {
      print('Profile not loaded, cannot refresh workouts from Supabase.');
      // Optionally clear routines or show an error
      setState(() {
        _sampleRoutines = [];
        totalRoutines = 0;
      });
    }
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

  void _createAIWorkout() async {
    // Add haptic feedback
    HapticFeedback.lightImpact();

    if (_currentProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please complete your fitness profile to create AI workouts.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      // Optionally, navigate to onboarding or show a dialog
      return;
    }

    // Navigate to AI workout creator
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AIWorkoutCreatorScreen(
          // Pass the current fitness profile to the creator screen
          // This assumes AIWorkoutCreatorScreen is updated to accept it.
          fitnessProfile: _currentProfile!,
        ),
      ),
    );

    // If a workout was created, add it to the list
    if (result != null && result is WorkoutRoutine) {
      setState(() {
        _sampleRoutines.insert(0, result); // Add to beginning of list
        totalRoutines++; // Update stats
        // TODO: Save the new AI workout routine to Supabase
        // if (_currentProfile != null) {
        //   _fitnessAIService.saveWorkoutRoutine(_currentProfile!.userId, result);
        // }
      });
    }
  }

  Widget _buildDismissBackground(bool isDark) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 32),
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF8B0000) : const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
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
          backgroundColor: isDark ? PremiumColors.darkCard : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Delete Workout',
            style: PremiumTypography.h4.copyWith(
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${routine.name}"? This action cannot be undone.',
            style: PremiumTypography.bodyMedium.copyWith(
              color: isDark
                  ? PremiumColors.darkTextSecondary
                  : PremiumColors.slate600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: PremiumTypography.button.copyWith(
                  color: isDark
                      ? PremiumColors.darkTextSecondary
                      : PremiumColors.slate600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                backgroundColor:
                    isDark ? const Color(0xFF8B0000) : const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Delete',
                style: PremiumTypography.button.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _deleteWorkout(WorkoutRoutine routine) {
    // Add haptic feedback
    HapticFeedback.mediumImpact();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Remove from sample routines list
    setState(() {
      _sampleRoutines.removeWhere((r) => r.id == routine.id);
      if (routine.name.contains('AI')) {
        // Update stats if it was an AI workout
        if (totalRoutines > 0) totalRoutines--;
      }
    });

    // Show confirmation snackbar with undo option
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${routine.name} deleted'),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isDark ? PremiumColors.slate700 : PremiumColors.slate800,
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () => _undoDeleteWorkout(routine),
        ),
      ),
    );

    // In real app, this would delete from the database/service
    print('Deleted workout: ${routine.name}');
  }

  void _undoDeleteWorkout(WorkoutRoutine routine) {
    // Add haptic feedback
    HapticFeedback.lightImpact();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Add back to sample routines list
    setState(() {
      _sampleRoutines.add(routine);
      if (routine.name.contains('AI')) {
        totalRoutines++;
      }
    });

    // Show restored confirmation
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${routine.name} restored'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isDark ? PremiumColors.slate700 : PremiumColors.slate800,
      ),
    );

    print('Restored workout: ${routine.name}');
  }
}
