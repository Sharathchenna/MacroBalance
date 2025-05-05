import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import '../providers/foodEntryProvider.dart';
import '../models/foodEntry.dart';

class MacroTrackingScreen extends StatefulWidget {
  final bool hideAppBar;

  const MacroTrackingScreen({
    Key? key,
    this.hideAppBar = false,
  }) : super(key: key);

  @override
  State<MacroTrackingScreen> createState() => _MacroTrackingScreenState();
}

class _MacroTrackingScreenState extends State<MacroTrackingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  String _selectedTimeFrame = 'Week';
  String _selectedChartView = 'Calories';

  // Macro targets
  double _targetProtein = 0;
  double _targetCarbs = 0;
  double _targetFat = 0;

  // Macro history
  List<Map<String, dynamic>> _macroHistory = [];

  // ValueNotifier for macro percentages (updated when data loads or changes)
  late final ValueNotifier<Map<String, double>> _macroPercentages;

  // Flag to ensure animation starts only once
  bool _isAnimationStarted = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _macroPercentages = ValueNotifier({
      'protein': 0,
      'carbs': 0,
      'fat': 0,
    });

    // Load initial goals and history after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadInitialData(); // Renamed function
      }
    });
    // DO NOT start animation here
  }

  @override
  void dispose() {
    _macroPercentages.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Combined function to load goals and history
  Future<void> _loadInitialData() async {
    // No setState for loading = true needed, FutureBuilder handles UI
    try {
      final foodEntryProvider =
          Provider.of<FoodEntryProvider>(context, listen: false);
      // FutureBuilder already ensures initialization, but double-check won't hurt
      await foodEntryProvider.ensureInitialized();

      // --- Load History (Keep this logic here for the chart) ---
      List<Map<String, dynamic>> history = [];
      history = List<Map<String, dynamic>>.empty(growable: true);
      final todayDateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      for (int i = 29; i >= 0; i--) {
          final date = DateTime.now().subtract(Duration(days: i));
          // This might be inefficient if getAllEntriesForDate is slow,
          // consider optimizing in provider if needed.
          List<FoodEntry> entriesForDate = foodEntryProvider.getAllEntriesForDate(date);
          double protein = 0, carbs = 0, fat = 0;
          for (var entry in entriesForDate) {
              double multiplier = entry.quantity;
              switch (entry.unit) {
                  case "oz": multiplier *= 28.35; break;
                  case "kg": multiplier *= 1000; break;
                  case "lbs": multiplier *= 453.59; break;
              }
              multiplier /= 100;
              protein += (entry.food.nutrients['Protein'] ?? 0) * multiplier;
              carbs += (entry.food.nutrients['Carbohydrate, by difference'] ?? 0) * multiplier;
              fat += (entry.food.nutrients['Total lipid (fat)'] ?? 0) * multiplier;
          }
          history.add({'date': date, 'protein': protein, 'carbs': carbs, 'fat': fat});
      }
      // Ensure history isn't empty for chart rendering
      if (history.isEmpty) {
        history = List.generate(30, (i) {
            final date = DateTime.now().subtract(Duration(days: 29 - i));
            return {'date': date, 'protein': 0.0, 'carbs': 0.0, 'fat': 0.0};
        });
      }
      // --- End History Load ---


      // Load goals and history into state in one go
      if (mounted) {
        setState(() {
          _targetProtein = foodEntryProvider.proteinGoal;
          _targetCarbs = foodEntryProvider.carbsGoal;
          _targetFat = foodEntryProvider.fatGoal;
          _macroHistory = history; // Update history state
        });
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      if (mounted) {
         setState(() {
             // Initialize history with default data on error
             _macroHistory = List.generate(30, (i) {
                 final date = DateTime.now().subtract(Duration(days: 29 - i));
                 return {'date': date, 'protein': 0.0, 'carbs': 0.0, 'fat': 0.0};
             });
             // Optionally set default goals or show error message
         });
      }
    }
    // No setState for loading = false, no animation start here
  }

  // Update macro percentages - Use data directly from Consumer/Provider
  void _updateMacroPercentages(double totalCalories, Map<String, double> nutrientTotals) {
      final percentages = {
          'protein': totalCalories > 0 ? ((nutrientTotals['protein'] ?? 0.0) * 4 / totalCalories * 100) : 0,
          'carbs': totalCalories > 0 ? ((nutrientTotals['carbs'] ?? 0.0) * 4 / totalCalories * 100) : 0,
          'fat': totalCalories > 0 ? ((nutrientTotals['fat'] ?? 0.0) * 9 / totalCalories * 100) : 0,
      };
      _macroPercentages.value = {
          'protein': percentages['protein']!.toDouble(),
          'carbs': percentages['carbs']!.toDouble(),
          'fat': percentages['fat']!.toDouble(),
      };
  }

  // Calculates target calories based on target macros (state)
  double _calculateTargetCalories(double protein, double carbs, double fat) {
    return (protein * 4) + (carbs * 4) + (fat * 9);
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
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              title: Text(
                'Macro Tracking',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: customColors.textPrimary,
                ),
              ),
              backgroundColor: theme.scaffoldBackgroundColor,
              elevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle.dark,
            ),
      body: FutureBuilder(
        // Use FutureBuilder ONLY to ensure provider is ready
        future: Provider.of<FoodEntryProvider>(context, listen: false)
            .ensureInitialized(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show loading indicator while provider initializes
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Text('Error initializing provider: ${snapshot.error}'));
          } else {
            // Provider is initialized, now use Consumer to get data and build UI
            return SafeArea(
              child: Consumer<FoodEntryProvider>(
                builder: (context, foodEntryProvider, child) {
                  // --- Get Data Directly from Provider ---
                  final nutrientTotals = foodEntryProvider
                      .getNutrientTotalsForDate(DateTime.now());
                  final currentCalories = nutrientTotals['calories'] ?? 0.0;
                  final currentProtein = nutrientTotals['protein'] ?? 0.0;
                  final currentCarbs = nutrientTotals['carbs'] ?? 0.0;
                  final currentFat = nutrientTotals['fat'] ?? 0.0;

                  // --- Animation Control ---
                  // Start animation only once after the first build completes with data
                  // This runs *after* the build method completes for this frame.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_isAnimationStarted) {
                      _animationController.forward();
                      _isAnimationStarted = true; // Set flag to prevent restart
                    }
                  });

                  // Update ValueNotifier for percentages (doesn't trigger full rebuild)
                  _updateMacroPercentages(currentCalories, nutrientTotals);

                  // Calculate target calories based on state goals
                  final targetCalories = _calculateTargetCalories(
                      _targetProtein, _targetCarbs, _targetFat);

                  // Build the main UI using data from provider and state
                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RepaintBoundary(
                                child: _buildMacroSummaryCard(
                                    context,
                                    customColors,
                                    currentCalories, // Pass current calories
                                    targetCalories, // Pass target calories
                                    // Pass current macros from provider
                                    currentProtein,
                                    currentCarbs,
                                    currentFat
                                 ),
                              ),
                              const SizedBox(height: 24),
                              // Pass history from state to chart
                              _buildMacroChart(customColors),
                              const SizedBox(height: 24),
                              RepaintBoundary(
                                child: _buildMacroGoals(customColors,
                                    targetCalories), // Pass calculated target calories
                              ),
                              const SizedBox(height: 50),
                            ],
                          ),
                        ),
                      )
                    ],
                  );
                },
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildMacroChart(CustomColors customColors) {
    // Calculate target value based on view type
    final targetValueForChart = _selectedChartView == 'Calories'
        ? _calculateTargetCalories(_targetProtein, _targetCarbs, _targetFat)
        : _targetProtein + _targetCarbs + _targetFat;

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: customColors.cardBackground,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Nutrition Intake',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: customColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 240,
              child: RepaintBoundary(
                child: MacroBarChart(
                  macroData: _getFilteredHistory(),
                  animation: _animationController,
                  customColors: customColors,
                  targetProtein: _targetProtein, // Added targetProtein
                  targetCarbs: _targetCarbs, // Added targetCarbs
                  targetFat: _targetFat, // Added targetFat
                  // targetValue: targetValueForChart, // Removed - Painter calculates this internally
                  showCalories: _selectedChartView == 'Calories',
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              spacing: 16,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem(
                    'Protein', // Use round()
                    Colors.red.shade600,
                    customColors), // Protein: Red
                _buildLegendItem(
                    'Carbs', // Use round()
                    Colors.blue.shade600,
                    customColors), // Carbs: Blue
                _buildLegendItem(
                    'Fat', // Use round()
                    Colors.amber.shade600,
                    customColors), // Fat: Yellow/Amber
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartViewTab(
      String title, bool isSelected, CustomColors customColors) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedChartView = title;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? customColors.cardBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              title == 'Calories' ? Icons.local_fire_department : Icons.scale,
              size: 14,
              color: isSelected
                  ? customColors.accentPrimary
                  : customColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? customColors.accentPrimary
                    : customColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroSummaryCard(BuildContext context, CustomColors customColors,
      double currentCalories, double targetCalories, double currentProtein, double currentCarbs, double currentFat){
    // Added parameters
    final calorieProgress =
        _getProgressPercentage(currentCalories, targetCalories);

    return Container(
      decoration: BoxDecoration(
        color: customColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Today\'s Nutrition',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: customColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color:
                                  customColors.accentPrimary.withOpacity(0.8),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                DateFormat('EEEE, MMM d')
                                    .format(DateTime.now()),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: customColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Content
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: customColors.cardBackground,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
                border: Border.all(
                  color: customColors.accentPrimary.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Calorie progress circle
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.easeOutExpo,
                    tween: Tween<double>(begin: 0, end: calorieProgress),
                    builder: (context, animatedProgress, child) {
                      return Container(
                        width: 120,
                        height: 120,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: customColors.cardBackground,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 100,
                                height: 100,
                                child: CircularProgressIndicator(
                                  value: animatedProgress,
                                  backgroundColor:
                                      customColors.dateNavigatorBackground,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    animatedProgress >= 1.0
                                        ? Colors.green.shade500
                                        : customColors.accentPrimary,
                                  ),
                                  strokeWidth: 8,
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: customColors.cardBackground,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TweenAnimationBuilder<double>(
                                      duration:
                                          const Duration(milliseconds: 1500),
                                      curve: Curves.easeOutCubic,
                                      tween: Tween<double>(
                                          begin: 0, end: currentCalories),
                                      builder: (context, value, _) {
                                        return Text(
                                          value.round().toString(),
                                          style: GoogleFonts.inter(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: animatedProgress >= 1.0
                                                ? Colors.green.shade500
                                                : customColors.accentPrimary,
                                          ),
                                        );
                                      },
                                    ),
                                    Text(
                                      'kcal',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: customColors.textSecondary,
                                        height: 1.2,
                                      ),
                                    ),
                                    Text(
                                      'of ${targetCalories.round()}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: customColors.textSecondary
                                            .withOpacity(0.7),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (animatedProgress >= 1.0)
                                Positioned(
                                  top: 10,
                                  child: Icon(
                                    Icons.star_rounded,
                                    color: Colors.amber.shade400,
                                    size: 20,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMacroIndicator(
                        'Protein',
                        currentProtein, // Use passed value
                        _targetProtein, // Use state value for target
                        Colors.red.shade600,
                        customColors,
                      ),
                      const SizedBox(height: 14),
                      _buildMacroIndicator(
                        'Carbs',
                        currentCarbs, // Use passed value
                        _targetCarbs, // Use state value for target
                        Colors.blue.shade600,
                        customColors,
                      ),
                      const SizedBox(height: 14),
                      _buildMacroIndicator(
                        'Fat',
                        currentFat, // Use passed value
                        _targetFat, // Use state value for target
                        Colors.amber.shade600,
                        customColors,
                      ),
                    ]// Macr)o indicators - Pass current values from parameters
                  ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroIndicator(
    String label,
    double current,
    double target,
    Color color,
    CustomColors customColors,
  ) {
    final progress = _getProgressPercentage(current, target);
    final percentage = (progress * 100).round(); // Use round()

    // Create gradient colors based on progress
    final gradientColors = progress >= 1.0
        ? [Colors.green.shade600, Colors.green.shade400]
        : [color.withOpacity(0.9), color];

    return LayoutBuilder(builder: (context, constraints) {
      // Determine if we're on a narrow screen
      final isNarrow = constraints.maxWidth < 220;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Label with icon
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: customColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              // Adaptive spacing
              SizedBox(width: isNarrow ? 4 : 8),

              // Values with percentage
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Current value
                    Text(
                      '${current.round()}', // Use round()
                      style: GoogleFonts.inter(
                        fontSize: isNarrow ? 13 : 14,
                        fontWeight: FontWeight.w700,
                        color: customColors.textPrimary,
                      ),
                    ),

                    // Target value with slash
                    Text(
                      '/${target.round()}g', // Use round()
                      style: GoogleFonts.inter(
                        fontSize: isNarrow ? 13 : 14,
                        color: customColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(width: isNarrow ? 3 : 6),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Progress bar with rounded corners and shadow
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  // Background
                  Container(
                    height: 8,
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  // Progress with gradient
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(begin: 0, end: progress),
                    builder: (context, animatedProgress, _) {
                      // Ensure animatedProgress is within valid range to prevent rendering errors
                      final safeProgress = animatedProgress.clamp(0.0, 1.0);
                      return Container(
                        height: 8,
                        width: safeProgress * constraints.maxWidth,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: gradientColors,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildMacroBreakdown(
      CustomColors customColors,
      double totalCalories,
      // Add current macros from provider
      double currentProtein,
      double currentCarbs,
      double currentFat
   ) {
    // Use passed-in values instead of state variables
    final proteinPercentage = totalCalories > 0
        ? (currentProtein * 4 / totalCalories * 100).round()
        : 0;
    final carbsPercentage = totalCalories > 0
        ? (currentCarbs * 4 / totalCalories * 100).round()
        : 0;
    final fatPercentage =
        totalCalories > 0 ? (currentFat * 9 / totalCalories * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: customColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Macro Breakdown',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: customColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Percentage of total calories from each source',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: customColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Macro distribution bar
          Container(
            height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Row(
                children: [
                  Expanded(
                    flex: proteinPercentage,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.red.shade700,
                            Colors.red.shade500
                          ], // Protein: Blue
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: carbsPercentage,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.blue.shade700,
                            Colors.blue.shade500
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: fatPercentage,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.amber.shade700,
                            Colors.amber.shade500
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroPercentageIndicator('Protein', proteinPercentage,
                  Colors.red.shade600, customColors), // Carbs: Red
              _buildMacroPercentageIndicator(
                  'Carbs', carbsPercentage, Colors.blue.shade600, customColors),
              _buildMacroPercentageIndicator('Fat', fatPercentage,
                  Colors.amber.shade600, customColors), // Fat: Yellow/Amber
            ],
          ),
          const SizedBox(height: 24),

          _buildMacroBreakdownItem(
            'Protein',
            currentProtein, // Use passed value
            proteinPercentage,
            Colors.red.shade600,
            customColors,
          ),
          const SizedBox(height: 16),
          _buildMacroBreakdownItem(
            'Carbs',
            currentCarbs, // Use passed value
            carbsPercentage,
            Colors.blue.shade600,
            customColors,
          ),
          const SizedBox(height: 16),
          _buildMacroBreakdownItem(
            'Fat',
            currentFat, // Use passed value
            fatPercentage,
            Colors.amber.shade600,
            customColors,
          ),
        ],
      ),
    );
  }

  Widget _buildMacroPercentageIndicator(
      String label, int percentage, Color color, CustomColors customColors) {
    return Column(
      children: [
        Text(
          '$percentage%',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: customColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMacroBreakdownItem(
    String label,
    double grams,
    int percentage,
    Color color,
    CustomColors customColors,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$percentage%',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: customColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${grams.round()}g', // Use round()
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    Text(
                      ' • ${(grams * (label == 'Fat' ? 9 : 4)).round()} calories', // Use round()
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: customColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.analytics_outlined,
              size: 20,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroGoals(CustomColors customColors, double targetCalories) {
    // Added targetCalories
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: customColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nutrition Goals',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: customColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your daily targets',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: customColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: customColors.accentPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () => _showEditGoalsDialog(context),
                  icon: Icon(
                    Icons.edit_outlined,
                    color: customColors.accentPrimary,
                    size: 20,
                  ),
                  tooltip: 'Edit Goals',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: customColors.dateNavigatorBackground.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildGoalItem(
                    'Protein',
                    _targetProtein,
                    Colors.red.shade600, // Carbs: Red
                    customColors),
                Container(
                  height: 40,
                  width: 1,
                  color: customColors.dateNavigatorBackground,
                ),
                _buildGoalItem(
                    'Carbs', _targetCarbs, Colors.blue.shade600, customColors),
                Container(
                  height: 40,
                  width: 1,
                  color: customColors.dateNavigatorBackground,
                ),
                _buildGoalItem('Fat', _targetFat, Colors.amber.shade600,
                    customColors), // Fat: Yellow/Amber
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Total calorie goal card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  customColors.accentPrimary.withOpacity(0.1),
                  customColors.cardBackground,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: customColors.accentPrimary.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: customColors.accentPrimary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_fire_department_outlined,
                    color: customColors.accentPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Calorie Goal',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: customColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${targetCalories.round()} calories', // Use passed targetCalories and round()
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: customColors.accentPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalItem(
    String label,
    double target,
    Color color,
    CustomColors customColors,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: customColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              target.round().toString(), // Use round()
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              'g',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: customColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showAddMacrosDialog(
      BuildContext context, CustomColors customColors) async {
    double protein = 0;
    double carbs = 0;
    double fat = 0;
    final proteinController =
        TextEditingController(text: protein.round().toString()); // Use round()
    final carbsController =
        TextEditingController(text: carbs.round().toString()); // Use round()
    final fatController =
        TextEditingController(text: fat.round().toString()); // Use round()

    // Calculate total calories from macros
    double calculateCalories() {
      return (protein * 4) + (carbs * 4) + (fat * 9);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with title and close button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                TweenAnimationBuilder(
                                  duration: Duration(milliseconds: 500),
                                  tween: Tween<double>(begin: 0, end: 1),
                                  builder: (context, double value, child) {
                                    return Transform.scale(
                                      scale: value,
                                      child: Icon(
                                        Icons.restaurant,
                                        color: customColors.accentPrimary,
                                        size: 28,
                                      ),
                                    );
                                  },
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Add Food',
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: customColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(Icons.close,
                                  color: customColors.textSecondary),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),

                        SizedBox(height: 16),

                        // Calorie counter display
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: customColors.accentPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Calories to Add',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: customColors.textSecondary,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  TweenAnimationBuilder<double>(
                                    duration: Duration(milliseconds: 500),
                                    tween: Tween<double>(
                                      begin: 0,
                                      end: calculateCalories(),
                                    ),
                                    builder: (context, value, child) {
                                      return Text(
                                        value.round().toString(), // Use round()
                                        style: GoogleFonts.inter(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w800,
                                          color: customColors.accentPrimary,
                                        ),
                                      );
                                    },
                                  ),
                                  Text(
                                    ' kcal',
                                    style: GoogleFonts.inter(
                                      // Corrected style
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: customColors.accentPrimary,
                                    ),
                                  ),
                                  // Removed duplicate Text widget that caused error
                                ],
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 24),

                        // Protein input
                        _buildMacroInputField(
                          'Protein',
                          proteinController,
                          Colors.red
                              .shade600, // Carbs: Red (Fixing inconsistency)
                          customColors,
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              protein = double.tryParse(value) ?? protein;
                              dialogSetState(() {});
                            }
                          },
                        ),

                        SizedBox(height: 16),

                        // Carbs input
                        _buildMacroInputField(
                          'Carbs',
                          carbsController,
                          Colors.blue
                              .shade600, // Protein: Blue (Fixing inconsistency)
                          customColors,
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              carbs = double.tryParse(value) ?? carbs;
                              dialogSetState(() {});
                            }
                          },
                        ),

                        SizedBox(height: 16),

                        // Fat input
                        _buildMacroInputField(
                          'Fat',
                          fatController,
                          Colors.amber
                              .shade600, // Fat: Yellow/Amber (Fixing inconsistency)
                          customColors,
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              fat = double.tryParse(value) ?? fat;
                              dialogSetState(() {});
                            }
                          },
                        ),

                        SizedBox(height: 32),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade200,
                                  foregroundColor: Colors.black87,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: customColors.accentPrimary,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    // Now inside the state class
                                    _targetProtein = protein;
                                    _targetCarbs = carbs;
                                    _targetFat = fat;
                                  });

                                  // Update in FoodEntryProvider
                                  final foodEntryProvider =
                                      Provider.of<FoodEntryProvider>(context,
                                          listen: false);
                                  // Use the setters which handle saving and syncing
                                  foodEntryProvider.proteinGoal = protein;
                                  foodEntryProvider.carbsGoal = carbs;
                                  foodEntryProvider.fatGoal = fat;
                                  // Recalculate calorie goal based on new macros
                                  foodEntryProvider.caloriesGoal =
                                      _calculateTargetCalories(protein, carbs, fat);

                                  Navigator.pop(context);

                                  // Show success message
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Goals updated successfully!'),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Save Goals',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
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
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showEditGoalsDialog(BuildContext context) async {
    final customColors = Theme.of(context).extension<CustomColors>()!;

    // Variables to hold user input
    double protein = _targetProtein; // Now accessible
    double carbs = _targetCarbs; // Now accessible
    double fat = _targetFat; // Now accessible
    final proteinController =
        TextEditingController(text: protein.round().toString());
    final carbsController =
        TextEditingController(text: carbs.round().toString());
    final fatController = TextEditingController(text: fat.round().toString());

    // Helper to recalculate calories within the dialog
    double calculateDialogCalories() {
      return (protein * 4) + (carbs * 4) + (fat * 9);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with title and close button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                TweenAnimationBuilder(
                                  duration: Duration(milliseconds: 500),
                                  tween: Tween<double>(begin: 0, end: 1),
                                  builder: (context, double value, child) {
                                    return Transform.scale(
                                      scale: value,
                                      child: Icon(
                                        Icons.fitness_center,
                                        color: customColors.accentPrimary,
                                        size: 28,
                                      ),
                                    );
                                  },
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Set Nutrition Goals',
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: customColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(Icons.close,
                                  color: customColors.textSecondary),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),

                        SizedBox(height: 16),

                        // Calorie counter display
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: customColors.accentPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Daily Calorie Goal',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: customColors.textSecondary,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  TweenAnimationBuilder<double>(
                                    duration: Duration(milliseconds: 500),
                                    tween: Tween<double>(
                                      begin: 0,
                                      end:
                                          calculateDialogCalories(), // Use helper
                                    ),
                                    builder: (context, value, child) {
                                      return Text(
                                        value.toInt().toString(),
                                        style: GoogleFonts.inter(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w800,
                                          color: customColors.accentPrimary,
                                        ),
                                      );
                                    },
                                  ),
                                  Text(
                                    ' kcal',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: customColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 24),

                        // Protein input
                        _buildMacroInputField(
                          'Protein',
                          proteinController,
                          Colors.red.shade600, // Carbs: Red
                          customColors,
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              protein = double.tryParse(value) ?? protein;
                              dialogSetState(() {}); // Update dialog state
                            }
                          },
                        ),

                        SizedBox(height: 16),

                        // Carbs input
                        _buildMacroInputField(
                          'Carbs',
                          carbsController,
                          Colors.blue.shade600, // Protein: Blue
                          customColors,
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              carbs = double.tryParse(value) ?? carbs;
                              dialogSetState(() {}); // Update dialog state
                            }
                          },
                        ),

                        SizedBox(height: 16),

                        // Fat input
                        _buildMacroInputField(
                          'Fat',
                          fatController,
                          Colors.amber.shade600, // Fat: Yellow/Amber
                          customColors,
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              fat = double.tryParse(value) ?? fat;
                              dialogSetState(() {}); // Update dialog state
                            }
                          },
                        ),

                        SizedBox(height: 32),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade200,
                                  foregroundColor: Colors.black87,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: customColors.accentPrimary,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  try {
                                    // Update goals in the main state
                                    setState(() {
                                      // Now inside the state class
                                      _targetProtein = protein;
                                      _targetCarbs = carbs;
                                      _targetFat = fat;
                                    });

                                    // Update in FoodEntryProvider
                                    final foodEntryProvider =
                                        Provider.of<FoodEntryProvider>(context,
                                            listen: false);
                                    // Use the setters which handle saving and syncing
                                    foodEntryProvider.proteinGoal = protein;
                                    foodEntryProvider.carbsGoal = carbs;
                                    foodEntryProvider.fatGoal = fat;
                                    // Recalculate calorie goal based on new macros
                                    foodEntryProvider.caloriesGoal =
                                        calculateDialogCalories();

                                    Navigator.pop(context);

                                    // Show success message
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('Goals updated successfully!'),
                                        backgroundColor: Colors.green,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    // Handle error
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Failed to update goals: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Text(
                                  'Save Goals',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
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
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMacroInputField(
    String label,
    TextEditingController controller,
    Color color,
    CustomColors customColors, {
    required void Function(String) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                label[0],
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: customColors.textPrimary,
                  ),
                ),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  onChanged: onChanged,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    suffixText: 'grams',
                    suffixStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: customColors.textSecondary,
                    ),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
    String label,
    Color color,
    CustomColors customColors,
  ) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: customColors.textSecondary,
          ),
        ),
      ],
    );
  }

  double _calculateTotalCalories(double protein, double carbs, double fat) {
    return (protein * 4) + (carbs * 4) + (fat * 9);
  }

  double _getProgressPercentage(double current, double target) {
    if (target == 0) return 0;
    final progress = current / target;
    return progress > 1 ? 1 : progress;
  }

  List<Map<String, dynamic>> _getFilteredHistory() {
    final DateTime now = DateTime.now();
    List<Map<String, dynamic>> filtered = [];

    // Get the last 7 days only
    final weekAgo = now.subtract(const Duration(days: 7));
    filtered = _macroHistory
        .where((entry) =>
            (entry['date'] as DateTime).isAfter(weekAgo) ||
            DateFormat('yyyy-MM-dd').format(entry['date'] as DateTime) ==
                DateFormat('yyyy-MM-dd').format(weekAgo))
        .toList();

    // Ensure we have at most 7 entries by taking the most recent
    if (filtered.length > 7) {
      filtered = filtered.sublist(filtered.length - 7);
    }

    return filtered;
  }
}

class MacroBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> macroData;
  final Animation<double> animation;
  final CustomColors customColors;
  final double targetProtein;
  final double targetCarbs;
  final double targetFat;
  final bool showCalories;

  const MacroBarChart({
    Key? key,
    required this.macroData,
    required this.animation,
    required this.customColors,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
    required this.showCalories,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _MacroBarChartPainter(
                macroData: macroData,
                animation: animation.value,
                customColors: customColors,
                targetProtein: targetProtein,
                targetCarbs: targetCarbs,
                targetFat: targetFat,
                showCalories: showCalories,
              ),
            );
          },
        );
      },
    );
  }
}

