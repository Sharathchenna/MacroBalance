import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/screens/onboarding/results_screen.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:math'; // For min/max
import 'package:intl/intl.dart'; // For date formatting
import 'package:flutter/foundation.dart'; // For debugPrint
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

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  // Total pages is now 11, adding Apple Health page
  final int _totalPages =
      11; // Welcome(0)+Gender(1)+Weight(2)+Height(3)+Age(4)+Activity(5)+Goal(6)+SetNewGoal(7)+Advanced(8)+AppleHealth(9)+Summary(10)
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
    _updateProgressAnimation(); // Set correct initial animation state
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
    if (_goal == MacroCalculatorService.GOAL_MAINTAIN || _deficit == 0)
      return 0.0;
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
        (_goal == MacroCalculatorService.GOAL_GAIN && weightDifference <= 0))
      return null;
    if (weightDifference.abs() < 0.1) return DateTime.now();
    if ((weeklyRate < 0 && _goal == MacroCalculatorService.GOAL_GAIN) ||
        (weeklyRate > 0 && _goal == MacroCalculatorService.GOAL_LOSE))
      return null;
    double numberOfWeeks = weightDifference / weeklyRate;
    if (numberOfWeeks <= 0) return DateTime.now();
    if (numberOfWeeks > 52 * 10) numberOfWeeks = 52 * 10;
    int numberOfDays = (numberOfWeeks * 7).round();
    try {
      return DateTime.now().add(Duration(days: numberOfDays));
    } catch (e) {
      debugPrint("Error calculating projected date: $e");
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
    int currentPageIndex = _currentPage;
    int nextPage = currentPageIndex + 1;

    // Validate ranges before moving from SetNewGoal page (index 7)
    if (currentPageIndex == 7) {
      _validateRanges(); // Keep validation, now triggered after setting goal details
    }

    // Skip SetNewGoalPage (index 7) if goal is Maintain
    if (currentPageIndex == 6 &&
        _goal == MacroCalculatorService.GOAL_MAINTAIN) {
      nextPage = 8; // Skip to Advanced Settings (index 8)
    }

    if (nextPage < _totalPages) {
      _goToPage(nextPage);
    } else if (nextPage == _totalPages) {
      // Check if we are at the last logical step
      _calculateAndShowResults();
    }
  }

  void _previousPage() {
    int currentPageIndex = _currentPage;
    int prevPage = currentPageIndex - 1;

    // Skip SetNewGoalPage (index 7) if goal is Maintain when going back from Advanced (index 8)
    if (currentPageIndex == 8 &&
        _goal == MacroCalculatorService.GOAL_MAINTAIN) {
      prevPage = 6; // Go back to Goal Page (index 6)
    }

    if (prevPage >= 0) {
      _goToPage(prevPage);
    }
  }

  void _goToPage(int page) {
    // Adjust target page if skipping SetNewGoalPage (index 7) for Maintain goal
    int targetPage = page;
    if (targetPage == 7 && _goal == MacroCalculatorService.GOAL_MAINTAIN) {
      // If trying to go to page 7 and goal is maintain, redirect based on direction
      if (_currentPage < 7) {
        targetPage = 8; // Skip forward to Advanced
      } else {
        targetPage = 6; // Skip backward to Goal
      }
    }

    if (targetPage >= 0 &&
        targetPage < _totalPages &&
        targetPage != _currentPage) {
      // Validate if jumping past SetNewGoal page (index 7)
      if (_currentPage < 7 && targetPage > 7) _validateRanges();

      int oldPage = _currentPage;
      setState(() {
        // Update _currentPage to the actual target page index
        _currentPage = targetPage;
        // Update animation based on the jump to the target page
        _progressAnimation = Tween<double>(
          begin: oldPage / _totalPages,
          end: (targetPage + 1) /
              _totalPages, // Animate towards the end of the target page
        ).animate(CurvedAnimation(
            parent: _animationController, curve: Curves.easeInOut));
      });

      _pageController.animateToPage(targetPage,
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      _animationController.forward(from: 0);
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
      StorageService().put('macro_results', json.encode(macroResults));
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
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
        if (supabaseData['macro_targets'] != null)
          (supabaseData['macro_targets'] as Map<String, dynamic>)
              .removeWhere((_, v) => v is double && (v.isNaN || v.isInfinite));
        await Supabase.instance.client.from('user_macros').upsert(supabaseData);
        debugPrint('Successfully saved macro results to Supabase');
      }
      _saveLocalGoals(macroResults);
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
                        .withOpacity(0.3),
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
                physics: NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                    _updateProgressAnimation();
                    _animationController.forward(from: 0.0);
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
                      : SizedBox(width: 80), // Empty space for alignment

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
    return ElevatedButton(
      onPressed: _nextPage,
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
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
      AdvancedSettingsPage(
        // Now at index 8
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
      // Add Apple Health integration page (index 9)
      AppleHealthPage(
        onNext: _nextPage,
        onSkip: _nextPage,
      ),
      SummaryPage(
        // Now at index 10
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
