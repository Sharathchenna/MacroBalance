import 'package:flutter/material.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/screens/onboarding/results_screen.dart';
import 'package:macrotracker/theme/app_theme.dart'; // Import theme

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 7; // Increased by 1 for summary page
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  // User data
  int _gender = MacroCalculatorService.MALE;
  double _weightKg = 70;
  double _heightCm = 170;
  int _age = 30;
  double _activityLevel = MacroCalculatorService.MODERATELY_ACTIVE;
  int _goal = MacroCalculatorService.GOAL_MAINTAIN;
  int _deficit = 500;
  double _proteinRatio = 1.8;
  double _fatRatio = 0.25;
  
  // Unit toggles
  bool _useMetricSystem = true;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: (_currentPage + 1) / _totalPages,
    );
    _progressAnimation = Tween<double>(
      begin: (_currentPage + 1) / _totalPages,
      end: (_currentPage + 1) / _totalPages,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      // Animate to next page
      _animationController.animateTo(
        (_currentPage + 2) / _totalPages,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      // Final page - calculate and navigate to results
      _calculateAndShowResults();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      // Animate to previous page
      _animationController.animateTo(
        _currentPage / _totalPages,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }
  
  void _goToPage(int page) {
    if (page >= 0 && page < _totalPages) {
      _animationController.animateTo(
        (page + 1) / _totalPages,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _calculateAndShowResults() {
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
    );

    // Navigate to results screen with a transition
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
          ResultsScreen(results: results),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
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

  @override
  Widget build(BuildContext context) {
    // Get the custom colors from theme
    final customColors = Theme.of(context).extension<CustomColors>();

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
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
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
                          onPressed: _previousPage,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 2,
                      shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      surfaceTintColor: Colors.transparent,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage == _totalPages - 1 ? 'Calculate' : 'Next',
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
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.restaurant,
                        size: 64,
                        color: Colors.white,
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
                    'Welcome to Macro Tracker',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: customColors?.textPrimary,
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
                    'Let\'s personalize your experience by calculating your optimal macro nutrients.',
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
              color: Theme.of(context).colorScheme.primary,
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
                  onTap: () =>
                      setState(() => _gender = MacroCalculatorService.MALE),
                  icon: Icons.male,
                  label: 'Male',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSelectionCard(
                  isSelected: _gender == MacroCalculatorService.FEMALE,
                  onTap: () =>
                      setState(() => _gender = MacroCalculatorService.FEMALE),
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

    return Padding(
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

          // Weight slider with unit toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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
              // Unit toggle
              Row(
                children: [
                  Text(
                    'kg',
                    style: TextStyle(
                      fontSize: 14,
                      color: _useMetricSystem
                          ? Theme.of(context).colorScheme.primary
                          : customColors?.textSecondary,
                      fontWeight:
                          _useMetricSystem ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  Switch.adaptive(
                    value: !_useMetricSystem,
                    activeColor: Theme.of(context).colorScheme.primary,
                    onChanged: (value) {
                      setState(() {
                        _useMetricSystem = !value;
                        if (!_useMetricSystem) {
                          // Convert from lb to kg
                          _weightKg = _weightKg / 2.20462;
                        } else {
                          // Convert from kg to lb
                          _weightKg = _weightKg * 2.20462;
                        }
                      });
                    },
                  ),
                  Text(
                    'lb',
                    style: TextStyle(
                      fontSize: 14,
                      color: !_useMetricSystem
                          ? Theme.of(context).colorScheme.primary
                          : customColors?.textSecondary,
                      fontWeight:
                          !_useMetricSystem ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildEnhancedSlider(
                  value: _weightKg,
                  min: _useMetricSystem ? 40 : 88, // 40kg = ~88lb
                  max: _useMetricSystem ? 150 : 330, // 150kg = ~330lb
                  divisions: 110,
                  onChanged: (value) {
                    setState(() {
                      _weightKg = double.parse(value.toStringAsFixed(1));
                    });
                  },
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  _useMetricSystem
                      ? '${_weightKg.toStringAsFixed(1)} kg'
                      : '${(_weightKg).round()} lb',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: customColors?.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Height slider with unit toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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
                    'Your height is used alongside weight to calculate your BMI and base metabolic rate'),
                ],
              ),
              // Unit toggle for height
              Row(
                children: [
                  Text(
                    'cm',
                    style: TextStyle(
                      fontSize: 14,
                      color: _useMetricSystem
                          ? Theme.of(context).colorScheme.primary
                          : customColors?.textSecondary,
                      fontWeight:
                          _useMetricSystem ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  Switch.adaptive(
                    value: !_useMetricSystem,
                    activeColor: Theme.of(context).colorScheme.primary,
                    onChanged: (value) {
                      setState(() {
                        _useMetricSystem = !value;
                        if (!_useMetricSystem) {
                          // Convert from in to cm
                          _heightCm = _heightCm / 2.54;
                        } else {
                          // Convert from cm to in
                          _heightCm = _heightCm * 2.54;
                        }
                      });
                    },
                  ),
                  Text(
                    'in',
                    style: TextStyle(
                      fontSize: 14,
                      color: !_useMetricSystem
                          ? Theme.of(context).colorScheme.primary
                          : customColors?.textSecondary,
                      fontWeight:
                          !_useMetricSystem ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildEnhancedSlider(
                  value: _heightCm,
                  min: _useMetricSystem ? 140 : 55, // 140cm = ~55in
                  max: _useMetricSystem ? 220 : 87, // 220cm = ~87in
                  divisions: 80,
                  onChanged: (value) {
                    setState(() {
                      _heightCm = double.parse(value.toStringAsFixed(1));
                    });
                  },
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  _useMetricSystem
                      ? '${_heightCm.round()} cm'
                      : '${_heightCm.round()} in',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: customColors?.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Age slider
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
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildEnhancedSlider(
                  value: _age.toDouble(),
                  min: 18,
                  max: 80,
                  divisions: 62,
                  onChanged: (value) {
                    setState(() {
                      _age = value.round();
                    });
                  },
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  '$_age',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: customColors?.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
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
            inactiveTrackColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 8,
              elevation: 4,
              pressedElevation: 8,
            ),
            overlayColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
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
                double position = (((marker['value'] as double) - min) / (max - min));
                return Positioned(
                  left: position * MediaQuery.of(context).size.width * 0.75,
                  child: Column(
                    children: [
                      Container(
                        width: 2,
                        height: 8,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                      ),
                      Text(
                        marker['label'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
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

    return Padding(
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
          if (_goal != MacroCalculatorService.GOAL_MAINTAIN) ...[
            const SizedBox(height: 24),
            Text(
              'Deficit/Surplus (calories per day)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: customColors?.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _deficit.toDouble(),
                    min: 250,
                    max: 750,
                    divisions: 10,
                    label: _deficit.toString(),
                    onChanged: (value) {
                      setState(() {
                        _deficit = value.round();
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text('$_deficit cal',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: customColors?.textPrimary,
                          )),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdvancedSettingsPage() {
    final customColors = Theme.of(context).extension<CustomColors>();

    return Padding(
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
            'Fine-tune your macro distribution (optional)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: customColors?.textPrimary,
                ),
          ),
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
          Row(
            children: [
              Expanded(
                child: _buildEnhancedSlider(
                  value: _proteinRatio,
                  min: 1.2,
                  max: 2.4,
                  divisions: 12,
                  onChanged: (value) {
                    setState(() {
                      _proteinRatio = double.parse(value.toStringAsFixed(1));
                    });
                  },
                  markers: [
                    {'value': 1.6, 'label': 'Min'},
                    {'value': 2.2, 'label': 'Max'},
                  ],
                ),
              ),
              SizedBox(
                width: 60,
                child: Text('${_proteinRatio.toStringAsFixed(1)} g/kg',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: customColors?.textPrimary,
                          fontWeight: FontWeight.w500,
                        )),
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
          Row(
            children: [
              Expanded(
                child: _buildEnhancedSlider(
                  value: _fatRatio,
                  min: 0.2,
                  max: 0.4,
                  divisions: 10,
                  onChanged: (value) {
                    setState(() {
                      _fatRatio = double.parse(value.toStringAsFixed(2));
                    });
                  },
                  markers: [
                    {'value': 0.25, 'label': 'Min'},
                    {'value': 0.35, 'label': 'Max'},
                  ],
                ),
              ),
              SizedBox(
                width: 50,
                child: Text('${(_fatRatio * 100).round()}%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: customColors?.textPrimary,
                          fontWeight: FontWeight.w500,
                        )),
              ),
            ],
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
                ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
              blurRadius: isSelected ? 8 : 3,
              offset: Offset(0, isSelected ? 3 : 1),
              spreadRadius: isSelected ? 1 : 0,
            ),
          ],
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
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
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
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
                      ? Theme.of(context).colorScheme.primary
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
    required double level,
    required String title,
    required String description,
  }) {
    final bool isSelected = _activityLevel == level;
    final customColors = Theme.of(context).extension<CustomColors>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: () => setState(() => _activityLevel = level),
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
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.withOpacity(0.1),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Center(
                          child: Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
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
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected 
                              ? Theme.of(context).colorScheme.primary
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
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
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
    required int goal,
    required String title,
    required IconData icon,
    required String description,
  }) {
    final bool isSelected = _goal == goal;
    final customColors = Theme.of(context).extension<CustomColors>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: GestureDetector(
        onTap: () => setState(() => _goal = goal),
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
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
            gradient: isSelected 
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      customColors?.cardBackground ?? Colors.white,
                      Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    ],
                  )
                : null,
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
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                        : Colors.grey.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: AnimatedScale(
                      scale: isSelected ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        icon,
                        size: 28,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
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
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected 
                              ? Theme.of(context).colorScheme.primary
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
                AnimatedOpacity(
                  opacity: isSelected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
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

  Widget _buildSummaryPage() {
    final customColors = Theme.of(context).extension<CustomColors>();
    
    String getActivityLevelText() {
      if (_activityLevel == MacroCalculatorService.SEDENTARY) return 'Sedentary';
      if (_activityLevel == MacroCalculatorService.LIGHTLY_ACTIVE) return 'Lightly Active';
      if (_activityLevel == MacroCalculatorService.MODERATELY_ACTIVE) return 'Moderately Active';
      if (_activityLevel == MacroCalculatorService.VERY_ACTIVE) return 'Very Active';
      if (_activityLevel == MacroCalculatorService.EXTRA_ACTIVE) return 'Extra Active';
      return 'Unknown';
    }
    
    String getGoalText() {
      if (_goal == MacroCalculatorService.GOAL_LOSE) return 'Lose Weight';
      if (_goal == MacroCalculatorService.GOAL_MAINTAIN) return 'Maintain Weight';
      if (_goal == MacroCalculatorService.GOAL_GAIN) return 'Gain Weight';
      return 'Unknown';
    }

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
            items: [
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
                'value': _useMetricSystem
                    ? '${_weightKg.toStringAsFixed(1)} kg'
                    : '${(_weightKg).round()} lb',
                'page': 2,
              },
              {
                'label': 'Height',
                'value': _useMetricSystem
                    ? '${_heightCm.round()} cm'
                    : '${_heightCm.round()} in',
                'page': 2,
              },
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Activity & Goals Section
          _buildSummarySection(
            title: 'Activity & Goals',
            icon: Icons.fitness_center,
            items: [
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
              if (_goal != MacroCalculatorService.GOAL_MAINTAIN)
                {
                  'label': _goal == MacroCalculatorService.GOAL_LOSE ? 'Calorie Deficit' : 'Calorie Surplus',
                  'value': '$_deficit calories per day',
                  'page': 4,
                },
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Macro Settings Section
          _buildSummarySection(
            title: 'Macro Settings',
            icon: Icons.science,
            items: [
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
            ],
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
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
}