class _MacroBarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> macroData;
  final double animation;
  final CustomColors customColors;
  final double targetProtein;
  final double targetCarbs;
  final double targetFat;
  final bool showCalories;

  // Cache for expensive calculations
  late final double _maxYValue;
  late final List<TextPainter> _dayLabels;
  late final List<TextPainter> _dateLabels;

  _MacroBarChartPainter({
    required this.macroData,
    required this.animation,
    required this.customColors,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
    required this.showCalories,
  }) {
    _maxYValue = _calculateMaxYValue();
    _dayLabels = _createDayLabels();
    _dateLabels = _createDateLabels();
  }

  double _calculateMaxYValue() {
    if (macroData.isEmpty) return showCalories ? 1800 : 300;

    double maxValue = 0;
    for (var data in macroData) {
      final double protein = (data['protein'] as num).toDouble();
      final double carbs = (data['carbs'] as num).toDouble();
      final double fat = (data['fat'] as num).toDouble();

      final double total = showCalories
          ? (protein * 4 + carbs * 4 + fat * 9)
          : protein + carbs + fat;
      maxValue = math.max(maxValue, total);
    }

    // Add target value to scale
    final targetValue = showCalories
        ? (targetProtein * 4 + targetCarbs * 4 + targetFat * 9)
        : targetProtein + targetCarbs + targetFat;
    maxValue = math.max(maxValue, targetValue);

    // Round up to nearest 500 for calories or 50 for grams
    if (showCalories) {
      maxValue = ((maxValue / 500).ceil() * 500).toDouble();
      return math.max(maxValue, 1800);
    } else {
      maxValue = ((maxValue / 50).ceil() * 50).toDouble();
      return math.max(maxValue, 300);
    }
  }

  List<TextPainter> _createDayLabels() {
    final daysOfWeek = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return macroData.map((data) {
      final date = data['date'] as DateTime;
      final isToday = DateFormat('yyyy-MM-dd').format(date) ==
          DateFormat('yyyy-MM-dd').format(DateTime.now());
      return TextPainter(
        text: TextSpan(
          text: daysOfWeek[date.weekday % 7],
          style: TextStyle(
            color: isToday
                ? customColors.accentPrimary
                : customColors.textSecondary,
            fontSize: 12,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
    }).toList();
  }

  List<TextPainter> _createDateLabels() {
    return macroData.map((data) {
      final date = data['date'] as DateTime;
      final isToday = DateFormat('yyyy-MM-dd').format(date) ==
          DateFormat('yyyy-MM-dd').format(DateTime.now());
      return TextPainter(
        text: TextSpan(
          text: DateFormat('d').format(date),
          style: TextStyle(
            color: isToday
                ? customColors.accentPrimary
                : customColors.textSecondary,
            fontSize: 10,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
    }).toList();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (macroData.isEmpty) return;

    final chartArea = Rect.fromLTWH(
      40,
      10,
      size.width - 50,
      size.height - 40,
    );

    _drawYAxis(canvas, chartArea);
    _drawBars(canvas, chartArea);
    _drawTargetLine(canvas, chartArea);
  }

  void _drawBars(Canvas canvas, Rect chartArea) {
    final barWidth = chartArea.width / (macroData.length * 2 + 1);
    final cornerRadius = 2.0;

    for (int i = 0; i < macroData.length; i++) {
      final data = macroData[i];
      final x = chartArea.left + (i * 2 + 1) * barWidth;
      _drawBar(canvas, data, x, barWidth, cornerRadius, chartArea);

      // Draw labels
      _dayLabels[i].paint(
        canvas,
        Offset(x - _dayLabels[i].width / 2, chartArea.bottom + 5),
      );
      _dateLabels[i].paint(
        canvas,
        Offset(x - _dateLabels[i].width / 2, chartArea.bottom + 22),
      );
    }
  }

  void _drawBar(Canvas canvas, Map<String, dynamic> data, double x,
      double barWidth, double cornerRadius, Rect chartArea) {
    final double protein = (data['protein'] as num).toDouble();
    final double carbs = (data['carbs'] as num).toDouble();
    final double fat = (data['fat'] as num).toDouble();

    final double totalHeight = showCalories
        ? (protein * 4 + carbs * 4 + fat * 9) / _maxYValue * chartArea.height
        : (protein + carbs + fat) / _maxYValue * chartArea.height;

    final double proteinHeight = showCalories
        ? (protein * 4) / _maxYValue * chartArea.height
        : protein / _maxYValue * chartArea.height;

    final double carbsHeight = showCalories
        ? (carbs * 4) / _maxYValue * chartArea.height
        : carbs / _maxYValue * chartArea.height;

    final double fatHeight = showCalories
        ? (fat * 9) / _maxYValue * chartArea.height
        : fat / _maxYValue * chartArea.height;

    final barRect = Rect.fromLTWH(
      x - barWidth / 2,
      chartArea.bottom - totalHeight * animation,
      barWidth,
      totalHeight * animation,
    );

    // Draw protein segment
    if (proteinHeight > 0) {
      final proteinRect = Rect.fromLTWH(
        barRect.left,
        barRect.bottom - proteinHeight,
        barWidth,
        proteinHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          proteinRect,
          // topLeft: Radius.circular(cornerRadius),
          // topRight: Radius.circular(cornerRadius),
        ),
        Paint()..color = Colors.red.shade600, // Carbs: Red
      );
    }

    // Draw carbs segment
    if (carbsHeight > 0) {
      final carbsRect = Rect.fromLTWH(
        barRect.left,
        barRect.bottom - proteinHeight - carbsHeight,
        barWidth,
        carbsHeight,
      );
      canvas.drawRect(
        carbsRect,
        Paint()..color = Colors.blue.shade600, // Protein: Blue
      );
    }

    // Draw fat segment
    if (fatHeight > 0) {
      final fatRect = Rect.fromLTWH(
        barRect.left,
        barRect.bottom - proteinHeight - carbsHeight - fatHeight,
        barWidth,
        fatHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          fatRect,
          topLeft: Radius.circular(cornerRadius),
          topRight: Radius.circular(cornerRadius),
        ),
        Paint()..color = Colors.amber.shade600, // Fat: Yellow/Amber
      );
    }
  }

  void _drawYAxis(Canvas canvas, Rect chartArea) {
    final paint = Paint()
      ..color = customColors.textSecondary.withOpacity(0.2)
      ..strokeWidth = 1;

    // Draw horizontal grid lines
    final yStep = chartArea.height / 5;
    for (int i = 0; i <= 5; i++) {
      final y = chartArea.top + (i * yStep);
      canvas.drawLine(
        Offset(chartArea.left, y),
        Offset(chartArea.right, y),
        paint,
      );

      // Draw y-axis labels
      if (i < 5) {
        final value = _maxYValue * (1 - (i / 5));
        final label = showCalories
            ? '${(value / 100).round() * 100}'
            : '${(value / 10).round() * 10}g';

        final textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: customColors.textSecondary.withOpacity(0.7),
              fontSize: 10,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(chartArea.left - textPainter.width - 8,
              y - textPainter.height / 2),
        );
      }
    }
  }

  void _drawTargetLine(Canvas canvas, Rect chartArea) {
    final targetValue = showCalories
        ? (targetProtein * 4 + targetCarbs * 4 + targetFat * 9) /
            _maxYValue *
            chartArea.height
        : (targetProtein + targetCarbs + targetFat) /
            _maxYValue *
            chartArea.height;

    final y = chartArea.bottom - targetValue;

    final paint = Paint()
      ..color = Colors.blue.shade400
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Draw dashed line
    double x = chartArea.left;
    while (x < chartArea.right) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x + 6, y),
        paint,
      );
      x += 10;
    }
  }

  @override
  bool shouldRepaint(covariant _MacroBarChartPainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.showCalories != showCalories;
  }
}

