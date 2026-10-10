import 'package:flutter/material.dart';
import 'package:macrotracker/providers/energy_provider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/services/energy/bmr.dart';
import 'package:macrotracker/services/energy/checkin_day.dart';
import 'package:macrotracker/services/energy/constants.dart';
import 'package:macrotracker/services/energy/energy_summary.dart';
import 'package:macrotracker/services/energy/phase_engine.dart';
import 'package:macrotracker/services/energy/projection.dart';
import 'package:macrotracker/services/energy/recalculate.dart';
import 'package:macrotracker/services/energy/targets.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/screens/onboarding/results_screen.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:math'; // For min/max
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:macrotracker/theme/typography.dart';
import 'package:macrotracker/services/posthog_service.dart';
import 'package:macrotracker/widgets/adaptive_choice.dart';
import 'package:macrotracker/widgets/plan_style_choice.dart';

// Import Page Widgets
import 'pages/welcome_page.dart';
import 'pages/gender_page.dart';
import 'pages/weight_page.dart';
import 'pages/height_page.dart';
import 'pages/age_page.dart';
import 'pages/activity_level_page.dart';
import 'pages/goal_page.dart';
import 'pages/set_new_goal_page.dart'; // Import the new goal details page
// Removed TargetSummaryPage import
import 'pages/plan_style_page.dart';
import 'pages/adaptive_page.dart';
import 'pages/advanced_settings_page.dart';
import 'pages/apple_health_page.dart'; // Import the new Apple Health page
import 'pages/summary_page.dart';
import 'onboarding_steps.dart';
import 'package:macrotracker/providers/detailed_stats_provider.dart';

class OnboardingScreen extends StatefulWidget {
  /// Recalculate goals for an existing user: only the body and goal
  /// questions, prefilled, and nothing else about the account changes.
  final bool recalculateOnly;

  /// Opened from "Set a new goal" on the goal-reached check-in: whatever is
  /// chosen starts a fresh plan, even with the same goal and pace.
  final bool goalReached;

  const OnboardingScreen({super.key, this.recalculateOnly = false, this.goalReached = false});

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final List<OnboardingStep> _steps =
      onboardingStepsFor(recalculateOnly: widget.recalculateOnly);
  int get _totalPages => _steps.length;
  OnboardingStep get _currentStep => _steps[_currentPage];

  bool _isSkipped(OnboardingStep step) => isOnboardingStepSkipped(step,
      goal: _goal, usesLearnedExpenditure: _usesLearnedTdee,
      showDetailedStats: _detailed);
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  // --- State Variables ---
  String _gender = MacroCalculatorService.MALE;
  double _weightKg = 70;
  double _heightCm = 170;
  int _age = 30;
  int _activityLevel = MacroCalculatorService.MODERATELY_ACTIVE;
  String _goal = MacroCalculatorService.GOAL_MAINTAIN;
  double _pacePct = kDefaultLosePace; // % of body weight a week
  double? _proteinRatio; // null: the default for the goal
  double _fatRatio = 0.25;
  double _goalWeightKg = 70;
  double? _bodyFatPercentage; // null until the user sets one
  bool _showBodyFatInput = false;
  bool _adaptiveGoals = true; // recommended; see AdaptivePage
  PlanStyle? _planStyleChoice; // null: the default for the goal's size
  // Recalculating: the plan as saved, to tell whether it changed.
  ({PlanStyle style, String goal, double pace})? _savedPlan;
  // Recalculating only (spec 7.6): the targets now, the confident learned
  // expenditure, and the trend weight offered after a recent weigh-in.
  GoalTargets? _currentTargets;
  double? _learnedTdee;
  double? _recentTrendKg;
  // Start in the unit system of the phone's region.
  bool _isMetricWeight = WeightUnitProvider.localeDefaultIsMetric();
  bool _isMetricHeight = WeightUnitProvider.localeDefaultIsMetric();
  // --- End State Variables ---

