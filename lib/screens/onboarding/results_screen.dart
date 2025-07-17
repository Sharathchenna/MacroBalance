import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrotracker/screens/Dashboard.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/services/storage_service.dart'; // Import StorageService
import 'dart:convert';
import 'dart:async';
import 'package:macrotracker/services/superwall_placements.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/subscription_provider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';

class ResultsScreen extends StatefulWidget {
  final Map<String, dynamic> results;

  const ResultsScreen({Key? key, required this.results}) : super(key: key);

  @override
  _ResultsScreenState createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late ScrollController _scrollController;
  bool _showDetailedMetrics = false;
  bool _showCalculationDetails = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    _animationController.forward();

    _scrollController = ScrollController();

    // Save results to shared preferences
    _saveResultsToPrefs(); // Now synchronous

    // Ensure all SnackBars use fixed behavior by default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
      }
    });
  }

  // Now synchronous
  void _saveResultsToPrefs() {
    HapticFeedback.mediumImpact();
    // Assuming StorageService is initialized
    StorageService().put('macro_results', jsonEncode(widget.results));
  }

  void _shareResults() {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sharing functionality coming soon!'),
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  void _showPaywallAndProceed() {
    HapticFeedback.mediumImpact();

    // Get providers
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    final foodEntryProvider = Provider.of<FoodEntryProvider>(context, listen: false);

    // Prepare nutrition goals sync helper
    Future<void> syncNutritionGoals() async {
      await foodEntryProvider.loadNutritionGoals();
      try {
        debugPrint('Syncing nutrition goals to Supabase after onboarding');
        await foodEntryProvider.syncAllDataWithSupabase();
        debugPrint('Completed sync of nutrition goals to Supabase');
      } catch (e) {
        debugPrint('Error syncing nutrition goals to Supabase: $e');
      }
    }

    // Use the new Superwall placement system
    SuperwallPlacements.showOnboardingPaywall(
      context,
      onPremiumUser: () async {
        // User has premium access - sync data and proceed to dashboard
        await syncNutritionGoals();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const Dashboard(),
            ),
          );
        }
      },
      onFreeUser: () async {
        // User doesn't have premium - show hard paywall message and remain on results
        await syncNutritionGoals();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A subscription is required to use this app'),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.fixed,
            ),
          );
          // Stay on results screen - user can try again or use back button
        }
      },
    );
  }

  void _navigateBack() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(); // Navigate back to previous screen
  }

  void _savePlan() {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text('Plan saved successfully!'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>()!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: customColors.textPrimary),
          onPressed: _navigateBack,
          tooltip: 'Back to previous step',
        ),
        title: Text(
          'Your Nutrition Plan',
          style: GoogleFonts.poppins(
            color: customColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AnimatedBuilder(
        animation: _fadeInAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeInAnimation.value,
            child: child,
          );
        },
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildDailyCalorieTargetCard(),
                    const SizedBox(height: 16),
                    _buildMacroDistributionCard(),
                    const SizedBox(height: 16),
                    _buildDetailedMetricsToggle(),
                    if (_showDetailedMetrics) ...[
                      const SizedBox(height: 16),
                      _buildGoalRelatedInformation(
                          widget.results['goal_weight_kg'] != null),
                      const SizedBox(height: 16),
                      _buildLifestyleRecommendations(),
                    ],
                    const SizedBox(height: 16),
                    _buildCalculationDetailsToggle(),
                    if (_showCalculationDetails) ...[
                      const SizedBox(height: 16),
                      _buildCalculationDetails(),
                    ],
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyCalorieTargetCard() {
    final customColors = Theme.of(context).extension<CustomColors>()!;
    final calorieTarget = widget.results['target_calories'];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: customColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Your Daily Calorie Target",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: customColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Calculated specifically for your ${_getGoalText()} goal",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: customColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Container(
                  height: 140,
                  width: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(calorieTarget * value).round()}',
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'cal/day',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This target supports sustainable progress toward your goals',
                      style: TextStyle(
                        fontSize: 14,
                        color: customColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
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

  String _getGoalText() {
    final goal = widget.results['goal'] ?? '';
    if (goal == 'lose') return 'weight loss';
    if (goal == 'gain') return 'muscle gain';
    return 'maintenance';
  }

  Widget _buildMacroDistributionCard() {
    final customColors = Theme.of(context).extension<CustomColors>()!;
    final protein = widget.results['protein_g'] ?? 0;
    final fat = widget.results['fat_g'] ?? 0;
    final carbs = widget.results['carb_g'] ?? 0;
    final proteinPercent = widget.results['protein_percent'] ?? 0;
    final fatPercent = widget.results['fat_percent'] ?? 0;
    final carbPercent = widget.results['carb_percent'] ?? 0;

    const proteinColor = Color(0xFF6366F1); // Indigo
    const carbColor = Color(0xFF10B981); // Emerald  
    const fatColor = Color(0xFFF59E0B); // Amber

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: customColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.timeline_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Daily Macronutrients',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: customColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your optimal macronutrient breakdown',
              style: TextStyle(
                fontSize: 14,
                color: customColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            _buildMacroProgressBar(
              'Protein',
              protein,
              proteinPercent,
              proteinColor,
              isAnimated: true,
              animationDelay: 200,
            ),
            const SizedBox(height: 16),
            _buildMacroProgressBar(
              'Carbs',
              carbs,
              carbPercent,
              carbColor,
              isAnimated: true,
              animationDelay: 400,
            ),
            const SizedBox(height: 16),
            _buildMacroProgressBar(
              'Fat',
              fat,
              fatPercent,
              fatColor,
              isAnimated: true,
              animationDelay: 600,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Based on ISSN guidelines',
                      style: TextStyle(
                        fontSize: 12,
                        color: customColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildMacroProgressBar(
    String name,
    int grams,
    int percentage,
    Color color, {
    bool isAnimated = false,
    int animationDelay = 0,
  }) {
    final customColors = Theme.of(context).extension<CustomColors>()!;

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: customColors.textPrimary,
              ),
            ),
            Row(
              children: [
                Text(
                  '${grams}g',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: customColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: percentage / 100),
          duration: Duration(milliseconds: 1000 + animationDelay),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              borderRadius: BorderRadius.circular(4),
            );
          },
        ),
      ],
    );

    if (isAnimated) {
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: Duration(milliseconds: 600 + animationDelay),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(20 * (1 - value), 0),
              child: content,
            ),
          );
        },
      );
    }

    return content;
  }

  Widget _buildMacroLegendItem(
      String name, String grams, String percentage, Color color,
      {bool isAnimated = false, int animationDelay = 0}) {
    final customColors = Theme.of(context).extension<CustomColors>()!;

    Widget content = Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: customColors.textPrimary,
              ),
            ),
            SizedBox(height: 2),
            Row(
              children: [
                Text(
                  grams,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: customColors.textPrimary,
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    percentage,
                    style: TextStyle(
                      fontSize: 12,
                      color: color.darken(30),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    if (isAnimated) {
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(20 * (1 - value), 0),
              child: content,
            ),
          );
        },
      );
    }

    return content;
  }

  Widget _buildGoalRelatedInformation(bool hasGoalWeight) {
    final customColors = Theme.of(context).extension<CustomColors>()!;
    final goalWeightKg = widget.results['goal_weight_kg'];
    final recommendedWeeklyRate = widget.results['recommended_weekly_rate'];
    final goalTimeframeWeeks = widget.results['goal_timeframe_weeks'];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: customColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.track_changes_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
                SizedBox(width: 8),
                Text(
                  hasGoalWeight ? 'Your Goal Plan' : 'Your Current Stats',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: customColors.textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              hasGoalWeight
                  ? 'Projected timeline and metrics for your goal'
                  : 'Your baseline metabolic calculations',
              style: TextStyle(
                fontSize: 14,
                color: customColors.textSecondary,
              ),
            ),
            SizedBox(height: 20),
            if (hasGoalWeight) ...[
              _buildProgressRow(
                'Current Weight',
                'Target Weight',
                '${widget.results['weight_kg'].toStringAsFixed(1)} kg',
                '${goalWeightKg.toStringAsFixed(1)} kg',
                Theme.of(context).colorScheme.primary,
              ),
              SizedBox(height: 24),
              _buildInfoRow(
                'Recommended Rate',
                '${recommendedWeeklyRate.toStringAsFixed(1)} kg/week',
                Icons.show_chart_rounded,
                Colors.blue.shade400,
                'This is a safe and sustainable rate of weight change based on scientific research.',
              ),
              SizedBox(height: 16),
              _buildInfoRow(
                'Estimated Timeframe',
                '${goalTimeframeWeeks.toString()} weeks',
                Icons.calendar_today_rounded,
                Colors.purple.shade300,
                'This is how long it may take to reach your goal weight at your current deficit/surplus.',
              ),
              SizedBox(height: 16),
            ],
            _buildInfoRow(
              'Basal Metabolic Rate (BMR)',
              '${widget.results['bmr']} calories/day',
              Icons.hotel_rounded,
              Colors.amber.shade700,
              'This is how many calories your body needs at complete rest.',
            ),
            SizedBox(height: 16),
            _buildInfoRow(
              'Total Daily Energy Expenditure',
              '${widget.results['tdee']} calories/day',
              Icons.directions_run_rounded,
              Colors.green.shade600,
              'This is your BMR plus calories burned through daily activity.',
            ),
            SizedBox(height: 16),
            _buildInfoRow(
              'Recommended Steps',
              '${widget.results['recommended_steps'] ?? 10000} steps/day',
              Icons.directions_walk_rounded,
              Colors.teal.shade500,
              'Aim for this step count to support your fitness goal.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRow(String startLabel, String endLabel,
      String startValue, String endValue, Color progressColor) {
    final customColors = Theme.of(context).extension<CustomColors>()!;

    return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: Duration(milliseconds: 1500),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        startLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: customColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        startValue,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: customColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        endLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: customColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        endValue,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: customColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 12),
              LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        });
  }

  Widget _buildInfoRow(
    String title,
    String value,
    IconData icon,
    Color color,
    String tooltip,
  ) {
    final customColors = Theme.of(context).extension<CustomColors>()!;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: customColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: customColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: tooltip,
            child: Icon(
              Icons.info_outline,
              color: color.withOpacity(0.7),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationDetails() {
    final customColors = Theme.of(context).extension<CustomColors>();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: customColors?.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.analytics_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
                SizedBox(width: 8),
                Text(
                  'Calculation Method',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: customColors?.textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'The science behind your personalized calculations',
              style: TextStyle(
                fontSize: 14,
                color: customColors?.textSecondary,
              ),
            ),
            SizedBox(height: 20),

            // BMR Formula
            _buildMethodCard(
              'Formula Used',
              widget.results.containsKey('formula_used')
                  ? '${widget.results['formula_used']}'
                  : 'Automatically selected formula',
              'Our system selected the most accurate formula for your body type',
              Icons.functions_rounded,
              Colors.indigo.shade400,
            ),

            SizedBox(height: 16),

            // Show body fat percentage if provided
            if (widget.results.containsKey('body_fat_percentage') &&
                widget.results['body_fat_percentage'] != null)
              Column(
                children: [
                  _buildMethodCard(
                    'Body Fat Percentage',
                    '${widget.results['body_fat_percentage'].round()}%',
                    'Used for more accurate metabolic calculations',
                    Icons.monitor_weight_outlined,
                    Colors.orange.shade500,
                  ),
                  SizedBox(height: 16),
                ],
              ),

            // Show athletic status if provided
            if (widget.results.containsKey('is_athlete') &&
                widget.results['is_athlete'] == true)
              Column(
                children: [
                  _buildMethodCard(
                    'Athletic Status',
                    'Athlete',
                    'Athletic individuals may have higher metabolic rates',
                    Icons.sports_rounded,
                    Colors.green.shade500,
                  ),
                  SizedBox(height: 16),
                ],
              ),

            // Add scientific sources section
            Divider(height: 32),
            Row(
              children: [
                Icon(
                  Icons.science_rounded,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Scientific Sources',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: customColors?.textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              '• BMR Formulas: Mifflin-St Jeor (1990), Harris-Benedict (1919), Katch-McArdle (1996)\n'
              '• Protein: International Society of Sports Nutrition\n'
              '• Fat & Carbs: Harvard School of Public Health\n'
              '• Weight change rate: National Institutes of Health',
              style: TextStyle(
                fontSize: 13,
                color: customColors?.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodCard(
    String title,
    String value,
    String description,
    IconData icon,
    Color color,
  ) {
    final customColors = Theme.of(context).extension<CustomColors>()!;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: customColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: customColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
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

  Widget _buildLifestyleRecommendations() {
    final customColors = Theme.of(context).extension<CustomColors>()!;
    final weight =
        widget.results['weight_kg'] ?? 70; // Default to 70kg if not available

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: customColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
                SizedBox(width: 8),
                Text(
                  'Lifestyle Recommendations',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: customColors.textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Supporting habits to optimize your results',
              style: TextStyle(
                fontSize: 14,
                color: customColors.textSecondary,
              ),
            ),
            SizedBox(height: 20),
            _buildLifestyleCard(
              'Water Intake',
              '${(weight * 0.033).toStringAsFixed(1)} liters/day',
              'Stay hydrated to support metabolism and overall health.',
              Icons.water_drop_rounded,
              Colors.blue.shade400,
              isAnimated: true,
              animationDelay: 300,
            ),
            SizedBox(height: 16),
            _buildLifestyleCard(
              'Sleep Recommendation',
              '7-9 hours/night',
              'Quality sleep is essential for recovery and hormonal balance.',
              Icons.nightlight_round,
              Colors.indigo.shade400,
              isAnimated: true,
              animationDelay: 500,
            ),
            SizedBox(height: 16),
            _buildLifestyleCard(
              'Exercise',
              '150+ minutes/week',
              'Regular physical activity enhances your results and well-being.',
              Icons.fitness_center_rounded,
              Colors.green.shade500,
              isAnimated: true,
              animationDelay: 700,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLifestyleCard(String title, String value, String description,
      IconData icon, Color color,
      {bool isAnimated = false, int animationDelay = 0}) {
    final customColors = Theme.of(context).extension<CustomColors>()!;

    Widget card = Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: customColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: color.darken(10),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: customColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isAnimated) {
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(30 * (1 - value), 0),
              child: card,
            ),
          );
        },
      );
    }

    return card;
  }

  Widget _buildDetailedMetricsToggle() {
    final customColors = Theme.of(context).extension<CustomColors>()!;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: customColors.cardBackground,
      child: InkWell(
        onTap: () {
          setState(() {
            _showDetailedMetrics = !_showDetailedMetrics;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.insights_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Detailed Metrics & Recommendations',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: customColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                _showDetailedMetrics 
                  ? Icons.keyboard_arrow_up 
                  : Icons.keyboard_arrow_down,
                color: customColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalculationDetailsToggle() {
    final customColors = Theme.of(context).extension<CustomColors>()!;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: customColors.cardBackground,
      child: InkWell(
        onTap: () {
          setState(() {
            _showCalculationDetails = !_showCalculationDetails;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.science_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'How We Calculated This',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: customColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                _showCalculationDetails 
                  ? Icons.keyboard_arrow_up 
                  : Icons.keyboard_arrow_down,
                color: customColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: _savePlan,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bookmark_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Save Plan",
                      style: GoogleFonts.poppins(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _showPaywallAndProceed,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Start Your Journey",
                      style: GoogleFonts.poppins(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// Color utility extension
extension ColorExtension on Color {
  Color darken([int percent = 10]) {
    assert(1 <= percent && percent <= 100);
    final f = 1 - percent / 100;
    return Color.fromARGB(
      alpha,
      (red * f).round(),
      (green * f).round(),
      (blue * f).round(),
    );
  }

  Color lighten([int percent = 10]) {
    assert(1 <= percent && percent <= 100);
    final p = percent / 100;
    return Color.fromARGB(
      alpha,
      red + ((255 - red) * p).round(),
      green + ((255 - green) * p).round(),
      blue + ((255 - blue) * p).round(),
    );
  }
}
