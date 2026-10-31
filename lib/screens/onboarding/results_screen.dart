import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:macrotracker/auth/auth_gate.dart';
import 'package:macrotracker/screens/onboarding/save_screen.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_widgets.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/services/superwall_placements.dart';
import 'package:macrotracker/theme/ob_theme.dart';
import 'package:macrotracker/widgets/adaptive_choice.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/acquisition_source_page.dart';
import 'package:macrotracker/services/posthog_service.dart';

/// The plan reveal (docs/onboarding-redesign/mock/Reveal*.dc.html): the daily
/// cals counting up, the macros, what the user burns and the pace, and the
/// projection for the chosen goal. For new users the button saves the plan
/// (signing up first when signed out) and goes on to the paywall; when
/// recalculating from Settings it saves and goes back.
class ResultsScreen extends StatefulWidget {
  final Map<String, dynamic> results;

  /// Recalculating goals from Settings: save and go back, no paywall.
  final bool recalculateOnly;

  /// Saves the new goals; used in recalculate mode, where onboarding doesn't
  /// save up front.
  final Future<void> Function()? onSave;

  /// Whether the target will follow the learned expenditure (adaptive goals)
  /// or stay fixed: one line under the target says which.
  final bool adaptiveGoals;

  /// Phased plans: "3 loss phases + 2 breaks · about 34 weeks" under the
  /// adaptive line (spec 7.5).
  final String? planLine;
  final bool? isMetricWeight;
  final double? goalWeightKg;

  /// "Review answers" link at the top, shown when set.
  final VoidCallback? onReview;

  /// Saves the plan to the account made on the Save screen. Onboarding
  /// saved it on the device only, as there was no account then.
  final Future<void> Function()? onSignedUp;

  /// Today's weight, the start of the projection. Falls back to the weight
  /// in [results].
  final double? currentWeightKg;

  /// When the goal weight is reached; falls back to [results].
  final DateTime? projectedDate;

  /// Weeks to the goal; only used when there is no [projectedDate].
  final int? weeks;

  const ResultsScreen(
      {Key? key,
      required this.results,
      this.recalculateOnly = false,
      this.onSave,
      this.adaptiveGoals = true,
      this.planLine,
      this.isMetricWeight,
      this.goalWeightKg,
      this.onReview,
      this.onSignedUp,
      this.currentWeightKg,
      this.projectedDate,
      this.weeks})
      : super(key: key);

