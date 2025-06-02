import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/screens/onboarding/results_screen.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:math'; // For min/max
// import 'package:intl/intl.dart'; // For date formatting
// import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:macrotracker/theme/typography.dart';

// Import Page Widgets
import 'pages/welcome_page.dart';
import 'pages/gender_page.dart';
import 'pages/weight_page.dart';
import 'pages/height_page.dart';
import 'pages/age_page.dart';
import 'pages/activity_level_page.dart';
import 'pages/goal_page.dart';
import 'pages/set_new_goal_page.dart'; // Import the new goal details page
// Removed TargetSummaryPage import
import 'pages/advanced_settings_page.dart';
import 'pages/apple_health_page.dart'; // Import the new Apple Health page
import 'pages/summary_page.dart';

// Import new fitness onboarding pages
import 'pages/fitness_level_page.dart';
import 'pages/equipment_preferences_page.dart';
import 'pages/workout_schedule_page.dart';

// Import fitness profile model
import '../../models/fitness_profile.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  OnboardingScreenState createState() => OnboardingScreenState();
}

class OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  // Total pages is now 14, adding 3 new fitness pages
  final int _totalPages =
      14; // Welcome(0)+Gender(1)+Weight(2)+Height(3)+Age(4)+Activity(5)+Goal(6)+SetNewGoal(7)+Fitness(8)+Equipment(9)+Schedule(10)+Advanced(11)+AppleHealth(12)+Summary(13)
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  // --- State Variables ---
  String _gender = MacroCalculatorService.MALE;
  double _weightKg = 70;
  double _heightCm = 170;
  int _age = 30;
  int _activityLevel = MacroCalculatorService.MODERATELY_ACTIVE;
  String _goal = MacroCalculatorService.GOAL_MAINTAIN;
  int _deficit = 500;
  double _proteinRatio = 1.8;
  double _fatRatio = 0.25;
  double _goalWeightKg = 70;
  double _bodyFatPercentage = 20.0;
  bool _isAthlete = false;
  bool _showBodyFatInput = false;
  bool _isMetricWeight = true;
  bool _isMetricHeight = true;

  // --- New Fitness State Variables ---
  String _fitnessLevel = '';
  int _yearsOfExperience = 0;
  List<String> _previousExerciseTypes = [];
  String _workoutLocation = '';
  List<String> _availableEquipment = [];
  bool _hasGymAccess = false;
  String _workoutSpace = '';
  int _workoutsPerWeek = 3;
  int _maxWorkoutDuration = 30;
  String _preferredTimeOfDay = '';
  List<String> _preferredDays = [];
  // --- End State Variables ---

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Initialize animation with default values before first build
    _progressAnimation = Tween<double>(begin: 0, end: 1 / _totalPages).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    // _updateProgressAnimation(); // Removed redundant call
    _animationController.forward();
    _goalWeightKg = _weightKg; // Initialize goal weight
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _updateProgressAnimation() {
    // Ensure division by totalPages is correct and handles _totalPages = 0 case
    double beginFraction = _currentPage / (_totalPages > 0 ? _totalPages : 1);
    double endFraction =
        (_currentPage + 1) / (_totalPages > 0 ? _totalPages : 1);

    _progressAnimation = Tween<double>(
      begin: beginFraction,
      end: endFraction,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  // --- Helper Functions for Projected Date ---
  double _calculateWeeklyRate() {
    if (_goal == MacroCalculatorService.GOAL_MAINTAIN || _deficit == 0) {
      return 0.0;
    }
    const kcalPerKg = 7700.0;
    double weeklyKcalChange =
        _deficit * 7.0 * (_goal == MacroCalculatorService.GOAL_LOSE ? -1 : 1);
    return weeklyKcalChange / kcalPerKg;
  }

  DateTime? _calculateProjectedDate() {
    if (_goal == MacroCalculatorService.GOAL_MAINTAIN) return null;
    double weeklyRate = _calculateWeeklyRate();
    if (weeklyRate.abs() < 0.01) return null;
    double weightDifference = _goalWeightKg - _weightKg;
    if ((_goal == MacroCalculatorService.GOAL_LOSE && weightDifference >= 0) ||
        (_goal == MacroCalculatorService.GOAL_GAIN && weightDifference <= 0)) {
      return null;
    }
    if (weightDifference.abs() < 0.1) return DateTime.now();
    if ((weeklyRate < 0 && _goal == MacroCalculatorService.GOAL_GAIN) ||
        (weeklyRate > 0 && _goal == MacroCalculatorService.GOAL_LOSE)) {
      return null;
    }
    double numberOfWeeks = weightDifference / weeklyRate;
    if (numberOfWeeks <= 0) return DateTime.now();
    if (numberOfWeeks > 52 * 10) numberOfWeeks = 52 * 10;
    int numberOfDays = (numberOfWeeks * 7).round();
    try {
      return DateTime.now().add(Duration(days: numberOfDays));
    } catch (e) {
      debugPrint('Error calculating projected date: $e');
      return null;
    }
  }

  // Helper function to calculate target calories based on current inputs
  double? _calculateTargetCalories() {
    // Use the main calculation method to get consistent results
    final calculatorService = MacroCalculatorService();
    // Call calculateAll with current state to get the target calories
    final results = calculatorService.calculateAll(
      gender: _gender,
      weightKg: _weightKg,
      heightCm: _heightCm,
      age: _age,
      activityLevel: _activityLevel,
      goal: _goal, // Pass the goal
      deficit: _deficit, // Pass the deficit/surplus
      proteinRatio:
          _proteinRatio, // Pass ratios, though not needed for calories
      fatRatio: _fatRatio,
      // Goal weight isn't strictly needed for TDEE/Target Cals but pass for completeness if available
      goalWeightKg:
          _goal != MacroCalculatorService.GOAL_MAINTAIN ? _goalWeightKg : null,
      bodyFatPercentage: _showBodyFatInput ? _bodyFatPercentage : null,
      isAthlete: _isAthlete,
    );

    // Extract target calories from the results map
    final targetCalories = results['target_calories'];

    // Ensure it's a double or null
    if (targetCalories is num) {
      return targetCalories.toDouble();
    }
    return null;
  }
  // --- End Helper Functions ---

  // --- Navigation ---
  void _nextPage() {
    HapticFeedback.selectionClick();
    int currentPageIndex = _currentPage;
    int nextPage = currentPageIndex + 1;

    // Validate ranges before moving from SetNewGoal page (index 7)
    if (currentPageIndex == 7) {
      _validateRanges(); // Keep validation, now triggered after setting goal details
    }

    // Skip SetNewGoalPage (index 7) if goal is Maintain
    if (currentPageIndex == 6 &&
        _goal == MacroCalculatorService.GOAL_MAINTAIN) {
      nextPage = 8; // Skip to Fitness Level (index 8)
    }

    if (nextPage < _totalPages) {
      _goToPage(nextPage);
    } else if (nextPage == _totalPages) {
      // Check if we are at the last logical step
      _calculateAndShowResults();
    }
  }

  void _previousPage() {
    HapticFeedback.selectionClick();
    int currentPageIndex = _currentPage;
    int prevPage = currentPageIndex - 1;

    // Skip SetNewGoalPage (index 7) if goal is Maintain when going back from Fitness Level (index 8)
    if (currentPageIndex == 8 &&
        _goal == MacroCalculatorService.GOAL_MAINTAIN) {
      prevPage = 6; // Go back to Goal Page (index 6)
    }

    if (prevPage >= 0) {
      _goToPage(prevPage);
    }
  }

  void _goToPage(int page) {
    HapticFeedback.selectionClick();
    int targetPage = page;
    bool isSkippingForwardMaintain = false; // Flag for the specific skip

    // Adjust target page if skipping SetNewGoalPage (index 7) for Maintain goal
    // This handles cases where _goToPage might be called with 7 directly
    if (targetPage == 7 && _goal == MacroCalculatorService.GOAL_MAINTAIN) {
      if (_currentPage < 7) {
        // Moving forward from a page before 7
        targetPage = 8; // Skip forward to Fitness Level
        isSkippingForwardMaintain = true; // Mark this specific skip
      } else {
        // Moving backward from a page after 7
        targetPage = 6; // Skip backward to Goal
      }
    }
    // Also handle the specific case triggered by _nextPage when on page 6 and goal is Maintain
    else if (targetPage == 8 &&
        _currentPage == 6 &&
        _goal == MacroCalculatorService.GOAL_MAINTAIN) {
      isSkippingForwardMaintain = true; // Mark this specific skip
    }

    if (targetPage >= 0 &&
        targetPage < _totalPages &&
        targetPage != _currentPage) {
      // Validate if jumping past SetNewGoal page (index 7)
      // This validation might still be relevant even with jumpToPage
      if (_currentPage < 7 && targetPage > 7) _validateRanges();

      if (isSkippingForwardMaintain) {
        // Use jumpToPage for instantaneous transition when skipping forward for Maintain goal
        _pageController.jumpToPage(targetPage);
        // Manually update state and animation since onPageChanged might not fire reliably with jumpToPage
        setState(() {
          _currentPage = targetPage;
          _updateProgressAnimation();
          _animationController.forward(from: 0.0);
        });
      } else {
        // Use animateToPage for all other transitions
        _pageController.animateToPage(targetPage,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut);
        // Let onPageChanged handle state/animation updates for animated transitions
      }
    }
  }
  // --- End Navigation ---

  // --- Calculation & Saving ---
  void _calculateAndShowResults() async {
    final calculatorService = MacroCalculatorService();
    final results = calculatorService.calculateAll(
      gender: _gender,
      weightKg: _weightKg,
      heightCm: _heightCm,
      age: _age,
      activityLevel: _activityLevel,
      goal: _goal,
      deficit: _deficit,
      proteinRatio: _proteinRatio,
      fatRatio: _fatRatio,
      goalWeightKg:
          _goal != MacroCalculatorService.GOAL_MAINTAIN ? _goalWeightKg : null,
      bodyFatPercentage: _showBodyFatInput ? _bodyFatPercentage : null,
      isAthlete: _isAthlete,
    );
    await saveMacroResults(results);
    // Use context safely
    if (!mounted) return;
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          ResultsScreen(results: results),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;
        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
            position: animation.drive(tween),
            child: FadeTransition(opacity: animation, child: child));
      },
      transitionDuration: const Duration(milliseconds: 500),
    ));
  }

  Future<void> saveMacroResults(Map<String, dynamic> macroResults) async {
    try {
      // Create fitness profile from collected data
      final fitnessProfile = FitnessProfile(
        fitnessLevel: _fitnessLevel,
        yearsOfExperience: _yearsOfExperience,
        previousExerciseTypes: _previousExerciseTypes,
        workoutLocation: _workoutLocation,
        availableEquipment: _availableEquipment,
        hasGymAccess: _hasGymAccess,
        workoutSpace: _workoutSpace,
        workoutsPerWeek: _workoutsPerWeek,
        maxWorkoutDuration: _maxWorkoutDuration,
        preferredTimeOfDay: _preferredTimeOfDay,
        preferredDays: _preferredDays,
        lastUpdated: DateTime.now(),
      );

      // Save locally with fitness data
      final expandedResults = {
        ...macroResults,
        'fitness_profile': fitnessProfile.toJson(),
      };
      StorageService().put('macro_results', json.encode(expandedResults));

      // Also save fitness profile separately for easy access
      StorageService()
          .put('fitness_profile', json.encode(fitnessProfile.toJson()));

      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        // Save macro data to user_macros table
        final Map<String, dynamic> supabaseData = {
          'id': currentUser.id,
          'email': currentUser.email ?? '',
          'macro_results': macroResults,
          'calories_goal': (macroResults['target_calories'] ?? 0).toDouble(),
          'protein_goal': (macroResults['protein_g'] ?? 0).toDouble(),
          'carbs_goal': (macroResults['carb_g'] ?? 0).toDouble(),
          'fat_goal': (macroResults['fat_g'] ?? 0).toDouble(),
          'gender': _gender,
          'weight': _weightKg.toDouble(),
          'height': _heightCm.toDouble(),
          'age': _age,
          'activity_level': _activityLevel,
          'goal_type': _goal,
          'deficit_surplus': _deficit,
          'protein_ratio': _proteinRatio.toDouble(),
          'fat_ratio': _fatRatio.toDouble(),
          'goal_weight_kg': _goalWeightKg.toDouble(),
          'current_weight_kg': _weightKg.toDouble(),
          'bmr': macroResults['bmr']?.toDouble(),
          'tdee': macroResults['tdee']?.toDouble(),
          'steps_goal': macroResults['recommended_steps'] ?? 10000,
          'body_fat_percentage':
              _showBodyFatInput ? _bodyFatPercentage.toDouble() : null,
          'updated_at': DateTime.now().toIso8601String(),
          'macro_targets': {
            'calories': (macroResults['target_calories'] ?? 0).toDouble(),
            'protein': (macroResults['protein_g'] ?? 0).toDouble(),
            'carbs': (macroResults['carb_g'] ?? 0).toDouble(),
            'fat': (macroResults['fat_g'] ?? 0).toDouble(),
          },
        };
        supabaseData
            .removeWhere((_, v) => v is double && (v.isNaN || v.isInfinite));
        if (supabaseData['macro_targets'] != null) {
          (supabaseData['macro_targets'] as Map<String, dynamic>)
              .removeWhere((_, v) => v is double && (v.isNaN || v.isInfinite));
        }

        await Supabase.instance.client.from('user_macros').upsert(supabaseData);

        // Save fitness profile data to fitness_profiles table
        final Map<String, dynamic> fitnessData = {
          'user_id': currentUser.id,
          'fitness_level': _fitnessLevel,
          'years_of_experience': _yearsOfExperience,
          'previous_exercise_types': _previousExerciseTypes,
          'workout_location': _workoutLocation,
          'available_equipment': _availableEquipment,
          'has_gym_access': _hasGymAccess,
          'workout_space': _workoutSpace,
          'workouts_per_week': _workoutsPerWeek,
          'max_workout_duration': _maxWorkoutDuration,
          'preferred_time_of_day': _preferredTimeOfDay,
          'preferred_days': _preferredDays,
          'updated_at': DateTime.now().toIso8601String(),
          'last_updated': DateTime.now().toIso8601String(),
        };

        await Supabase.instance.client
            .from('fitness_profiles')
            .upsert(fitnessData, onConflict: 'user_id');

        debugPrint(
            'Successfully saved macro results and fitness profile to Supabase');
      }
      _saveLocalGoals(expandedResults);
    } catch (e) {
      debugPrint('Error saving macro results: $e');
      if (e is PostgrestException) debugPrint('Supabase error: ${e.message}');
      // Consider showing an error message to the user here
      // rethrow; // Rethrowing might crash the app if not caught higher up
    }
  }

  void _saveLocalGoals(Map<String, dynamic> macroResults) {
    final nutritionGoals = {
      'macro_targets': {
        'calories': (macroResults['target_calories'] ?? 0).toDouble(),
        'protein': (macroResults['protein_g'] ?? 0).toDouble(),
        'carbs': (macroResults['carb_g'] ?? 0).toDouble(),
        'fat': (macroResults['fat_g'] ?? 0).toDouble(),
      },
      'goal_weight_kg': _goalWeightKg,
      'current_weight_kg': _weightKg,
      'goal_type': _goal,
      'deficit_surplus': _deficit,
      'protein_ratio': _proteinRatio,
      'fat_ratio': _fatRatio,
      'steps_goal': macroResults['recommended_steps'] ?? 10000,
      'bmr': macroResults['bmr']?.toDouble(),
      'tdee': macroResults['tdee']?.toDouble(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    StorageService().put('nutrition_goals', json.encode(nutritionGoals));
    debugPrint('Successfully saved nutrition goals locally');
  }
  // --- End Calculation & Saving ---

  // --- Validation ---
  void _validateRanges() {
    if (_goal == MacroCalculatorService.GOAL_LOSE) {
      double minWeight = _weightKg * 0.75; // Example lower bound
      _goalWeightKg =
          max(minWeight, _goalWeightKg); // Ensure goal is not too low
      _goalWeightKg = min(
          _goalWeightKg, _weightKg - 0.1); // Ensure goal is less than current
    } else if (_goal == MacroCalculatorService.GOAL_GAIN) {
      double maxWeight = _weightKg * 1.5; // Example upper bound
      _goalWeightKg =
          min(maxWeight, _goalWeightKg); // Ensure goal is not too high
      _goalWeightKg = max(
          _goalWeightKg, _weightKg + 0.1); // Ensure goal is more than current
    }
    // Clamp goal weight to reasonable min/max if needed (e.g., 40kg to 150kg)
    _goalWeightKg = _goalWeightKg.clamp(40.0, 150.0);
  }
  // --- End Validation ---

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    // Get theme and colors
    final theme = Theme.of(context);
    final customColors = Theme.of(context).extension<CustomColors>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator at top
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return LinearProgressIndicator(
                    value: _progressAnimation.value,
                    backgroundColor: (customColors?.dateNavigatorBackground ??
                            theme.colorScheme.surface)
                        .withAlpha((0.3 * 255).round()),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        customColors?.textPrimary ?? theme.colorScheme.primary),
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  );
                },
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Keep physics
                onPageChanged: (index) {
                  // This will now correctly fire after animateToPage completes
                  setState(() {
                    _currentPage = index;
                    _updateProgressAnimation(); // Update animation bounds for the new page
                    _animationController.forward(
                        from: 0.0); // Restart animation for the new segment
                  });
                },
                children: _buildPages(),
              ),
            ),

            // Bottom navigation
            Container(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  _currentPage > 0
                      ? TextButton(
                          onPressed: _previousPage,
                          child: Text(
                            'Back',
                            style: AppTypography.onboardingButton.copyWith(
                              color: customColors?.textSecondary ??
                                  theme.colorScheme.secondary,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : const SizedBox(width: 80), // Empty space for alignment

                  // Next button or Done
                  _buildNextButton(theme, customColors),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextButton(ThemeData theme, CustomColors? customColors) {
    // Hide the button on the Apple Health page (index 12)
    if (_currentPage == 12) {
      // Return an empty SizedBox to maintain layout spacing if needed,
      // or just an empty Container if no space is required.
      // Match the width of the back button for alignment.
      return const SizedBox(width: 80);
    }

    return ElevatedButton(
      onPressed: _nextPage,
      style: ElevatedButton.styleFrom(
        backgroundColor: customColors?.textPrimary ?? theme.colorScheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        elevation: 0,
      ),
      child: Text(
        _currentPage == _totalPages - 1 ? 'Calculate' : 'Next',
        style: AppTypography.onboardingButton.copyWith(
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }

  List<Widget> _buildPages() {
    return [
      const WelcomePage(),
      GenderPage(
        currentGender: _gender,
        onGenderSelected: (newGender) => setState(() => _gender = newGender),
      ),
      WeightPage(
        currentWeightKg: _weightKg,
        isMetric: _isMetricWeight,
        onWeightChanged: (newWeight) => setState(() => _weightKg = newWeight),
        onUnitChanged: (isMetric) => setState(() => _isMetricWeight = isMetric),
      ),
      HeightPage(
        currentHeightCm: _heightCm,
        isMetric: _isMetricHeight,
        onHeightChanged: (newHeight) => setState(() => _heightCm = newHeight),
        onUnitChanged: (isMetric) => setState(() => _isMetricHeight = isMetric),
      ),
      AgePage(
        currentAge: _age,
        onAgeChanged: (newAge) => setState(() => _age = newAge),
      ),
      ActivityLevelPage(
        currentActivityLevel: _activityLevel,
        onActivityLevelChanged: (newLevel) =>
            setState(() => _activityLevel = newLevel),
      ),
      GoalPage(
        // Removed parameters: currentWeightKg, goalWeightKg, deficit, isMetricWeight, projectedDate, onGoalWeightChanged, onDeficitChanged, onWeightUnitChanged
        currentGoal: _goal,
        onGoalChanged: (newGoal) => setState(() {
          _goal = newGoal;
          // Logic to reset goal weight/deficit when goal changes remains here
          if (_goal == MacroCalculatorService.GOAL_MAINTAIN) {
            _goalWeightKg = _weightKg;
            _deficit = 0;
            // // Navigate immediately if Maintain is selected
            // // Need WidgetsBinding.instance.addPostFrameCallback to avoid calling
            // // _goToPage during build/setState.
            // WidgetsBinding.instance.addPostFrameCallback((_) {
            //   // Check mounted again inside the callback for safety
            //   if (mounted && _goal == MacroCalculatorService.GOAL_MAINTAIN) {
            //     _goToPage(8); // Go directly to Advanced Settings (index 8)
            //   }
            // });
          } else {
            _deficit = 500;
            _goalWeightKg = _goal == MacroCalculatorService.GOAL_LOSE
                ? max(40.0, _weightKg * 0.9)
                : min(150.0, _weightKg * 1.1);
            _validateRanges(); // Keep validation logic here
          }
        }),
        // Removed onGoalWeightChanged, onDeficitChanged, onWeightUnitChanged callbacks
      ),
      // Replace TargetSummaryPage with SetNewGoalPage (index 7)
      SetNewGoalPage(
        currentGoal: _goal,
        currentWeightKg: _weightKg,
        goalWeightKg: _goalWeightKg,
        deficit: _deficit,
        isMetricWeight: _isMetricWeight,
        projectedDate: _calculateProjectedDate(),
        targetCalories: _calculateTargetCalories(),
        onGoalWeightChanged: (newWeight) => setState(() {
          _goalWeightKg = newWeight;
          _validateRanges();
        }),
        onDeficitChanged: (newDeficit) => setState(() => _deficit = newDeficit),
        onWeightUnitChanged: (isMetric) =>
            setState(() => _isMetricWeight = isMetric),
      ),

      // NEW FITNESS ONBOARDING PAGES (index 8, 9, 10)
      FitnessLevelPage(
        currentFitnessLevel: _fitnessLevel,
        yearsOfExperience: _yearsOfExperience,
        previousExerciseTypes: _previousExerciseTypes,
        onFitnessLevelChanged: (level) => setState(() => _fitnessLevel = level),
        onYearsOfExperienceChanged: (years) =>
            setState(() => _yearsOfExperience = years),
        onPreviousExerciseTypesChanged: (types) =>
            setState(() => _previousExerciseTypes = types),
      ),
      EquipmentPreferencesPage(
        workoutLocation: _workoutLocation,
        availableEquipment: _availableEquipment,
        hasGymAccess: _hasGymAccess,
        workoutSpace: _workoutSpace,
        onWorkoutLocationChanged: (location) =>
            setState(() => _workoutLocation = location),
        onAvailableEquipmentChanged: (equipment) =>
            setState(() => _availableEquipment = equipment),
        onGymAccessChanged: (hasAccess) =>
            setState(() => _hasGymAccess = hasAccess),
        onWorkoutSpaceChanged: (space) => setState(() => _workoutSpace = space),
      ),
      WorkoutSchedulePage(
        workoutsPerWeek: _workoutsPerWeek,
        maxWorkoutDuration: _maxWorkoutDuration,
        preferredTimeOfDay: _preferredTimeOfDay,
        preferredDays: _preferredDays,
        onWorkoutsPerWeekChanged: (count) =>
            setState(() => _workoutsPerWeek = count),
        onMaxWorkoutDurationChanged: (duration) =>
            setState(() => _maxWorkoutDuration = duration),
        onPreferredTimeOfDayChanged: (time) =>
            setState(() => _preferredTimeOfDay = time),
        onPreferredDaysChanged: (days) => setState(() => _preferredDays = days),
      ),

      AdvancedSettingsPage(
        // Now at index 11
        isAthlete: _isAthlete, showBodyFatInput: _showBodyFatInput,
        bodyFatPercentage: _bodyFatPercentage,
        proteinRatio: _proteinRatio, fatRatio: _fatRatio,
        gender: _gender,
        onAthleteChanged: (isAthlete) => setState(() => _isAthlete = isAthlete),
        onShowBodyFatChanged: (show) =>
            setState(() => _showBodyFatInput = show),
        onBodyFatChanged: (bfp) => setState(() => _bodyFatPercentage = bfp),
        onProteinRatioChanged: (ratio) => setState(() => _proteinRatio = ratio),
        onFatRatioChanged: (ratio) => setState(() => _fatRatio = ratio),
      ),
      // Add Apple Health integration page (index 12)
      AppleHealthPage(
        onNext: _nextPage,
        onSkip: _nextPage,
      ),
      SummaryPage(
        // Now at index 13
        gender: _gender, weightKg: _weightKg, heightCm: _heightCm,
        age: _age,
        activityLevel: _activityLevel, goal: _goal,
        deficit: _deficit,
        proteinRatio: _proteinRatio, fatRatio: _fatRatio,
        goalWeightKg: _goalWeightKg,
        isAthlete: _isAthlete, showBodyFatInput: _showBodyFatInput,
        bodyFatPercentage: _bodyFatPercentage,
        onEdit: _goToPage, // _goToPage handles indices correctly
      ),
    ];
  }
}