  /// Body fat counts only once the user has chosen to enter it and set a value.
  double? get _knownBodyFat => _showBodyFatInput ? _bodyFatPercentage : null;

  double get _defaultProteinRatio => defaultProteinPerKg(
      goal: MacroCalculatorService.goalKindOf(_goal),
      bodyFatKnown: _knownBodyFat != null);

  GoalKind get _goalKind => MacroCalculatorService.goalKindOf(_goal);

  bool get _detailed => context.read<DetailedStatsProvider>().showDetailedStats;

  /// Simple plans start Steady; detailed mode retains the size-based default.
  /// A saved or explicitly chosen plan keeps its style in either mode.
  PlanStyle get _planStyle => _goal != MacroCalculatorService.GOAL_LOSE
      ? PlanStyle.steady
      : _planStyleChoice ?? (_detailed ? _defaultPlanStyle : PlanStyle.steady);

  PlanStyle get _defaultPlanStyle =>
      defaultPlanStyle(weightKg: _weightKg, goalWeightKg: _goalWeightKg);

  /// How the plan unfolds at the chosen pace, from the projection.
  PlanOutline? get _planOutline => _goal != MacroCalculatorService.GOAL_LOSE
      ? null
      : _projectionFor(_pacePct).outline;

  /// Weeks to the goal at [pacePct] (spec 6.9): the plan style, adaptive
  /// choice and safety limits as chosen so far.
  Projection _projectionFor(double pacePct, {double? tdee}) => projectToGoal(
        goal: _goalKind,
        weightKg: _weightKg,
        goalWeightKg: _goalWeightKg,
        tdee: tdee ?? _tdee,
        pacePct: pacePct,
        body: MacroCalculatorService.bodyFor(
          gender: _gender,
          heightCm: _heightCm,
          age: _age,
          activityLevel: _activityLevel,
          bodyFatPercentage: _knownBodyFat,
        ),
        on: DateTime.now(),
        adaptive: _adaptiveGoals,
        style: _planStyle,
      );

  /// "3 loss phases + 2 breaks · about 34 weeks" for phased plans.
  String? get _planLine {
    final o = _planOutline;
    return o == null || _planStyle == PlanStyle.steady ? null : PlanStyleCopy.outline(o);
  }

  /// Plans come from the learned expenditure while adaptive goals are on
  /// and it's confident; activity isn't asked then (spec 7.6).
  bool get _usesLearnedTdee => _adaptiveGoals && _learnedTdee != null;

  /// The expenditure the targets come from.
  double get _tdee => _usesLearnedTdee ? _learnedTdee! : _formulaTdee;

  double get _formulaTdee => formulaTdee(
        sex: MacroCalculatorService.sexOf(_gender),
        weightKg: _weightKg,
        heightCm: _heightCm,
        age: _age,
        activityLevel: _activityLevel,
        bodyFatPct: _knownBodyFat,
      );

  /// The target a pace gives today, after the safety limits.
  PaceTarget _targetFor(double pacePct, {double? tdee, double? kcalPerKg}) =>
      targetForPace(
        goal: _goalKind,
        pacePct: pacePct,
        tdee: tdee ?? _tdee,
        sex: MacroCalculatorService.sexOf(_gender),
        weightKg: _weightKg,
        energyDensity: kcalPerKg ?? _kcalPerKg,
      );

  /// Every pace offered for the goal, with its cals and weeks to the goal.
  List<PaceChoice> _paceChoices() {
    final tdee = _tdee;
    final kcalPerKg = _kcalPerKg;
    final options = _goalKind == GoalKind.gain ? kGainPaceOptions : kLosePaceOptions;
    return [
      for (final pace in options)
        () {
          final target = _targetFor(pace, tdee: tdee, kcalPerKg: kcalPerKg);
          final projection = _projectionFor(pace, tdee: tdee);
          return PaceChoice(
            target: target,
            weeks: projection.aboutWeeks,
            date: projection.date,
          );
        }(),
    ];
  }

