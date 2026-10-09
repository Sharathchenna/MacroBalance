import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/services/weight_sync_service.dart';
import 'package:macrotracker/utils/weight_range.dart';
import 'package:macrotracker/utils/weight_trend.dart';
import 'package:macrotracker/widgets/app_bottom_bar.dart';
import 'package:macrotracker/widgets/progress_card.dart';
import 'package:macrotracker/widgets/weight_chart.dart';
import 'package:macrotracker/widgets/weight_range_selector.dart';
import 'package:provider/provider.dart';

import '../providers/detailed_stats_provider.dart';
import '../providers/energy_provider.dart';
import '../providers/goals_provider.dart';
import '../providers/weight_unit_provider.dart';
import '../services/energy/checkin.dart' show planTdee;
import '../services/energy/constants.dart';
import '../services/energy/energy_estimator.dart' show EnergyState;
import '../services/energy/energy_summary.dart';
import '../services/energy/phase_engine.dart' show phaseSwitchDays;
import '../services/energy/projection.dart';
import '../services/energy/trend_weight.dart';
import '../services/macro_calculator_service.dart';
import '../services/posthog_service.dart';
import '../theme/app_theme.dart';

/// Progress › Weight: where your weight is, where it's heading, and how far
/// off the goal is. Shown in kg or lbs from the unit setting; stored in kg.
///
/// "Where your weight is" means the trend weight ([TrendSeries]), not the
/// last scale reading: the headline, the pace and goal progress all use it.
///
/// Phase switches (`phaseSwitchDays`) are faint bands on the chart, and the
/// days after one are labelled as the expected water and glycogen shift
/// (spec 7.2). The trend uses the switches as the estimator does.
///
/// Two views of the same numbers ([DetailedStatsProvider]):
/// - simple (the default): "Your weight" with one plain change line and an
///   on-track pill, the goal as "3.1 of 7 kg lost" with when you'll get
///   there ([projectToGoal]), a quiet chart, and the calories you burn;
/// - detailed: the trend weight with its pace row (kg and %/week against the
///   goal pace), Start / Trend / Goal, the chart legend and why a reading
///   was ignored.
class WeightTrackingScreen extends StatefulWidget {
  final bool hideAppBar;

  /// Opens the Energy tab from the "calories you burn" card; without it the
  /// card isn't shown.
  final VoidCallback? onOpenEnergy;

  const WeightTrackingScreen({
    Key? key,
    this.hideAppBar = false,
    this.onOpenEnergy,
  }) : super(key: key);

  @override
  State<WeightTrackingScreen> createState() => _WeightTrackingScreenState();
}

class _WeightTrackingScreenState extends State<WeightTrackingScreen> {
  bool _isLoading = true;
  WeightRange _range = WeightRange.month;

  /// Stored rows (`{date, weight}` in kg), kept as-is for storage and sync.
  List<Map<String, dynamic>> _weightData = [];
  List<WeightEntry> _entries = [];
  TrendSeries _series = TrendSeries.compute(const []);

  /// Trend weight at each of [_entries].
  List<double> _trend = [];

  /// Index into the visible entries while the chart is being touched.
  int? _scrubbed;

  /// Phase switch days, and the key they were last read with.
  List<DateTime> _switches = const [];
  String? _switchesKey;

