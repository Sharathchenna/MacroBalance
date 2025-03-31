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
  bool _isLoading = true;
  String _selectedTimeFrame = 'Week';
  String _selectedChartView = 'Calories';
  
  // Macro targets
  double _targetProtein = 0;
  double _targetCarbs = 0;
  double _targetFat = 0;
  
  // Current macros
  double _currentProtein = 0;
  double _currentCarbs = 0;
  double _currentFat = 0;
  
  // Macro history
  List<Map<String, dynamic>> _macroHistory = [];

  // Add caching for computed values
  late final ValueNotifier<double> _currentCalories;
  late final ValueNotifier<Map<String, double>> _macroPercentages;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _loadMacroData();
    
    _currentCalories = ValueNotifier(0);
    _macroPercentages = ValueNotifier({
      'protein': 0,
      'carbs': 0,
      'fat': 0,
    });
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _currentCalories.dispose();
    _macroPercentages.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _updateCalculatedValues() {
    final totalCalories = _calculateTotalCalories(
      _currentProtein,
      _currentCarbs,
      _currentFat,
    );
    _currentCalories.value = totalCalories;

    final percentages = {
      'protein': totalCalories > 0 ? (_currentProtein * 4 / totalCalories * 100) : 0,
      'carbs': totalCalories > 0 ? (_currentCarbs * 4 / totalCalories * 100) : 0,
      'fat': totalCalories > 0 ? (_currentFat * 9 / totalCalories * 100) : 0,
    };
    _macroPercentages.value = percentages as Map<String, double>;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>()!;

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RepaintBoundary(
                          child: _buildMacroSummaryCard(context, customColors),
                        ),
                        const SizedBox(height: 24),
                        _buildTimeFrameSelector(customColors),
                        const SizedBox(height: 24),
                        _buildMacroChart(customColors),
                        const SizedBox(height: 24),
                        RepaintBoundary(
                          child: _buildMacroBreakdown(customColors),
                        ),
                        const SizedBox(height: 24),
                        RepaintBoundary(
                          child: _buildMacroGoals(customColors),
                        ),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildMacroChart(CustomColors customColors) {
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
                  'Macro Intake',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: customColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track your nutrition progress',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: customColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: customColors.dateNavigatorBackground.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildChartViewTab('Calories', _selectedChartView == 'Calories', customColors),
                        _buildChartViewTab('Grams', _selectedChartView == 'Grams', customColors),
                      ],
                    ),
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
                  targetProtein: _targetProtein,
                  targetCarbs: _targetCarbs,
                  targetFat: _targetFat,
                  showCalories: _selectedChartView == 'Calories',
                ),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildLegendItem('Protein (${_targetProtein.toInt()}g)',
                    Colors.amber.shade300, customColors),
                _buildLegendItem('Carbs (${_targetCarbs.toInt()}g)',
                    Colors.teal.shade300, customColors),
                _buildLegendItem('Fat (${_targetFat.toInt()}g)',
                    Colors.purple.shade400, customColors),
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
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          children: [
            Icon(
              title == 'Calories' ? Icons.local_fire_department : Icons.scale,
              size: 14,
              color: isSelected ? customColors.accentPrimary : customColors.textSecondary,
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

  Widget _buildMacroSummaryCard(
      BuildContext context, CustomColors customColors) {
    final currentCalories = _calculateTotalCalories(
      _currentProtein,
      _currentCarbs,
      _currentFat,
    );
    final targetCalories = _calculateTotalCalories(
      _targetProtein,
      _targetCarbs,
      _targetFat,
    );
    final calorieProgress =
        _getProgressPercentage(currentCalories, targetCalories);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            customColors.accentPrimary.withOpacity(0.2),
            customColors.cardBackground,
          ],
          stops: const [0.1, 0.9],
        ),
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
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: customColors.accentPrimary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: customColors.accentPrimary.withOpacity(0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            ),
                            child: Icon(
                              Icons.restaurant_menu,
                              size: 20,
                              color: customColors.accentPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
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
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 42),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color: customColors.accentPrimary.withOpacity(0.8),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                DateFormat('EEEE, MMM d').format(DateTime.now()),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: customColors.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: customColors.accentPrimary.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: customColors.accentPrimary.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        calorieProgress >= 1.0 
                            ? Icons.star_rounded 
                            : Icons.trending_up_rounded,
                        size: 16,
                        color: customColors.accentPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${(calorieProgress * 100).toInt()}%',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: customColors.accentPrimary,
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
              child: Column(
                children: [
                  // Calorie circle with animated gradient
                  // Calorie progress circle with animated gradient
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.easeOutExpo,
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (context, value, child) {
                      final safeValue = value.clamp(0.0, 1.0);
                      return Container(
                        width: 140,
                        height: 140,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            center: Alignment.center,
                            startAngle: -math.pi / 2,
                            endAngle: math.max(-math.pi / 2 + 0.01, (2 * math.pi * safeValue) - (math.pi / 2)),
                            colors: [
                              customColors.accentPrimary.withOpacity(0.2),
                              customColors.accentPrimary,
                              customColors.accentPrimary.withOpacity(0.2),
                            ],
                            stops: const [0.0, 0.8, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: customColors.accentPrimary.withOpacity(0.15),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: customColors.cardBackground,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Progress indicator
                              SizedBox(
                                width: 120,
                                height: 120,
                                child: CircularProgressIndicator(
                                  value: calorieProgress,
                                  backgroundColor: customColors.dateNavigatorBackground.withOpacity(0.15),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    calorieProgress >= 1.0 
                                        ? Colors.green.shade500
                                        : customColors.accentPrimary,
                                  ),
                                  strokeWidth: 8,
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                              
                              // Inner content
                              Container(
                                width: 95,
                                height: 95,
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
                                    // Animated calorie count
                                    TweenAnimationBuilder<double>(
                                      duration: const Duration(milliseconds: 1500),
                                      curve: Curves.easeOutCubic,
                                      tween: Tween<double>(begin: 0, end: currentCalories),
                                      builder: (context, value, _) {
                                        return Text(
                                          value.toInt().toString(),
                                          style: GoogleFonts.inter(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            color: calorieProgress >= 1.0
                                                ? Colors.green.shade500
                                                : customColors.accentPrimary,
                                          ),
                                        );
                                      },
                                    ),
                                    
                                    // Unit label
                                    Text(
                                      'kcal',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: customColors.textSecondary,
                                        height: 1.2,
                                      ),
                                    ),
                                    
                                    // Target calories
                                    Text(
                                      'of ${targetCalories.toInt()}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: customColors.textSecondary.withOpacity(0.7),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Achievement indicator
                              if (calorieProgress >= 1.0)
                                Positioned(
                                  top: 10,
                                  child: Icon(
                                    Icons.star_rounded,
                                    color: Colors.amber.shade400,
                                    size: 24,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Macro indicators
                  _buildMacroIndicator(
                    'Protein',
                    _currentProtein,
                    _targetProtein,
                    Colors.blue.shade600,
                    customColors,
                  ),
                  const SizedBox(height: 14),
                  _buildMacroIndicator(
                    'Carbs',
                    _currentCarbs,
                    _targetCarbs,
                    Colors.orange.shade600,
                    customColors,
                  ),
                  const SizedBox(height: 14),
                  _buildMacroIndicator(
                    'Fat',
                    _currentFat,
                    _targetFat,
                    Colors.red.shade500,
                    customColors,
                  ),
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
    final percentage = (progress * 100).toInt();
    
    // Create gradient colors based on progress
    final gradientColors = progress >= 1.0 
        ? [Colors.green.shade600, Colors.green.shade400] 
        : [color.withOpacity(0.9), color];

    return LayoutBuilder(
      builder: (context, constraints) {
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
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          )
                        ]
                      ),
                    ),
                    const SizedBox(width: 8),
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
                        '${current.toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: isNarrow ? 13 : 14,
                          fontWeight: FontWeight.w700,
                          color: customColors.textPrimary,
                        ),
                      ),
                      
                      // Target value with slash
                      Text(
                        '/${target.toInt()}g',
                        style: GoogleFonts.inter(
                          fontSize: isNarrow ? 13 : 14,
                          color: customColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      SizedBox(width: isNarrow ? 3 : 6),
                      
                      // Percentage badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: progress >= 1.0 
                              ? Colors.green.shade500.withOpacity(0.1) 
                              : color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: progress >= 1.0 
                                  ? Colors.green.shade500.withOpacity(0.1)
                                  : color.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '$percentage%',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: progress >= 1.0 ? Colors.green.shade500 : color,
                          ),
                        ),
                      ),
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
      }
    );
  }

  Widget _buildTimeFrameSelector(CustomColors customColors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: customColors.dateNavigatorBackground.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['Week', 'Month', 'Year'].map((timeFrame) {
          final isSelected = _selectedTimeFrame == timeFrame;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() {
                    _selectedTimeFrame = timeFrame;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? customColors.cardBackground : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: customColors.accentPrimary.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    timeFrame,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? customColors.accentPrimary
                          : customColors.textPrimary.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMacroBreakdown(CustomColors customColors) {
    final totalCalories = _calculateTotalCalories(
      _currentProtein,
      _currentCarbs,
      _currentFat,
    );

    final proteinPercentage = totalCalories > 0
        ? (_currentProtein * 4 / totalCalories * 100).round()
        : 0;
    final carbsPercentage = totalCalories > 0
        ? (_currentCarbs * 4 / totalCalories * 100).round()
        : 0;
    final fatPercentage =
        totalCalories > 0 ? (_currentFat * 9 / totalCalories * 100).round() : 0;

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
                          colors: [Colors.blue.shade700, Colors.blue.shade500],
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
                          colors: [Colors.orange.shade700, Colors.orange.shade500],
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
                          colors: [Colors.red.shade700, Colors.red.shade500],
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
              _buildMacroPercentageIndicator('Protein', proteinPercentage, Colors.blue.shade600, customColors),
              _buildMacroPercentageIndicator('Carbs', carbsPercentage, Colors.orange.shade600, customColors),
              _buildMacroPercentageIndicator('Fat', fatPercentage, Colors.red.shade500, customColors),
            ],
          ),
          const SizedBox(height: 24),
          
          _buildMacroBreakdownItem(
            'Protein',
            _currentProtein,
            proteinPercentage,
            Colors.blue.shade600,
            customColors,
          ),
          const SizedBox(height: 16),
          _buildMacroBreakdownItem(
            'Carbs',
            _currentCarbs,
            carbsPercentage,
            Colors.orange.shade600,
            customColors,
          ),
          const SizedBox(height: 16),
          _buildMacroBreakdownItem(
            'Fat',
            _currentFat,
            fatPercentage,
            Colors.red.shade500,
            customColors,
          ),
        ],
      ),
    );
  }
  
  Widget _buildMacroPercentageIndicator(String label, int percentage, Color color, CustomColors customColors) {
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
                      '${grams.toInt()}g',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    Text(
                      ' • ${(grams * (label == 'Fat' ? 9 : 4)).toInt()} calories',
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

  Widget _buildMacroGoals(CustomColors customColors) {
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
                _buildGoalItem('Protein', _targetProtein, Colors.blue.shade600, customColors),
                Container(
                  height: 40,
                  width: 1,
                  color: customColors.dateNavigatorBackground,
                ),
                _buildGoalItem('Carbs', _targetCarbs, Colors.orange.shade600, customColors),
                Container(
                  height: 40,
                  width: 1,
                  color: customColors.dateNavigatorBackground,
                ),
                _buildGoalItem('Fat', _targetFat, Colors.red.shade500, customColors),
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
                        _calculateTotalCalories(_targetProtein, _targetCarbs, _targetFat).toInt().toString() + ' calories',
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
              target.toInt().toString(),
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
    final proteinController = TextEditingController(text: protein.toInt().toString());
    final carbsController = TextEditingController(text: carbs.toInt().toString());
    final fatController = TextEditingController(text: fat.toInt().toString());

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
                              icon: Icon(Icons.close, color: customColors.textSecondary),
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
                          Colors.red,
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
                          Colors.green,
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
                          Colors.blue,
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
                                    _currentProtein += protein;
                                    _currentCarbs += carbs;
                                    _currentFat += fat;
                                    
                                    // Update the macro history for today
                                    if (_macroHistory.isNotEmpty) {
                                      final today = _macroHistory.last;
                                      today['protein'] = _currentProtein;
                                      today['carbs'] = _currentCarbs;
                                      today['fat'] = _currentFat;
                                    }
                                  });
                                  Navigator.pop(context);
                                  
                                  // Show success message
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Food added successfully!'),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Add Food',
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

  Future<void> _showEditGoalsDialog(
      BuildContext context) async {
    final customColors = Theme.of(context).extension<CustomColors>()!;
    
    // Variables to hold user input
    double protein = _targetProtein;
    double carbs = _targetCarbs;
    double fat = _targetFat;
    final proteinController = TextEditingController(text: protein.toInt().toString());
    final carbsController = TextEditingController(text: carbs.toInt().toString());
    final fatController = TextEditingController(text: fat.toInt().toString());

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
                              icon: Icon(Icons.close, color: customColors.textSecondary),
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
                                      end: calculateCalories(),
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
                          Colors.red,
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
                          Colors.green,
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
                          Colors.blue,
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
                                  try {
                                    // Update goals
                                    setState(() {
                                      _targetProtein = protein;
                                      _targetCarbs = carbs;
                                      _targetFat = fat;
                                    });
                                    
                                    // Update in FoodEntryProvider
                                    final foodEntryProvider = Provider.of<FoodEntryProvider>(context, listen: false);
                                    foodEntryProvider.proteinGoal = _targetProtein;
                                    foodEntryProvider.carbsGoal = _targetCarbs;
                                    foodEntryProvider.fatGoal = _targetFat;
                                    
                                    Navigator.pop(context);
                                    
                                    // Show success message
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Goals updated successfully!'),
                                        backgroundColor: Colors.green,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    // Handle error
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to update goals: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
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

  Future<void> _loadMacroData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get the FoodEntryProvider
      final foodEntryProvider = Provider.of<FoodEntryProvider>(context, listen: false);
      
      // Get protein, carbs, and fat goals from provider
      _targetProtein = foodEntryProvider.proteinGoal;
      _targetCarbs = foodEntryProvider.carbsGoal;
      _targetFat = foodEntryProvider.fatGoal;

      // Generate macro history for the last 30 days
      _macroHistory = List<Map<String, dynamic>>.empty(growable: true);
      for (int i = 29; i >= 0; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        
        // Get food entries for this date
        List<FoodEntry> entriesForDate = foodEntryProvider.getEntriesForDate(date);
        
        // Calculate macros from food entries
        double protein = 0, carbs = 0, fat = 0;
        
        for (var entry in entriesForDate) {
          // Calculate multiplier based on quantity and unit
          double multiplier = entry.quantity;
          switch (entry.unit) {
            case "oz":
              multiplier *= 28.35;
              break;
            case "kg":
              multiplier *= 1000;
              break;
            case "lbs":
              multiplier *= 453.59;
              break;
          }
          multiplier /= 100; // Since nutrients are per 100g
          
          // Add protein, carbs and fat
          protein += (entry.food.nutrients['Protein'] ?? 0) * multiplier;
          carbs += (entry.food.nutrients['Carbohydrate, by difference'] ?? 0) * multiplier;
          fat += (entry.food.nutrients['Total lipid (fat)'] ?? 0) * multiplier;
        }
        
        _macroHistory.add({
          'date': date,
          'protein': protein,
          'carbs': carbs,
          'fat': fat,
        });
      }

      // Set current day's macros
      if (_macroHistory.isNotEmpty) {
        final today = _macroHistory.last;
        _currentProtein = (today['protein'] as num).toDouble();
        _currentCarbs = (today['carbs'] as num).toDouble();
        _currentFat = (today['fat'] as num).toDouble();
      }
    } catch (e) {
      // Handle potential errors including PostgreSQL errors
      debugPrint('Error loading macro data: $e');
      
      // Initialize with default values if there's an error
      if (_macroHistory.isEmpty) {
        for (int i = 29; i >= 0; i--) {
          final date = DateTime.now().subtract(Duration(days: i));
          _macroHistory.add({
            'date': date,
            'protein': 0.0,
            'carbs': 0.0,
            'fat': 0.0,
          });
        }
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

    switch (_selectedTimeFrame) {
      case 'Week':
        // Get the last 7 days
        final weekAgo = now.subtract(const Duration(days: 7));
        filtered = _macroHistory
            .where((entry) =>
                (entry['date'] as DateTime).isAfter(weekAgo) ||
                DateFormat('yyyy-MM-dd').format(entry['date'] as DateTime) ==
                    DateFormat('yyyy-MM-dd').format(weekAgo))
            .toList();
        break;
      case 'Month':
        // Get the last 30 days
        final monthAgo = DateTime(now.year, now.month - 1, now.day);
        filtered = _macroHistory
            .where((entry) =>
                (entry['date'] as DateTime).isAfter(monthAgo) ||
                DateFormat('yyyy-MM-dd').format(entry['date'] as DateTime) ==
                    DateFormat('yyyy-MM-dd').format(monthAgo))
            .toList();
        break;
      case 'Year':
        // Get the last 12 months
        filtered = _macroHistory;
        break;
      default:
        filtered = _macroHistory;
    }

    // Ensure we have at most 7 entries for week view by taking the most recent
    if (_selectedTimeFrame == 'Week' && filtered.length > 7) {
      filtered = filtered.sublist(filtered.length - 7);
    }

    // For month view, aggregate by week
    if (_selectedTimeFrame == 'Month' && filtered.length > 7) {
      // Aggregate data by weeks (for simplicity just take every ~4th entry)
      final int step = (filtered.length / 7).ceil();
      List<Map<String, dynamic>> aggregated = [];

      for (int i = filtered.length - 1; i >= 0; i -= step) {
        if (aggregated.length < 7) {
          aggregated.add(filtered[i]);
        }
      }

      filtered = aggregated.reversed.toList();
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
            color: isToday ? customColors.accentPrimary : customColors.textSecondary,
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
            color: isToday ? customColors.accentPrimary : customColors.textSecondary,
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
    final cornerRadius = 4.0;

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

  void _drawBar(Canvas canvas, Map<String, dynamic> data, double x, double barWidth, double cornerRadius, Rect chartArea) {
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
          topLeft: Radius.circular(cornerRadius),
          topRight: Radius.circular(cornerRadius),
        ),
        Paint()..color = Colors.amber.shade300,
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
        Paint()..color = Colors.teal.shade300,
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
        Paint()..color = Colors.purple.shade400,
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
          Offset(chartArea.left - textPainter.width - 8, y - textPainter.height / 2),
        );
      }
    }
  }

  void _drawTargetLine(Canvas canvas, Rect chartArea) {
    final targetValue = showCalories
        ? (targetProtein * 4 + targetCarbs * 4 + targetFat * 9) / _maxYValue * chartArea.height
        : (targetProtein + targetCarbs + targetFat) / _maxYValue * chartArea.height;

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
