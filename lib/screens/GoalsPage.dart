// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/providers/dateProvider.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final ScrollController _scrollController = ScrollController();

  // Goal values
  int calorieGoal = 2000;
  int proteinGoal = 150;
  int carbGoal = 75;
  int fatGoal = 80;
  int stepsGoal = 9000;
  int bmr = 1500;
  int tdee = 2000;

  // Current values (for progress demonstration)
  int caloriesConsumed = 0;
  int proteinConsumed = 0;
  int carbsConsumed = 0;
  int fatConsumed = 0;
  int stepsCompleted = 0;

  // Weekly progress data (for the chart)
  final List<FlSpot> weeklyCaloriesData = [];
  final List<FlSpot> weeklyProteinData = [];
  final List<String> weekDays = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _loadGoals();
    _loadCurrentValues();
    _generateWeeklyData();
  }

  Future<void> _loadGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? resultsString = prefs.getString('macro_results');

      if (resultsString != null && resultsString.isNotEmpty) {
        final Map<String, dynamic> results = jsonDecode(resultsString);
        if (mounted) {
          setState(() {
            calorieGoal = results['calorie_target'] ?? 2000;
            proteinGoal = results['protein'] ?? 150;
            carbGoal = results['carbs'] ?? 75;
            fatGoal = results['fat'] ?? 80;
            stepsGoal = results['recommended_steps'] ?? 9000;
            bmr = results['bmr'] ?? 1500;
            tdee = results['tdee'] ?? 2000;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading nutrition goals: $e');
    }
  }

  // Load current daily values (would normally come from food entry provider)
  Future<void> _loadCurrentValues() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? dailyProgress = prefs.getString('daily_progress');

      if (dailyProgress != null && dailyProgress.isNotEmpty) {
        final Map<String, dynamic> progress = jsonDecode(dailyProgress);
        if (mounted) {
          setState(() {
            caloriesConsumed = progress['calories'] ?? 0;
            proteinConsumed = progress['protein'] ?? 0;
            carbsConsumed = progress['carbs'] ?? 0;
            fatConsumed = progress['fat'] ?? 0;
            stepsCompleted = progress['steps'] ?? 0;
          });
        }
      }
      // Instead of generating dummy data, initialize with 0 if no progress exists
      else {
        setState(() {
          caloriesConsumed = 0;
          proteinConsumed = 0;
          carbsConsumed = 0;
          fatConsumed = 0;
          stepsCompleted = 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading daily progress: $e');
    }
  }

  // Generate weekly data for the chart
  void _generateWeeklyData() {
    final now = DateTime.now();
    weeklyCaloriesData.clear();
    weeklyProteinData.clear();
    weekDays.clear();

    final foodEntryProvider =
        Provider.of<FoodEntryProvider>(context, listen: false);

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final entries = foodEntryProvider.getAllEntriesForDate(day);

      double totalCalories = 0;
      double totalProtein = 0;

      for (var entry in entries) {
        double quantityInGrams = entry.quantity;
        switch (entry.unit) {
          case "oz":
            quantityInGrams *= 28.35;
            break;
          case "kg":
            quantityInGrams *= 1000;
            break;
          case "lbs":
            quantityInGrams *= 453.59;
            break;
        }

        final multiplier = quantityInGrams / 100;
        totalCalories += entry.food.calories * multiplier;
        totalProtein += (entry.food.nutrients["Protein"] ?? 0) * multiplier;
      }

      weeklyCaloriesData.add(FlSpot(6 - i.toDouble(), totalCalories));
      weeklyProteinData.add(FlSpot(6 - i.toDouble(), totalProtein));
      weekDays.add(DateFormat('E').format(day));
    }
  }

  Future<void> _saveGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> results = {
        'calorie_target': calorieGoal,
        'protein': proteinGoal,
        'carbs': carbGoal,
        'fat': fatGoal,
        'recommended_steps': stepsGoal,
        'bmr': bmr,
        'tdee': tdee,
      };
      await prefs.setString('macro_results', jsonEncode(results));
    } catch (e) {
      debugPrint('Error saving nutrition goals: $e');
    }
  }

  void _showEditDialog(
      String title, int currentValue, String unit, Function(int) onSave) {
    final TextEditingController controller =
        TextEditingController(text: currentValue.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $title'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            suffixText: unit,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newValue = int.tryParse(controller.text);
              if (newValue != null && newValue > 0) {
                onSave(newValue);
                _saveGoals();
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<FoodEntryProvider, DateProvider>(
      builder: (context, foodEntryProvider, dateProvider, _) {
        // Calculate total macros from all food entries
        final entries = foodEntryProvider.getAllEntriesForDate(DateTime.now());

        double totalCarbs = 0;
        double totalFat = 0;
        double totalProtein = 0;
        double totalCalories = 0;

        for (var entry in entries) {
          final carbs =
              entry.food.nutrients["Carbohydrate, by difference"] ?? 0;
          final fat = entry.food.nutrients["Total lipid (fat)"] ?? 0;
          final protein = entry.food.nutrients["Protein"] ?? 0;

          // Convert quantity to grams
          double quantityInGrams = entry.quantity;
          switch (entry.unit) {
            case "oz":
              quantityInGrams *= 28.35;
              break;
            case "kg":
              quantityInGrams *= 1000;
              break;
            case "lbs":
              quantityInGrams *= 453.59;
              break;
          }

          // Since nutrients are per 100g, divide by 100 to get per gram
          final multiplier = quantityInGrams / 100;
          totalCarbs += carbs * multiplier;
          totalFat += fat * multiplier;
          totalProtein += protein * multiplier;
          totalCalories += entry.food.calories * multiplier;
        }

        // Update the state variables with actual values
        caloriesConsumed = totalCalories.round();
        carbsConsumed = totalCarbs.round();
        fatConsumed = totalFat.round();
        proteinConsumed = totalProtein.round();

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).scaffoldBackgroundColor,
                  Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
                ],
              ),
            ),
            child: SafeArea(
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(context),

                  // Weekly progress chart
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                      child: _buildWeeklyProgressChart(context),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.2),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: _controller,
                              curve: Interval(
                                index * 0.1,
                                1.0,
                                curve: Curves.easeOutQuart,
                              ),
                            )),
                            child: FadeTransition(
                              opacity: _controller,
                              child: _buildGoalCard(getGoalData(index)),
                            ),
                          );
                        },
                        childCount: 6,
                      ),
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {},
            elevation: 2,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(0.8),
                  ],
                ),
              ),
              child: const Icon(Icons.add, size: 28),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeeklyProgressChart(BuildContext context) {
    return Container(
      height: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                'Weekly Progress',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Last 7 Days',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: calorieGoal / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.15),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 &&
                            value.toInt() < weekDays.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              weekDays[value.toInt()],
                              style: TextStyle(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: calorieGoal / 2,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                            fontSize: 10,
                          ),
                        );
                      },
                      reservedSize: 40,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: calorieGoal.toDouble() * 1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: weeklyCaloriesData,
                    isCurved: true,
                    color: Theme.of(context).colorScheme.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Theme.of(context).colorScheme.primary,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.2),
                    ),
                  ),
                  LineChartBarData(
                    spots: weeklyProteinData,
                    isCurved: true,
                    color: Colors.red,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.red.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(
                  'Calories', Theme.of(context).colorScheme.primary),
              const SizedBox(width: 16),
              _buildLegendItem('Protein', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[300]
                : Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: Row(
          children: [
            Text(
              'My Goals',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 20),
        onPressed: () => Navigator.of(context).pop(),
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildGoalCard(Map<String, dynamic> data) {
    final progress = data['currentValue'] != null
        ? data['currentValue'] / data['value']
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: data['editable'] == true ? data['onEdit'] : null,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  data['color'].withOpacity(0.15),
                  data['color'].withOpacity(0.05),
                ],
              ),
              border: Border.all(
                color: data['color'].withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: data['color'].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            data['icon'],
                            color: data['color'],
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          data['title'],
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (data['editable'] == true)
                      Icon(
                        Icons.edit,
                        size: 20,
                        color: data['color'],
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                data['currentValue'] != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${data['currentValue']} / ${data['value']} ${data['unit']}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _getProgressColor(progress),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              backgroundColor: Colors.grey.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  _getProgressColor(progress)),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            data['secondaryValue'] != null
                                ? '${data['value']} / ${data['secondaryValue']} ${data['unit']}'
                                : '${data['value']} ${data['unit']}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                              letterSpacing: -0.5,
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
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.9) return Colors.green;
    if (progress >= 0.7) return Colors.lime;
    if (progress >= 0.5) return Colors.orange;
    return Colors.red;
  }

  Map<String, dynamic> getGoalData(int index) {
    switch (index) {
      case 0:
        return {
          'title': 'Daily Calorie Goal',
          'value': calorieGoal,
          'currentValue': caloriesConsumed,
          'unit': 'kcal',
          'icon': Icons.local_fire_department,
          'color': Colors.orange,
          'editable': true,
          'onEdit': () => _showEditDialog(
                'Daily Calorie Goal',
                calorieGoal,
                'kcal',
                (value) => setState(() => calorieGoal = value),
              ),
        };
      case 1:
        return {
          'title': 'Protein Goal',
          'value': proteinGoal,
          'currentValue': proteinConsumed,
          'unit': 'g',
          'icon': Icons.fitness_center,
          'color': Colors.red,
          'editable': true,
          'onEdit': () => _showEditDialog(
                'Protein Goal',
                proteinGoal,
                'g',
                (value) => setState(() => proteinGoal = value),
              ),
        };
      case 2:
        return {
          'title': 'Carbohydrate Goal',
          'value': carbGoal,
          'currentValue': carbsConsumed,
          'unit': 'g',
          'icon': Icons.grain,
          'color': Colors.blue,
          'editable': true,
          'onEdit': () => _showEditDialog(
                'Carbohydrate Goal',
                carbGoal,
                'g',
                (value) => setState(() => carbGoal = value),
              ),
        };
      case 3:
        return {
          'title': 'Fat Goal',
          'value': fatGoal,
          'currentValue': fatConsumed,
          'unit': 'g',
          'icon': Icons.opacity,
          'color': Colors.yellow,
          'editable': true,
          'onEdit': () => _showEditDialog(
                'Fat Goal',
                fatGoal,
                'g',
                (value) => setState(() => fatGoal = value),
              ),
        };
      case 4:
        return {
          'title': 'Daily Steps Goal',
          'value': stepsGoal,
          'currentValue': stepsCompleted,
          'unit': 'steps',
          'icon': Icons.directions_walk,
          'color': Colors.green,
          'editable': true,
          'onEdit': () => _showEditDialog(
                'Daily Steps Goal',
                stepsGoal,
                'steps',
                (value) => setState(() => stepsGoal = value),
              ),
        };
      case 5:
        return {
          'title': 'Metabolic Info',
          'value': bmr,
          'secondaryValue': tdee,
          'unit': 'BMR/TDEE',
          'icon': Icons.show_chart,
          'color': Colors.purple,
          'editable': false,
        };
      default:
        return {
          'title': '',
          'value': 0,
          'unit': '',
          'icon': Icons.help,
          'color': Colors.grey,
          'editable': false,
        };
    }
  }
}
