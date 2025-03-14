import 'package:flutter/material.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/screens/onboarding/results_screen.dart';
import 'package:macrotracker/theme/app_theme.dart'; // Import theme

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 6;

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

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Final page - calculate and navigate to results
      _calculateAndShowResults();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
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

    // Navigate to results screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ResultsScreen(results: results),
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
              child: LinearProgressIndicator(
                value: (_currentPage + 1) / _totalPages,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary),
              ),
            ),

            // Page content
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
                          child: Text(
                            'Back',
                            style: TextStyle(
                              color: customColors?.textPrimary ?? Colors.black,
                            ),
                          ),
                        )
                      : SizedBox(width: 80),
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      elevation: 0,
                      surfaceTintColor: Colors.transparent,
                    ),
                    child: Text(
                        _currentPage == _totalPages - 1 ? 'Calculate' : 'Next'),
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
          Icon(
            Icons.fitness_center,
            size: 100,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to Macro Tracker',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: customColors?.textPrimary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Let\'s personalize your experience by collecting some information to calculate your optimal macro nutrients.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: customColors?.textPrimary,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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

          // Weight slider
          Text('Weight (kg)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: customColors?.textPrimary,
                  )),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _weightKg,
                  min: 40,
                  max: 150,
                  divisions: 110,
                  label: _weightKg.toStringAsFixed(1),
                  onChanged: (value) {
                    setState(() {
                      _weightKg = double.parse(value.toStringAsFixed(1));
                    });
                  },
                ),
              ),
              SizedBox(
                width: 50,
                child: Text('${_weightKg.toStringAsFixed(1)} kg',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: customColors?.textPrimary,
                        )),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Height slider
          Text('Height (cm)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: customColors?.textPrimary,
                  )),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _heightCm,
                  min: 140,
                  max: 220,
                  divisions: 80,
                  label: _heightCm.round().toString(),
                  onChanged: (value) {
                    setState(() {
                      _heightCm = double.parse(value.toStringAsFixed(1));
                    });
                  },
                ),
              ),
              SizedBox(
                width: 50,
                child: Text('${_heightCm.round()} cm',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: customColors?.textPrimary,
                        )),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Age slider
          Text('Age',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: customColors?.textPrimary,
                  )),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _age.toDouble(),
                  min: 18,
                  max: 80,
                  divisions: 62,
                  label: _age.toString(),
                  onChanged: (value) {
                    setState(() {
                      _age = value.round();
                    });
                  },
                ),
              ),
              SizedBox(
                width: 50,
                child: Text('$_age',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: customColors?.textPrimary,
                        )),
              ),
            ],
          ),
        ],
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
          Text('Protein (g per kg of bodyweight)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: customColors?.textPrimary,
                  )),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _proteinRatio,
                  min: 1.2,
                  max: 2.4,
                  divisions: 12,
                  label: _proteinRatio.toStringAsFixed(1),
                  onChanged: (value) {
                    setState(() {
                      _proteinRatio = double.parse(value.toStringAsFixed(1));
                    });
                  },
                ),
              ),
              SizedBox(
                width: 50,
                child: Text('${_proteinRatio.toStringAsFixed(1)} g/kg',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: customColors?.textPrimary,
                        )),
              ),
            ],
          ),
          Text(
            'Recommended: 1.6-2.0 for active individuals, 1.8-2.2 for building muscle',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: customColors?.textSecondary,
                ),
          ),
          const SizedBox(height: 24),

          // Fat ratio slider
          Text('Fat (% of total calories)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: customColors?.textPrimary,
                  )),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _fatRatio,
                  min: 0.2,
                  max: 0.4,
                  divisions: 10,
                  label: '${(_fatRatio * 100).round()}%',
                  onChanged: (value) {
                    setState(() {
                      _fatRatio = double.parse(value.toStringAsFixed(2));
                    });
                  },
                ),
              ),
              SizedBox(
                width: 50,
                child: Text('${(_fatRatio * 100).round()}%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: customColors?.textPrimary,
                        )),
              ),
            ],
          ),
          Text(
            'Recommended: 20-35% of calories from healthy fats',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: customColors?.textSecondary,
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
      child: Card(
        elevation: isSelected ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 64,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: customColors?.textPrimary ?? Colors.black,
                ),
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
        child: Card(
          elevation: isSelected ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Radio<double>(
                  value: level,
                  groupValue: _activityLevel,
                  onChanged: (value) {
                    if (value != null) setState(() => _activityLevel = value);
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: customColors?.textPrimary ?? Colors.black,
                        ),
                      ),
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
    required int goal,
    required String title,
    required IconData icon,
    required String description,
  }) {
    final bool isSelected = _goal == goal;
    final customColors = Theme.of(context).extension<CustomColors>();

    return GestureDetector(
      onTap: () => setState(() => _goal = goal),
      child: Card(
        elevation: isSelected ? 4 : 1,
        surfaceTintColor: Colors.transparent,
        color: customColors?.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withAlpha(51)
                      : Colors.grey.withAlpha(25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: customColors?.textPrimary ?? Colors.black,
                      ),
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
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