  /// Onboarding is done: drops the intro and quiz underneath so Back can't
  /// return to them, and lets the gate show the app (as login does).
  static void enterApp(NavigatorState navigator) {
    AuthGate.signedOutOnboarding = false;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  _ResultsScreenState createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with SingleTickerProviderStateMixin {
  /// One clock for the reveal: the count-up, the macro bars and the
  /// projection line each take their own slice of it, as in the mock.
  static const _total = Duration(milliseconds: 2600);
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: _total);
  bool _busy = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _saveResultsToPrefs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _clock.value = 1;
    } else {
      _clock.forward();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _saveResultsToPrefs() {
    HapticFeedback.mediumImpact();
    StorageService().put('macro_results', jsonEncode(widget.results));
  }

  Future<void> _showPaywallAndProceed() async {
    if (_busy) return;
    HapticFeedback.mediumImpact();

    // Prepare nutrition goals sync helper. The providers are looked up when
    // it runs: signing up on the Save screen swaps in new per-account
    // providers and disposes the ones in place now.
    Future<void> syncNutritionGoals() async {
      if (!mounted) return;
      final foodEntryProvider = Provider.of<FoodEntryProvider>(context, listen: false);
      final goals = Provider.of<GoalsProvider>(context, listen: false);
      await goals.load();
      try {
        debugPrint('Syncing nutrition goals to Supabase after onboarding');
        await goals.syncToCloud();
        await foodEntryProvider.syncWithCloud();
        debugPrint('Completed sync of nutrition goals to Supabase');
      } catch (e) {
        debugPrint('Error syncing nutrition goals to Supabase: $e');
      }
    }

    if (widget.recalculateOnly) {
      (widget.onSave?.call() ?? Future.value())
          .then((_) => syncNutritionGoals())
          .then((_) {
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your goals are updated'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
      return;
    }

    // The plan is saved on the device already; an account keeps it in sync.
    if (Supabase.instance.client.auth.currentUser == null) {
      _busy = true;
      final saved = await Navigator.of(context).push<SavedPlan>(
          MaterialPageRoute(builder: (_) => const SaveScreen()));
      if (saved == SavedPlan.newPlan) await widget.onSignedUp?.call();
      _busy = false;
      if (saved == null || !mounted) return;
    }

    _askAcquisitionSourceOnce().then((_) {
      if (mounted) _presentPaywall(syncNutritionGoals);
    });
  }

  /// "How did you hear about us?" now comes after the user has seen their
  /// plan, and can be skipped. Asked once per device.
  Future<void> _askAcquisitionSourceOnce() async {
    const askedKey = 'acquisition_source_asked';
    if (StorageService().get(askedKey) == true) return;
    await StorageService().put(askedKey, true);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const AcquisitionSourceStep(),
    ));
  }

  void _presentPaywall(Future<void> Function() syncNutritionGoals) {
    // Use the new Superwall placement system
    SuperwallPlacements.showOnboardingPaywall(
      context,
      onPremiumUser: () async {
        // User has premium access - sync data and proceed to dashboard
        await syncNutritionGoals();
        if (mounted) ResultsScreen.enterApp(Navigator.of(context));
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

  // ---- the plan -----------------------------------------------------------

  Map<String, dynamic> get _stats =>
      widget.results['weight_stats'] as Map<String, dynamic>? ?? const {};

  String get _goal {
    final g = widget.results['goal'] ?? widget.results['goal_type'];
    return g == MacroCalculatorService.GOAL_GAIN ||
            g == MacroCalculatorService.GOAL_MAINTAIN
        ? g as String
        : MacroCalculatorService.GOAL_LOSE;
  }

  double _num(String key) => (widget.results[key] as num?)?.toDouble() ?? 0;

  double? get _startKg =>
      widget.currentWeightKg ?? (_stats['current_weight'] as num?)?.toDouble();

  double? get _goalKg =>
      widget.goalWeightKg ?? (_stats['goal_weight'] as num?)?.toDouble();

  DateTime? get _date {
    if (widget.projectedDate != null) return widget.projectedDate;
    final s = _stats['goal_date'] as String?;
    if (s != null) return DateTime.tryParse(s);
    if (widget.weeks != null) {
      return DateTime.now().add(Duration(days: widget.weeks! * 7));
    }
    return null;
  }

  bool get _metric =>
      widget.isMetricWeight ?? context.watch<WeightUnitProvider>().isMetric;

  String _weight(double kg) =>
      _metric ? '${kg.toStringAsFixed(1)} kg' : '${(kg * 2.20462).round()} lb';

  String _pace() {
    final kg = _num('weekly_weight_change');
    if (_goal == MacroCalculatorService.GOAL_MAINTAIN || kg.abs() < 0.005) {
      return 'Hold';
    }
    final v = _metric ? kg : kg * 2.20462;
    final a = v.abs();
    final text = a.toStringAsFixed(a < 0.1 ? 2 : 1);
    return '${v < 0 ? '−' : '+'}$text ${_metric ? 'kg' : 'lb'}/wk';
  }

  static const _label = {
    MacroCalculatorService.GOAL_LOSE: 'LOSE FAT',
    MacroCalculatorService.GOAL_MAINTAIN: 'MAINTAIN',
    MacroCalculatorService.GOAL_GAIN: 'BUILD MUSCLE',
  };

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    final goal = _goal;
    final cals = _num('target_calories');
    final fmt = NumberFormat('#,###');
    final goalKg = _goalKg;
    final date = _date;
    final startKg = _startKg;
    final maintain = goal == MacroCalculatorService.GOAL_MAINTAIN;

    final bold = ObText.body(c.text, size: 16, weight: FontWeight.w600);
    final String lead;
    String target = '';
    String mid = '';
    String when = '';
    if (maintain) {
      lead = startKg != null
          ? 'cals a day to hold steady around'
          : 'cals a day to hold steady';
      if (startKg != null) target = _weight(startKg);
    } else if (goalKg != null) {
      lead = date != null ? 'cals a day to reach' : 'cals a day to work towards';
      target = _weight(goalKg);
      if (date != null) {
        mid = ' around ';
        when = DateFormat('MMM d').format(date);
      }
    } else {
      lead = 'cals a day for your plan';
    }

    final previous = widget.recalculateOnly
        ? context.read<GoalsProvider>().caloriesGoal
        : null;
    final checkinDay = widget.recalculateOnly
        ? context.read<GoalsProvider>().checkinWeekday
        : DateTime.now().weekday;
    final firstCheckIn = DateTime.now().add(const Duration(days: 7));

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _rise(0,
                       child: SizedBox(
                        height: 44,
                        child: Row(
                          children: [
                            if (widget.recalculateOnly) ...[
                              ObBackButton(
                                  onPressed: () => Navigator.of(context).maybePop()),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Text(
                                '${widget.recalculateOnly ? 'YOUR NEW PLAN' : 'YOUR PLAN'} · ${_label[goal]}',
                                overflow: TextOverflow.ellipsis,
                                style: ObText.eyebrow(c.leafText),
                              ),
                            ),
                            if (widget.onReview != null)
                              InkWell(
                                onTap: widget.onReview,
                                child: SizedBox(
                                  height: 44,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_outlined,
                                          size: 16, color: c.text2),
                                      const SizedBox(width: 6),
                                      Text('Review answers',
                                          style: ObText.body(c.text2,
                                              size: 14, weight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _rise(100,
                      
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedBuilder(
                            animation: _clock,
                            builder: (context, _) {
                              final k = _slice(0, 1400, Curves.easeOutCubic);
                              return Text(
                                fmt.format((cals * k).round()),
                                key: const Key('reveal_cals'),
                                style: ObText.display(64, color: c.text, height: 1)
                                    .copyWith(letterSpacing: -2.6),
                              );
                            },
                          ),
                          if (previous != null &&
                              previous.round() != cals.round()) ...[
                            const SizedBox(height: 4),
                            Text('Previously ${fmt.format(previous.round())} cals a day',
                                style: ObText.body(c.muted, size: 13)),
                          ],
                          const SizedBox(height: 6),
                          Text.rich(
                            key: const Key('reveal_lead'),
                            TextSpan(children: [
                              TextSpan(text: '$lead '),
                              TextSpan(text: maintain ? target.trim() : target, style: bold),
                              if (maintain && target.isNotEmpty) const TextSpan(text: ''),
                              TextSpan(text: mid),
                              TextSpan(text: when, style: bold),
                            ]),
                            style: ObText.body(c.text2, size: 16).copyWith(height: 1.45),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _rise(500, child: _macros(c)),
                    const SizedBox(height: 10),
                    _rise(900,
                      
                      child: Row(
                        children: [
                          Expanded(
                              child: _Stat(
                                  label: 'You burn',
                                  value: '≈${fmt.format(_num('tdee').round())}')),
                          const SizedBox(width: 8),
                          Expanded(child: _Stat(label: 'Pace', value: _pace())),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _Stat(
                                  label: 'Check-in',
                                  value: '${_weekday(checkinDay)}s')),
                        ],
                      ),
                    ),
                    if (startKg != null && (maintain || goalKg != null)) ...[
                      const SizedBox(height: 10),
                      _rise(1200, child: _chart(c, goal, startKg, goalKg, date)),
                    ],
                    const SizedBox(height: 12),
                    _rise(1200,
                      
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _noteLine(
                            c,
                            widget.adaptiveGoals
                                ? Icons.autorenew_rounded
                                : Icons.lock_outline_rounded,
                            AdaptiveChoiceCopy.resultLine(widget.adaptiveGoals),
                            const Key('results_adaptive_line'),
                          ),
                          if (widget.planLine case final planLine?)
                            _noteLine(c, Icons.timeline_rounded, planLine,
                                const Key('results_plan_line')),
                          const SizedBox(height: 8),
                          Text(
                            widget.results['tdee_learned'] == true
                                ? 'Based on how your body has responded so far.'
                                : widget.adaptiveGoals
                                    ? 'A starting estimate. From your first check-in on '
                                        '${DateFormat('MMM d').format(firstCheckIn)}, your logs and '
                                        'weigh-ins take over.'
                                    : 'Your targets stay the same until you change them.',
                            key: const Key('results_target_tip'),
                            style: ObText.body(c.muted, size: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: _rise(1200,
                
                child: ObPrimaryButton(
                  label: widget.recalculateOnly ? 'Save' : 'Save my plan',
                  onPressed: _showPaywallAndProceed,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fades and lifts [child] in at [startMs] on the reveal clock. Driven by
  /// the clock, not a timer, so nothing is left pending when the screen goes.
  Widget _rise(int startMs, {required Widget child}) => AnimatedBuilder(
        animation: _clock,
        child: child,
        builder: (context, child) {
          final t = _slice(startMs, 700, ObMotion.curve);
          return Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
          );
        },
      );

  /// Progress through [startMs]..[startMs] + [lengthMs] of the reveal clock.
  double _slice(int startMs, int lengthMs, Curve curve) {
    final t = (_clock.value * _total.inMilliseconds - startMs) / lengthMs;
    return curve.transform(t.clamp(0.0, 1.0));
  }

  static String _weekday(int iso) => const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ][(iso - 1) % 7];

  Widget _noteLine(ObColors c, IconData icon, String text, Key key) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text.rich(
          key: key,
          TextSpan(children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(icon, size: 15, color: c.muted),
              ),
            ),
            TextSpan(text: text),
          ]),
          style: ObText.body(c.muted, size: 13),
        ),
      );

  Widget _macros(ObColors c) {
    final p = _num('protein_g');
    final cb = _num('carb_g');
    final f = _num('fat_g');
    final kc = [p * 4, cb * 4, f * 9];
    final total = kc.reduce((a, b) => a + b);
    final maxG = [p, cb, f].reduce((a, b) => a > b ? a : b);
    final rows = [
      ('Protein', p, kc[0], c.protein, 700),
      ('Carbs', cb, kc[1], c.carbs, 850),
      ('Fat', f, kc[2], c.fat, 1000),
    ];
    return ObCard(
      padding: const EdgeInsets.all(18),
      radius: 24,
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) => Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(rows[i].$1,
                      style: ObText.body(c.text, size: 14, weight: FontWeight.w600)),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: '${rows[i].$2.round()} g',
                          style: ObText.body(c.text, size: 14, weight: FontWeight.w600)),
                      TextSpan(
                          text: ' · ${total > 0 ? (rows[i].$3 / total * 100).round() : 0}%'),
                    ]),
                    style: ObText.body(c.text2, size: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  height: 10,
                  color: c.raised,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: maxG > 0
                        ? rows[i].$2 / maxG * 0.96 * _slice(rows[i].$5, 1000, ObMotion.curve)
                        : 0,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                          color: rows[i].$4, borderRadius: BorderRadius.circular(5)),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chart(ObColors c, String goal, double startKg, double? goalKg, DateTime? date) {
    final maintain = goal == MacroCalculatorService.GOAL_MAINTAIN;
    final String endLabel;
    final String endValue;
    if (maintain) {
      endLabel = 'Healthy range';
      final band = _metric ? 1.0 : 1 / 2.20462;
      endValue = _metric
          ? '${(startKg - band).toStringAsFixed(1)}–${(startKg + band).toStringAsFixed(1)} kg'
          : '${((startKg - band) * 2.20462).round()}–${((startKg + band) * 2.20462).round()} lb';
    } else {
      endLabel = date != null ? 'Goal · ${DateFormat('MMM d').format(date)}' : 'Goal';
      endValue = _weight(goalKg!);
    }
    final description = maintain
        ? 'Weight holding steady inside a band around ${_weight(startKg)}'
        : 'Weight trending ${goal == MacroCalculatorService.GOAL_GAIN ? 'up' : 'down'} '
            'from ${_weight(startKg)} to ${_weight(goalKg!)}';
    return ObCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Today', style: ObText.body(c.text2, size: 12)),
                  const SizedBox(height: 2),
                  Text(_weight(startKg), style: ObText.title(c.text, size: 15)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(endLabel, style: ObText.body(c.text2, size: 12)),
                  const SizedBox(height: 2),
                  Text(endValue, style: ObText.title(c.leafText, size: 15)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: description,
            child: AnimatedBuilder(
              animation: _clock,
              builder: (context, _) => SizedBox(
                height: 72,
                child: CustomPaint(
                  painter: _ProjectionPainter(
                    goal: goal,
                    progress: _slice(1200, 1400, const Cubic(.4, 0, .2, 1)),
                    fade: _slice(1200, 800, Curves.easeOut),
                    line: c.leaf,
                    guide: c.line,
                    dot: c.text,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ObText.body(c.text2, size: 12)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, style: ObText.title(c.text)),
          ),
        ],
      ),
    );
  }
}

/// The projection from the mock: a 310 x 72 drawing scaled to the card's
/// width. Lose falls to a dashed goal line, gain rises to one, and maintain
/// wobbles flat inside a soft band.
class _ProjectionPainter extends CustomPainter {
  _ProjectionPainter({
    required this.goal,
    required this.progress,
    required this.fade,
    required this.line,
    required this.guide,
    required this.dot,
  });

  final String goal;
  final double progress;
  final double fade;
  final Color line;
  final Color guide;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 310;
    final sy = size.height / 72;
    canvas.scale(sx, sy);

    final path = Path();
    final Offset start;
    final Offset end;
    switch (goal) {
      case MacroCalculatorService.GOAL_GAIN:
        start = const Offset(8, 62);
        end = const Offset(300, 10);
        path
          ..moveTo(8, 62)
          ..cubicTo(110, 56, 200, 26, 300, 10);
        _dashed(canvas, 10);
      case MacroCalculatorService.GOAL_MAINTAIN:
        start = const Offset(8, 36);
        end = const Offset(300, 36);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(0, 18, 310, 36), const Radius.circular(10)),
            Paint()..color = line.withValues(alpha: 0.1 * fade));
        path
          ..moveTo(8, 36)
          ..cubicTo(40, 30, 70, 42, 110, 36)
          ..cubicTo(150, 30, 180, 30, 220, 37)
          ..cubicTo(260, 44, 280, 38, 300, 36);
      default:
        start = const Offset(8, 10);
        end = const Offset(300, 62);
        path
          ..moveTo(8, 10)
          ..cubicTo(100, 26, 190, 54, 300, 62);
        _dashed(canvas, 62);
    }

    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(start, 5, Paint()..color = dot);
    canvas.drawCircle(end, 6, Paint()..color = line);
  }

  void _dashed(Canvas canvas, double y) {
    final paint = Paint()
      ..color = guide
      ..strokeWidth = 1;
    for (double x = 0; x < 310; x += 10) {
      canvas.drawLine(Offset(x, y), Offset(x + 4, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ProjectionPainter old) =>
      old.progress != progress ||
      old.fade != fade ||
      old.goal != goal ||
      old.line != line ||
      old.guide != guide ||
      old.dot != dot;
}

/// Full-screen, skippable "How did you hear about us?" step shown after the
/// plan reveal. The page itself reports the answer to PostHog.
class AcquisitionSourceStep extends StatefulWidget {
  const AcquisitionSourceStep({super.key});

  @override
  State<AcquisitionSourceStep> createState() => _AcquisitionSourceStepState();
}

class _AcquisitionSourceStepState extends State<AcquisitionSourceStep> {
  String? _source;

  void _close({bool answered = false}) {
    if (answered && _source != null) {
      PostHogService.trackEvent('acquisition_source_answered',
          properties: {'acquisition_source': _source});
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              child: SizedBox(
                height: 44,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () => _close(),
                    child: SizedBox(
                      height: 44,
                      child: Center(
                        child: Text('Skip',
                            key: const Key('source_skip_link'),
                            style: ObText.body(c.text2, weight: FontWeight.w500)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: AcquisitionSourcePage(
                currentSource: _source,
                onSourceSelected: (source) => setState(() => _source = source),
                onSkip: () => _close(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: _source == null
                  ? Material(
                      color: c.raised,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _close(),
                        child: SizedBox(
                          height: 56,
                          child: Center(
                            child: Text('Skip',
                                key: const Key('source_cta'),
                                style: ObText.button(c.text)),
                          ),
                        ),
                      ),
                    )
                  : ObPrimaryButton(
                      label: 'Continue', onPressed: () => _close(answered: true)),
            ),
          ],
        ),
      ),
    );
  }
}
