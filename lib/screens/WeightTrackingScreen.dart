import 'dart:convert';

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

import '../providers/energy_provider.dart';
import '../providers/goals_provider.dart';
import '../providers/weight_unit_provider.dart';
import '../services/energy/constants.dart';
import '../services/energy/phase_engine.dart' show phaseSwitchDays;
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
class WeightTrackingScreen extends StatefulWidget {
  final bool hideAppBar;

  const WeightTrackingScreen({
    Key? key,
    this.hideAppBar = false,
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
                _buildSummary(colors),
                const SizedBox(height: 16),
                _buildChartCard(colors),
                const SizedBox(height: 16),
                _buildGoalCard(colors),
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

  Widget _buildChartCard(CustomColors colors) {
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
    if (scrubbed != null) {
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
          ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52), child: header),
          const SizedBox(height: 12),
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
                    goalKg: _goalKg,
                    ignored: ignoredInRange,
                    switches: switches,
                    colors: colors,
                    onScrub: (i) => setState(() => _scrubbed = i),
                    onTapEntry: (i) => _editEntry(inRange[i], colors,
                        offTrendKg: ignoredInRange[i]
                            ? inRange[i].kg - trendInRange[i]
                            : null,
                        settling: _settling(inRange[i].date)),
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
                    'Expected: water & glycogen after your phase change',
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

  Widget _buildGoalCard(CustomColors colors) {
    final goal = _goalKg;
    final editButton = TextButton(
      onPressed: () => _editGoal(colors),
      style: TextButton.styleFrom(
        foregroundColor: colors.accentPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(goal == null ? 'Set goal' : 'Edit',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
    );

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
  Future<void> _editEntry(WeightEntry entry, CustomColors colors,
      {double? offTrendKg, bool settling = false}) async {
    HapticFeedback.lightImpact();
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        title: Text('${_fmt(entry.kg)} · ${_day(entry.date)}'),
        message: offTrendKg == null
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
  const _GoalBar({required this.progress, required this.colors});

  final double progress;
  final CustomColors colors;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
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
