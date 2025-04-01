import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/screens/onboarding/results_screen.dart';
import 'package:macrotracker/theme/app_theme.dart'; // Import theme
import 'package:numberpicker/numberpicker.dart'; // Add this import
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:math'; // Import dart:math for min/max functions
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:flutter/foundation.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 7; // Increased by 1 for summary page
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  // User data
  String _gender = MacroCalculatorService.MALE;
  double _weightKg = 70;
  double _heightCm = 170;
  int _age = 30;
  int _activityLevel = MacroCalculatorService.MODERATELY_ACTIVE;
  String _goal = MacroCalculatorService.GOAL_MAINTAIN;
  int _deficit = 500;
  double _proteinRatio = 1.8;
  double _fatRatio = 0.25;
  double _goalWeightKg = 70; // Added goal weight tracking
  double _bodyFatPercentage = 20.0; // Add body fat percentage variable
  bool _isAthlete = false; // Whether the user is an athlete
  bool _showBodyFatInput = false; // Flag to show/hide body fat input

  // Removed unit system toggle - always using metric
  bool _isMetricWeight = true;
  bool _isMetricHeight = true;

  int _imperialWeightLbs = 154; // Imperial weight in lbs
  int _imperialGoalWeightLbs = 154; // Imperial goal weight in lbs
  int _imperialHeightFeet = 5; // Imperial height in feet
  int _imperialHeightInches = 9; // Imperial height in inches

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _progressAnimation = Tween<double>(
      begin: 0,
      end: 1 / _totalPages,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();

    // Initialize goal weight to match current weight
    _goalWeightKg = _weightKg;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // Update the _nextPage() and _previousPage() methods

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      // If moving from goal page, validate the goal weight
      if (_currentPage == 4) {
        _validateRanges();
      }

      setState(() {
        _currentPage++;
        _progressAnimation = Tween<double>(
          begin: _currentPage / _totalPages,
          end: (_currentPage + 1) / _totalPages,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOut,
        ));
      });

      // Animate to next page
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );

      // Animate progress
      _animationController.forward(from: 0);
    } else {
      // Final page - calculate and show results
      _calculateAndShowResults();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
        _progressAnimation = Tween<double>(
          begin: (_currentPage + 1) / _totalPages,
          end: _currentPage / _totalPages,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOut,
        ));
      });

      // Animate to previous page
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );

      // Animate progress
      _animationController.forward(from: 0);
    }
  }

  void _goToPage(int page) {
    if (page >= 0 && page < _totalPages) {
      setState(() {
        _currentPage = page;
        _progressAnimation = Tween<double>(
          begin: _currentPage / _totalPages,
          end: (_currentPage + 1) / _totalPages,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOut,
        ));
      });

      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );

      // Animate progress
      _animationController.forward(from: 0);
    }
  }

  void _calculateAndShowResults() async {
    // Calculate results first without showing the paywall
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

    // Save macro results
    await saveMacroResults(results);

    // Navigate to results screen with a transition
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ResultsScreen(results: results),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  Future<void> saveMacroResults(Map<String, dynamic> macroResults) async {
    try {
      // Save locally first
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('macro_results', json.encode(macroResults));

      // Save to Supabase if user is authenticated
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        // Prepare data with proper type conversion
        final Map<String, dynamic> supabaseData = {
          'id': currentUser.id,
          'email': currentUser.email ?? '',
          'macro_results': macroResults,
          'calories_goal':
              (macroResults['calories'] ?? macroResults['calorie_target'])
                  ?.toDouble(),
          'protein_goal': macroResults['protein']?.toDouble(),
          'carbs_goal': macroResults['carbs']?.toDouble(),
          'fat_goal': macroResults['fat']?.toDouble(),
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
            'calories': (macroResults['calories'] ??
                    macroResults['calorie_target'] ??
                    0)
                .toDouble(),
            'protein': (macroResults['protein'] ?? 0).toDouble(),
            'carbs': (macroResults['carbs'] ?? 0).toDouble(),
            'fat': (macroResults['fat'] ?? 0).toDouble(),
          },
        };

        // Remove any NaN or infinite values
        supabaseData.removeWhere(
            (_, value) => value is double && (value.isNaN || value.isInfinite));

        // Validate and clean nested maps
        if (supabaseData['macro_targets'] != null) {
          (supabaseData['macro_targets'] as Map<String, dynamic>).removeWhere(
              (_, value) =>
                  value is double && (value.isNaN || value.isInfinite));
        }

        // Try to update first, if it fails then insert
        try {
          await Supabase.instance.client
              .from('user_macros')
              .upsert(supabaseData);

          debugPrint('Successfully saved macro results to Supabase');

          // Verify the sync
          final verification = await Supabase.instance.client
              .from('user_macros')
              .select()
              .eq('id', currentUser.id)
              .single();

          if (verification != null) {
            debugPrint('Sync verification successful');
            debugPrint('Calories goal: ${verification['calories_goal']}');
            debugPrint('Weight: ${verification['weight']}');
          }
        } catch (e) {
          debugPrint('Error in Supabase upsert: $e');
          // If upsert fails, try insert
          await Supabase.instance.client
              .from('user_macros')
              .insert(supabaseData);
        }
      }

      // Always save to local storage for offline access
      await _saveLocalGoals(macroResults);
    } catch (e) {
      debugPrint('Error saving macro results: $e');
      if (e is PostgrestException) {
        debugPrint('Supabase error: ${e.message}');
      }
      rethrow; // Re-throw to handle in UI
    }
  }

  Future<void> _saveLocalGoals(Map<String, dynamic> macroResults) async {
    final prefs = await SharedPreferences.getInstance();

    // Save comprehensive nutrition goals
    final nutritionGoals = {
      'macro_targets': {
        'calories':
            (macroResults['calories'] ?? macroResults['calorie_target'] ?? 0)
                .toDouble(),
        'protein': (macroResults['protein'] ?? 0).toDouble(),
        'carbs': (macroResults['carbs'] ?? 0).toDouble(),
        'fat': (macroResults['fat'] ?? 0).toDouble(),
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

    await prefs.setString('nutrition_goals', json.encode(nutritionGoals));
    debugPrint('Successfully saved nutrition goals locally');
  }

  @override
  Widget build(BuildContext context) {
    // Get the custom colors from theme
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Enhanced progress tracker
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Progress background
                          Container(
                            height: 12,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),

                          // Progress indicator
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: _progressAnimation.value,
                              child: Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(context).colorScheme.primary,
                                      Theme.of(context).colorScheme.secondary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  // Step indicator text
                  Text(
                    'Step ${_currentPage + 1} of $_totalPages',
                    style: TextStyle(
                      color: customColors?.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Page content with improved transitions
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildWelcomePage(),
                  _buildGenderPage(),
                  _buildBodyMeasurementsPage(),
                  _buildActivityLevelPage(),
                  _buildGoalPage(),
                  _buildAdvancedSettingsPage(),
                  _buildSummaryPage(), // New summary page
                ],
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _currentPage > 0
                      ? TextButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            _previousPage();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_back_rounded,
                                size: 16,
                                color: customColors?.textPrimary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Back',
                                style: TextStyle(
                                  color: customColors?.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(width: 80),
                  ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _nextPage();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 2,
                      shadowColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.3),
                      backgroundColor: customColors!.textPrimary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      surfaceTintColor: Colors.transparent,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage == _totalPages - 1
                              ? 'Calculate'
                              : 'Next',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _currentPage == _totalPages - 1
                              ? Icons.check_circle_outline_rounded
                              : Icons.arrow_forward_rounded,
                          size: 16,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // App logo/icon with animation
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          customColors!.dateNavigatorBackground
                              .withOpacity(0.8),
                          Theme.of(context)
                              .colorScheme
                              .onSecondary
                              .withOpacity(0.8),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary
                              .withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        Theme.of(context).brightness == Brightness.light
                            ? 'assets/icons/icon_black.png'
                            : 'assets/icons/icon_white.png',
                        width: 200,
                        height: 200,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 40),

          // Animated title
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Text(
                    'Welcome to MacroBalance',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: customColors?.textPrimary,
                          fontSize: 24,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Animated description
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Text(
                    'Let\'s personalize your experience by calculating your optimal macronutrients intake.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: customColors?.textPrimary,
                          height: 1.5,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 40),

          // Feature highlights
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFeatureItem(
                        icon: Icons.calculate_outlined,
                        label: 'Calculate',
                      ),
                      _buildFeatureItem(
                        icon: Icons.track_changes_outlined,
                        label: 'Track',
                      ),
                      _buildFeatureItem(
                        icon: Icons.trending_up_outlined,
                        label: 'Progress',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({required IconData icon, required String label}) {
    final customColors = Theme.of(context).extension<CustomColors>();

    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Icon(
              icon,
              color: customColors!.textPrimary.withOpacity(0.8),
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: customColors?.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildGenderPage() {
    final customColors = Theme.of(context).extension<CustomColors>();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What\'s your biological sex?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: customColors?.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'We use this for calculating your basal metabolic rate.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: customColors?.textPrimary,
                ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: _buildSelectionCard(
                  isSelected: _gender == MacroCalculatorService.MALE,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _gender = MacroCalculatorService.MALE);
                  },
                  icon: Icons.male,
                  label: 'Male',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSelectionCard(
                  isSelected: _gender == MacroCalculatorService.FEMALE,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _gender = MacroCalculatorService.FEMALE);
                  },
                  icon: Icons.female,
                  label: 'Female',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBodyMeasurementsPage() {
    final customColors = Theme.of(context).extension<CustomColors>();
    // Create a scroll controller to detect scroll position
    final ScrollController scrollController = ScrollController();
    // State variable to track if we're at the bottom of the scroll
    final ValueNotifier<bool> isAtBottom = ValueNotifier<bool>(false);

    // Add listener to check scroll position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.addListener(() {
          if (scrollController.position.pixels >=
              scrollController.position.maxScrollExtent - 20) {
            isAtBottom.value = true;
          } else {
            isAtBottom.value = false;
          }
        });
      }
    });

    // Function to scroll to the bottom
    void scrollToBottom() {
      if (scrollController.hasClients) {
        HapticFeedback.lightImpact();
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
        );
      }
    }

    return Stack(
      children: [
        SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your body measurements',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: customColors?.textPrimary,
                    ),
              ),
              const SizedBox(height: 32),

              // Weight Picker
              Row(
                children: [
                  Text(
                    'Weight',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: customColors?.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 8),
                  _buildTooltip(
                      'Your current body weight is used to calculate your daily caloric needs'),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: customColors?.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Unit selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildUnitSelector(
                          isMetric: _isMetricWeight,
                          metricUnit: 'kg',
                          imperialUnit: 'lbs',
                          onChanged: (isMetric) {
                            HapticFeedback.heavyImpact();
                            setState(() {
                              _isMetricWeight = isMetric;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Weight pickers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isMetricWeight) ...[
                          // Metric (kg) pickers
                          NumberPicker(
                            value: _weightKg.floor(),
                            minValue: 30,
                            maxValue: 200,
                            onChanged: (value) {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _weightKg =
                                    value + (_weightKg - _weightKg.floor());
                              });
                            },
                            selectedTextStyle: TextStyle(
                              color: customColors?.textPrimary,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                            textStyle: TextStyle(
                              color: customColors?.textSecondary,
                              fontSize: 20,
                            ),
                          ),
                          Text(
                            '.',
                            style: TextStyle(
                              color: customColors?.textPrimary,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          NumberPicker(
                            value:
                                ((_weightKg - _weightKg.floor()) * 10).round(),
                            minValue: 0,
                            maxValue: 9,
                            onChanged: (value) {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _weightKg = _weightKg.floor() + (value / 10);
                              });
                            },
                            selectedTextStyle: TextStyle(
                              color: customColors?.textPrimary,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                            textStyle: TextStyle(
                              color: customColors?.textSecondary,
                              fontSize: 20,
                            ),
                          ),
                        ] else ...[
                          // Imperial (lbs) picker
                          NumberPicker(
                            value: (_weightKg * 2.20462).round(),
                            minValue: 66, // 30kg in lbs
                            maxValue: 441, // 200kg in lbs
                            onChanged: (value) {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _weightKg = value / 2.20462;
                              });
                            },
                            selectedTextStyle: TextStyle(
                              color: customColors?.textPrimary,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                            textStyle: TextStyle(
                              color: customColors?.textSecondary,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Height Picker
              Row(
                children: [
                  Text(
                    'Height',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: customColors?.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 8),
                  _buildTooltip(
                      'Your height is used to calculate your BMI and base metabolic rate'),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: customColors?.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Unit selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildUnitSelector(
                          isMetric: _isMetricHeight,
                          metricUnit: 'cm',
                          imperialUnit: 'ft',
                          onChanged: (isMetric) {
                            HapticFeedback.heavyImpact();
                            setState(() {
                              _isMetricHeight = isMetric;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Height pickers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isMetricHeight) ...[
                          // Metric (cm) picker
                          NumberPicker(
                            value: _heightCm.round(),
                            minValue: 90,
                            maxValue: 220,
                            onChanged: (value) {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _heightCm = value.toDouble();
                              });
                            },
                            selectedTextStyle: TextStyle(
                              color: customColors?.textPrimary,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                            textStyle: TextStyle(
                              color: customColors?.textSecondary,
                              fontSize: 20,
                            ),
                          ),
                        ] else ...[
                          // Imperial (ft & in) pickers
                          NumberPicker(
                            value: max(3, min(7, (_heightCm / 30.48).floor())),
                            minValue: 3,
                            maxValue: 7,
                            onChanged: (feet) {
                              HapticFeedback.lightImpact();
                              // Calculate current inches, ensuring value stays within bounds
                              double remainingCm = _heightCm -
                                  ((_heightCm / 30.48).floor() * 30.48);
                              int currentInches =
                                  max(0, min(11, (remainingCm / 2.54).round()));

                              setState(() {
                                _heightCm =
                                    (feet * 30.48) + (currentInches * 2.54);
                              });
                            },
                            selectedTextStyle: TextStyle(
                              color: customColors?.textPrimary,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                            textStyle: TextStyle(
                              color: customColors?.textSecondary,
                              fontSize: 20,
                            ),
                          ),
                          Text(
                            'ft',
                            style: TextStyle(
                              color: customColors?.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          NumberPicker(
                            value: max(0,
                                min(11, ((_heightCm % 30.48) / 2.54).round())),
                            minValue: 0,
                            maxValue: 11,
                            onChanged: (inches) {
                              HapticFeedback.lightImpact();
                              final feet = (_heightCm / 30.48).floor();
                              setState(() {
                                _heightCm = (feet * 30.48) + (inches * 2.54);
                              });
                            },
                            selectedTextStyle: TextStyle(
                              color: customColors?.textPrimary,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                            textStyle: TextStyle(
                              color: customColors?.textSecondary,
                              fontSize: 20,
                            ),
                          ),
                          Text(
                            'in',
                            style: TextStyle(
                              color: customColors?.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Age Picker
              Row(
                children: [
                  Text(
                    'Age',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: customColors?.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 8),
                  _buildTooltip(
                      'Your age affects your basal metabolic rate (BMR) calculation'),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: customColors?.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    NumberPicker(
                      value: _age,
                      minValue: 18,
                      maxValue: 80,
                      onChanged: (value) {
                        HapticFeedback.lightImpact();
                        setState(() => _age = value);
                      },
                      selectedTextStyle: TextStyle(
                        color: customColors?.textPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      textStyle: TextStyle(
                        color: customColors?.textSecondary,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'years',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Extra padding to ensure content can scroll enough to hide arrow
              const SizedBox(height: 60),
            ],
          ),
        ),

        // Scroll indicator arrow - positioned on the left side
        Positioned(
          bottom: 16,
          left: 24, // Position on the left with some padding
          child: ValueListenableBuilder<bool>(
            valueListenable: isAtBottom,
            builder: (context, isAtBottom, child) {
              return AnimatedOpacity(
                opacity: isAtBottom ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: GestureDetector(
                  onTap: scrollToBottom,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: customColors!.textPrimary.withOpacity(0.8),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: 4),
                      duration: const Duration(seconds: 1),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, sin(value) * 3),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 24,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedSlider({
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    List<Map<String, dynamic>>? markers,
  }) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            trackShape: const RoundedRectSliderTrackShape(),
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor:
                Theme.of(context).colorScheme.primary.withOpacity(0.1),
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 8,
              elevation: 4,
              pressedElevation: 8,
            ),
            overlayColor:
                Theme.of(context).colorScheme.primary.withOpacity(0.2),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
            valueIndicatorColor: Theme.of(context).colorScheme.primary,
            valueIndicatorTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 14,
            ),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: value.toStringAsFixed(1),
            onChanged: onChanged,
          ),
        ),

        // Optional markers for recommended ranges
        if (markers != null && markers.isNotEmpty)
          SizedBox(
            height: 16,
            child: Stack(
              children: markers.map((marker) {
                double position =
                    (((marker['value'] as double) - min) / (max - min));
                return Positioned(
                  left: position * MediaQuery.of(context).size.width * 0.75,
                  child: Column(
                    children: [
                      Container(
                        width: 2,
                        height: 8,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.5),
                      ),
                      Text(
                        marker['label'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildTooltip(String message) {
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
      ),
      child: Icon(
        Icons.info_outline_rounded,
        size: 16,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildActivityLevelPage() {
    final customColors = Theme.of(context).extension<CustomColors>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How active are you?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: customColors?.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the option that best describes your typical week.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: customColors?.textPrimary,
                ),
          ),
          const SizedBox(height: 24),
          _buildActivityLevelCard(
            level: MacroCalculatorService.SEDENTARY,
            title: 'Sedentary',
            description: 'Little or no exercise, desk job',
          ),
          _buildActivityLevelCard(
            level: MacroCalculatorService.LIGHTLY_ACTIVE,
            title: 'Lightly Active',
            description: 'Light exercise 1-3 days/week',
          ),
          _buildActivityLevelCard(
            level: MacroCalculatorService.MODERATELY_ACTIVE,
            title: 'Moderately Active',
            description: 'Moderate exercise 3-5 days/week',
          ),
          _buildActivityLevelCard(
            level: MacroCalculatorService.VERY_ACTIVE,
            title: 'Very Active',
            description: 'Heavy exercise 6-7 days/week',
          ),
          _buildActivityLevelCard(
            level: MacroCalculatorService.EXTRA_ACTIVE,
            title: 'Extra Active',
            description:
                'Very heavy exercise, physical job or training twice a day',
          ),
        ],
      ),
    );
  }

  Widget _buildGoalPage() {
    final customColors = Theme.of(context).extension<CustomColors>();

    // Update goal weight when goal changes to ensure it's valid
    if (_goal == MacroCalculatorService.GOAL_LOSE &&
        _goalWeightKg >= _weightKg) {
      _goalWeightKg = max(40.0, _weightKg - 5.0); // Default to 5kg loss
    } else if (_goal == MacroCalculatorService.GOAL_GAIN &&
        _goalWeightKg <= _weightKg) {
      _goalWeightKg = min(150.0, _weightKg + 5.0); // Default to 5kg gain
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What\'s your goal?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: customColors?.textPrimary,
                ),
          ),
          const SizedBox(height: 32),
          _buildGoalCard(
            goal: MacroCalculatorService.GOAL_LOSE,
            title: 'Lose Weight',
            icon: Icons.trending_down,
            description: 'Calorie deficit to lose body fat',
          ),
          const SizedBox(height: 16),
          _buildGoalCard(
            goal: MacroCalculatorService.GOAL_MAINTAIN,
            title: 'Maintain Weight',
            icon: Icons.balance,
            description: 'Balanced calories for weight maintenance',
          ),
          const SizedBox(height: 16),
          _buildGoalCard(
            goal: MacroCalculatorService.GOAL_GAIN,
            title: 'Gain Weight',
            icon: Icons.trending_up,
            description: 'Calorie surplus to build muscle',
          ),

          // Conditionally show goal weight input for weight loss/gain
          if (_goal != MacroCalculatorService.GOAL_MAINTAIN) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'Target Weight',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: customColors?.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 8),
                _buildTooltip(
                    '${_goal == MacroCalculatorService.GOAL_LOSE ? 'Set your target weight loss goal' : 'Set your target weight gain goal'} - this helps calculate a realistic timeframe'),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: customColors?.cardBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Weight picker for goal weight
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isMetricWeight) ...[
                        // Calculate safe min and max values for metric
                        NumberPicker(
                          value: _goalWeightKg.floor(),
                          // For weight loss: min is 40kg, max is current weight - 0.1kg
                          // For weight gain: min is current weight + 0.1kg, max is 150kg
                          minValue: _goal == MacroCalculatorService.GOAL_LOSE
                              ? 40
                              : (_weightKg.floor() + 1),
                          maxValue: _goal == MacroCalculatorService.GOAL_LOSE
                              ? (_weightKg.floor() - 1)
                              : 150,
                          onChanged: (value) {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _goalWeightKg = value +
                                  (_goalWeightKg - _goalWeightKg.floor());
                              _validateRanges();
                            });
                          },
                          selectedTextStyle: TextStyle(
                            color: customColors?.textPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                          textStyle: TextStyle(
                            color: customColors?.textSecondary,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          '.',
                          style: TextStyle(
                            color: customColors?.textPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        NumberPicker(
                          value: ((_goalWeightKg - _goalWeightKg.floor()) * 10)
                              .round(),
                          minValue: 0,
                          maxValue: 9,
                          onChanged: (value) {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _goalWeightKg =
                                  _goalWeightKg.floor() + (value / 10);
                              _validateRanges();
                            });
                          },
                          selectedTextStyle: TextStyle(
                            color: customColors?.textPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                          textStyle: TextStyle(
                            color: customColors?.textSecondary,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          'kg',
                          style: TextStyle(
                            color: customColors?.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else ...[
                        // Imperial (lbs) picker for goal weight
                        NumberPicker(
                          value: (_goalWeightKg * 2.20462).round(),
                          // Calculate min/max inline to avoid issues
                          minValue: _goal == MacroCalculatorService.GOAL_LOSE
                              ? 88
                              : ((_weightKg * 2.20462).round() + 1),
                          maxValue: _goal == MacroCalculatorService.GOAL_LOSE
                              ? ((_weightKg * 2.20462).round() - 1)
                              : 330,
                          onChanged: (value) {
                            setState(() {
                              _goalWeightKg = value / 2.20462;
                              _validateRanges();
                            });
                          },
                          selectedTextStyle: TextStyle(
                            color: customColors?.textPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                          textStyle: TextStyle(
                            color: customColors?.textSecondary,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          'lbs',
                          style: TextStyle(
                            color: customColors?.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Weight difference indicator
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(
                      _goal == MacroCalculatorService.GOAL_LOSE
                          ? 'Lose ${(_weightKg - _goalWeightKg).toStringAsFixed(1)} kg'
                          : 'Gain ${(_goalWeightKg - _weightKg).toStringAsFixed(1)} kg',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _goal == MacroCalculatorService.GOAL_LOSE
                            ? Colors.red.shade400
                            : Colors.green.shade500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Safe weight change note based on Harvard/NIH recommendations
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 16.0),
              child: Text(
                _goal == MacroCalculatorService.GOAL_LOSE
                    ? 'Safe weight loss is typically 0.5-1 kg (1-2 lbs) per week'
                    : 'Safe muscle gain is typically 0.25-0.5 kg (0.5-1 lb) per week',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: customColors?.textSecondary,
                    ),
              ),
            ),
          ],

          // Deficit/Surplus section - keep existing code
          if (_goal != MacroCalculatorService.GOAL_MAINTAIN) ...[
            const SizedBox(height: 24),
            Text(
              'Deficit/Surplus (calories per day)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: customColors?.textPrimary,
                  ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: customColors?.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      if (_deficit > 250) {
                        setState(() => _deficit -= 50);
                        HapticFeedback.lightImpact();
                      }
                    },
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: _deficit > 250
                          ? customColors?.textPrimary
                          : Colors.grey.withOpacity(0.3),
                    ),
                  ),
                  Text(
                    '$_deficit cal',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: customColors?.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (_deficit < 750) {
                        setState(() => _deficit += 50);
                        HapticFeedback.lightImpact();
                      }
                    },
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: _deficit < 750
                          ? customColors?.textPrimary
                          : Colors.grey.withOpacity(0.3),
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

  Widget _buildAdvancedSettingsPage() {
    final customColors = Theme.of(context).extension<CustomColors>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Advanced Settings',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: customColors?.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fine-tune your macro distribution and calculation details',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: customColors?.textPrimary,
                ),
          ),
          const SizedBox(height: 32),

          // Athletic status selection
          Row(
            children: [
              Text(
                'Are you an athlete?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: customColors?.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 8),
              _buildTooltip(
                  'Select "Yes" if you regularly engage in intense sports or training'),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: customColors?.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildToggleOption(
                      label: 'No',
                      isSelected: !_isAthlete,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isAthlete = false);
                      }),
                ),
                Expanded(
                  child: _buildToggleOption(
                    label: 'Yes',
                    isSelected: _isAthlete,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _isAthlete = true);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Body Fat Percentage Input (shown to all users, but optional)
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                'Body Fat Percentage (Optional)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: customColors?.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 8),
              _buildTooltip(
                  'If you know your body fat percentage, enter it here for more accurate calculations'),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: customColors?.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildToggleOption(
                      label: 'Skip',
                      isSelected: !_showBodyFatInput,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _showBodyFatInput = false);
                      }),
                ),
                Expanded(
                  child: _buildToggleOption(
                    label: 'Enter',
                    isSelected: _showBodyFatInput,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _showBodyFatInput = true);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Body fat percentage slider if selected
          if (_showBodyFatInput) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: customColors?.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (_bodyFatPercentage > 5) {
                            setState(() {
                              _bodyFatPercentage -= 1;
                            });
                            HapticFeedback.lightImpact();
                          }
                        },
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: _bodyFatPercentage > 5
                              ? customColors?.textPrimary
                              : Colors.grey.withOpacity(0.3),
                        ),
                      ),
                      Text(
                        '${_bodyFatPercentage.round()}%',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: customColors?.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      IconButton(
                        onPressed: () {
                          if (_bodyFatPercentage < 50) {
                            setState(() {
                              _bodyFatPercentage += 1;
                            });
                            HapticFeedback.lightImpact();
                          }
                        },
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: _bodyFatPercentage < 50
                              ? customColors?.textPrimary
                              : Colors.grey.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),

                  // Slider for more precise control
                  Slider(
                    value: _bodyFatPercentage,
                    min: 5,
                    max: 50,
                    divisions: 45,
                    label: '${_bodyFatPercentage.round()}%',
                    onChanged: (value) {
                      setState(() {
                        _bodyFatPercentage = value;
                      });
                    },
                  ),

                  // Healthy range indicators
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _gender == MacroCalculatorService.MALE
                              ? 'Athletic: 6-13%'
                              : 'Athletic: 14-20%',
                          style: TextStyle(
                            fontSize: 12,
                            color: customColors?.textSecondary,
                          ),
                        ),
                        Text(
                          _gender == MacroCalculatorService.MALE
                              ? 'Healthy: 14-24%'
                              : 'Healthy: 21-31%',
                          style: TextStyle(
                            fontSize: 12,
                            color: customColors?.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Protein ratio slider
          Row(
            children: [
              Text(
                'Protein (g per kg of bodyweight)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: customColors?.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 8),
              _buildTooltip(
                  'Higher protein intake supports muscle maintenance and growth'),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: customColors?.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () {
                        if (_proteinRatio > 1.2) {
                          setState(() => _proteinRatio = double.parse(
                              (_proteinRatio - 0.1).toStringAsFixed(1)));
                          HapticFeedback.lightImpact();
                        }
                      },
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: _proteinRatio > 1.2
                            ? customColors?.textPrimary
                            : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '${_proteinRatio.toStringAsFixed(1)}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: customColors?.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          'g per kg bodyweight',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: customColors?.textSecondary,
                                  ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () {
                        if (_proteinRatio < 2.4) {
                          setState(() => _proteinRatio = double.parse(
                              (_proteinRatio + 0.1).toStringAsFixed(1)));
                          HapticFeedback.lightImpact();
                        }
                      },
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: _proteinRatio < 2.4
                            ? customColors?.textPrimary
                            : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Min: 1.2 g/kg',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: customColors?.textSecondary,
                          ),
                    ),
                    Text(
                      'Max: 2.4 g/kg',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: customColors?.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 16.0),
            child: Text(
              'Recommended: 1.6-2.0 for active individuals, 1.8-2.2 for muscle building',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: customColors?.textSecondary,
                  ),
            ),
          ),
          const SizedBox(height: 24),

          // Fat ratio slider
          Row(
            children: [
              Text(
                'Fat (% of total calories)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: customColors?.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 8),
              _buildTooltip(
                  'Fat is essential for hormone production and vitamin absorption'),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: customColors?.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    if (_fatRatio > 0.2) {
                      setState(() => _fatRatio =
                          double.parse((_fatRatio - 0.01).toStringAsFixed(2)));
                      HapticFeedback.lightImpact();
                    }
                  },
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: _fatRatio > 0.2
                        ? customColors?.textPrimary
                        : Colors.grey.withOpacity(0.3),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${(_fatRatio * 100).round()}%',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: customColors?.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    Text(
                      'of total calories',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: customColors?.textSecondary,
                          ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    if (_fatRatio < 0.4) {
                      setState(() => _fatRatio =
                          double.parse((_fatRatio + 0.01).toStringAsFixed(2)));
                      HapticFeedback.lightImpact();
                    }
                  },
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: _fatRatio < 0.4
                        ? customColors?.textPrimary
                        : Colors.grey.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 16.0),
            child: Text(
              'Recommended: 20-35% of calories from healthy fats',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: customColors?.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final customColors = Theme.of(context).extension<CustomColors>();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: //isSelected
              // ? customColors!.textSecondary.withOpacity(0.1)
              Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    isSelected ? customColors!.textPrimary : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? customColors!.textPrimary
                      : Colors.grey.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? customColors!.textPrimary
                    : customColors?.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard({
    required bool isSelected,
    required VoidCallback onTap,
    required IconData icon,
    required String label,
  }) {
    final customColors = Theme.of(context).extension<CustomColors>();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: customColors?.cardBackground ?? Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? customColors!.textPrimary.withOpacity(0.2)
                  : Colors.black.withOpacity(0.05),
              blurRadius: isSelected ? 8 : 3,
              offset: Offset(0, isSelected ? 3 : 1),
              spreadRadius: isSelected ? 1 : 0,
            ),
          ],
          border: Border.all(
            color: isSelected
                ? customColors!.textPrimary
                : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AnimatedScale(
                    scale: isSelected ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      icon,
                      size: 48,
                      color:
                          isSelected ? customColors!.textPrimary : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? customColors!.textPrimary
                      : customColors?.textPrimary ?? Colors.black,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityLevelCard({
    required int level,
    required String title,
    required String description,
  }) {
    final bool isSelected = _activityLevel == level;
    final customColors = Theme.of(context).extension<CustomColors>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _activityLevel = level);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: customColors?.cardBackground ?? Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                    : Colors.black.withOpacity(0.03),
                blurRadius: isSelected ? 6 : 3,
                offset: Offset(0, isSelected ? 2 : 1),
              ),
            ],
            border: Border.all(
              color: isSelected
                  ? customColors!.textPrimary
                  : Colors.grey.withOpacity(0.1),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? customColors!.textPrimary
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? customColors!.textPrimary
                          : Colors.grey.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Icon(
                            Icons.check,
                            size: 16,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? customColors!.textPrimary
                              : customColors?.textPrimary ?? Colors.black,
                        ),
                        child: Text(title),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: customColors?.textSecondary ?? Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoalCard({
    required String goal,
    required String title,
    required IconData icon,
    required String description,
  }) {
    final bool isSelected = _goal == goal;
    final customColors = Theme.of(context).extension<CustomColors>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          setState(() => _goal = goal);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: customColors?.cardBackground ?? Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                    : Colors.black.withOpacity(0.03),
                blurRadius: isSelected ? 8 : 3,
                offset: Offset(0, isSelected ? 3 : 1),
                spreadRadius: isSelected ? 1 : 0,
              ),
            ],
            border: Border.all(
              color:
                  isSelected ? customColors!.textPrimary : Colors.transparent,
              width: 2,
            ),
            //   gradient: isSelected
            //       ? LinearGradient(
            //           begin: Alignment.topLeft,
            //           end: Alignment.bottomRight,
            //           colors: [
            //             customColors?.cardBackground ?? Colors.white,
            //             Theme.of(context).colorScheme.primary.withOpacity(0.05),
            //           ],
            //         )
            //       : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.15)
                        : Colors.grey.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: AnimatedScale(
                      scale: isSelected ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        icon,
                        size: 28,
                        color: isSelected
                            ? customColors!.textPrimary
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? customColors!.textPrimary
                              : customColors?.textPrimary ?? Colors.black,
                        ),
                        child: Text(title),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: customColors?.textSecondary ?? Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryPage() {
    final customColors = Theme.of(context).extension<CustomColors>();

    String getActivityLevelText() {
      if (_activityLevel == MacroCalculatorService.SEDENTARY)
        return 'Sedentary';
      if (_activityLevel == MacroCalculatorService.LIGHTLY_ACTIVE)
        return 'Lightly Active';
      if (_activityLevel == MacroCalculatorService.MODERATELY_ACTIVE)
        return 'Moderately Active';
      if (_activityLevel == MacroCalculatorService.VERY_ACTIVE)
        return 'Very Active';
      if (_activityLevel == MacroCalculatorService.EXTRA_ACTIVE)
        return 'Extra Active';
      return 'Unknown';
    }

    String getGoalText() {
      if (_goal == MacroCalculatorService.GOAL_LOSE) return 'Lose Weight';
      if (_goal == MacroCalculatorService.GOAL_MAINTAIN)
        return 'Maintain Weight';
      if (_goal == MacroCalculatorService.GOAL_GAIN) return 'Gain Weight';
      return 'Unknown';
    }

    // Create the items lists for each section
    final personalInfoItems = [
      {
        'label': 'Gender',
        'value': _gender == MacroCalculatorService.MALE ? 'Male' : 'Female',
        'page': 1,
      },
      {
        'label': 'Age',
        'value': '$_age years',
        'page': 2,
      },
      {
        'label': 'Weight',
        'value': '${_weightKg.toStringAsFixed(1)} kg',
        'page': 2,
      },
      {
        'label': 'Height',
        'value': '${_heightCm.round()} cm',
        'page': 2,
      },
      {
        'label': 'Athletic Status',
        'value': _isAthlete ? 'Athlete' : 'Non-Athlete',
        'page': 5,
      },
      if (_showBodyFatInput)
        {
          'label': 'Body Fat Percentage',
          'value': '${_bodyFatPercentage.round()}%',
          'page': 5,
        },
    ];

    // Create activity and goals items
    final List<Map<String, dynamic>> activityGoalsItems = [
      {
        'label': 'Activity Level',
        'value': getActivityLevelText(),
        'page': 3,
      },
      {
        'label': 'Goal',
        'value': getGoalText(),
        'page': 4,
      },
    ];

    // Add deficit/surplus and target weight if not maintaining
    if (_goal != MacroCalculatorService.GOAL_MAINTAIN) {
      activityGoalsItems.add({
        'label': _goal == MacroCalculatorService.GOAL_LOSE
            ? 'Calorie Deficit'
            : 'Calorie Surplus',
        'value': '$_deficit calories per day',
        'page': 4,
      });

      activityGoalsItems.add({
        'label': 'Target Weight',
        'value': '${_goalWeightKg.toStringAsFixed(1)} kg',
        'page': 4,
      });
    }

    // Create macro settings items
    final List<Map<String, dynamic>> macroSettingsItems = [
      {
        'label': 'Protein Ratio',
        'value': '${_proteinRatio.toStringAsFixed(1)} g per kg of bodyweight',
        'page': 5,
      },
      {
        'label': 'Fat Ratio',
        'value': '${(_fatRatio * 100).round()}% of total calories',
        'page': 5,
      },
      {
        'label': 'Carbs',
        'value': 'Remaining calories after protein and fat',
        'page': 5,
      },
      {
        'label': 'BMR Formula',
        'value': 'Auto-selected based on your profile',
        'page': 5,
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: customColors?.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review your information before calculating your personalized macros',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: customColors?.textPrimary,
                ),
          ),
          const SizedBox(height: 32),

          // Personal Info Section
          _buildSummarySection(
            title: 'Personal Information',
            icon: Icons.person,
            items: personalInfoItems,
          ),

          const SizedBox(height: 24),

          // Activity & Goals Section
          _buildSummarySection(
            title: 'Activity & Goals',
            icon: Icons.fitness_center,
            items: activityGoalsItems,
          ),

          const SizedBox(height: 24),

          // Macro Settings Section
          _buildSummarySection(
            title: 'Macro Settings',
            icon: Icons.science,
            items: macroSettingsItems,
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> items,
  }) {
    final customColors = Theme.of(context).extension<CustomColors>();

    return Container(
      decoration: BoxDecoration(
        color: customColors?.cardBackground ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: customColors?.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.grey.withOpacity(0.1),
          ),

          // List items
          ...items.map((item) => _buildSummaryItem(
                label: item['label'],
                value: item['value'],
                page: item['page'],
              )),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required int page,
  }) {
    final customColors = Theme.of(context).extension<CustomColors>();

    return InkWell(
      onTap: () => _goToPage(page),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: customColors?.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: customColors?.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitSelector({
    required bool isMetric,
    required String metricUnit,
    required String imperialUnit,
    required ValueChanged<bool> onChanged,
  }) {
    final customColors = Theme.of(context).extension<CustomColors>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildUnitOption(
            isSelected: isMetric,
            label: metricUnit,
            onTap: () => onChanged(true),
          ),
          _buildUnitOption(
            isSelected: !isMetric,
            label: imperialUnit,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitOption({
    required bool isSelected,
    required String label,
    required VoidCallback onTap,
  }) {
    final customColors = Theme.of(context).extension<CustomColors>();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? customColors!.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : customColors?.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Add this method to ensure values are within valid ranges
  void _validateRanges() {
    // Ensure goal weight is realistic based on current weight and goal
    if (_goal == MacroCalculatorService.GOAL_LOSE) {
      // For weight loss, goal weight should be less than current weight
      // and not too extreme (safe to assume not less than 75% of current weight)
      double minWeight = _weightKg * 0.75;
      _goalWeightKg = _goalWeightKg < minWeight ? minWeight : _goalWeightKg;
      _goalWeightKg =
          _goalWeightKg >= _weightKg ? _weightKg - 0.5 : _goalWeightKg;
    } else if (_goal == MacroCalculatorService.GOAL_GAIN) {
      // For weight gain, goal weight should be more than current weight
      // and not too extreme (safe to assume not more than 150% of current weight)
      double maxWeight = _weightKg * 1.5;
      _goalWeightKg = _goalWeightKg > maxWeight ? maxWeight : _goalWeightKg;
      _goalWeightKg =
          _goalWeightKg <= _weightKg ? _weightKg + 0.5 : _goalWeightKg;
    }
    // If goal is MAINTAIN, no validation needed for goal weight
  }

  void _setImperialValues() {
    // Convert kg to lbs
    _imperialWeightLbs = (_weightKg * 2.20462).round();
    _imperialGoalWeightLbs = (_goalWeightKg * 2.20462).round();

    // Convert cm to feet and inches
    double totalInches = _heightCm / 2.54;
    _imperialHeightFeet = (totalInches / 12).floor();
    _imperialHeightInches = (totalInches % 12).round();

    // Update UI
    setState(() {});
  }

  void _updateGoal(String newGoal) {
    setState(() {
      _goal = newGoal;

      // Update goal weight and deficit based on goal
      if (_goal == MacroCalculatorService.GOAL_MAINTAIN) {
        _goalWeightKg = _weightKg;
        _deficit = 0; // No deficit/surplus for maintaining
      } else if (_goal == MacroCalculatorService.GOAL_LOSE) {
        _goalWeightKg = _weightKg * 0.9; // Default to 10% weight loss
        _deficit = 500; // Default deficit
      } else if (_goal == MacroCalculatorService.GOAL_GAIN) {
        _goalWeightKg = _weightKg * 1.1; // Default to 10% weight gain
        _deficit = 500; // Default surplus
      }

      // Update imperial values if needed
      if (!_isMetricWeight) {
        _setImperialValues();
      }

      // Validate the ranges
      _validateRanges();
    });
  }
}
