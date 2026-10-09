// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../../../Health/Health.dart';
import '../../../providers/dateProvider.dart';
import '../../../providers/energy_provider.dart';
import '../../../providers/foodEntryProvider.dart';
import '../../../providers/goals_provider.dart';
import '../../../screens/NutritionTrendsScreen.dart';
import '../../../screens/StepsTrackingScreen.dart';
import '../../../screens/energy/checkin_sheet.dart';
import '../../../services/storage_service.dart';
import '../../../theme/app_theme.dart';

/// Widget that displays calorie tracking information with progress indicators.
/// Shows calories consumed, remaining, and macro breakdown with circular progress.
class CalorieTracker extends StatefulWidget {
  const CalorieTracker({super.key});

  @override
  State<CalorieTracker> createState() => _CalorieTrackerState();
}

class _CalorieTrackerState extends State<CalorieTracker> {
  final HealthService _healthService = HealthService();
  int _steps = 0;
  double _caloriesBurned = 0;
  bool _hasHealthPermissions = false;
  bool _isLoadingHealthData = false;
  DateTime? _lastFetchedDate;
  late DateProvider _dateProvider;
  final StorageService _storageService = StorageService();
  VoidCallback? _storageListener;

  @override
  void initState() {
    super.initState();
    _dateProvider = Provider.of<DateProvider>(context, listen: false);
    _dateProvider.addListener(_onDateChanged);
    _initializeHealthData();

    _storageListener = () {
      final newStatus = _storageService.get('healthConnected', defaultValue: false);
      if (mounted && newStatus != _hasHealthPermissions) {
        setState(() => _hasHealthPermissions = newStatus);
        if (_hasHealthPermissions) _fetchHealthData();
      }
    };

    try {
      Hive.box('user_preferences').listenable().addListener(_storageListener!);
    } catch (e) {
      print("Error adding storage listener: $e");
    }
  }

  @override
  void dispose() {
    _dateProvider.removeListener(_onDateChanged);
    if (_storageListener != null) {
      try {
        Hive.box('user_preferences').listenable().removeListener(_storageListener!);
      } catch (e) {
        print("Error removing storage listener: $e");
      }
    }
    super.dispose();
  }

