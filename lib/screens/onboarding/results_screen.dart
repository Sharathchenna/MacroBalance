import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrotracker/screens/Dashboard.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/services/storage_service.dart'; // Import StorageService
import 'dart:convert';
import 'dart:async';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:macrotracker/screens/RevenueCat/custom_paywall_screen.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/subscription_provider.dart';
import 'package:macrotracker/auth/paywall_gate.dart';
import 'package:macrotracker/screens/onboarding/onboarding_screen.dart'; // Add this import
import 'package:macrotracker/providers/foodEntryProvider.dart'; // Import FoodEntryProvider

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

    // First check if user is already a Pro user
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);

    // Get access to the FoodEntryProvider to ensure data refresh
    final foodEntryProvider =
        Provider.of<FoodEntryProvider>(context, listen: false);

    // Force reload nutrition goals to ensure latest data from onboarding
    // is reflected in the Dashboard
    foodEntryProvider.loadNutritionGoals().then((_) {
      debugPrint(
          'Refreshed nutrition goals in FoodEntryProvider: Calories=${foodEntryProvider.caloriesGoal}, Protein=${foodEntryProvider.proteinGoal}');

      // Explicitly sync nutrition goals to Supabase after loading
      // Use a private method via reflection to access _syncNutritionGoalsToSupabase
      try {
        // Access the private method using reflection
        final syncGoalsMethod = foodEntryProvider.syncAllDataWithSupabase();
        debugPrint(
            'Explicitly syncing nutrition goals to Supabase after onboarding');
        syncGoalsMethod.then((_) {
          debugPrint('Completed explicit sync of nutrition goals to Supabase');
        });
      } catch (e) {
        debugPrint('Error syncing nutrition goals to Supabase: $e');
      }

      // Now check subscription status
      subscriptionProvider.refreshSubscriptionStatus().then((isProUser) {
        if (isProUser) {
          // Pro user - proceed directly to dashboard without showing paywall
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const Dashboard(),
              ),
            );
          }
        } else {
          // Not a Pro user - show paywall
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (context) => CustomPaywallScreen(
                  onDismiss: () async {
                    // Use our subscription provider to check subscription status
                    final subscriptionProvider =
                        Provider.of<SubscriptionProvider>(context,
                            listen: false);
                    await subscriptionProvider.refreshSubscriptionStatus();

                    // Always refresh the goals again before navigating
                    final foodEntryProvider =
                        Provider.of<FoodEntryProvider>(context, listen: false);
                    await foodEntryProvider.loadNutritionGoals();

                    // Explicitly sync nutrition goals to Supabase
                    try {
                      debugPrint(
                          'Explicitly syncing nutrition goals to Supabase after paywall dismissal');
                      await foodEntryProvider.syncAllDataWithSupabase();
                      debugPrint(
                          'Completed explicit sync of nutrition goals to Supabase');
                    } catch (e) {
                      debugPrint(
                          'Error syncing nutrition goals to Supabase: $e');
                    }

                    if (subscriptionProvider.isProUser) {
                      // Pro user - proceed to dashboard
                      if (mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            // Wrap Dashboard with PaywallGate for extra security
                            builder: (context) => const PaywallGate(
                              child: Dashboard(),
                            ),
                          ),
                        );
                      }
                    } else {
                      // Free user - hard paywall, show them the paywall again with explicit message
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'A subscription is required to use this app'),
                            duration: Duration(seconds: 3),
                            behavior: SnackBarBehavior.fixed,
                          ),
                        );

                        // Show the paywall again, but this time with harder enforcement
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (context) => CustomPaywallScreen(
                              allowDismissal:
                                  false, // Don't allow dismissal without subscribing
                              onDismiss: () async {
                                // This will only be called if they subscribe
                                final subscriptionProvider =
                                    Provider.of<SubscriptionProvider>(context,
                                        listen: false);
                                await subscriptionProvider
                                    .refreshSubscriptionStatus();

                                // Always refresh the goals again before navigating
                                final foodEntryProvider =
                                    Provider.of<FoodEntryProvider>(context,
                                        listen: false);
                                await foodEntryProvider.loadNutritionGoals();

                                // Explicitly sync nutrition goals to Supabase
                                try {
                                  debugPrint(
                                      'Explicitly syncing nutrition goals to Supabase after hard paywall dismissal');
                                  await foodEntryProvider
                                      .syncAllDataWithSupabase();
                                  debugPrint(
                                      'Completed explicit sync of nutrition goals to Supabase');
                                } catch (e) {
                                  debugPrint(
                                      'Error syncing nutrition goals to Supabase: $e');
                                }

                                if (mounted && subscriptionProvider.isProUser) {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (context) => const Dashboard(),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        );
                      }
                    }
                  },
                  // When back button is pressed on paywall shown from results, just pop back to results
                  onBackPressedOverride: () {
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  // Start with a soft paywall to give users a chance to subscribe willingly
                  allowDismissal: true,
                ),
              ),
            );
          }
        }
      });
    });
  }

  void _navigateBack() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(); // Navigate back to previous screen
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
                    SizedBox(height: 8),
                    _buildDailyCalorieTargetCard(),
                    SizedBox(height: 20),
                    _buildMacroDistributionCard(),
                    SizedBox(height: 20),
                    _buildGoalRelatedInformation(
                        widget.results['goal_weight_kg'] != null),
                    SizedBox(height: 20),
                    _buildCalculationDetails(),
                    SizedBox(height: 20),
                    _buildLifestyleRecommendations(),
                    SizedBox(height: 100), // Extra padding at bottom
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

    return Container(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Your Personalized Nutrition Plan",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: customColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              "Based on your information, we've calculated your optimal nutrition plan to help you reach your goals.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: customColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          SizedBox(height: 30),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: Duration(milliseconds: 1500),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 200,
                    width: 200,
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: 15,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(calorieTarget * value).round()}',
                        style: GoogleFonts.poppins(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: customColors.textPrimary,
                        ),
                      ),
                      Text(
                        'calories/day',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: customColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This calorie level is designed to help you achieve your ${_getGoalText()} goal in a sustainable way.',
                      style: TextStyle(
                        fontSize: 13,
                        color: customColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
                  Icons.pie_chart_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
                SizedBox(width: 8),
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
            SizedBox(height: 8),
            Text(
              'Balance these nutrients for optimal health and performance',
              style: TextStyle(
                fontSize: 14,
                color: customColors.textSecondary,
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: Duration(milliseconds: 1200),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return CustomPaint(
                          painter: MacroPieChartPainter(
                            proteinPercent: proteinPercent * value / 100,
                            carbPercent: carbPercent * value / 100,
                            fatPercent: fatPercent * value / 100,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMacroLegendItem(
                        'Protein',
                        '$protein g',
                        '$proteinPercent%',
                        Colors.red.shade400,
                        isAnimated: true,
                        animationDelay: 300,
                      ),
                      SizedBox(height: 14),
                      _buildMacroLegendItem(
                        'Carbs',
                        '$carbs g',
                        '$carbPercent%',
                        Colors.blue.shade400,
                        isAnimated: true,
                        animationDelay: 500,
                      ),
                      SizedBox(height: 14),
                      _buildMacroLegendItem(
                        'Fat',
                        '$fat g',
                        '$fatPercent%',
                        Colors.orange.shade400,
                        isAnimated: true,
                        animationDelay: 700,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 8),
            Text(
              'Based on scientific guidelines from the International Society of Sports Nutrition',
              style: TextStyle(
                fontSize: 12,
                color: customColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildBottomButtons() {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          // boxShadow: [
          //   BoxShadow(
          //     color: Colors.black.withOpacity(0.05),
          //     blurRadius: 10,
          //     offset: Offset(0, -2),
          //   ),
          // ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Center(
          child: ElevatedButton(
            onPressed: _showPaywallAndProceed,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 16),
              backgroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 4,
              shadowColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Start Your Journey",
                  style: GoogleFonts.poppins(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom painter for macro pie chart
class MacroPieChartPainter extends CustomPainter {
  final double proteinPercent;
  final double carbPercent;
  final double fatPercent;

  MacroPieChartPainter({
    required this.proteinPercent,
    required this.carbPercent,
    required this.fatPercent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // Define colors for each segment
    final proteinColor = Colors.red.shade400;
    final carbColor = Colors.blue.shade400;
    final fatColor = Colors.orange.shade400;

    // Calculate total - should equal 1.0 but just in case
    final total = proteinPercent + carbPercent + fatPercent;

    // Convert percentages to radians
    final proteinRadians = 2 * math.pi * (proteinPercent / total);
    final carbRadians = 2 * math.pi * (carbPercent / total);
    final fatRadians = 2 * math.pi * (fatPercent / total);

    // Starting angle is -π/2 (top of circle)
    double startAngle = -math.pi / 2;

    // Draw protein segment
    if (proteinPercent > 0) {
      final paint = Paint()
        ..color = proteinColor
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        proteinRadians,
        true,
        paint,
      );

      startAngle += proteinRadians;
    }

    // Draw carb segment
    if (carbPercent > 0) {
      final paint = Paint()
        ..color = carbColor
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        carbRadians,
        true,
        paint,
      );

      startAngle += carbRadians;
    }

    // Draw fat segment
    if (fatPercent > 0) {
      final paint = Paint()
        ..color = fatColor
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        fatRadians,
        true,
        paint,
      );
    }

    // Draw inner circle to create a donut chart
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      center,
      radius * 0.6, // Inner radius is 60% of outer radius
      innerPaint,
    );
  }

  @override
  bool shouldRepaint(MacroPieChartPainter oldDelegate) {
    return oldDelegate.proteinPercent != proteinPercent ||
        oldDelegate.carbPercent != carbPercent ||
        oldDelegate.fatPercent != fatPercent;
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
