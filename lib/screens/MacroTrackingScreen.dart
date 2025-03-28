import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

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
  bool _isLoading = false;
  late AnimationController _animationController;

  // Current macros (in grams)
  double _currentProtein = 0;
  double _currentCarbs = 0;
  double _currentFat = 0;

  // Target macros (in grams)
  double _targetProtein = 150;
  double _targetCarbs = 200;
  double _targetFat = 65;

  // History data
  List<Map<String, dynamic>> _macroHistory = [];
  String _selectedTimeFrame = 'Week';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _loadMacroData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadMacroData() {
    setState(() {
      _isLoading = true;
    });

    // Simulate loading macro data
    // TODO: Replace with actual data loading from your backend
    _macroHistory = List.generate(30, (index) {
      final date = DateTime.now().subtract(Duration(days: 29 - index));
      return {
        'date': date,
        'protein': _targetProtein * (0.7 + math.Random().nextDouble() * 0.6),
        'carbs': _targetCarbs * (0.7 + math.Random().nextDouble() * 0.6),
        'fat': _targetFat * (0.7 + math.Random().nextDouble() * 0.6),
      };
    });

    // Set current day's macros
    if (_macroHistory.isNotEmpty) {
      final today = _macroHistory.last;
      _currentProtein = today['protein'];
      _currentCarbs = today['carbs'];
      _currentFat = today['fat'];
    }

    setState(() {
      _isLoading = false;
    });

    return Future.value();
  }

  double _calculateTotalCalories(double protein, double carbs, double fat) {
    return (protein * 4) + (carbs * 4) + (fat * 9);
  }

  double _getProgressPercentage(double current, double target) {
    if (target == 0) return 0;
    final progress = current / target;
    return progress > 1 ? 1 : progress;
  }

  Color _getMacroColor(String macro) {
    switch (macro.toLowerCase()) {
      case 'protein':
        return Colors.blue;
      case 'carbs':
        return Colors.orange;
      case 'fat':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>()!;

    Widget body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMacroSummaryCard(context, customColors),
                    const SizedBox(height: 24),
                    _buildTimeFrameSelector(customColors),
                    const SizedBox(height: 24),
                    _buildMacroChart(customColors),
                    const SizedBox(height: 24),
                    _buildMacroBreakdown(customColors),
                    const SizedBox(height: 24),
                    _buildMacroGoals(customColors),
                  ],
                ),
              ),
            ),
          );

    if (!widget.hideAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Macro Tracking',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: customColors.textPrimary,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: theme.brightness == Brightness.light
              ? SystemUiOverlayStyle.dark
              : SystemUiOverlayStyle.light,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: customColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: body,
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddMacrosDialog(context, customColors),
          backgroundColor: customColors.accentPrimary,
          child: const Icon(Icons.add),
        ),
      );
    }

    return body;
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            customColors.cardBackground,
            customColors.cardBackground.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today\'s Macros',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: customColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, MMMM d').format(DateTime.now()),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: customColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: calorieProgress,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          calorieProgress >= 1.0
                              ? Colors.green
                              : customColors.accentPrimary,
                        ),
                        strokeWidth: 12,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: customColors.cardBackground,
                        shape: BoxShape.circle,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentCalories.toInt().toString(),
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: customColors.textPrimary,
                            ),
                          ),
                          Text(
                            'kcal',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: customColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMacroIndicator(
                      'Protein',
                      _currentProtein,
                      _targetProtein,
                      Colors.blue,
                      customColors,
                    ),
                    const SizedBox(height: 12),
                    _buildMacroIndicator(
                      'Carbs',
                      _currentCarbs,
                      _targetCarbs,
                      Colors.orange,
                      customColors,
                    ),
                    const SizedBox(height: 12),
                    _buildMacroIndicator(
                      'Fat',
                      _currentFat,
                      _targetFat,
                      Colors.red,
                      customColors,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: customColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${current.toInt()}/${target.toInt()}g',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: customColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: color.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(
            progress >= 1.0 ? Colors.green : color,
          ),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  Widget _buildTimeFrameSelector(CustomColors customColors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: customColors.dateNavigatorBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['Week', 'Month', 'Year'].map((timeFrame) {
          final isSelected = _selectedTimeFrame == timeFrame;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextButton(
              onPressed: () {
                setState(() {
                  _selectedTimeFrame = timeFrame;
                });
              },
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(
                  isSelected ? customColors.cardBackground : Colors.transparent,
                ),
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                padding: MaterialStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
              ),
              child: Text(
                timeFrame,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? customColors.accentPrimary
                      : customColors.textPrimary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMacroChart(CustomColors customColors) {
    // Filter history based on selected time frame
    final List<Map<String, dynamic>> filteredHistory = _getFilteredHistory();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: customColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Macro Intake',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: customColors.textPrimary,
                ),
              ),
              
              // Add tabs for "Calories" and "Grams" views
              Container(
                height: 32,
                decoration: BoxDecoration(
                  color: customColors.dateNavigatorBackground.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    // These buttons could toggle between calories and grams view
                    _buildChartViewTab('Calories', true, customColors),
                    _buildChartViewTab('Grams', false, customColors),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 240,
            child: Stack(
              children: [
                // Main chart
                MacroBarChart(
                  macroData: filteredHistory,
                  animation: _animationController,
                  customColors: customColors,
                  targetProtein: _targetProtein,
                  targetCarbs: _targetCarbs,
                  targetFat: _targetFat,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Chart legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendItem('Protein (${_targetProtein.toInt()}g)', Colors.amber.shade300, customColors),
              _buildLegendItem('Carbs (${_targetCarbs.toInt()}g)', Colors.teal.shade300, customColors),
              _buildLegendItem('Fat (${_targetFat.toInt()}g)', Colors.purple.shade400, customColors),
            ],
          ),
          
          // Goal vs Average comparison
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Column headings
              Container(width: 100),
              Text('Avg', style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: customColors.textSecondary,
              )),
              Text('Goal', style: GoogleFonts.inter(
                fontSize: 14, 
                fontWeight: FontWeight.w600,
                color: customColors.textSecondary,
              )),
            ],
          ),
          
          const SizedBox(height: 12),
          // Carbs comparison
          _buildMacroComparison(
            'Net Carbs',
            '22%',
            '35%',
            Colors.teal.shade300,
            customColors
          ),
          
          const SizedBox(height: 12),
          // Fat comparison  
          _buildMacroComparison(
            'Fat',
            '33%',
            '25%',
            Colors.purple.shade400,
            customColors
          ),
          
          const SizedBox(height: 12),
          // Protein comparison
          _buildMacroComparison(
            'Protein',
            '45%',
            '40%',
            Colors.amber.shade300,
            customColors
          ),
        ],
      ),
    );
  }
  
  Widget _buildChartViewTab(String title, bool isSelected, CustomColors customColors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? customColors.cardBackground : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? customColors.accentPrimary : customColors.textSecondary,
        ),
      ),
    );
  }
  
  Widget _buildMacroComparison(String label, String actual, String goal, Color color, CustomColors customColors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Label
        SizedBox(
          width: 100,
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: customColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Actual percentage
        Text(
          actual,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: customColors.textPrimary,
          ),
        ),
        
        // Goal percentage with indicator dot
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              goal,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Helper to get filtered history based on selected time frame
  List<Map<String, dynamic>> _getFilteredHistory() {
    final DateTime now = DateTime.now();
    List<Map<String, dynamic>> filtered = [];
    
    switch (_selectedTimeFrame) {
      case 'Week':
        // Get the last 7 days
        final weekAgo = now.subtract(const Duration(days: 7));
        filtered = _macroHistory.where((entry) => 
          (entry['date'] as DateTime).isAfter(weekAgo) || 
          DateFormat('yyyy-MM-dd').format(entry['date'] as DateTime) == 
          DateFormat('yyyy-MM-dd').format(weekAgo)
        ).toList();
        break;
      case 'Month':
        // Get the last 30 days
        final monthAgo = DateTime(now.year, now.month - 1, now.day);
        filtered = _macroHistory.where((entry) => 
          (entry['date'] as DateTime).isAfter(monthAgo) || 
          DateFormat('yyyy-MM-dd').format(entry['date'] as DateTime) == 
          DateFormat('yyyy-MM-dd').format(monthAgo)
        ).toList();
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: customColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Macro Breakdown',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: customColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildMacroBreakdownItem(
            'Protein',
            _currentProtein,
            proteinPercentage,
            Colors.blue,
            customColors,
          ),
          const SizedBox(height: 16),
          _buildMacroBreakdownItem(
            'Carbs',
            _currentCarbs,
            carbsPercentage,
            Colors.orange,
            customColors,
          ),
          const SizedBox(height: 16),
          _buildMacroBreakdownItem(
            'Fat',
            _currentFat,
            fatPercentage,
            Colors.red,
            customColors,
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBreakdownItem(
    String label,
    double grams,
    int percentage,
    Color color,
    CustomColors customColors,
  ) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '$percentage%',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
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
                  fontWeight: FontWeight.w500,
                  color: customColors.textPrimary,
                ),
              ),
              Text(
                '${grams.toInt()}g',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: customColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMacroGoals(CustomColors customColors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: customColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Macro Goals',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: customColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => _showEditGoalsDialog(context, customColors),
                child: Text(
                  'Edit Goals',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: customColors.accentPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildGoalItem(
                  'Protein', _targetProtein, Colors.blue, customColors),
              _buildGoalItem(
                  'Carbs', _targetCarbs, Colors.orange, customColors),
              _buildGoalItem('Fat', _targetFat, Colors.red, customColors),
            ],
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: customColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${target.toInt()}g',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddMacrosDialog(
      BuildContext context, CustomColors customColors) async {
    double protein = 0;
    double carbs = 0;
    double fat = 0;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Macros',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: customColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Protein (g)',
                suffixText: 'g',
              ),
              onChanged: (value) {
                protein = double.tryParse(value) ?? 0;
              },
            ),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Carbs (g)',
                suffixText: 'g',
              ),
              onChanged: (value) {
                carbs = double.tryParse(value) ?? 0;
              },
            ),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Fat (g)',
                suffixText: 'g',
              ),
              onChanged: (value) {
                fat = double.tryParse(value) ?? 0;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: customColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _currentProtein += protein;
                _currentCarbs += carbs;
                _currentFat += fat;
                // TODO: Save to backend
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: customColors.accentPrimary,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditGoalsDialog(
      BuildContext context, CustomColors customColors) async {
    double protein = _targetProtein;
    double carbs = _targetCarbs;
    double fat = _targetFat;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit Macro Goals',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: customColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Protein Goal (g)',
                suffixText: 'g',
                hintText: protein.toInt().toString(),
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  protein = double.tryParse(value) ?? protein;
                }
              },
            ),
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Carbs Goal (g)',
                suffixText: 'g',
                hintText: carbs.toInt().toString(),
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  carbs = double.tryParse(value) ?? carbs;
                }
              },
            ),
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Fat Goal (g)',
                suffixText: 'g',
                hintText: fat.toInt().toString(),
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  fat = double.tryParse(value) ?? fat;
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: customColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _targetProtein = protein;
                _targetCarbs = carbs;
                _targetFat = fat;
                // TODO: Save to backend
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: customColors.accentPrimary,
            ),
            child: const Text('Save'),
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
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: customColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class MacroBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> macroData;
  final Animation<double> animation;
  final CustomColors customColors;
  final double targetProtein;
  final double targetCarbs;
  final double targetFat;

  const MacroBarChart({
    Key? key,
    required this.macroData,
    required this.animation,
    required this.customColors,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
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

  _MacroBarChartPainter({
    required this.macroData,
    required this.animation,
    required this.customColors,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (macroData.isEmpty) return;
    
    final chartArea = Rect.fromLTWH(
      40, // Left padding for y-axis labels
      10, // Top padding
      size.width - 50, // Width minus padding
      size.height - 40, // Height minus padding for x-axis labels
    );
    
    // Calculate the max value for the y-axis
    double maxTotalMacros = 0;
    for (var data in macroData) {
      final double protein = data['protein'] as double;
      final double carbs = data['carbs'] as double;
      final double fat = data['fat'] as double;
      final double total = protein + carbs + fat;
      if (total > maxTotalMacros) {
        maxTotalMacros = total;
      }
    }
    
    // Round up to nearest 500 for clean y-axis
    maxTotalMacros = ((maxTotalMacros / 500).ceil() * 500).toDouble();
    maxTotalMacros = math.max(maxTotalMacros, 1800); // Ensure minimum scale
    
    // Draw y-axis grid lines and labels
    _drawYAxis(canvas, chartArea, maxTotalMacros);
    
    // Draw bars
    final barWidth = chartArea.width / (macroData.length * 2 + 1);
    
    // Pre-compute target goal line position
    final double targetTotalMacros = targetProtein + targetCarbs + targetFat;
    final double targetY = chartArea.bottom - 
        (targetTotalMacros / maxTotalMacros * chartArea.height);
    
    for (int i = 0; i < macroData.length; i++) {
      final data = macroData[i];
      final double protein = (data['protein'] as double) * animation;
      final double carbs = (data['carbs'] as double) * animation;
      final double fat = (data['fat'] as double) * animation;
      
      final double x = chartArea.left + (i * 2 + 1) * barWidth;
      
      // Draw stacked bar segments
      double segmentBottom = chartArea.bottom;
      
      // Draw protein segment (bottom)
      final proteinHeight = (protein / maxTotalMacros) * chartArea.height;
      final proteinRect = Rect.fromLTWH(
        x - barWidth / 2,
        segmentBottom - proteinHeight,
        barWidth,
        proteinHeight,
      );
      canvas.drawRect(
        proteinRect,
        Paint()..color = Colors.amber.shade300,
      );
      segmentBottom -= proteinHeight;
      
      // Draw fat segment (middle)
      final fatHeight = (fat / maxTotalMacros) * chartArea.height;
      final fatRect = Rect.fromLTWH(
        x - barWidth / 2,
        segmentBottom - fatHeight,
        barWidth,
        fatHeight,
      );
      canvas.drawRect(
        fatRect,
        Paint()..color = Colors.purple.shade400,
      );
      segmentBottom -= fatHeight;
      
      // Draw carbs segment (top)
      final carbsHeight = (carbs / maxTotalMacros) * chartArea.height;
      final carbsRect = Rect.fromLTWH(
        x - barWidth / 2,
        segmentBottom - carbsHeight,
        barWidth,
        carbsHeight,
      );
      canvas.drawRect(
        carbsRect,
        Paint()..color = Colors.teal.shade300,
      );
      
      // Draw bar border
      final totalHeight = proteinHeight + fatHeight + carbsHeight;
      if (totalHeight > 0) {
        canvas.drawRect(
          Rect.fromLTWH(
            x - barWidth / 2,
            chartArea.bottom - totalHeight,
            barWidth,
            totalHeight,
          ),
          Paint()
            ..color = customColors.cardBackground.withOpacity(0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
        );
      }
      
      // Draw x-axis labels
      final date = data['date'] as DateTime;
      final dayLabel = _getDayLabel(date);
      final dateLabel = DateFormat('d').format(date);
      
      final dayTextPainter = TextPainter(
        text: TextSpan(
          text: dayLabel,
          style: TextStyle(
            color: customColors.textSecondary,
            fontSize: 12,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      
      dayTextPainter.paint(
        canvas, 
        Offset(x - dayTextPainter.width / 2, chartArea.bottom + 5),
      );
      
      final dateTextPainter = TextPainter(
        text: TextSpan(
          text: dateLabel,
          style: TextStyle(
            color: customColors.textSecondary,
            fontSize: 10,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      
      dateTextPainter.paint(
        canvas, 
        Offset(x - dateTextPainter.width / 2, chartArea.bottom + 22),
      );
    }
    
    // Draw target goal horizontal line
    final targetLinePaint = Paint()
      ..color = Colors.blue.shade500
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    
    // Draw dashed line
    double dashWidth = 5;
    double dashSpace = 3;
    double startX = chartArea.left;
    
    while (startX < chartArea.right) {
      canvas.drawLine(
        Offset(startX, targetY),
        Offset(startX + dashWidth, targetY),
        targetLinePaint,
      );
      startX += dashWidth + dashSpace;
    }
    
    // Add target label
    final targetTextPainter = TextPainter(
      text: TextSpan(
        text: 'Goal',
        style: TextStyle(
          color: Colors.blue.shade500,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    
    // Draw a background for the label
    final labelRect = Rect.fromLTWH(
      chartArea.right - targetTextPainter.width - 8,
      targetY - targetTextPainter.height / 2 - 2,
      targetTextPainter.width + 6,
      targetTextPainter.height + 4,
    );
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(2)),
      Paint()..color = customColors.cardBackground.withOpacity(0.9),
    );
    
    targetTextPainter.paint(
      canvas,
      Offset(chartArea.right - targetTextPainter.width - 5, targetY - targetTextPainter.height / 2),
    );
  }
  
  void _drawYAxis(Canvas canvas, Rect chartArea, double maxValue) {
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;
    
    final labelStyle = TextStyle(
      color: Colors.grey.shade600,
      fontSize: 10,
    );
    
    final verticalSteps = 6;
    final stepSize = maxValue / verticalSteps;
    
    for (int i = 0; i <= verticalSteps; i++) {
      final y = chartArea.bottom - (i * chartArea.height / verticalSteps);
      
      // Draw horizontal grid line
      canvas.drawLine(
        Offset(chartArea.left, y),
        Offset(chartArea.right, y),
        gridPaint,
      );
      
      // Draw label
      final value = (i * stepSize).toInt();
      final textPainter = TextPainter(
        text: TextSpan(
          text: i == 0 ? '0' : '${value.toString()}',
          style: labelStyle,
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.right,
      )..layout();
      
      textPainter.paint(
        canvas,
        Offset(chartArea.left - textPainter.width - 5, y - textPainter.height / 2),
      );
    }
  }
  
  String _getDayLabel(DateTime date) {
    final daysOfWeek = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return daysOfWeek[date.weekday % 7];
  }

  @override
  bool shouldRepaint(covariant _MacroBarChartPainter oldDelegate) {
    return oldDelegate.animation != animation ||
           oldDelegate.macroData != macroData;
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
      final proteinAngle = (protein / targetProtein).clamp(0.0, 1.0) * (2 * math.pi / 3);
      final carbsAngle = (carbs / targetCarbs).clamp(0.0, 1.0) * (2 * math.pi / 3);
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
