import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/meal_planning_provider.dart';
import '../models/meal_plan.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../theme/typography.dart';

class MealPlanningScreen extends StatefulWidget {
  const MealPlanningScreen({super.key});

  @override
  State<MealPlanningScreen> createState() => _MealPlanningScreenState();
}

class _MealPlanningScreenState extends State<MealPlanningScreen>
    with TickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  late TabController _weekTabController;
  final PageController _pageController = PageController(viewportFraction: 0.95);
  bool _showWeekView = false;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _weekTabController = TabController(length: 7, vsync: this);
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider =
          Provider.of<MealPlanningProvider>(context, listen: false);
      provider.fetchMealPlanForDate(_selectedDate);
      _fabAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _weekTabController.dispose();
    _fabAnimationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _generateMealPlan() async {
    final provider = Provider.of<MealPlanningProvider>(context, listen: false);

    // Show loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _GeneratingMealPlanDialog(),
    );

    // Get user preferences from Hive database instead of hardcoded values
    final storageService = StorageService();
    final userPrefs = storageService.getUserPreferencesWithDefaults();

    try {
      await provider.generateMealPlan(
        date: _selectedDate,
        userPreferences: userPrefs,
      );
      if (mounted) Navigator.of(context).pop(); // Close loading dialog
      _showSuccessSnackBar();
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Close loading dialog
      _showErrorSnackBar(e.toString());
    }
  }

  void _showSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Meal plan generated successfully!'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackBar(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(error)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>()!;

    return Consumer<MealPlanningProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: CustomScrollView(
            slivers: [
              _buildSliverAppBar(theme, customColors, provider),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8),
                    _buildDateNavigation(theme, customColors),
                    const SizedBox(height: 24),
                    _buildQuickStats(theme, customColors, provider),
                    const SizedBox(height: 24),
                    _buildMealPlanContent(theme, customColors, provider),
                    const SizedBox(height: 100), // Space for FAB
                  ]),
                ),
              ),
            ],
          ),
          floatingActionButton: _buildFloatingActionButton(provider),
        );
      },
    );
  }

  SliverAppBar _buildSliverAppBar(ThemeData theme, CustomColors customColors,
      MealPlanningProvider provider) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Meal Planning',
          style: AppTypography.h2.copyWith(
            color: customColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _showWeekView ? Icons.calendar_view_day : Icons.calendar_view_week,
            color: customColors.textPrimary,
          ),
          onPressed: () {
            setState(() {
              _showWeekView = !_showWeekView;
            });
          },
        ),
        IconButton(
          icon: Icon(Icons.settings, color: customColors.textPrimary),
          onPressed: () => _showPreferencesDialog(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildDateNavigation(ThemeData theme, CustomColors customColors) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: customColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(((0.05) * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _showWeekView
          ? _buildWeekView(customColors)
          : _buildDayView(customColors),
    );
  }

  Widget _buildDayView(CustomColors customColors) {
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left, color: customColors.textSecondary),
          onPressed: () => _changeDate(-1),
        ),
        Expanded(
          child: GestureDetector(
            onTap: _showDatePicker,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('EEEE').format(_selectedDate),
                  style: AppTypography.caption.copyWith(
                    color: customColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy').format(_selectedDate),
                  style: AppTypography.h3.copyWith(
                    color: customColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.chevron_right, color: customColors.textSecondary),
          onPressed: () => _changeDate(1),
        ),
      ],
    );
  }

  Widget _buildWeekView(CustomColors customColors) {
    final weekDays = List.generate(7, (index) {
      return _selectedDate
          .subtract(Duration(days: _selectedDate.weekday - 1 - index));
    });

    return TabBar(
      controller: _weekTabController,
      isScrollable: true,
      indicator: BoxDecoration(
        color: customColors.accentPrimary,
        borderRadius: BorderRadius.circular(16),
      ),
      labelColor: Colors.white,
      unselectedLabelColor: customColors.textSecondary,
      labelStyle: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
      unselectedLabelStyle: AppTypography.caption,
      tabs: weekDays
          .map((date) => Tab(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(DateFormat('E').format(date)),
                    Text(DateFormat('d').format(date)),
                  ],
                ),
              ))
          .toList(),
      onTap: (index) {
        setState(() {
          _selectedDate = weekDays[index];
        });
        _fetchMealPlan();
      },
    );
  }

  Widget _buildQuickStats(ThemeData theme, CustomColors customColors,
      MealPlanningProvider provider) {
    final mealPlan = provider.currentMealPlan;
    if (mealPlan == null) return const SizedBox.shrink();

    final stats = _calculateNutritionStats(mealPlan);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            customColors.accentPrimary.withAlpha((0.1 * 255).round()),
            customColors.accentPrimary.withAlpha((0.05 * 255).round()),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: customColors.accentPrimary.withAlpha((0.2 * 255).round()),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Progress',
                style: AppTypography.h3.copyWith(
                  color: customColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: customColors.accentPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${((stats.totalCalories / mealPlan.targetCalories) * 100).toInt()}%',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMacroCard(
                  'Calories',
                  stats.totalCalories,
                  mealPlan.targetCalories,
                  'kcal',
                  const Color(0xFF6366F1),
                  customColors,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMacroCard(
                  'Protein',
                  stats.totalProtein,
                  mealPlan.targetProtein,
                  'g',
                  const Color(0xFFEF4444),
                  customColors,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMacroCard(
                  'Carbs',
                  stats.totalCarbs,
                  mealPlan.targetCarbohydrates,
                  'g',
                  const Color(0xFF10B981),
                  customColors,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMacroCard(
                  'Fat',
                  stats.totalFat,
                  mealPlan.targetFat,
                  'g',
                  const Color(0xFFF59E0B),
                  customColors,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCard(String label, double current, double target,
      String unit, Color color, CustomColors customColors) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: customColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.03 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: customColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${current.toInt()}',
            style: AppTypography.h3.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '/ ${target.toInt()} $unit',
            style: AppTypography.caption.copyWith(
              color: customColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withAlpha((0.1 * 255).round()),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }

  Widget _buildMealPlanContent(ThemeData theme, CustomColors customColors,
      MealPlanningProvider provider) {
    if (provider.isLoading) {
      return _buildLoadingState(customColors);
    }

    if (provider.error != null) {
      return _buildErrorState(provider.error!, customColors);
    }

    final mealPlan = provider.currentMealPlan;
    if (mealPlan == null ||
        (mealPlan.plannedMeals.isEmpty && mealPlan.loggedMeals.isEmpty)) {
      return _buildEmptyState(customColors);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Meals',
          style: AppTypography.h2.copyWith(
            color: customColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        ...mealPlan.plannedMeals
            .map((meal) => _buildModernMealCard(meal, customColors, false)),
        if (mealPlan.loggedMeals.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Logged Meals',
            style: AppTypography.h3.copyWith(
              color: customColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...mealPlan.loggedMeals
              .map((meal) => _buildModernMealCard(meal, customColors, true)),
        ],
      ],
    );
  }

  Widget _buildModernMealCard(
      Meal meal, CustomColors customColors, bool isLogged) {
    final mealIcon = _getMealIcon(meal.name);
    final mealTime = DateFormat('h:mm a').format(meal.time);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: customColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: isLogged
            ? Border.all(
                color: customColors.accentPrimary.withAlpha((0.3 * 255).round()),
                width: 1,
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showMealDetails(meal),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: mealIcon.color.withAlpha((0.1 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          mealIcon.icon,
                          color: mealIcon.color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    meal.name,
                                    style: AppTypography.h3.copyWith(
                                      color: customColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (isLogged)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: customColors.accentPrimary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Logged',
                                      style: AppTypography.caption.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              mealTime,
                              style: AppTypography.caption.copyWith(
                                color: customColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (meal.items.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: customColors.textSecondary.withAlpha((0.05 * 255).round()),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          ...meal.items.take(3).map(
                              (item) => _buildMealItem(item, customColors)),
                          if (meal.items.length > 3)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '+${meal.items.length - 3} more items',
                                style: AppTypography.caption.copyWith(
                                  color: customColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMealSummary(meal, customColors),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMealItem(MealItem item, CustomColors customColors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: customColors.accentPrimary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: AppTypography.body2.copyWith(
                    color: customColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${item.calories.toStringAsFixed(0)} cal • ${item.servings}x serving',
                  style: AppTypography.caption.copyWith(
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

  Widget _buildMealSummary(Meal meal, CustomColors customColors) {
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (final item in meal.items) {
      totalCalories += item.calories;
      totalProtein += item.protein;
      totalCarbs += item.carbohydrates;
      totalFat += item.fat;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildNutrientSummary('Cal', totalCalories.toInt().toString(),
            const Color(0xFF6366F1), customColors),
        _buildNutrientSummary('P', '${totalProtein.toInt()}g',
            const Color(0xFFEF4444), customColors),
        _buildNutrientSummary('C', '${totalCarbs.toInt()}g',
            const Color(0xFF10B981), customColors),
        _buildNutrientSummary(
            'F', '${totalFat.toInt()}g', const Color(0xFFF59E0B), customColors),
      ],
    );
  }

  Widget _buildNutrientSummary(
      String label, String value, Color color, CustomColors customColors) {
    return Column(
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: customColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.body2.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(CustomColors customColors) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: customColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor:
                AlwaysStoppedAnimation<Color>(customColors.accentPrimary),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your meal plan...',
            style: AppTypography.body1.copyWith(
              color: customColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, CustomColors customColors) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: customColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.red.withAlpha((0.2 * 255).round()),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: AppTypography.h3.copyWith(
              color: customColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: AppTypography.body2.copyWith(
              color: customColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchMealPlan,
            style: ElevatedButton.styleFrom(
              backgroundColor: customColors.accentPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(CustomColors customColors) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: customColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 64,
            color: customColors.textSecondary.withAlpha((0.5 * 255).round()),
          ),
          const SizedBox(height: 24),
          Text(
            'No meal plan yet',
            style: AppTypography.h2.copyWith(
              color: customColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Generate a personalized meal plan based on your preferences and goals.',
            style: AppTypography.body1.copyWith(
              color: customColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _generateMealPlan,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate Meal Plan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: customColors.accentPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(MealPlanningProvider provider) {
    return AnimatedBuilder(
      animation: _fabAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _fabAnimation.value,
          child: FloatingActionButton.extended(
            onPressed: provider.isGeneratingMealPlan ? null : _generateMealPlan,
            backgroundColor:
                Theme.of(context).extension<CustomColors>()!.accentPrimary,
            foregroundColor: Colors.white,
            elevation: 8,
            label: provider.isGeneratingMealPlan
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Generating...'),
                    ],
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome),
                      SizedBox(width: 8),
                      Text('Generate Plan'),
                    ],
                  ),
          ),
        );
      },
    );
  }

  MealIcon _getMealIcon(String mealName) {
    final name = mealName.toLowerCase();
    if (name.contains('breakfast')) {
      return MealIcon(Icons.free_breakfast, const Color(0xFFF59E0B));
    } else if (name.contains('lunch')) {
      return MealIcon(Icons.lunch_dining, const Color(0xFF10B981));
    } else if (name.contains('dinner')) {
      return MealIcon(Icons.dinner_dining, const Color(0xFF6366F1));
    } else if (name.contains('snack')) {
      return MealIcon(Icons.cookie, const Color(0xFFEF4444));
    } else {
      return MealIcon(Icons.restaurant, const Color(0xFF8B5CF6));
    }
  }

  NutritionStats _calculateNutritionStats(DailyMealPlan mealPlan) {
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (final meal in [...mealPlan.plannedMeals, ...mealPlan.loggedMeals]) {
      for (final item in meal.items) {
        totalCalories += item.calories;
        totalProtein += item.protein;
        totalCarbs += item.carbohydrates;
        totalFat += item.fat;
      }
    }

    return NutritionStats(
      totalCalories: totalCalories,
      totalProtein: totalProtein,
      totalCarbs: totalCarbs,
      totalFat: totalFat,
    );
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _fetchMealPlan();
  }

  void _fetchMealPlan() {
    Provider.of<MealPlanningProvider>(context, listen: false)
        .fetchMealPlanForDate(_selectedDate);
  }

  Future<void> _showDatePicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
      _fetchMealPlan();
    }
  }

  void _showMealDetails(Meal meal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MealDetailsSheet(meal: meal),
    );
  }

  void _showPreferencesDialog() {
    showDialog(
      context: context,
      builder: (context) => const _PreferencesDialog(),
    );
  }
}

// Helper classes
class MealIcon {
  final IconData icon;
  final Color color;

  MealIcon(this.icon, this.color);
}

class NutritionStats {
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;

  NutritionStats({
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
  });
}

// Dialog widgets
class _GeneratingMealPlanDialog extends StatelessWidget {
  const _GeneratingMealPlanDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Generating your meal plan...',
              style: AppTypography.h3,
            ),
            const SizedBox(height: 8),
            Text(
              'This may take a moment',
              style: AppTypography.body2.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealDetailsSheet extends StatelessWidget {
  final Meal meal;

  const _MealDetailsSheet({required this.meal});

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>()!;

    return Container(
      decoration: BoxDecoration(
        color: customColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: customColors.textSecondary.withAlpha((0.3 * 255).round()),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  meal.name,
                  style: AppTypography.h2.copyWith(
                    color: customColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('h:mm a').format(meal.time),
                  style: AppTypography.body1.copyWith(
                    color: customColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                if (meal.items.isNotEmpty) ...[
                  Text(
                    'Ingredients',
                    style: AppTypography.h3.copyWith(
                      color: customColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...meal.items.map(
                      (item) => _buildDetailedMealItem(item, customColors)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailedMealItem(MealItem item, CustomColors customColors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: customColors.textSecondary.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            style: AppTypography.body1.copyWith(
              color: customColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.calories.toStringAsFixed(0)} calories',
                  style: AppTypography.body2.copyWith(
                    color: customColors.textSecondary,
                  ),
                ),
              ),
              Text(
                '${item.servings}x serving',
                style: AppTypography.body2.copyWith(
                  color: customColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'P: ${item.protein.toStringAsFixed(1)}g',
                style: AppTypography.caption.copyWith(
                  color: const Color(0xFFEF4444),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'C: ${item.carbohydrates.toStringAsFixed(1)}g',
                style: AppTypography.caption.copyWith(
                  color: const Color(0xFF10B981),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'F: ${item.fat.toStringAsFixed(1)}g',
                style: AppTypography.caption.copyWith(
                  color: const Color(0xFFF59E0B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreferencesDialog extends StatelessWidget {
  const _PreferencesDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Meal Preferences'),
      content: const Text('Meal preferences dialog coming soon!'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