  double get _kcalPerKg => MacroCalculatorService.energyDensityFor(
        gender: _gender,
        weightKg: _weightKg,
        heightCm: _heightCm,
        age: _age,
        bodyFatPercentage: _knownBodyFat,
      );

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    // Track screen view
    PostHogService.trackScreen('onboarding_screen');
    
    // Initialize animation with default values before first build
    _progressAnimation = Tween<double>(begin: 0, end: 1 / _totalPages).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    // _updateProgressAnimation(); // Removed redundant call
    _animationController.forward();
    _goalWeightKg = _weightKg; // Initialize goal weight
    // Start from the unit the user already uses (their Settings choice, or
    // the region default), so finishing doesn't silently switch it.
    _isMetricWeight = Provider.of<WeightUnitProvider>(context, listen: false).isMetric;
    if (widget.recalculateOnly) _prefillFromCurrentGoals();
  }

  /// Starts recalculation from what the app already knows: the trend
  /// weight (else the profile weight), the account profile, the goal
  /// settings and, once confident, the learned expenditure.
  void _prefillFromCurrentGoals() {
    final goals = Provider.of<GoalsProvider>(context, listen: false);
    final energy = Provider.of<EnergyProvider>(context, listen: false);
    if (goals.currentWeightKg > 0) _weightKg = goals.currentWeightKg;
    final trend =
        weightPrefill(EnergyProvider.storedWeights(), today: DateTime.now());
    if (trend != null) {
      // To the picker's 0.1 kg.
      _weightKg = (trend.kg * 10).round() / 10;
      if (trend.recent) _recentTrendKg = _weightKg;
    }
    _currentTargets = goals.targets;
    _learnedTdee = learnedTdee(EnergySummary.from(
      estimates: energy.estimates,
      learningStartedOn: goals.learningStartedOn,
      formulaTdee: goals.formulaTdee ?? goals.tdee,
    ));
    // Sex, height and age aren't asked again: they come from the account.
    _gender = goals.sex ?? _gender;
    _heightCm = goals.heightCm ?? _heightCm;
    _age = goals.age ?? _age;
    _activityLevel = goals.activityLevel ?? _activityLevel;
    _goal = goals.goalType;
    _pacePct = _validPace(goals.pacePctPerWeek);
    _adaptiveGoals = goals.adaptiveGoals;
    if (!_detailed) {
      // The simple flow skips nutrition fine tuning, so keep saved overrides.
      _proteinRatio = goals.checkinSettings.proteinPerKg;
      _fatRatio = goals.checkinSettings.fatRatio ?? _fatRatio;
      _bodyFatPercentage = goals.bodyFatPct;
      _showBodyFatInput = _bodyFatPercentage != null;
    }
    // A lose goal has had its style chosen; otherwise the default applies
    // once the user picks lose.
    if (_goal == MacroCalculatorService.GOAL_LOSE) _planStyleChoice = goals.planStyle;
    _savedPlan = (style: goals.planStyle, goal: _goal, pace: _pacePct);
    _goalWeightKg = goals.goalWeightKg > 0 ? goals.goalWeightKg : _weightKg;
    // A saved goal weight can be on the wrong side of the current weight (no
    // goal weight saved, or the user has since passed it). Bring it back in
    // range so the goal-weight wheel can show it.
    _validateRanges();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _updateProgressAnimation() {
    // Ensure division by totalPages is correct and handles _totalPages = 0 case
    double beginFraction = _currentPage / (_totalPages > 0 ? _totalPages : 1);
    double endFraction =
        (_currentPage + 1) / (_totalPages > 0 ? _totalPages : 1);

    _progressAnimation = Tween<double>(
      begin: beginFraction,
      end: endFraction,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  // --- Helper Functions for Projected Date ---
  /// [pace] if it's offered for the goal, else the recommended pace.
  double _validPace(double pace) {
    final options = _goalKind == GoalKind.gain ? kGainPaceOptions : kLosePaceOptions;
    return options.contains(pace) ? pace : defaultPacePct(_goalKind);
  }

  DateTime? _calculateProjectedDate() => _projectionFor(_pacePct).date;

  // --- End Helper Functions ---

  // --- Navigation ---
  void _nextPage() {
    HapticFeedback.selectionClick();
    if (_currentStep == OnboardingStep.setNewGoal) _validateRanges();
    var next = _currentPage + 1;
    while (next < _totalPages && _isSkipped(_steps[next])) {
      next++;
    }
    if (next < _totalPages) {
      _goToIndex(next);
    } else {
      _calculateAndShowResults();
    }
  }

  void _previousPage() {
    HapticFeedback.selectionClick();
    var previous = _currentPage - 1;
    while (previous >= 0 && _isSkipped(_steps[previous])) {
      previous--;
    }
    if (previous >= 0) _goToIndex(previous);
  }

  /// Used by the summary page's "edit" links.
  void _goToStep(OnboardingStep step) {
    final index = _steps.indexOf(step);
    if (index >= 0) _goToIndex(index);
  }

  void _goToIndex(int target) {
    if (target == _currentPage || target < 0 || target >= _totalPages) return;
    if (_currentPage < _steps.indexOf(OnboardingStep.setNewGoal) &&
        target > _steps.indexOf(OnboardingStep.setNewGoal)) {
      _validateRanges();
    }
    if ((target - _currentPage).abs() > 1) {
      // Jump rather than animate through skipped or intermediate pages.
      _pageController.jumpToPage(target);
      setState(() {
        _currentPage = target;
        _updateProgressAnimation();
        _animationController.forward(from: 0.0);
      });
    } else {
      _pageController.animateToPage(target,
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }
  // --- End Navigation ---

  // --- Calculation & Saving ---
  /// The plan the answers so far give.
  Map<String, dynamic> _calculate() => MacroCalculatorService().calculateAll(
      gender: _gender,
      weightKg: _weightKg,
      heightCm: _heightCm,
      age: _age,
      activityLevel: _activityLevel,
      goal: _goal,
      pacePct: _pacePct,
      proteinRatio: _proteinRatio,
      fatRatio: _fatRatio,
      goalWeightKg:
          _goal != MacroCalculatorService.GOAL_MAINTAIN ? _goalWeightKg : null,
      bodyFatPercentage: _knownBodyFat,
      tdee: _usesLearnedTdee ? _learnedTdee : null,
      adaptive: _adaptiveGoals,
      planStyle: _planStyle,
    );

  GoalTargets _targetsOf(Map<String, dynamic> results) => GoalTargets(
        calories: (results['target_calories'] as num).toDouble(),
        protein: (results['protein_g'] as num).toDouble(),
        carbs: (results['carb_g'] as num).toDouble(),
        fat: (results['fat_g'] as num).toDouble(),
      );

  void _calculateAndShowResults() async {
    final results = _calculate();

    if (_goal != MacroCalculatorService.GOAL_MAINTAIN) {
      PostHogService.trackEvent('pace_chosen', properties: {
        'pct': _pacePct,
        'clamped': results['limit_hit'] != null,
      });
    }
    if (_goal == MacroCalculatorService.GOAL_LOSE) trackPlanStyleChosen(_planStyle);
    if (_steps.contains(OnboardingStep.adaptive)) {
      trackAdaptiveChoice(
          _adaptiveGoals,
          widget.recalculateOnly
              ? AdaptiveChoiceContext.recalculate
              : AdaptiveChoiceContext.onboarding);
    }
    PostHogService.trackEvent(
        widget.recalculateOnly ? 'goals_recalculated' : 'onboarding_completed',
        properties: {
      'goal': _goal,
      'gender': _gender,
      'age': _age,
      'activity_level': _activityLevel,
      'target_calories': results['target_calories'],
      'tdee_learned': results['tdee_learned'],
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // When recalculating, nothing changes until the user taps Save.
    if (!widget.recalculateOnly) await saveMacroResults(results);
    // Use context safely
    if (!mounted) return;
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          ResultsScreen(
            results: results,
            recalculateOnly: widget.recalculateOnly,
            adaptiveGoals: _adaptiveGoals,
            isMetricWeight: _isMetricWeight,
            goalWeightKg: _goal == MacroCalculatorService.GOAL_MAINTAIN ? null : _goalWeightKg,
            planLine: _planLine,
            onSave: widget.recalculateOnly ? () => saveMacroResults(results) : null,
          ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;
        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
            position: animation.drive(tween),
            child: FadeTransition(opacity: animation, child: child));
      },
      transitionDuration: const Duration(milliseconds: 500),
    ));
  }

  Future<void> saveMacroResults(Map<String, dynamic> macroResults) async {
    // Keep the unit system the user chose for their weight.
    Provider.of<WeightUnitProvider>(context, listen: false).setMetric(_isMetricWeight);
    final settings = _goalSettings(macroResults);
    try {
      StorageService().put('macro_results', json.encode(macroResults));
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        final Map<String, dynamic> supabaseData = {
          'id': currentUser.id,
          'email': currentUser.email ?? '',
          'macro_results': macroResults,
          'calories_goal': (macroResults['target_calories'] ?? 0).toDouble(),
          'protein_goal': (macroResults['protein_g'] ?? 0).toDouble(),
          'carbs_goal': (macroResults['carb_g'] ?? 0).toDouble(),
          'fat_goal': (macroResults['fat_g'] ?? 0).toDouble(),
          'weight': _weightKg.toDouble(),
          ...settings,
          // Learning starts when onboarding completes; a recalculation
          // never resets it (the upsert leaves the column alone).
          if (!widget.recalculateOnly) 'learning_started_on': _today(),
          'updated_at': DateTime.now().toIso8601String(),
          'macro_targets': _macroTargets(macroResults),
        };
        supabaseData
            .removeWhere((_, v) => v is double && (v.isNaN || v.isInfinite));
        (supabaseData['macro_targets'] as Map<String, dynamic>)
            .removeWhere((_, v) => v is double && (v.isNaN || v.isInfinite));
        await Supabase.instance.client.from('user_macros').upsert(supabaseData);
        debugPrint('Successfully saved macro results to Supabase');
      }
      _saveLocalGoals(macroResults, settings);
      await _replanIfChanged();
    } catch (e) {
      debugPrint('Error saving macro results: $e');
      if (e is PostgrestException) debugPrint('Supabase error: ${e.message}');
      // Consider showing an error message to the user here
      // rethrow; // Rethrowing might crash the app if not caught higher up
    }
  }

  /// Starts a fresh phase sequence from today's weight (spec 6.7) at
  /// onboarding, and when a recalculation changed the plan style, goal or
  /// pace (or there's no plan yet). Otherwise the plan carries on.
  Future<void> _replanIfChanged() async {
    final energy = Provider.of<EnergyProvider>(context, listen: false);
    final pace = _goal == MacroCalculatorService.GOAL_MAINTAIN ? null : _pacePct;
    final saved = _savedPlan;
    final unchanged = widget.recalculateOnly &&
        !widget.goalReached &&
        saved != null &&
        energy.currentPhase != null &&
        saved.style == _planStyle &&
        saved.goal == _goal &&
        (pace == null || saved.pace == pace);
    if (unchanged) return;
    await energy.replan(
      style: _planStyle,
      goal: _goalKind,
      trendKg: _weightKg,
      heightCm: _heightCm,
    );
  }

  /// The goal settings this flow saves, in `user_macros` column names: the
  /// account row and the device copy are both built from it.
  Map<String, dynamic> _goalSettings(Map<String, dynamic> macroResults) {
    final goals = Provider.of<GoalsProvider>(context, listen: false);
    return {
      'sex': _gender,
      'height_cm': _heightCm.toDouble(),
      'age': _age,
      'age_recorded_on': _today(),
      'activity_level': _activityLevel,
      'goal_type': _goal,
      'pace_pct_per_week':
          _goal == MacroCalculatorService.GOAL_MAINTAIN ? null : _pacePct,
      'goal_weight_kg': _goalWeightKg.toDouble(),
      'current_weight_kg': _weightKg.toDouble(),
      'body_fat_pct': _knownBodyFat,
      'protein_g_per_kg': _proteinRatio,
      'fat_ratio': _fatRatio.toDouble(),
      'formula_tdee': _keepsFormulaTdee
          ? goals.formulaTdee ?? goals.tdee
          : macroResults['formula_tdee']?.toDouble(),
      'bmr': macroResults['bmr']?.toDouble(),
      'tdee': macroResults['tdee']?.toDouble(),
      'steps_goal': macroResults['recommended_steps'] ?? 10000,
      'adaptive_goals': _adaptiveGoals,
      'plan_style': _planStyle.code,
      // Check-ins fall on the weekday onboarding finished; a recalculation
      // keeps the day already in use.
      'checkin_weekday': widget.recalculateOnly
          ? goals.checkinWeekday
          : defaultCheckinWeekday(DateTime.now()),
    };
  }

  /// Planning from the learned expenditure asks no activity level, so the
  /// formula TDEE (the estimator's starting point) stays as it is and the
  /// learned history replays unchanged.
  bool get _keepsFormulaTdee => widget.recalculateOnly && _usesLearnedTdee;

  Map<String, dynamic> _macroTargets(Map<String, dynamic> macroResults) => {
        'calories': (macroResults['target_calories'] ?? 0).toDouble(),
        'protein': (macroResults['protein_g'] ?? 0).toDouble(),
        'carbs': (macroResults['carb_g'] ?? 0).toDouble(),
        'fat': (macroResults['fat_g'] ?? 0).toDouble(),
      };

  /// The learning start already saved, kept through a recalculation.
  String? _learningStartedOn() {
    final day =
        Provider.of<GoalsProvider>(context, listen: false).learningStartedOn;
    return day?.toIso8601String().substring(0, 10);
  }

  /// The day the age was recorded, as a date for `user_macros`.
  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  /// The device copy (`nutrition_goals`), which GoalsProvider reads.
  void _saveLocalGoals(
      Map<String, dynamic> macroResults, Map<String, dynamic> settings) {
    final nutritionGoals = {
      'macro_targets': _macroTargets(macroResults),
      for (final e in settings.entries)
        // The device copy keeps the protein override as `protein_ratio`.
        (e.key == 'protein_g_per_kg' ? 'protein_ratio' : e.key): e.value,
      'learning_started_on': widget.recalculateOnly
          ? _learningStartedOn()
          : _today(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    StorageService().put('nutrition_goals', json.encode(nutritionGoals));
    debugPrint('Successfully saved nutrition goals locally');
  }
  // --- End Calculation & Saving ---

  // --- Validation ---
  void _validateRanges() {
    if (_goal == MacroCalculatorService.GOAL_LOSE) {
      double minWeight = _weightKg * 0.75; // Example lower bound
      _goalWeightKg =
          max(minWeight, _goalWeightKg); // Ensure goal is not too low
      _goalWeightKg = min(
          _goalWeightKg, _weightKg - 0.1); // Ensure goal is less than current
    } else if (_goal == MacroCalculatorService.GOAL_GAIN) {
      double maxWeight = _weightKg * 1.5; // Example upper bound
      _goalWeightKg =
          min(maxWeight, _goalWeightKg); // Ensure goal is not too high
      _goalWeightKg = max(
          _goalWeightKg, _weightKg + 0.1); // Ensure goal is more than current
    }
    // Clamp goal weight to reasonable min/max if needed (e.g., 40kg to 150kg)
    _goalWeightKg = _goalWeightKg.clamp(40.0, 150.0);
  }
  // --- End Validation ---

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    // Get theme and colors
    final theme = Theme.of(context);
    final customColors = Theme.of(context).extension<CustomColors>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator at top
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return LinearProgressIndicator(
                    value: _progressAnimation.value,
                    backgroundColor: (customColors?.dateNavigatorBackground ??
                            theme.colorScheme.surface)
                        .withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        customColors?.textPrimary ?? theme.colorScheme.primary),
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  );
                },
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Keep physics
                onPageChanged: (index) {
                  // This will now correctly fire after animateToPage completes
                  setState(() {
                    _currentPage = index;
                    _updateProgressAnimation(); // Update animation bounds for the new page
                    _animationController.forward(
                        from: 0.0); // Restart animation for the new segment
                  });
                },
                children: _buildPages(),
              ),
            ),

            // Bottom navigation
            Container(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  // When recalculating from Settings, the first step's
                  // Back leaves the flow; otherwise there'd be no way out.
                  _currentPage > 0 || widget.recalculateOnly
                      ? TextButton(
                          onPressed: _currentPage > 0
                              ? _previousPage
                              : () => Navigator.of(context).maybePop(),
                          child: Text(
                            _currentPage > 0 ? 'Back' : 'Cancel',
                            style: AppTypography.onboardingButton.copyWith(
                              color: customColors?.textSecondary ??
                                  theme.colorScheme.secondary,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : SizedBox(width: 80), // Empty space for alignment

                  // Next button or Done
                  _buildNextButton(theme, customColors),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextButton(ThemeData theme, CustomColors? customColors) {
    // The Apple Health page has its own buttons.
    if (_currentStep == OnboardingStep.appleHealth) {
      // Return an empty SizedBox to maintain layout spacing if needed,
      // or just an empty Container if no space is required.
      // Match the width of the back button for alignment.
      return const SizedBox(width: 80);
    }

    return ElevatedButton(
      onPressed: _nextPage,
      style: ElevatedButton.styleFrom(
        backgroundColor: customColors?.textPrimary ?? theme.colorScheme.onBackground,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        elevation: 0,
      ),
      child: Text(
        _currentPage == _totalPages - 1 ? 'Calculate' : 'Next',
        style: AppTypography.onboardingButton.copyWith(
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }

  List<Widget> _buildPages() => _steps.map(_buildStep).toList();

  Widget _buildStep(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.welcome:
        return const WelcomePage();
      case OnboardingStep.gender:
        return GenderPage(
          currentGender: _gender,
          onGenderSelected: (newGender) => setState(() => _gender = newGender),
        );
      case OnboardingStep.weight:
        return WeightPage(
          currentWeightKg: _weightKg,
          isMetric: _isMetricWeight,
          // Re-check the goal weight: after choosing to lose, a lower weight
          // could leave the goal above it.
          onWeightChanged: (newWeight) => setState(() {
            _weightKg = newWeight;
            _validateRanges();
          }),
          onUnitChanged: (isMetric) => setState(() => _isMetricWeight = isMetric),
          trendKg: _recentTrendKg,
          onUseTrend: () {
            setState(() {
              _weightKg = _recentTrendKg!;
              _validateRanges();
            });
            _nextPage();
          },
        );
      case OnboardingStep.height:
        return HeightPage(
          currentHeightCm: _heightCm,
          isMetric: _isMetricHeight,
          onHeightChanged: (newHeight) => setState(() => _heightCm = newHeight),
          onUnitChanged: (isMetric) => setState(() => _isMetricHeight = isMetric),
        );
      case OnboardingStep.age:
        return AgePage(
          currentAge: _age,
          onAgeChanged: (newAge) => setState(() => _age = newAge),
        );
      case OnboardingStep.activity:
        return ActivityLevelPage(
          currentActivityLevel: _activityLevel,
          onActivityLevelChanged: (newLevel) =>
              setState(() => _activityLevel = newLevel),
        );
      case OnboardingStep.goal:
        return GoalPage(
          currentGoal: _goal,
          onGoalChanged: (newGoal) => setState(() {
            _goal = newGoal;
            _planStyleChoice = null;
            if (_goal == MacroCalculatorService.GOAL_MAINTAIN) {
              _goalWeightKg = _weightKg;
            } else {
              _pacePct = defaultPacePct(_goalKind);
              _goalWeightKg = _goal == MacroCalculatorService.GOAL_LOSE
                  ? max(40.0, _weightKg * 0.9)
                  : min(150.0, _weightKg * 1.1);
              _validateRanges();
            }
          }),
        );
      case OnboardingStep.setNewGoal:
        return SetNewGoalPage(
          currentGoal: _goal,
          currentWeightKg: _weightKg,
          goalWeightKg: _goalWeightKg,
          paceChoices: _goal == MacroCalculatorService.GOAL_MAINTAIN
              ? const []
              : _paceChoices(),
          pacePct: _pacePct,
          recommendedPacePct: defaultPacePct(_goalKind),
          isMetricWeight: _isMetricWeight,
          projectedDate: _calculateProjectedDate(),
          targetCalories: _goal == MacroCalculatorService.GOAL_MAINTAIN
              ? null
              : _targetFor(_pacePct).cals,
          planStyle: _goal == MacroCalculatorService.GOAL_LOSE ? _planStyle : null,
          onPlanStyleChanged: (style) => setState(() => _planStyleChoice = style),
          onGoalWeightChanged: (newWeight) => setState(() {
            _goalWeightKg = newWeight;
            _validateRanges();
          }),
          onPaceChanged: (pace) => setState(() => _pacePct = pace),
          onWeightUnitChanged: (isMetric) =>
              setState(() => _isMetricWeight = isMetric),
        );
      case OnboardingStep.planStyle:
        final style = _planStyle;
        return PlanStylePage(
          style: style,
          lossPct: phaseLossPct(weightKg: _weightKg, heightCm: _heightCm),
          recommended: _defaultPlanStyle == PlanStyle.phased ? PlanStyle.phased : null,
          outline: style == PlanStyle.steady ? null : _planOutline,
          onChanged: (s) => setState(() => _planStyleChoice = s),
        );
      case OnboardingStep.adaptive:
        return AdaptivePage(
          adaptive: _adaptiveGoals,
          onChanged: (adaptive) => setState(() => _adaptiveGoals = adaptive),
        );
      case OnboardingStep.advanced:
        return AdvancedSettingsPage(
          showBodyFatInput: _showBodyFatInput,
          bodyFatPercentage: _bodyFatPercentage,
          proteinRatio: _proteinRatio,
          defaultProteinRatio: _defaultProteinRatio,
          fatRatio: _fatRatio,
          gender: _gender,
          onShowBodyFatChanged: (show) => setState(() => _showBodyFatInput = show),
          onBodyFatChanged: (bfp) => setState(() => _bodyFatPercentage = bfp),
          onProteinRatioChanged: (ratio) => setState(() => _proteinRatio = ratio),
          onFatRatioChanged: (ratio) => setState(() => _fatRatio = ratio),
        );
      case OnboardingStep.appleHealth:
        return AppleHealthPage(
          onNext: _nextPage,
          onSkip: _nextPage,
        );
      case OnboardingStep.summary:
        return SummaryPage(
          gender: _gender,
          weightKg: _weightKg,
          heightCm: _heightCm,
          age: _age,
          activityLevel: _activityLevel,
          goal: _goal,
          pacePct: _pacePct,
          proteinRatio: _proteinRatio ?? _defaultProteinRatio,
          fatRatio: _fatRatio,
          goalWeightKg: _goalWeightKg,
          bodyFatPercentage: _knownBodyFat,
          adaptiveGoals: _adaptiveGoals,
          planStyle: _goal == MacroCalculatorService.GOAL_LOSE ? _planStyle : null,
          planLine: _planLine,
          onEdit: _goToStep,
          editableSteps: _steps.toSet(),
          isMetricWeight: _isMetricWeight,
          projectedDate: _calculateProjectedDate(),
          effectivePacePct: _targetFor(_pacePct).effectivePacePct,
          currentTargets: _currentTargets,
          newTargets: _targetsOf(_calculate()),
          learnedTdee: _usesLearnedTdee ? _learnedTdee : null,
        );
    }
  }
}
