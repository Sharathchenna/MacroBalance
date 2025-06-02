import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

import '../providers/food_entry_provider.dart';
import '../models/nutrition_goals.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_macro_ring.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_input.dart';

class MacroTrackingScreen extends StatefulWidget {
  final bool hideAppBar;

  const MacroTrackingScreen({
    super.key,
    this.hideAppBar = false,
  });

  @override
  State<MacroTrackingScreen> createState() => _MacroTrackingScreenState();
}

class _MacroTrackingScreenState extends State<MacroTrackingScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;

  bool _isLoading = true;
  bool _isAnimationStarted = false;

  // Macro targets
  double _targetProtein = 0;
  double _targetCarbs = 0;
  double _targetFat = 0;

  // Macro history for chart
  List<Map<String, dynamic>> _macroHistory = [];

  @override
  void initState() {
    super.initState();

    // Main animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // FAB animation controller
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Initialize animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
    ));

    _loadInitialData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final foodEntryProvider =
          Provider.of<FoodEntryProvider>(context, listen: false);
      await foodEntryProvider.initialize();

      // Load macro history for the past 7 days
      List<Map<String, dynamic>> history = [];
      for (int i = 6; i >= 0; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        final entries = foodEntryProvider.getAllEntriesForDate(date);

        double protein = 0, carbs = 0, fat = 0, calories = 0;
        for (var entry in entries) {
          double multiplier = entry.quantity;
          switch (entry.unit) {
            case 'oz':
              multiplier *= 28.35;
              break;
            case 'kg':
              multiplier *= 1000;
              break;
            case 'lbs':
              multiplier *= 453.59;
              break;
          }
          multiplier /= 100;

          protein += (entry.food.nutrients['Protein'] ?? 0) * multiplier;
          carbs += (entry.food.nutrients['Carbohydrate, by difference'] ?? 0) *
              multiplier;
          fat += (entry.food.nutrients['Total lipid (fat)'] ?? 0) * multiplier;
          calories += (entry.food.nutrients['Energy'] ?? 0) * multiplier;
        }

        history.add({
          'date': date,
          'protein': protein.round(),
          'carbs': carbs.round(),
          'fat': fat.round(),
          'calories': calories.round(),
          'dayName': DateFormat('E').format(date),
        });
      }

      if (mounted) {
        setState(() {
          _targetProtein = foodEntryProvider.proteinGoal;
          _targetCarbs = foodEntryProvider.carbsGoal;
          _targetFat = foodEntryProvider.fatGoal;
          _macroHistory = history;
          _isLoading = false;
        });

        // Start animations
        _animationController.forward();
        _fabAnimationController.forward();
      }
    } catch (e) {
      debugPrint('Error loading macro data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Initialize with empty data
          _macroHistory = List.generate(7, (i) {
            final date = DateTime.now().subtract(Duration(days: 6 - i));
            return {
              'date': date,
              'protein': 0,
              'carbs': 0,
              'fat': 0,
              'calories': 0,
              'dayName': DateFormat('E').format(date),
            };
          });
        });
        _animationController.forward();
        _fabAnimationController.forward();
      }
    }
  }

  double _calculateTargetCalories() {
    return (_targetProtein * 4) + (_targetCarbs * 4) + (_targetFat * 9);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = Theme.of(context).extension<CustomColors>();

    if (customColors == null) {
      return const Center(child: Text('Error: Theme extension not found'));
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: widget.hideAppBar ? null : _buildAppBar(customColors),
      body: _isLoading ? _buildLoadingState() : _buildContent(customColors),
      floatingActionButton: _buildFloatingActionButton(customColors),
    );
  }

  PreferredSizeWidget _buildAppBar(CustomColors customColors) {
    return AppBar(
      title: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Text(
              'Macro Tracking',
              style: PremiumTypography.h4.copyWith(
                color: customColors.textPrimary,
              ),
            ),
          );
        },
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarBrightness: Theme.of(context).brightness,
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your nutrition data...',
            style: PremiumTypography.bodyMedium.copyWith(
              color: Theme.of(context).extension<CustomColors>()?.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(CustomColors customColors) {
    return Consumer<FoodEntryProvider>(
      builder: (context, foodEntryProvider, child) {
        final nutritionTotals =
            foodEntryProvider.getNutritionTotalsForDate(DateTime.now());
        final currentCalories = nutritionTotals['calories'] ?? 0.0;
        final currentProtein = nutritionTotals['protein'] ?? 0.0;
        final currentCarbs = nutritionTotals['carbs'] ?? 0.0;
        final currentFat = nutritionTotals['fat'] ?? 0.0;

        // Start animation only once after the first build completes with data
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isAnimationStarted) {
            _animationController.forward();
            _isAnimationStarted = true;
          }
        });

        final targetCalories = _calculateTargetCalories();

        return AnimatedBuilder(
          animation: _slideAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Section
                            _buildHeaderSection(customColors),
                            const SizedBox(height: 24),

                            // Today's Summary Card
                            AnimatedBuilder(
                              animation: _scaleAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _scaleAnimation.value,
                                  child: _buildTodaysSummaryCard(
                                    customColors,
                                    currentCalories,
                                    targetCalories,
                                    currentProtein,
                                    currentCarbs,
                                    currentFat,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),

                            // Macro Rings
                            _buildMacroRingsSection(
                              customColors,
                              currentProtein,
                              currentCarbs,
                              currentFat,
                            ),
                            const SizedBox(height: 24),

                            // Weekly Chart
                            _buildWeeklyChart(customColors),
                            const SizedBox(height: 24),

                            // Quick Actions
                            _buildQuickActions(customColors),
                            const SizedBox(height: 100), // Space for FAB
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeaderSection(CustomColors customColors) {
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PremiumColors.blue500.withAlpha(((0.1) * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              color: PremiumColors.blue500,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nutrition Dashboard',
                  style: PremiumTypography.h3.copyWith(
                    color: customColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                  style: PremiumTypography.bodyMedium.copyWith(
                    color: customColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysSummaryCard(
    CustomColors customColors,
    double currentCalories,
    double targetCalories,
    double currentProtein,
    double currentCarbs,
    double currentFat,
  ) {
    final progress =
        targetCalories > 0 ? currentCalories / targetCalories : 0.0;
    final progressClamped = progress.clamp(0.0, 1.0);

    return PremiumCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Progress',
                style: PremiumTypography.h4.copyWith(
                  color: customColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: progress >= 1.0
                      ? PremiumColors.emerald500.withAlpha(((0.1) * 255).round())
                      : PremiumColors.blue500.withAlpha(((0.1) * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(progress * 100).round()}%',
                  style: PremiumTypography.caption.copyWith(
                    color: progress >= 1.0
                        ? PremiumColors.emerald500
                        : PremiumColors.blue500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Calorie progress ring
          Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background circle
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: customColors.cardBackground,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(((0.05) * 255).round()),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                  ),

                  // Progress indicator
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(begin: 0, end: progressClamped),
                    builder: (context, animatedProgress, _) {
                      return CustomPaint(
                        size: const Size(140, 140),
                        painter: _CalorieProgressPainter(
                          progress: animatedProgress,
                          color: progress >= 1.0
                              ? PremiumColors.emerald500
                              : PremiumColors.blue500,
                          backgroundColor: customColors.dateNavigatorBackground,
                        ),
                      );
                    },
                  ),

                  // Center content
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeOutCubic,
                        tween: Tween<double>(begin: 0, end: currentCalories),
                        builder: (context, value, _) {
                          return Text(
                            value.round().toString(),
                            style: PremiumTypography.h2.copyWith(
                              color: progress >= 1.0
                                  ? PremiumColors.emerald500
                                  : PremiumColors.blue500,
                              fontWeight: FontWeight.w800,
                            ),
                          );
                        },
                      ),
                      Text(
                        'calories',
                        style: PremiumTypography.caption.copyWith(
                          color: customColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'of ${targetCalories.round()}',
                        style: PremiumTypography.caption.copyWith(
                          color: customColors.textSecondary.withAlpha(((0.7) * 255).round()),
                        ),
                      ),
                    ],
                  ),

                  // Achievement indicator
                  if (progress >= 1.0)
                    Positioned(
                      top: 15,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: PremiumColors.emerald500,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: PremiumColors.emerald500.withAlpha(((0.3) * 255).round()),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Quick macro overview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickMacroStat('Protein', currentProtein, _targetProtein,
                  PremiumColors.red500),
              _buildQuickMacroStat(
                  'Carbs', currentCarbs, _targetCarbs, PremiumColors.blue500),
              _buildQuickMacroStat(
                  'Fat', currentFat, _targetFat, PremiumColors.amber500),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMacroStat(
      String label, double current, double target, Color color) {
    final progress = target > 0 ? current / target : 0.0;

    return Column(
      children: [
        Text(
          label,
          style: PremiumTypography.caption.copyWith(
            color: Theme.of(context).extension<CustomColors>()?.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${current.round()}g',
          style: PremiumTypography.bodyLarge.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: color.withAlpha(((0.2) * 255).round()),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMacroRingsSection(
    CustomColors customColors,
    double currentProtein,
    double currentCarbs,
    double currentFat,
  ) {
    return PremiumCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Macro Breakdown',
            style: PremiumTypography.h4.copyWith(
              color: customColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              PremiumMacroRing(
                label: 'Protein',
                current: currentProtein.round(),
                target: _targetProtein.round(),
                color: PremiumColors.red500,
                icon: Icons.fitness_center_rounded,
                size: 90,
                animated: true,
              ),
              PremiumMacroRing(
                label: 'Carbs',
                current: currentCarbs.round(),
                target: _targetCarbs.round(),
                color: PremiumColors.blue500,
                icon: Icons.grain_rounded,
                size: 90,
                animated: true,
              ),
              PremiumMacroRing(
                label: 'Fat',
                current: currentFat.round(),
                target: _targetFat.round(),
                color: PremiumColors.amber500,
                icon: Icons.opacity_rounded,
                size: 90,
                animated: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(CustomColors customColors) {
    return PremiumCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Overview',
            style: PremiumTypography.h4.copyWith(
              color: customColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your nutrition intake over the past 7 days',
            style: PremiumTypography.bodyMedium.copyWith(
              color: customColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: _buildWeeklyBarChart(customColors),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildChartLegend('Protein', PremiumColors.red500),
              _buildChartLegend('Carbs', PremiumColors.blue500),
              _buildChartLegend('Fat', PremiumColors.amber500),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: PremiumTypography.caption.copyWith(
            color: Theme.of(context).extension<CustomColors>()?.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyBarChart(CustomColors customColors) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, 200),
          painter: _WeeklyChartPainter(
            data: _macroHistory,
            animation: _animationController,
            customColors: customColors,
            targetProtein: _targetProtein,
            targetCarbs: _targetCarbs,
            targetFat: _targetFat,
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(CustomColors customColors) {
    return PremiumCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: PremiumTypography.h4.copyWith(
              color: customColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PremiumButton.secondary(
                  text: 'Set Goals',
                  icon: Icons.flag_outlined,
                  onPressed: () => _showGoalsDialog(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PremiumButton.secondary(
                  text: 'View History',
                  icon: Icons.history,
                  onPressed: () => _showHistoryDialog(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(CustomColors customColors) {
    return AnimatedBuilder(
      animation: _fabAnimationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _fabAnimationController.value,
          child: FloatingActionButton.extended(
            onPressed: () => _showAddFoodDialog(),
            backgroundColor: PremiumColors.blue500,
            foregroundColor: Colors.white,
            elevation: 8,
            label: const Text(
              'Add Food',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            icon: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _showGoalsDialog() {
    showDialog(
      context: context,
      builder: (context) => _GoalsDialog(
        currentProtein: _targetProtein,
        currentCarbs: _targetCarbs,
        currentFat: _targetFat,
        onSave: (protein, carbs, fat) {
          setState(() {
            _targetProtein = protein;
            _targetCarbs = carbs;
            _targetFat = fat;
          });

          // Update provider
          final provider =
              Provider.of<FoodEntryProvider>(context, listen: false);

          // Create updated nutrition goals
          final updatedGoals = NutritionGoals(
            calories: _calculateTargetCalories(),
            protein: protein,
            carbs: carbs,
            fat: fat,
            steps: provider.nutritionGoals.steps,
            bmr: provider.nutritionGoals.bmr,
            tdee: provider.nutritionGoals.tdee,
            goalWeightKg: provider.nutritionGoals.goalWeightKg,
            currentWeightKg: provider.nutritionGoals.currentWeightKg,
            goalType: provider.nutritionGoals.goalType,
            deficitSurplus: provider.nutritionGoals.deficitSurplus,
          );

          provider.updateNutritionGoals(updatedGoals);
        },
      ),
    );
  }

  void _showHistoryDialog() {
    // Implement history dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('History feature coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAddFoodDialog() {
    // Implement add food dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add food feature coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// Custom painter for calorie progress
class _CalorieProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _CalorieProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 8.0;

    // Background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CalorieProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Custom painter for weekly chart
class _WeeklyChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final AnimationController animation;
  final CustomColors customColors;
  final double targetProtein;
  final double targetCarbs;
  final double targetFat;

  _WeeklyChartPainter({
    required this.data,
    required this.animation,
    required this.customColors,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final barWidth = size.width / (data.length * 1.5);
    final maxValue = _getMaxValue();

    for (int i = 0; i < data.length; i++) {
      final x = (i + 0.5) * (size.width / data.length);
      _drawBar(canvas, data[i], x, barWidth, size.height, maxValue);
      _drawDayLabel(canvas, data[i], x, size.height);
    }
  }

  double _getMaxValue() {
    double max = 0;
    for (var item in data) {
      final total = (item['protein'] + item['carbs'] + item['fat']).toDouble();
      max = math.max(max, total);
    }
    final targetTotal = targetProtein + targetCarbs + targetFat;
    return math.max(max, targetTotal) * 1.1; // 10% padding
  }

  void _drawBar(Canvas canvas, Map<String, dynamic> dayData, double x,
      double barWidth, double chartHeight, double maxValue) {
    final protein = dayData['protein'].toDouble();
    final carbs = dayData['carbs'].toDouble();
    final fat = dayData['fat'].toDouble();

    final proteinHeight =
        (protein / maxValue) * (chartHeight - 40) * animation.value;
    final carbsHeight =
        (carbs / maxValue) * (chartHeight - 40) * animation.value;
    final fatHeight = (fat / maxValue) * (chartHeight - 40) * animation.value;

    double currentY = chartHeight - 25;

    // Draw protein bar
    if (protein > 0) {
      final rect = Rect.fromLTWH(x - barWidth / 6, currentY - proteinHeight,
          barWidth / 3, proteinHeight);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()..color = PremiumColors.red500,
      );
      currentY -= proteinHeight + 2;
    }

    // Draw carbs bar
    if (carbs > 0) {
      final rect = Rect.fromLTWH(
          x - barWidth / 18, currentY - carbsHeight, barWidth / 3, carbsHeight);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()..color = PremiumColors.blue500,
      );
      currentY -= carbsHeight + 2;
    }

    // Draw fat bar
    if (fat > 0) {
      final rect = Rect.fromLTWH(
          x + barWidth / 18, currentY - fatHeight, barWidth / 3, fatHeight);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()..color = PremiumColors.amber500,
      );
    }
  }

  void _drawDayLabel(Canvas canvas, Map<String, dynamic> dayData, double x,
      double chartHeight) {
    final date = dayData['date'] as DateTime;
    final dayLabel = DateFormat('E').format(date).substring(0, 1);

    final textPainter = TextPainter(
      text: TextSpan(
        text: dayLabel,
        style: TextStyle(
          color: customColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, chartHeight - 20),
    );
  }

  @override
  bool shouldRepaint(_WeeklyChartPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}

// Goals dialog widget
class _GoalsDialog extends StatefulWidget {
  final double currentProtein;
  final double currentCarbs;
  final double currentFat;
  final Function(double, double, double) onSave;

  const _GoalsDialog({
    required this.currentProtein,
    required this.currentCarbs,
    required this.currentFat,
    required this.onSave,
  });

  @override
  State<_GoalsDialog> createState() => _GoalsDialogState();
}

class _GoalsDialogState extends State<_GoalsDialog> {
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatController;

  @override
  void initState() {
    super.initState();
    _proteinController =
        TextEditingController(text: widget.currentProtein.round().toString());
    _carbsController =
        TextEditingController(text: widget.currentCarbs.round().toString());
    _fatController =
        TextEditingController(text: widget.currentFat.round().toString());
  }

  @override
  void dispose() {
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  double get totalCalories {
    final protein = double.tryParse(_proteinController.text) ?? 0;
    final carbs = double.tryParse(_carbsController.text) ?? 0;
    final fat = double.tryParse(_fatController.text) ?? 0;
    return (protein * 4) + (carbs * 4) + (fat * 9);
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>()!;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: PremiumCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set Daily Goals',
              style: PremiumTypography.h3.copyWith(
                color: customColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure your daily macro targets',
              style: PremiumTypography.bodyMedium.copyWith(
                color: customColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Calorie display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PremiumColors.blue500.withAlpha(((0.1) * 255).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Calories',
                    style: PremiumTypography.bodyLarge.copyWith(
                      color: customColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${totalCalories.round()} kcal',
                    style: PremiumTypography.h4.copyWith(
                      color: PremiumColors.blue500,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Macro inputs
            PremiumInput(
              label: 'Protein (g)',
              controller: _proteinController,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.fitness_center_rounded,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            PremiumInput(
              label: 'Carbs (g)',
              controller: _carbsController,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.grain_rounded,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            PremiumInput(
              label: 'Fat (g)',
              controller: _fatController,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.opacity_rounded,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: PremiumButton.outlined(
                    text: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PremiumButton.primary(
                    text: 'Save Goals',
                    onPressed: () {
                      final protein =
                          double.tryParse(_proteinController.text) ?? 0;
                      final carbs = double.tryParse(_carbsController.text) ?? 0;
                      final fat = double.tryParse(_fatController.text) ?? 0;

                      widget.onSave(protein, carbs, fat);
                      Navigator.of(context).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Goals updated successfully!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