  @override
  void initState() {
    super.initState();
    PostHogService.trackScreen('weight_tracking_screen');
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWeightData());
  }

  GoalsProvider get _goals =>
      Provider.of<GoalsProvider>(context, listen: false);

  void _setHistory(List<Map<String, dynamic>> rows) {
    _weightData = rows;
    _entries = parseWeightHistory(rows);
    _series = trendSeries(_entries, switches: _switches);
    _trend = [for (final p in _series.points) p.trendKg];
  }

  /// Picks up phase changes: the trend and the bands depend on them.
  void _watchSwitches() {
    final key = context.select<EnergyProvider, String>((e) => [
          for (final d in phaseSwitchDays(e.phases)) d.toIso8601String()
        ].join(','));
    if (key == _switchesKey) return;
    _switchesKey = key;
    _switches = phaseSwitchDays(
        Provider.of<EnergyProvider>(context, listen: false).phases);
    _setHistory(_weightData);
  }

  /// Whether [day] is in the water and glycogen days after a switch.
  bool _settling(DateTime day) => settlingAfterSwitch(day, _switches) != null;

  bool _ignored(int i) => _series.points[i].ignored;

  /// The last scale reading.
  double get _latestKg =>
      _entries.isNotEmpty ? _entries.last.kg : _goals.currentWeightKg;

  /// The trend weight now.
  double get _trendKg => _trend.isNotEmpty ? _trend.last : _latestKg;

  /// Weigh-ins the trend used, for the rate behind the goal projection.
  List<WeightEntry> get _usedEntries => [
        for (var i = 0; i < _entries.length; i++)
          if (!_ignored(i)) _entries[i],
      ];

  double? get _goalKg => _goals.goalWeightKg > 0 ? _goals.goalWeightKg : null;

  Future<void> _loadWeightData() async {
    var rows = <Map<String, dynamic>>[];
    final stored = StorageService().get('weight_history');
    if (stored is String && stored.isNotEmpty) {
      try {
        rows = List<Map<String, dynamic>>.from(
            (json.decode(stored) as List).map((e) => Map<String, dynamic>.from(e as Map)));
      } catch (e) {
        debugPrint('Error decoding weight history: $e');
      }
    }
    // First visit: start the history from the weight given at onboarding.
    final profileKg = _goals.currentWeightKg;
    if (rows.isEmpty && profileKg > 0) {
      rows.add({'date': DateTime.now().toIso8601String(), 'weight': profileKg});
      StorageService().put('weight_history', json.encode(rows));
    }
    if (!mounted) return;
    setState(() {
      _setHistory(rows);
      _isLoading = false;
    });
    _syncProfileWeight();
    await _mergeWeightHistoryWithCloud();
  }

  /// Brings back history from the cloud (after a reinstall or from another
  /// device) and uploads anything this device hasn't sent yet.
  Future<void> _mergeWeightHistoryWithCloud() async {
    final merged = await WeightSyncService()
        .mergeWithCloud(List<Map<String, dynamic>>.from(_weightData));
    if (merged == null || !mounted) return;
    setState(() => _setHistory(merged));
    StorageService().put('weight_history', json.encode(_weightData));
    _syncProfileWeight();
    _refreshEnergy();
  }

  /// The expenditure estimate reads the stored weight history.
  void _refreshEnergy() =>
      Provider.of<EnergyProvider>(context, listen: false).scheduleRefresh();

  /// The profile's current weight follows the latest weigh-in.
  void _syncProfileWeight() {
    if (_entries.isEmpty) return;
    if (_goals.currentWeightKg != _entries.last.kg) {
      _goals.currentWeightKg = _entries.last.kg;
    }
  }

  // --- Formatting -----------------------------------------------------------

  WeightUnitProvider get _units =>
      Provider.of<WeightUnitProvider>(context, listen: false);

  String _fmt(double kg, {bool signed = false}) {
    final v = _units.convertFromKg(kg);
    final text = v.abs().toStringAsFixed(1);
    final sign = !signed || text == '0.0' ? '' : (v > 0 ? '+' : '−');
    return '$sign$text ${_units.unitLabel}';
  }

  /// Colour for a change: green toward the goal, otherwise neutral. Moving
  /// away from the goal is information, not failure, so it's never amber or
  /// red.
  Color _changeColor(double deltaKg, CustomColors colors) {
    final goal = _goalKg;
    if (goal == null || deltaKg.abs() < 0.05 || _entries.isEmpty) {
      return colors.textPrimary;
    }
    final wantDown = goal < _trendKg;
    final towardGoal = wantDown ? deltaKg < 0 : deltaKg > 0;
    return towardGoal ? colors.accentPrimary : colors.textPrimary;
  }

  /// A percentage with a real minus sign, trailing zeros dropped (−0.5, 0.25).
  static String _pct(double value, {bool signed = true}) {
    var text = value.abs().toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
    if (text == '0' || !signed) return text;
    return value < 0 ? '−$text' : '+$text';
  }

  /// "Sep 7", or "Sep 7, 2025" when it isn't this year.
  String _day(DateTime d) => d.year == DateTime.now().year
      ? DateFormat.MMMd().format(d)
      : DateFormat.yMMMd().format(d);

  // --- Range ----------------------------------------------------------------

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _rangeStart {
    final start = _range.start(DateTime.now());
    if (start != null) return start;
    return _entries.isNotEmpty
        ? _entries.first.day
        : DateTime(_today.year, _today.month - 1, _today.day);
  }

  String get _rangePhrase {
    switch (_range) {
      case WeightRange.week:
        return 'past week';
      case WeightRange.month:
        return 'past month';
      case WeightRange.threeMonths:
        return 'past 3 months';
      case WeightRange.sixMonths:
        return 'past 6 months';
      case WeightRange.year:
        return 'past year';
      case WeightRange.all:
        return _entries.isEmpty
            ? 'overall'
            : 'since ${DateFormat.yMMM().format(_entries.first.date)}';
    }
  }

  // --- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<CustomColors>()!;
    // Rebuild on unit and goal changes.
    context.watch<WeightUnitProvider>();
    context.select<GoalsProvider, double>((p) => p.goalWeightKg);
    final detailed = context.watch<DetailedStatsProvider>().showDetailedStats;
    _watchSwitches();

    final Widget body = _isLoading
        ? Center(child: CupertinoActivityIndicator(color: colors.textSecondary))
        : RefreshIndicator(
            onRefresh: _mergeWeightHistoryWithCloud,
            color: colors.accentPrimary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(
                  16, 16, 16, AppBottomBar.scrollClearance),
              children: [
                if (detailed) _buildSummary(colors) else _buildHeadline(colors),
                const SizedBox(height: 16),
                if (detailed) _buildGoalCard(colors) else _buildJourney(colors),
                const SizedBox(height: 16),
                _buildChartCard(colors, detailed: detailed),
                if (widget.onOpenEnergy != null) ...[
                  const SizedBox(height: 16),
                  _BurnCard(onTap: widget.onOpenEnergy!),
                ],
              ],
            ),
          );

    if (widget.hideAppBar) return body;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Weight',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: theme.brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: SafeArea(child: body),
    );
  }

  // --- Simple view ----------------------------------------------------------

  bool get _maintaining =>
      context.read<GoalsProvider>().goalType == MacroCalculatorService.GOAL_MAINTAIN;

  /// How the last week went against the plan; null under a week of
  /// weigh-ins. Uses the same pace test as the detailed pace row.
  _Pace? _pace() {
    final goals = context.watch<GoalsProvider>();
    final goalPct = signedGoalPacePct(
        MacroCalculatorService.goalKindOf(goals.goalType),
        goals.pacePctPerWeek);
    final change = _series.weeklyChange();
    if (change == null) return null;
    final onPace =
        isOnPace(actualPctPerWeek: change.pct, goalPctPerWeek: goalPct);
    if (goalPct == 0) {
      return onPace
          ? _Pace.steady
          : (change.kg > 0 ? _Pace.driftingUp : _Pace.driftingDown);
    }
    if (onPace) return _Pace.onTrack;
    final faster = goalPct < 0 ? change.pct < goalPct : change.pct > goalPct;
    return faster ? _Pace.faster : _Pace.slower;
  }

  /// "↓ 1.2 kg in the last 4 weeks" (up to four whole weeks of weigh-ins),
  /// or "Steady over …"; null under a week.
  String? _recentChange(_Pace? pace) {
    if (_entries.isEmpty) return null;
    final weeks = math.min(4, _today.difference(_entries.first.day).inDays ~/ 7);
    if (weeks < 1) return null;
    final then = _series.trendOn(
        DateTime(_today.year, _today.month, _today.day - 7 * weeks));
    if (then == null) return null;
    final delta = _trendKg - then;
    final window = weeks == 1 ? 'the last week' : 'the last $weeks weeks';
    final shown = _units.convertFromKg(delta.abs()).toStringAsFixed(1);
    if (shown == '0.0' || pace == _Pace.steady) return 'Steady over $window';
    return '${delta < 0 ? '↓' : '↑'} $shown ${_units.unitLabel} in $window';
  }

  /// A weight in the unit shown without a needless ".0": "7", "62.9".
  String _number(double kg) {
    final v = _units.convertFromKg(kg);
    return (v - v.round()).abs() < 0.05 ? '${v.round()}' : v.toStringAsFixed(1);
  }

  /// [_number] with the unit: "7 kg".
  String _amount(double kg) => '${_number(kg)} ${_units.unitLabel}';

  /// Simple headline: the trend as "Your weight", today's reading under it,
  /// then the recent change and an on-track pill.
  Widget _buildHeadline(CustomColors colors) {
    final latest = _entries.isNotEmpty ? _entries.last : null;
    final pace = _pace();
    final change = _recentChange(pace);
    final number = _units.convertFromKg(_trendKg).toStringAsFixed(1);
    final quiet = GoogleFonts.inter(fontSize: 14, color: colors.textSecondary);

    return ProgressCard(
      key: const Key('weight_headline'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your weight',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary)),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: _trendKg > 0 ? number : '—',
                          style: GoogleFonts.inter(
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1,
                            color: colors.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: ' ${_units.unitLabel}',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                          ),
                        ),
                      ]),
                    ),
                    if (latest != null && latest.day == _today) ...[
                      const SizedBox(height: 2),
                      Text('Today ${_fmt(latest.kg)}',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: colors.textSecondary)),
                    ],
                  ],
                ),
              ),
              _LogButton(onTap: () => _logWeight(colors)),
            ],
          ),
          const SizedBox(height: 18),
          if (latest == null)
            Text('Tap Log to add your first weigh-in.', style: quiet)
          else if (change == null)
            Text('Keep weighing in. Your progress shows after a week.',
                style: quiet)
          else
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  change,
                  key: const Key('weight_recent_change'),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                if (pace != null) _PacePill(pace),
              ],
            ),
        ],
      ),
    );
  }

  /// Simple goal card: how far along you are ("3.1 of 7 kg lost") and when
  /// the plan gets you there; maintaining is "Holding steady around 70 kg".
  Widget _buildJourney(CustomColors colors) {
    final goals = context.watch<GoalsProvider>();
    final energy = context.watch<EnergyProvider>();
    final goal = _goalKg;
    final pace = _pace();
    final big = GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: colors.textPrimary);
    final quiet = GoogleFonts.inter(
        fontSize: 14, height: 1.45, color: colors.textSecondary);
    final children = <Widget>[];

    if (_maintaining) {
      final drifting =
          pace == _Pace.driftingUp || pace == _Pace.driftingDown;
      // Around where you are: a maintain goal's stored goal weight is often
      // left over from an earlier lose or gain goal.
      final unit = _units.convertFromKg(_trendKg).round();
      children.addAll([
        Text(
          drifting
              ? 'Aiming to stay around $unit ${_units.unitLabel}'
              : 'Holding steady around $unit ${_units.unitLabel}',
          style: big,
        ),
        const SizedBox(height: 8),
        Text(
            _units.isMetric
                ? 'Ups and downs of a kilo or two are normal.'
                : 'Ups and downs of a few pounds are normal.',
            style: quiet),
      ]);
    } else if (goal == null || _entries.isEmpty) {
      children.add(Text(
        goal == null
            ? 'Set a goal weight to see how far you\'ve come and when '
                'you\'ll get there.'
            : 'Log your weight to see how far you\'ve come.',
        style: quiet,
      ));
    } else {
      final startKg = _trend.first;
      final total = (goal - startKg).abs();
      final doneKg = total < 0.05
          ? total
          : ((goal - startKg).sign * (_trendKg - startKg)).clamp(0.0, total);
      final reached = (goal - _trendKg).abs() < 0.25 || doneKg >= total;
      final verb = goal < startKg ? 'lost' : 'gained';
      if (reached) {
        children.addAll([
          Text('You reached ${_amount(goal)}!', style: big),
          const SizedBox(height: 14),
          _GoalBar(progress: 1, colors: colors, height: 10),
          const SizedBox(height: 14),
          Text('Nice work. Keep logging to stay there.', style: quiet),
        ]);
      } else {
        final when = _projection(goals, energy, goal, pace);
        children.addAll([
          Text(
            _units.convertFromKg(doneKg) < 0.05
                ? '${_amount(total)} to go'
                : '${_number(doneKg)} of ${_amount(total)} $verb',
            key: const Key('weight_goal_progress'),
            style: big,
          ),
          const SizedBox(height: 14),
          _GoalBar(
              progress: total == 0 ? 1 : doneKg / total,
              colors: colors,
              height: 10),
          if (when != null) ...[
            const SizedBox(height: 14),
            Text(when, key: const Key('weight_goal_when'), style: quiet),
          ],
        ]);
      }
    }

    return ProgressCard(
      key: const Key('weight_journey'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProgressCardTitle('Your goal', trailing: _goalButton(colors)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  /// "On track to reach 65 kg around mid-Dec", from the plan's projection
  /// (the same one as every "about N weeks" in the app).
  String? _projection(GoalsProvider goals, EnergyProvider energy, double goal,
      _Pace? pace) {
    final settings = goals.checkinSettings;
    final projection = projectToGoal(
      goal: settings.goal,
      weightKg: _trendKg,
      goalWeightKg: goal,
      tdee: planTdee(
          settings: settings, latest: energy.latest, weightKg: _trendKg),
      pacePct: math.max(settings.pacePct, 0.0),
      body: settings.body,
      on: _today,
      adaptive: settings.adaptive,
      cals: goals.caloriesGoal,
      style: goals.planStyle,
      phase: energy.currentPhase,
      phaseSettings: goals.phaseSettings,
    );
    final weeks = projection.weeks, date = projection.date;
    if (weeks == null || date == null || weeks == 0) return null;
    final reach = 'reach ${_amount(goal)} ${roughDate(date, weeks, _today)}';
    return switch (pace) {
      _Pace.onTrack => 'On track to $reach.',
      _Pace.faster => 'Your plan aims to $reach.',
      null => 'Your plan gets you there ${roughDate(date, weeks, _today)}.',
      _ => 'Stick with your plan to $reach.',
    };
  }

  Widget _goalButton(CustomColors colors) => TextButton(
        onPressed: () => _editGoal(colors),
        style: TextButton.styleFrom(
          foregroundColor: colors.accentPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(_goalKg == null ? 'Set goal' : 'Edit',
            style:
                GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
      );

  // --- Detailed view --------------------------------------------------------

  Widget _buildSummary(CustomColors colors) {
    final hasEntries = _entries.isNotEmpty;
    final latest = hasEntries ? _entries.last : null;

    String scale() {
      if (latest == null) return 'No weigh-ins yet';
      final days = _today.difference(latest.day).inDays;
      final when = days == 0
          ? 'today'
          : days == 1
              ? 'yesterday'
              : days < 7
                  ? DateFormat.EEEE().format(latest.date)
                  : _day(latest.date);
      return 'Scale ${_fmt(latest.kg)} · $when';
    }

    final number = _units.convertFromKg(_trendKg).toStringAsFixed(1);

    return ProgressCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Trend weight',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: colors.textSecondary),
                        ),
                        // Full-size tap target without pushing the
                        // number down.
                        const SizedBox(
                          width: 30,
                          height: 16,
                          child: OverflowBox(
                            maxWidth: 30,
                            maxHeight: 30,
                            child: InfoButton(_trendInfo),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: _trendKg > 0 ? number : '—',
                          style: GoogleFonts.inter(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                            color: colors.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: ' ${_units.unitLabel}',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      scale(),
                      style: GoogleFonts.inter(
                          fontSize: 13, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              _LogButton(onTap: () => _logWeight(colors)),
            ],
          ),
          if (hasEntries) ...[
            const SizedBox(height: 16),
            _buildPaceRow(colors),
          ],
        ],
      ),
    );
  }

  static const _trendInfo = ProgressInfo('Trend weight', [
    InfoSection(
      'Your weight swings a kilo or two from day to day with water, salt and '
      'food in your stomach. The trend smooths those swings out: each '
      'weigh-in moves it a tenth of the way toward the scale, so it shows '
      'where your weight is really heading.',
    ),
    InfoSection(
      'A reading more than 3% away from the trend is usually a slip, like '
      'weighing in clothes or a typo, so it\'s left out and drawn as a grey '
      'ring. Three in a row on the same side are a real change, and the '
      'trend follows them.',
      heading: 'Ignored readings',
    ),
    InfoSection(
      'Your pace is how much the trend moved over the last week. It reads as '
      'on pace within 0.15% a week of your goal pace.',
      heading: 'Pace',
    ),
  ]);

  /// "−0.3 kg/wk (−0.4%) · Goal −0.5%/wk". Neutral within
  /// [kPaceTolerancePct] of the goal pace, a soft accent otherwise; never red.
  Widget _buildPaceRow(CustomColors colors) {
    final goals = context.watch<GoalsProvider>();
    final goalPct = signedGoalPacePct(
        MacroCalculatorService.goalKindOf(goals.goalType),
        goals.pacePctPerWeek);
    final change = _series.weeklyChange();
    final onPace = change == null ||
        isOnPace(actualPctPerWeek: change.pct, goalPctPerWeek: goalPct);
    final emphasis = onPace ? colors.textPrimary : colors.accentPrimary;
    final quiet = onPace ? colors.textSecondary : colors.accentPrimary;

    return Container(
      key: const Key('weight_pace_row'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: onPace
            ? colors.textSecondary.withValues(alpha: 0.08)
            : colors.accentPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: change == null
          ? Text(
              'Your weekly pace shows after a week of weigh-ins',
              style: GoogleFonts.inter(fontSize: 13, color: quiet),
            )
          : Row(
              children: [
                Icon(
                  change.kg.abs() < 0.05
                      ? Icons.trending_flat_rounded
                      : change.kg < 0
                          ? Icons.trending_down_rounded
                          : Icons.trending_up_rounded,
                  size: 18,
                  color: emphasis,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_fmt(change.kg, signed: true)}/wk '
                      '(${_pct(double.parse(change.pct.toStringAsFixed(1)))}%)',
                      maxLines: 1,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: emphasis,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  goalPct == 0
                      ? 'Goal: hold steady'
                      : 'Goal ${_pct(goalPct)}%/wk',
                  style: GoogleFonts.inter(fontSize: 13, color: quiet),
                ),
              ],
            ),
    );
  }

  Widget _buildChartCard(CustomColors colors, {required bool detailed}) {
    final now = DateTime.now();
    final inRange = <WeightEntry>[];
    final trendInRange = <double>[];
    final ignoredInRange = <bool>[];
    for (var i = 0; i < _entries.length; i++) {
      if (_range.includes(_entries[i].date, now)) {
        inRange.add(_entries[i]);
        trendInRange.add(_trend[i]);
        ignoredInRange.add(_ignored(i));
      }
    }
    // Switches whose band reaches into the range.
    final rangeStart = _rangeStart;
    final switches = [
      for (final d in _switches)
        if (!DateTime(d.year, d.month, d.day + kSwitchExpectedDays)
            .isBefore(DateTime(rangeStart.year, rangeStart.month, rangeStart.day + 1)))
          d,
    ];
    final scrubbed =
        _scrubbed != null && _scrubbed! < inRange.length ? _scrubbed : null;
    final showsTrend = WeightChart.showsTrend(inRange);
    // "in the past week", or "so far" for All.
    final within =
        _range == WeightRange.all ? 'so far' : 'in the $_rangePhrase';

    Widget header;
    if (!detailed) {
      header = _simpleChartHeader(colors,
          scrubbed == null ? null : inRange[scrubbed],
          ignored: scrubbed != null && ignoredInRange[scrubbed]);
    } else if (scrubbed != null) {
      final e = inRange[scrubbed];
      header = ChartHeader(
        value: _fmt(e.kg),
        detail: ignoredInRange[scrubbed]
            ? '${_day(e.date)} · ignored for trend'
            : _settling(e.date)
            ? '${_day(e.date)} · expected water & glycogen'
            : showsTrend
                ? '${_day(e.date)} · trend ${_fmt(trendInRange[scrubbed])}'
                : '${_day(e.date)} · tap to edit',
      );
    } else if (inRange.length >= 2) {
      // How far the trend moved, so one light morning doesn't count.
      final delta = trendInRange.last - trendInRange.first;
      header = ChartHeader(
        value: _fmt(delta, signed: true),
        valueColor: _changeColor(delta, colors),
        detail: _range == WeightRange.all
            ? 'trend $_rangePhrase'
            : 'trend over the $_rangePhrase',
      );
    } else {
      header = ChartHeader(
        value: inRange.isEmpty ? 'No weigh-ins' : _fmt(inRange.first.kg),
        detail: inRange.isEmpty ? within : 'one weigh-in $within',
      );
    }

    return ProgressCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detailed)
            ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52), child: header)
          else
            header,
          SizedBox(height: detailed ? 12 : 14),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: WeightRangeSelector(
              selected: _range,
              onChanged: (r) {
                HapticFeedback.selectionClick();
                setState(() {
                  _range = r;
                  _scrubbed = null;
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: Stack(
              children: [
                Positioned.fill(
                  child: WeightChart(
                    entries: inRange,
                    trend: trendInRange,
                    start: _rangeStart,
                    end: _today,
                    isMetric: _units.isMetric,
                    // Simple view: no goal line when maintaining (the stored
                    // goal weight is often left from an earlier goal).
                    goalKg: !detailed && _maintaining ? null : _goalKg,
                    ignored: ignoredInRange,
                    switches: switches,
                    simple: !detailed,
                    colors: colors,
                    onScrub: (i) => setState(() => _scrubbed = i),
                    onTapEntry: (i) => _editEntry(inRange[i], colors,
                        offTrendKg: ignoredInRange[i]
                            ? inRange[i].kg - trendInRange[i]
                            : null,
                        settling: _settling(inRange[i].date),
                        detailed: detailed),
                  ),
                ),
                if (inRange.isEmpty)
                  Center(
                    child: Text(
                      _range == WeightRange.all
                          ? 'No weight logged yet'
                          : 'No weight logged $within',
                      style: GoogleFonts.inter(
                          fontSize: 14, color: colors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          if (detailed) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              LegendItem(
                  swatch: LegendDot(color: colors.accentPrimary, ring: true),
                  label: 'Weigh-ins'),
              if (showsTrend)
                LegendItem(
                    swatch: LegendLine(color: colors.accentPrimary),
                    label: 'Trend'),
              if (ignoredInRange.contains(true))
                LegendItem(
                    swatch: LegendDot(color: colors.textSecondary, ring: true),
                    label: 'Ignored'),
              if (WeightChart.showsGoal(inRange, trendInRange, _goalKg))
                LegendItem(
                    swatch:
                        LegendLine(color: colors.textSecondary, dashed: true),
                    label: 'Goal'),
              if (switches.isNotEmpty)
                LegendItem(
                    swatch: LegendBand(color: colors.textSecondary),
                    label: 'Phase change'),
            ],
          ),
          ],
          if (_settling(_today)) ...[
            const SizedBox(height: 10),
            Row(
              key: const Key('weight_settling_note'),
              children: [
                Icon(Icons.water_drop_outlined,
                    size: 15, color: colors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    detailed
                        ? 'Expected: water & glycogen after your phase change'
                        : _waterNote,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Glossary copy for the days after a phase change.
  static const _waterNote = 'Weight often jumps for a few days after a '
      'change. That\'s water, not fat.';

  /// Simple chart header: "Your journey", or the touched weigh-in.
  Widget _simpleChartHeader(CustomColors colors, WeightEntry? touched,
      {required bool ignored}) {
    if (touched == null) {
      return const SizedBox(height: 24, child: ProgressCardTitle('Your journey'));
    }
    final note = ignored
        ? ' · looked unusual'
        : _settling(touched.date)
            ? ' · likely water'
            : '';
    return SizedBox(
      height: 24,
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: _fmt(touched.kg),
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          TextSpan(
            text: '  ${_day(touched.date)}$note',
            style: GoogleFonts.inter(fontSize: 14, color: colors.textSecondary),
          ),
        ]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildGoalCard(CustomColors colors) {
    final goal = _goalKg;
    final editButton = _goalButton(colors);

    if (goal == null || _entries.isEmpty) {
      return ProgressCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProgressCardTitle('Goal weight', trailing: editButton),
            const SizedBox(height: 6),
            Text(
              'Set a goal weight to see how far you have left and when you\'re '
              'likely to get there.',
              style: GoogleFonts.inter(
                  fontSize: 14, height: 1.4, color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    // Progress is on the trend, which starts at the first weigh-in.
    final startKg = _trend.first;
    final nowKg = _trendKg;
    final total = (goal - startKg).abs();
    final done = total < 0.05
        ? 1.0
        : ((goal - startKg).sign * (nowKg - startKg) / total).clamp(0.0, 1.0);
    final left = (goal - nowKg).abs();
    final reached = left < 0.25 || done >= 1.0;

    final weekly = weeklyRateKg(recentForRate(_usedEntries, _today));
    final eta = projectedGoalDate(
        currentKg: nowKg, goalKg: goal, weeklyKg: weekly, from: _today);

    String outlook;
    if (reached) {
      outlook = 'You\'re at your goal. Keep logging to hold it there.';
    } else if (weekly == null) {
      outlook = 'Weigh in over at least a week to see when you\'re likely to '
          'reach it.';
    } else if (eta != null) {
      final weeks = (eta.difference(_today).inDays / 7).round();
      final when = eta.year == _today.year
          ? DateFormat.MMMd().format(eta)
          : DateFormat.yMMMd().format(eta);
      outlook = 'At your current pace you\'ll get there around $when'
          '${weeks >= 2 ? ' (about $weeks weeks)' : ''}.';
    } else if ((goal - nowKg).sign != weekly.sign && weekly.abs() >= 0.05) {
      outlook = 'Your trend is moving away from your goal right now.';
    } else {
      outlook = 'Your weight is holding steady. At this pace it\'ll be a while.';
    }

    return ProgressCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProgressCardTitle('Goal weight', trailing: editButton),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: ProgressStat(label: 'Start', value: _fmt(startKg))),
              Expanded(child: ProgressStat(label: 'Trend', value: _fmt(nowKg))),
              Expanded(child: ProgressStat(label: 'Goal', value: _fmt(goal))),
            ],
          ),
          const SizedBox(height: 14),
          _GoalBar(progress: done.toDouble(), colors: colors),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                reached ? 'Goal reached' : '${_fmt(left)} to go',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${(done * 100).round()}%',
                style: GoogleFonts.inter(
                    fontSize: 13, color: colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            outlook,
            style: GoogleFonts.inter(
                fontSize: 14, height: 1.4, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  // --- Editing --------------------------------------------------------------

  Future<void> _logWeight(CustomColors colors) async {
    HapticFeedback.lightImpact();
    final result = await showDialog<(DateTime, double)>(
      context: context,
      builder: (_) => _WeightDialog(
        title: 'Log weight',
        initialKg: _latestKg > 0 ? _latestKg : null,
        withDate: true,
      ),
    );
    if (result == null || !mounted) return;
    final (date, kg) = result;
    final previousKg = _latestKg;
    _saveDay(date, kg);
    PostHogService.trackWeightEntry(
      weight: double.parse(_units.convertFromKg(kg).toStringAsFixed(1)),
      unit: _units.unitLabel,
      properties: {
        'weight_kg': kg,
        'date': date.toIso8601String(),
        'previous_weight_kg': previousKg,
      },
    );
  }

  /// Rows other than [date]'s day.
  List<Map<String, dynamic>> _withoutDay(DateTime date) {
    final day = WeightSyncService.dayKey(date);
    return [
      for (final row in _weightData)
        if (WeightSyncService.dayKey(DateTime.parse(row['date'] as String)) != day)
          row,
    ];
  }

  void _storeHistory(List<Map<String, dynamic>> rows) {
    rows.sort((a, b) => DateTime.parse(a['date'] as String)
        .compareTo(DateTime.parse(b['date'] as String)));
    setState(() {
      _setHistory(rows);
      _scrubbed = null;
    });
    StorageService().put('weight_history', json.encode(_weightData));
    _syncProfileWeight();
    _refreshEnergy();
  }

  /// Sets [date]'s weight, replacing any weigh-in that day.
  void _saveDay(DateTime date, double kg) {
    _storeHistory(
        [..._withoutDay(date), {'date': date.toIso8601String(), 'weight': kg}]);
    WeightSyncService().upsertDay(date, kg);
  }

  /// Tapped weigh-in: change its weight or delete it. For a reading the
  /// trend left out, [offTrendKg] (scale minus trend) explains why; one in
  /// the days after a phase switch ([settling]) says the shift is expected.
  /// In the simple view the explanations are the glossary's plain ones.
  Future<void> _editEntry(WeightEntry entry, CustomColors colors,
      {double? offTrendKg, bool settling = false, bool detailed = true}) async {
    HapticFeedback.lightImpact();
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        title: Text('${_fmt(entry.kg)} · ${_day(entry.date)}'),
        message: !detailed
            ? (offTrendKg != null
                ? const Text('This one looked unusual, so it counts less.')
                : settling
                    ? const Text(_waterNote)
                    : null)
            : offTrendKg == null
            ? (settling
                ? Text('Expected: water & glycogen after your phase change. '
                    'The scale often moves '
                    '${_units.isMetric ? '0.5–1.5 kg' : '1–3 lbs'} in the '
                    'first days of a new phase. That\'s not fat, and the '
                    'trend settles within about $kSwitchExpectedDays days.')
                : null)
            : Text(
                'Ignored for trend: ${_fmt(offTrendKg.abs())} '
                '${offTrendKg > 0 ? 'over' : 'under'} your trend. Readings '
                'more than ${(kOutlierPct * 100).round()}% off are usually '
                'water, clothes or a typo. If it was real, the next few '
                'weigh-ins will bring the trend along.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheet, 'edit'),
            child: const Text('Edit weight'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(sheet, 'delete'),
            child: const Text('Delete weigh-in'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheet),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'delete') {
      _storeHistory(_withoutDay(entry.date));
      WeightSyncService().deleteDay(entry.date);
      PostHogService.trackEvent('weight_entry_deleted');
      return;
    }
    final result = await showDialog<(DateTime, double)>(
      context: context,
      builder: (_) => _WeightDialog(
        title: 'Edit weight',
        initialKg: entry.kg,
        withDate: false,
      ),
    );
    if (result == null || !mounted) return;
    _saveDay(entry.date, result.$2);
  }

  Future<void> _editGoal(CustomColors colors) async {
    HapticFeedback.lightImpact();
    final result = await showDialog<(DateTime, double)>(
      context: context,
      builder: (_) => _WeightDialog(
        title: 'Goal weight',
        initialKg: _goalKg ?? (_latestKg > 0 ? _latestKg : null),
        withDate: false,
      ),
    );
    if (result == null || !mounted) return;
    _goals.goalWeightKg = result.$2;
    setState(() {});
  }
}

/// When, roughly, for a goal [weeks] away on [date]: "within a week", "in a
/// few weeks", "around mid-Dec" or, further out, "around March" (with the
/// year when it isn't [today]'s).
String roughDate(DateTime date, double weeks, DateTime today) {
  if (weeks <= 1.5) return 'within a week';
  if (weeks <= 4.5) return 'in a few weeks';
  if (weeks <= 17) {
    final month = DateFormat.MMM().format(date);
    final part = date.day <= 10
        ? 'early $month'
        : date.day <= 20
            ? 'mid-$month'
            : 'late $month';
    return 'around $part';
  }
  final month = DateFormat.MMMM().format(date);
  return date.year == today.year ? 'around $month' : 'around $month ${date.year}';
}

/// How the last week went against the plan, for the simple view's pill.
enum _Pace {
  onTrack('On track'),
  slower('A bit slower than planned'),
  faster('Faster than planned'),
  steady('Holding steady'),
  driftingUp('Drifting up a little'),
  driftingDown('Drifting down a little');

  const _Pace(this.label);

  final String label;

  /// On track (or holding steady) is the good news, in the accent; the rest
  /// are information, in grey. Never red.
  bool get good => this == onTrack || this == steady;
}

class _PacePill extends StatelessWidget {
  const _PacePill(this.pace);

  final _Pace pace;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    return Container(
      key: const Key('weight_pace_pill'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: pace.good
            ? colors.accentPrimary.withValues(alpha: 0.14)
            : colors.textSecondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        pace.label,
        style: GoogleFonts.inter(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: pace.good ? colors.accentPrimary : colors.textSecondary,
        ),
      ),
    );
  }
}

/// The calories you burn, in one line, opening the Energy tab: "You burn
/// about 2,430 cals a day", or "Getting to know you · day 5 of 14" while the
/// estimate is still learning.
class _BurnCard extends StatelessWidget {
  const _BurnCard({required this.onTap});

  final VoidCallback onTap;

  /// The nominal length of "getting to know you".
  static const _learningDays = 14;

  static final _cals = NumberFormat.decimalPattern();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    final goals = context.watch<GoalsProvider>();
    final energy = context.watch<EnergyProvider>();
    final summary = EnergySummary.from(
      estimates: energy.estimates,
      learningStartedOn: goals.learningStartedOn,
      formulaTdee: goals.formulaTdee ?? goals.tdee,
    );

    final String title;
    String? detail;
    Widget leading;
    if (summary.state == EnergyState.learning) {
      final start = goals.learningStartedOn;
      final now = DateTime.now();
      final day = start == null
          ? null
          : DateTime(now.year, now.month, now.day)
                  .difference(DateTime(start.year, start.month, start.day))
                  .inDays +
              1;
      title = 'Getting to know you';
      detail = day == null || day > _learningDays
          ? 'Keep logging food and weighing in'
          : 'Day $day of $_learningDays · log food and weigh in';
      leading = SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          value: day == null ? 0 : math.min(day / _learningDays, 1.0),
          strokeWidth: 3,
          strokeCap: StrokeCap.round,
          color: colors.accentPrimary,
          backgroundColor: colors.accentPrimary.withValues(alpha: 0.18),
        ),
      );
    } else {
      title = 'You burn about '
          '${_cals.format(roundToTen(summary.tdee))} cals a day';
      detail = switch (summary.state) {
        EnergyState.paused => 'Log a few days to keep this up to date',
        EnergyState.estimated => 'This gets more accurate each week',
        _ => null,
      };
      leading = Icon(Icons.local_fire_department_rounded,
          size: 22, color: colors.accentPrimary);
    }

    return Semantics(
      button: true,
      child: GestureDetector(
        key: const Key('weight_burn_card'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: ProgressCard(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.accentPrimary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: leading,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: GoogleFonts.inter(
                            fontSize: 13, color: colors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 22, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogButton extends StatelessWidget {
  const _LogButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    return Material(
      color: colors.accentPrimary.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 18, color: colors.accentPrimary),
              const SizedBox(width: 4),
              Text(
                'Log',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.accentPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalBar extends StatelessWidget {
  const _GoalBar({required this.progress, required this.colors, this.height = 8});

  final double progress;
  final CustomColors colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: ColoredBox(
          color: colors.textSecondary.withOpacity(0.15),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: v,
                heightFactor: 1,
                child: ColoredBox(color: colors.accentPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks for a weight in the user's unit (and optionally a date); pops
/// `(date, kg)`.
class _WeightDialog extends StatefulWidget {
  const _WeightDialog({
    required this.title,
    required this.initialKg,
    required this.withDate,
  });

  final String title;
  final double? initialKg;
  final bool withDate;

  @override
  State<_WeightDialog> createState() => _WeightDialogState();
}

class _WeightDialogState extends State<_WeightDialog> {
  late final WeightUnitProvider _units = context.read<WeightUnitProvider>();
  late final TextEditingController _text = TextEditingController(
    text: widget.initialKg == null
        ? ''
        : _units.convertFromKg(widget.initialKg!).toStringAsFixed(1),
  );
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(_text.text.trim().replaceAll(',', '.'));
    final kg = value == null ? null : _units.convertToKg(value);
    if (kg == null || kg < 20 || kg > 400) {
      final lo = _units.convertFromKg(20).round();
      final hi = _units.convertFromKg(400).round();
      setState(() => _error = 'Enter a weight between $lo and $hi ${_units.unitLabel}');
      return;
    }
    Navigator.pop(context, (_date, kg));
  }

  void _pickDate(CustomColors colors) {
    showCupertinoModalPopup(
      context: context,
      builder: (popup) => Container(
        height: 260,
        color: colors.cardBackground,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                child: Text('Done', style: TextStyle(color: colors.accentPrimary)),
                onPressed: () => Navigator.of(popup).pop(),
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _date,
                maximumDate: DateTime.now(),
                minimumDate: DateTime(2000),
                backgroundColor: colors.cardBackground,
                onDateTimeChanged: (d) {
                  final now = DateTime.now();
                  // Keep the time of day for today so it sorts after earlier
                  // weigh-ins; past days just need the date.
                  setState(() => _date = DateUtils.isSameDay(d, now)
                      ? now
                      : DateTime(d.year, d.month, d.day, 12));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    final today = DateUtils.isSameDay(_date, DateTime.now());
    return AlertDialog(
      backgroundColor: colors.cardBackground,
      title: Text(
        widget.title,
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _text,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            style: GoogleFonts.inter(fontSize: 18, color: colors.textPrimary),
            onSubmitted: (_) => _save(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              hintText: 'Weight',
              suffixText: _units.unitLabel,
              errorText: _error,
              errorMaxLines: 2,
            ),
          ),
          if (widget.withDate) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Date',
                    style: GoogleFonts.inter(
                        fontSize: 15, color: colors.textSecondary)),
                const Spacer(),
                TextButton(
                  onPressed: () => _pickDate(colors),
                  child: Text(
                    today ? 'Today' : DateFormat.yMMMd().format(_date),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.accentPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
        ),
        TextButton(
          onPressed: _save,
          child: Text(
            'Save',
            style: TextStyle(
                color: colors.accentPrimary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