  void _onDateChanged() {
    final selectedDate = _dateProvider.selectedDate;
    if (_lastFetchedDate == null || !_isSameDay(_lastFetchedDate!, selectedDate)) {
      _fetchHealthData();
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  Future<void> _initializeHealthData() async {
    final initialStatus = _storageService.get('healthConnected', defaultValue: false);
    if (mounted) setState(() => _hasHealthPermissions = initialStatus);
    if (_hasHealthPermissions) await _fetchHealthData();
  }

  Future<void> _fetchHealthData() async {
    if (!_hasHealthPermissions || _isLoadingHealthData) return;
    if (!mounted) return;

    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final selectedDate = dateProvider.selectedDate;
    final bool isToday = _isSameDay(selectedDate, DateTime.now());

    if (!isToday && _lastFetchedDate != null && _isSameDay(_lastFetchedDate!, selectedDate)) {
      return;
    }

    if (mounted) setState(() => _isLoadingHealthData = true);

    try {
      final fetchedSteps = await _healthService.getStepsForDate(selectedDate);
      final fetchedCalories = await _healthService.getCaloriesForDate(selectedDate);

      if (mounted) {
        setState(() {
          _steps = fetchedSteps;
          _caloriesBurned = fetchedCalories;
          _lastFetchedDate = selectedDate;
        });
      }
    } catch (e) {
      print('Error fetching health data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingHealthData = false);
    }
  }

  IconData _getMacroIcon(String label) {
    switch (label) {
      case 'Carbs':
        return Icons.grain;
      case 'Protein':
        return Icons.fitness_center;
      case 'Fat':
        return Icons.opacity;
      case 'Steps':
        return Icons.directions_walk;
      default:
        return Icons.circle;
    }
  }

  Widget _buildMacroProgress(BuildContext context, String label, int value, int goal, Color color, String unit) {
    final progress = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;
    final textColor = Theme.of(context).brightness == Brightness.light
        ? Colors.grey.shade700
        : Colors.grey.shade300;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (label == 'Steps') {
          Navigator.push(
            context,
            CupertinoPageRoute(builder: (context) => const StepTrackingScreen()),
          );
        } else if (['Carbs', 'Protein', 'Fat'].contains(label)) {
          Navigator.push(
            context,
            CupertinoPageRoute(builder: (context) => const NutritionTrendsScreen()),
          );
        }
      },
      child: SizedBox(
        height: 116,
        width: 75,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 60,
                  width: 60,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Theme.of(context).brightness == Brightness.light
                        ? color.withOpacity(0.15)
                        : color.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Icon(_getMacroIcon(label), color: color, size: 22),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  TextSpan(
                    text: '/$goal${unit.isNotEmpty ? unit : ''}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.grey.shade600
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalorieInfoCard(BuildContext context, String label, int value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? color.withOpacity(0.1)
            : color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.grey.shade700
                        : Colors.grey.shade300,
                  ),
                ),
                Text(
                  '$value',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).extension<CustomColors>()?.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<FoodEntryProvider, GoalsProvider, DateProvider>(
      builder: (context, foodEntryProvider, goals, dateProvider, child) {
        final caloriesGoal = goals.caloriesGoal.toInt();
        final proteinGoal = goals.proteinGoal.toInt();
        final carbGoal = goals.carbsGoal.toInt();
        final fatGoal = goals.fatGoal.toInt();
        final stepsGoal = goals.stepsGoal.toInt();

        final nutrientTotals = foodEntryProvider.getNutrientTotalsForDate(dateProvider.selectedDate);
        final caloriesFromFood = nutrientTotals['calories'] ?? 0.0;
        final totalProtein = nutrientTotals['protein'] ?? 0.0;
        final totalCarbs = nutrientTotals['carbs'] ?? 0.0;
        final totalFat = nutrientTotals['fat'] ?? 0.0;

        final int caloriesRemaining = caloriesGoal > 0 ? caloriesGoal - caloriesFromFood.toInt() : 0;
        double progress = caloriesGoal > 0 ? caloriesFromFood / caloriesGoal : 0.0;
        progress = progress.clamp(0.0, 1.0);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).extension<CustomColors>()?.cardBackground,
            borderRadius: BorderRadius.circular(20.0),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.grey.shade300.withOpacity(0.5)
                    : Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.pie_chart_outline,
                              size: 20,
                              color: Theme.of(context).brightness == Brightness.light
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Nutrition & Activity',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).brightness == Brightness.light
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const CheckinChip(),
                    ],
                  ),
                ),
              ),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => const NutritionTrendsScreen(),
                            ),
                          );
                        },
                        child: Container(
                          height: 130,
                          width: 130,
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.light
                                ? Colors.white
                                : Colors.grey.shade900.withOpacity(0.3),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).brightness == Brightness.light
                                    ? Colors.grey.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                spreadRadius: 1,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 110,
                                height: 110,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 10,
                                  strokeCap: StrokeCap.round,
                                  backgroundColor: Theme.of(context).brightness == Brightness.light
                                      ? Colors.grey.shade200
                                      : Colors.grey.shade800,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    progress > 1.0 ? Colors.red : const Color(0xFF34C85A),
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    caloriesRemaining.toString(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .extension<CustomColors>()
                                          ?.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'cals left',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).brightness == Brightness.light
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildCalorieInfoCard(context, 'Goal', caloriesGoal,
                                  const Color(0xFF34C85A), Icons.flag_outlined),
                              const SizedBox(height: 8),
                              _buildCalorieInfoCard(context, 'Food', caloriesFromFood.toInt(),
                                  const Color(0xFFFFA726), Icons.restaurant_menu_outlined),
                              const SizedBox(height: 8),
                              _buildCalorieInfoCard(context, 'Burned', _caloriesBurned.toInt(),
                                  const Color(0xFF42A5F5), Icons.local_fire_department_outlined),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Wrap(
                      alignment: WrapAlignment.spaceAround,
                      spacing: 4,
                      runSpacing: 18,
                      children: [
                        _buildMacroProgress(context, 'Carbs', totalCarbs.round(), carbGoal,
                            const Color(0xFF42A5F5), 'g'),
                        _buildMacroProgress(context, 'Protein', totalProtein.round(), proteinGoal,
                            const Color(0xFFEF5350), 'g'),
                        _buildMacroProgress(context, 'Fat', totalFat.round(), fatGoal,
                            const Color(0xFFFFA726), 'g'),
                        _buildMacroProgress(context, 'Steps', _steps, stepsGoal,
                            const Color(0xFF66BB6A), ''),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// "New target" on the day a check-in ran (spec 7.4): reopens its sheet
/// until the day ends. Check-ins that kept the targets read "Check-in".
class CheckinChip extends StatelessWidget {
  const CheckinChip({super.key});

  @override
  Widget build(BuildContext context) {
    final checkin = context.watch<EnergyProvider>().todaysCheckin;
    if (checkin == null) return const SizedBox.shrink();
    final colors = Theme.of(context).extension<CustomColors>()!;
    final changed = checkin.variant.appliesTargets;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Material(
        color: colors.accentPrimary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: const Key('checkin_chip'),
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            showCheckinSheet(context, checkin, source: CheckinSheetSource.chip);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.autorenew_rounded, size: 14, color: colors.accentPrimary),
                const SizedBox(width: 4),
                Text(
                  changed ? 'New target' : 'Check-in',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.accentPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
