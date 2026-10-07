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

import '../providers/goals_provider.dart';
import '../providers/weight_unit_provider.dart';
import '../services/posthog_service.dart';
import '../theme/app_theme.dart';

/// Progress › Weight: where your weight is, where it's heading, and how far
/// off the goal is. Shown in kg or lbs from the unit setting; stored in kg.
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
  List<double> _trend = [];

  /// Index into the visible entries while the chart is being touched.
  int? _scrubbed;

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
    _trend = weightTrend(_entries);
  }

  double get _latestKg =>
      _entries.isNotEmpty ? _entries.last.kg : _goals.currentWeightKg;

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
  }

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

  /// Colour for a change: green toward the goal, amber away from it.
  Color _changeColor(double deltaKg, CustomColors colors) {
    final goal = _goalKg;
    if (goal == null || deltaKg.abs() < 0.05 || _entries.isEmpty) {
      return colors.textPrimary;
    }
    final wantDown = goal < _trend.last;
    final towardGoal = wantDown ? deltaKg < 0 : deltaKg > 0;
    return towardGoal ? colors.accentPrimary : Colors.orange.shade700;
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
    final rateEntries = recentForRate(_entries, _today);
    final weekly = weeklyRateKg(rateEntries);
    final latest = hasEntries ? _entries.last : null;

    String weighedIn() {
      if (latest == null) return 'No weigh-ins yet';
      final days = _today.difference(latest.day).inDays;
      if (days == 0) return 'Weighed in today';
      if (days == 1) return 'Weighed in yesterday';
      if (days < 7) return 'Weighed in ${DateFormat.EEEE().format(latest.date)}';
      return 'Weighed in ${_day(latest.date)}';
    }

    final number = _units.convertFromKg(_latestKg).toStringAsFixed(1);

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
                    Text(
                      'Current weight',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: colors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: _latestKg > 0 ? number : '—',
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
                      weighedIn(),
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
            Divider(height: 1, color: colors.textSecondary.withOpacity(0.15)),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ProgressStat(
                    label: 'Trend',
                    value: _fmt(_trend.last),
                    caption: 'smoothed',
                  ),
                ),
                Expanded(
                  child: ProgressStat(
                    label: 'Weekly rate',
                    value: weekly == null
                        ? '—'
                        : '${_fmt(weekly, signed: true)}/wk',
                    valueColor: weekly == null
                        ? null
                        : _changeColor(weekly, colors),
                    caption: weekly == null
                        ? 'needs 1 week'
                        : 'since ${_day(rateEntries.first.date)}',
                  ),
                ),
                Expanded(
                  child: ProgressStat(
                    label: 'Total change',
                    value: _entries.length < 2
                        ? '—'
                        : _fmt(_entries.last.kg - _entries.first.kg,
                            signed: true),
                    valueColor: _entries.length < 2
                        ? null
                        : _changeColor(
                            _entries.last.kg - _entries.first.kg, colors),
                    caption: _entries.length < 2
                        ? null
                        : 'since ${_day(_entries.first.date)}',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChartCard(CustomColors colors) {
    final now = DateTime.now();
    final inRange = <WeightEntry>[];
    final trendInRange = <double>[];
    for (var i = 0; i < _entries.length; i++) {
      if (_range.includes(_entries[i].date, now)) {
        inRange.add(_entries[i]);
        trendInRange.add(_trend[i]);
      }
    }
    final scrubbed =
        _scrubbed != null && _scrubbed! < inRange.length ? _scrubbed : null;
    final showsTrend = WeightChart.showsTrend(inRange);
    // "in the past week", or "so far" for All.
    final within =
        _range == WeightRange.all ? 'so far' : 'in the $_rangePhrase';

    Widget header;
    if (scrubbed != null) {
      final e = inRange[scrubbed];
      header = _ChartHeader(
        value: _fmt(e.kg),
        detail: showsTrend
            ? '${_day(e.date)} · trend ${_fmt(trendInRange[scrubbed])}'
            : '${_day(e.date)} · tap to edit',
      );
    } else if (inRange.length >= 2) {
      final delta = inRange.last.kg - inRange.first.kg;
      header = _ChartHeader(
        value: _fmt(delta, signed: true),
        valueColor: _changeColor(delta, colors),
        detail: _rangePhrase,
      );
    } else {
      header = _ChartHeader(
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
                    colors: colors,
                    onScrub: (i) => setState(() => _scrubbed = i),
                    onTapEntry: (i) => _editEntry(inRange[i], colors),
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
          Row(
            children: [
              _LegendDot(color: colors.accentPrimary, ring: true),
              _legendText('Weigh-ins', colors),
              if (showsTrend) ...[
                const SizedBox(width: 14),
                _LegendLine(color: colors.accentPrimary),
                _legendText('Trend', colors),
              ],
              if (WeightChart.showsGoal(inRange, trendInRange, _goalKg)) ...[
                const SizedBox(width: 14),
                _LegendLine(color: colors.textSecondary, dashed: true),
                _legendText('Goal', colors),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendText(String text, CustomColors colors) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Text(text,
            style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary)),
      );

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

    final startKg = _entries.first.kg;
    final nowKg = _latestKg;
    final total = (goal - startKg).abs();
    final done = total < 0.05
        ? 1.0
        : ((goal - startKg).sign * (nowKg - startKg) / total).clamp(0.0, 1.0);
    final left = (goal - nowKg).abs();
    final reached = left < 0.25 || done >= 1.0;

    final weekly = weeklyRateKg(recentForRate(_entries, _today));
    final eta = projectedGoalDate(
        currentKg: _trend.last, goalKg: goal, weeklyKg: weekly, from: _today);

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
    } else if ((goal - _trend.last).sign != weekly.sign && weekly.abs() >= 0.05) {
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
              Expanded(child: ProgressStat(label: 'Now', value: _fmt(nowKg))),
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
  }

  /// Sets [date]'s weight, replacing any weigh-in that day.
  void _saveDay(DateTime date, double kg) {
    _storeHistory(
        [..._withoutDay(date), {'date': date.toIso8601String(), 'weight': kg}]);
    WeightSyncService().upsertDay(date, kg);
  }

  /// Tapped weigh-in: change its weight or delete it.
  Future<void> _editEntry(WeightEntry entry, CustomColors colors) async {
    HapticFeedback.lightImpact();
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        title: Text('${_fmt(entry.kg)} · ${_day(entry.date)}'),
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

class _ChartHeader extends StatelessWidget {
  const _ChartHeader({required this.value, required this.detail, this.valueColor});

  final String value;
  final String detail;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: valueColor ?? colors.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
        ),
      ],
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

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, this.ring = false});

  final Color color;
  final bool ring;

  @override
  Widget build(BuildContext context) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: ring ? Border.all(color: color, width: 1.8) : null,
          color: ring ? null : color,
        ),
      );
}

class _LegendLine extends StatelessWidget {
  const _LegendLine({required this.color, this.dashed = false});

  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 16,
        height: 3,
        child: dashed
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(width: 4, height: 1.5, color: color),
                ],
              )
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
      );
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