// Replace the existing MacroDistributionPainter with this implementation
class MacroDistributionPainter extends CustomPainter {
  final double protein;
  final double carbs;
  final double fat;
  final double targetProtein;
  final double targetCarbs;
  final double targetFat;
  final Animation<double> animation;

  MacroDistributionPainter({
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
    required this.animation,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // Calculate total calories for percentages
    final totalCalories = (protein * 4) + (carbs * 4) + (fat * 9);
    final targetCalories =
        (targetProtein * 4) + (targetCarbs * 4) + (targetFat * 9);

    if (totalCalories > 0) {
      // Draw background arcs
      _drawArc(canvas, center, radius, 0, 2 * math.pi / 3,
          Colors.blue.withOpacity(0.1));
      _drawArc(canvas, center, radius, 2 * math.pi / 3, 4 * math.pi / 3,
          Colors.orange.withOpacity(0.1));
      _drawArc(canvas, center, radius, 4 * math.pi / 3, 2 * math.pi,
          Colors.red.withOpacity(0.1));

      // Draw progress arcs
      final proteinAngle =
          (protein / targetProtein).clamp(0.0, 1.0) * (2 * math.pi / 3);
      final carbsAngle =
          (carbs / targetCarbs).clamp(0.0, 1.0) * (2 * math.pi / 3);
      final fatAngle = (fat / targetFat).clamp(0.0, 1.0) * (2 * math.pi / 3);

      _drawArc(canvas, center, radius, 0, proteinAngle * animation.value,
          Colors.blue);
      _drawArc(canvas, center, radius, 2 * math.pi / 3,
          (2 * math.pi / 3) + (carbsAngle * animation.value), Colors.orange);
      _drawArc(canvas, center, radius, 4 * math.pi / 3,
          (4 * math.pi / 3) + (fatAngle * animation.value), Colors.red);
    }
  }

  void _drawArc(Canvas canvas, Offset center, double radius, double startAngle,
      double endAngle, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle - math.pi / 2,
      endAngle - startAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(MacroDistributionPainter oldDelegate) => true;
}
