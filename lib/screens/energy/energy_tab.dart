import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/energy_provider.dart';
import '../../providers/goals_provider.dart';
import '../../providers/weight_unit_provider.dart';
import '../../services/energy/checkin.dart';
import '../../services/energy/constants.dart';
import '../../services/energy/day_status.dart';
import '../../services/energy/energy_estimator.dart';
import '../../services/energy/energy_summary.dart';
import '../../services/energy/expenditure_series.dart';
import '../../services/posthog_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/weight_range.dart';
import '../../widgets/app_bottom_bar.dart';
import '../../widgets/expenditure_chart.dart';
import '../../widgets/progress_card.dart';
import '../../widgets/weight_range_selector.dart';
import 'checkin_history.dart';
import 'checkin_sheet.dart';
import 'goals_card.dart';

/// Progress → Energy: the learned daily expenditure, how it was worked out,
/// how good the data behind it is, the targets it feeds, and "Reset
/// learning" (spec 7.1).
class EnergyTab extends StatelessWidget {
  const EnergyTab({super.key, this.onLogWeight});

  /// Takes the user to log a weigh-in (shown while there are none).
  final VoidCallback? onLogWeight;

  /// The summary the tab shows, from the app's providers.
  static EnergySummary summaryOf(GoalsProvider goals, EnergyProvider energy) =>
      EnergySummary.from(
        estimates: energy.estimates,
        learningStartedOn: goals.learningStartedOn,
        formulaTdee: goals.formulaTdee ?? goals.tdee,
      );

  /// Sends `energy_tab_viewed{state}`.
  static void trackViewed(BuildContext context) {
    final summary = summaryOf(
      Provider.of<GoalsProvider>(context, listen: false),
      Provider.of<EnergyProvider>(context, listen: false),
    );
    PostHogService.trackEvent('energy_tab_viewed',
        properties: {'state': summary.state.code});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    final goals = context.watch<GoalsProvider>();
    final energy = context.watch<EnergyProvider>();
    context.watch<WeightUnitProvider>();
    final summary = summaryOf(goals, energy);
    final strip = energy.dataQuality();
    final noWeighIns = strip.isNotEmpty &&
        !strip.any((d) => d.weighedIn) &&
        summary.state == EnergyState.learning;

    return RefreshIndicator(
      onRefresh: energy.refresh,
      color: colors.accentPrimary,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding:
            const EdgeInsets.fromLTRB(16, 16, 16, AppBottomBar.scrollClearance),
        children: [
          _HeadlineCard(
            summary: summary,
            learningStartedOn: goals.learningStartedOn,
            onLogWeight: noWeighIns ? onLogWeight : null,
          ),
          if (energy.estimates.isNotEmpty) ...[
            const SizedBox(height: 16),
            ExpenditureCard(
              estimates: energy.estimates,
              learningStartedOn: goals.learningStartedOn,
              formulaTdee: goals.formulaTdee ?? goals.tdee,
              checkins: energy.checkins,
            ),
          ],
          if (summary.breakdown != null) ...[
            const SizedBox(height: 16),
            _HowCard(breakdown: summary.breakdown!, summary: summary),
          ],
          if (strip.isNotEmpty) ...[
            const SizedBox(height: 16),
            _QualityCard(strip: strip),
          ],
          const SizedBox(height: 16),
          const GoalsCard(),
          if (energy.checkins.isNotEmpty) ...[
            const SizedBox(height: 16),
            const CheckinHistoryCard(),
          ],
          const SizedBox(height: 20),
          _ResetLearning(formulaTdee: goals.formulaTdee ?? goals.tdee),
        ],
      ),
    );
  }
}

final _cals = NumberFormat.decimalPattern();

String _signed(int v) => v > 0
    ? '+${_cals.format(v)}'
    : v < 0
        ? '−${_cals.format(-v)}'
        : '0';

/// "Sep 28", or "Sep 28, 2025" when it isn't this year.
String _date(DateTime d) => d.year == DateTime.now().year
    ? DateFormat.MMMd().format(d)
    : DateFormat.yMMMd().format(d);

TextStyle _secondary(CustomColors colors, {double size = 13}) =>
    GoogleFonts.inter(fontSize: size, color: colors.textSecondary, height: 1.4);

// --- Headline ---------------------------------------------------------------

class _HeadlineCard extends StatelessWidget {
  const _HeadlineCard({
    required this.summary,
    required this.learningStartedOn,
    this.onLogWeight,
  });

  final EnergySummary summary;
  final DateTime? learningStartedOn;
  final VoidCallback? onLogWeight;

  static const _info = ProgressInfo('Your daily expenditure', [
    InfoSection(
      'This is how many cals you burn in a day, all in: your body at rest, '
      'digesting food, daily movement and exercise.',
    ),
    InfoSection(
      'It starts from a formula based on your height, weight, age and '
      'activity. Then it learns: if you eat 2,000 cals a day and your weight '
      'holds steady, you burn about 2,000. If you lose weight on that, you '
      'burn more. Each day it compares the last 3 weeks of food with how '
      'your weight moved and nudges the estimate.',
      heading: 'How it learns',
    ),
    InfoSection(
      'Learning: not enough data yet, so this is the formula\'s starting '
      'estimate.\n'
      'Estimated: learned from your data, still settling.\n'
      'Confident: within about ±200 cals.\n'
      'Paused: no complete days or weigh-ins for a week, so it holds the '
      'last value until you log again.',
      heading: 'What the labels mean',
    ),
  ]);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    final learning = summary.state == EnergyState.learning;
    final paused = summary.state == EnergyState.paused;
    final starting = learning || (paused && summary.lastUpdated == null);

    return ProgressCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                starting ? 'Starting estimate' : 'Your daily expenditure',
                style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
              ),
              // Full-size tap target without pushing the number down.
              const SizedBox(
                width: 30,
                height: 16,
                child: OverflowBox(
                  maxWidth: 30,
                  maxHeight: 30,
                  child: InfoButton(_info),
                ),
              ),
              const Spacer(),
              StatePill(state: summary.state),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _cals.format(summary.tdee.round()),
                style: GoogleFonts.inter(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                  color: starting ? colors.textSecondary : colors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                ' cals',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
              if (!starting) ...[
                const SizedBox(width: 10),
                Text(
                  '± ${roundToTen(summary.sd)}',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
          if (summary.weekChange != null) ...[
            const SizedBox(height: 2),
            Text(
              '${summary.weekChange! > 0 ? '▲' : '▼'} '
              '${_cals.format(summary.weekChange!.abs())} since last week',
              key: const Key('energy_week_change'),
              style: _secondary(colors),
            ),
          ],
          if (learning) ...[
            const SizedBox(height: 16),
            _LearningProgress(
              completeDays: summary.completeDays,
              weighIns: summary.weighIns,
              learningStartedOn: learningStartedOn,
            ),
          ] else if (paused) ...[
            const SizedBox(height: 10),
            _Note(
              icon: Icons.pause_circle_outline_rounded,
              text: summary.lastUpdated == null
                  ? 'Paused · log a few days to resume'
                  : 'Last updated ${_date(summary.lastUpdated!)} · '
                      'log a few days to resume',
            ),
          ] else if (summary.state == EnergyState.estimated) ...[
            const SizedBox(height: 10),
            const _Note(
              icon: Icons.timelapse_rounded,
              text: 'Still settling: the range narrows as you keep logging',
            ),
          ],
          if (onLogWeight != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onLogWeight,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accentPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Log your weight',
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The estimate's state as a small coloured pill.
class StatePill extends StatelessWidget {
  const StatePill({super.key, required this.state});

  final EnergyState state;

  static String labelOf(EnergyState state) => switch (state) {
        EnergyState.learning => 'Learning',
        EnergyState.estimated => 'Estimated',
        EnergyState.confident => 'Confident',
        EnergyState.paused => 'Paused',
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    final tint = switch (state) {
      EnergyState.confident || EnergyState.estimated => colors.accentPrimary,
      EnergyState.learning || EnergyState.paused => colors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              // Estimated is the accent at half strength: on its way.
              color: state == EnergyState.estimated
                  ? tint.withValues(alpha: 0.55)
                  : tint,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            labelOf(state),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// A quiet one-line note with an icon.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: colors.textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: _secondary(colors))),
        ],
      ),
    );
  }
}

/// The ring toward the first real estimate: complete days of
/// [kMinCompleteDays] outside, weigh-ins of [kMinWeighIns] inside.
class _LearningProgress extends StatelessWidget {
  const _LearningProgress({
    required this.completeDays,
    required this.weighIns,
    required this.learningStartedOn,
  });

  final int completeDays;
  final int weighIns;
  final DateTime? learningStartedOn;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    final days = math.min(completeDays, kMinCompleteDays);
    final weighed = math.min(weighIns, kMinWeighIns);
    final weighColor = Theme.of(context).colorScheme.secondary;

    // The first few days after the start are left out while water and
    // glycogen settle, so nothing counts yet.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final countsFrom = learningStartedOn == null
        ? null
        : DateTime(learningStartedOn!.year, learningStartedOn!.month,
            learningStartedOn!.day + kSwitchSettleDays);
    final settling = countsFrom != null && countsFrom.isAfter(today);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CustomPaint(
                key: const Key('energy_learning_ring'),
                painter: _RingPainter(
                  outer: days / kMinCompleteDays,
                  inner: weighed / kMinWeighIns,
                  outerColor: colors.accentPrimary,
                  innerColor: weighColor,
                  track: colors.textSecondary.withValues(alpha: 0.15),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Learning your metabolism',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _Legend(
                      color: colors.accentPrimary,
                      text: '$days of $kMinCompleteDays days logged'),
                  const SizedBox(height: 2),
                  _Legend(
                      color: weighColor,
                      text: '$weighed of $kMinWeighIns weigh-ins'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          settling
              ? 'We compare what you eat with how your weight moves to find '
                  'what you actually burn. Counting starts ${_date(countsFrom)}, '
                  'once the first few days settle.'
              : 'We compare what you eat with how your weight moves to find '
                  'what you actually burn.',
          style: _secondary(colors),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: _secondary(colors))),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.outer,
    required this.inner,
    required this.outerColor,
    required this.innerColor,
    required this.track,
  });

  final double outer;
  final double inner;
  final Color outerColor;
  final Color innerColor;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final c = size.center(Offset.zero);
    void ring(double radius, double fraction, Color color) {
      final rect = Rect.fromCircle(center: c, radius: radius);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(c, radius, paint..color = track);
      if (fraction > 0) {
        canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * fraction.clamp(0, 1),
            false, paint..color = color);
      }
    }

    final r = size.shortestSide / 2 - stroke / 2;
    ring(r, outer, outerColor);
    ring(r - stroke - 3, inner, innerColor);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.outer != outer ||
      old.inner != inner ||
      old.outerColor != outerColor ||
      old.innerColor != innerColor ||
      old.track != track;
}

// --- Expenditure chart ------------------------------------------------------

/// The estimate over time with its range and the starting estimate, with
/// 1M / 3M / 6M / All chips (spec 7.1 R2). Laid out like the Weight tab's
/// chart card: a header that reads the touched day, the chips, the chart,
/// then the legend.
class ExpenditureCard extends StatefulWidget {
  const ExpenditureCard({
    super.key,
    required this.estimates,
    required this.learningStartedOn,
    required this.formulaTdee,
    this.checkins = const [],
  });

  final List<EnergyEstimate> estimates;
  final DateTime? learningStartedOn;
  final double formulaTdee;

  /// Marked on the chart; tapping one reopens its sheet.
  final List<GoalCheckin> checkins;

  static const ranges = [
    WeightRange.month,
    WeightRange.threeMonths,
    WeightRange.sixMonths,
    WeightRange.all,
  ];

  @override
  State<ExpenditureCard> createState() => _ExpenditureCardState();
}

class _ExpenditureCardState extends State<ExpenditureCard> {
  WeightRange _range = WeightRange.month;
  EnergyEstimate? _scrubbed;

  static const _info = ProgressInfo('Your expenditure over time', [
    InfoSection(
      'The line is your daily expenditure as it was estimated each day. The '
      'shaded band is its likely range: it starts wide and narrows as your '
      'food and weigh-ins add up.',
    ),
    InfoSection(
      'The dashed line is the formula\'s estimate from your height, weight, '
      'age and activity, where learning started. The gap between the two is '
      'what your own data taught it.',
      heading: 'Starting estimate',
    ),
    InfoSection(
      'Resetting learning starts again from the formula. Earlier days stay '
      'on the chart in grey, after a break in the line, but no longer count.',
      heading: 'Resets',
    ),
    InfoSection(
      'The dots under the line are your weekly check-ins. Tap one to see '
      'what changed that week.',
      heading: 'Check-ins',
    ),
  ]);

  String get _phrase => switch (_range) {
        WeightRange.month => 'over the past month',
        WeightRange.threeMonths => 'over the past 3 months',
        WeightRange.sixMonths => 'over the past 6 months',
        _ => 'so far',
      };

  ChartHeader _header(ExpenditureSeries series) {
    final s = _scrubbed;
    if (s != null) {
      final preReset = widget.learningStartedOn != null &&
          s.day.isBefore(widget.learningStartedOn!);
      final note = preReset
          ? 'before you reset'
          : switch (s.state) {
              EnergyState.learning => 'starting estimate',
              EnergyState.paused => '± ${roundToTen(s.tdeeSd)} · paused',
              _ => '± ${roundToTen(s.tdeeSd)}',
            };
      final checkin = widget.checkins.any((c) => c.weekStart == s.day);
      return ChartHeader(
        value: '${_cals.format(s.tdee.round())} cals',
        detail: '${_date(s.day)} · $note${checkin ? ' · check-in' : ''}',
      );
    }
    final change = series.change;
    if (change != null) {
      return ChartHeader(
        value: change.delta.abs() < 10
            ? 'No change'
            : '${_signed(change.delta)} cals',
        detail: change.fromRunStart || _range == WeightRange.all
            ? 'since ${_date(change.from)}'
            : _phrase,
      );
    }
    final rows = series.rows;
    if (rows.isEmpty) {
      return const ChartHeader(value: 'No estimates', detail: 'in this range');
    }
    final last = rows.last;
    return ChartHeader(
      value: '${_cals.format(last.tdee.round())} cals',
      detail: series.segments.last.preReset
          ? 'before you reset on ${_date(series.last!)}'
          : _date(last.day),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    final all = ExpenditureSeries.from(widget.estimates,
        learningStartedOn: widget.learningStartedOn);
    final now = DateTime.now();
    var end = all.last ?? DateTime(now.year, now.month, now.day - 1);
    // Today's check-in has no estimate yet, but still gets its dot.
    final lastCheckin = widget.checkins.isEmpty ? null : widget.checkins.first.weekStart;
    if (lastCheckin != null && lastCheckin.isAfter(end) && !lastCheckin.isAfter(now)) {
      end = lastCheckin;
    }
    final start = _range.start(now) ?? all.first ?? end;
    final series = all.since(start);
    final showsFormula =
        !series.isEmpty && series.scale(formula: widget.formulaTdee).showsFormula;
    final hasPast = series.segments.any((s) => s.preReset);
    final hasCheckins = !series.isEmpty &&
        widget.checkins.any((c) => !c.weekStart.isBefore(start) && !c.weekStart.isAfter(end));

    return ProgressCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: _header(series),
                ),
              ),
              const InfoButton(_info),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: WeightRangeSelector(
              selected: _range,
              ranges: ExpenditureCard.ranges,
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
                  child: ExpenditureChart(
                    series: series,
                    start: start,
                    end: end,
                    formulaTdee: widget.formulaTdee,
                    colors: colors,
                    onScrub: (r) => setState(() => _scrubbed = r),
                    checkins: [for (final c in widget.checkins) c.weekStart],
                    onCheckin: (day) {
                      final c = widget.checkins.where((c) => c.weekStart == day).firstOrNull;
                      if (c != null) {
                        showCheckinSheet(context, c, source: CheckinSheetSource.chart);
                      }
                    },
                  ),
                ),
                if (series.isEmpty)
                  Center(
                    child: Text(
                      'No estimates $_phrase',
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
                swatch: LegendLine(color: colors.accentPrimary),
                label: 'Expenditure',
              ),
              LegendItem(
                swatch: LegendBand(color: colors.accentPrimary),
                label: 'Likely range',
              ),
              if (showsFormula)
                LegendItem(
                  swatch: LegendLine(color: colors.textSecondary, dashed: true),
                  label: 'Starting estimate',
                ),
              if (hasCheckins)
                LegendItem(
                  swatch: LegendDot(color: colors.accentPrimary),
                  label: 'Check-in',
                ),
              if (hasPast)
                LegendItem(
                  swatch: LegendLine(
                      color: colors.textSecondary.withValues(alpha: 0.6)),
                  label: 'Before reset',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- How we got this --------------------------------------------------------

class _HowCard extends StatelessWidget {
  const _HowCard({required this.breakdown, required this.summary});

  final Breakdown breakdown;
  final EnergySummary summary;

  static const _info = ProgressInfo('How we got this', [
    InfoSection(
      'Food you eat either gets burned or changes your weight. So what you '
      'burn is what you ate, plus whatever your weight change accounts for. '
      'Lose weight on 2,000 cals a day and you\'re burning more than 2,000.',
    ),
    InfoSection(
      'Your weight swings with water, salt and food from day to day. The '
      'estimate fits a line through 3 weeks of weigh-ins, so one heavy '
      'morning barely moves it, and readings far off your trend are left '
      'out.',
      heading: 'Why not just the scale',
    ),
    InfoSection(
      'A day with only some of your food logged would make it look like you '
      'ate less than you did. Days well under your expenditure count as '
      'partial and are left out, unless you tap Finish day to say they\'re '
      'complete.',
      heading: 'Why some days are left out',
    ),
    InfoSection(
      'Watches guess your burn from heart rate and movement and are often '
      'off by 20% or more. This is worked out from your own food and weight, '
      'so it\'s tuned to your body and to how you log.',
      heading: 'Better than a watch',
    ),
    InfoSection(
      'Each day\'s 3 weeks only nudge the estimate, so it blends in earlier '
      'weeks too. That\'s why your expenditure can differ a little from '
      'this window\'s number.',
      heading: 'Why the numbers can differ',
    ),
  ]);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    final units = Provider.of<WeightUnitProvider>(context, listen: false);
    final perWeek = units.convertFromKg(breakdown.trendKgPerWeek);
    final weight = perWeek.abs().toStringAsFixed(2);
    final weightText = weight == '0.00'
        ? '0.00 ${units.unitLabel}/week'
        : '${perWeek < 0 ? '−' : '+'}$weight ${units.unitLabel}/week';
    final latestDay = summary.latest?.day;
    final window = latestDay == null || breakdown.day == latestDay
        ? 'Last 3 weeks'
        : '3 weeks to ${_date(breakdown.day)}';

    return ProgressCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProgressCardTitle('How we got this', info: _info),
          Text(window, style: _secondary(colors)),
          const SizedBox(height: 14),
          _MathLine(
            label: 'You ate on average',
            value: '${_cals.format(breakdown.avgIntake)} cals/day',
            caption: '${breakdown.completeDays} complete days',
          ),
          _MathLine(label: 'Your weight changed', value: weightText),
          _MathLine(
            label: 'That change is worth',
            value: '≈ ${_signed(breakdown.weightTerm)} cals/day',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(
                height: 1, color: colors.textSecondary.withValues(alpha: 0.2)),
          ),
          _MathLine(
            label: 'You burned',
            value: '≈ ${_cals.format(breakdown.result)} cals/day',
            strong: true,
          ),
          const SizedBox(height: 8),
          Text(
            'Blended with earlier weeks, your expenditure is '
            '${_cals.format(summary.tdee.round())} cals.',
            style: _secondary(colors, size: 12),
          ),
        ],
      ),
    );
  }
}

/// A label on the left, a number on the right.
class _MathLine extends StatelessWidget {
  const _MathLine({
    required this.label,
    required this.value,
    this.caption,
    this.strong = false,
  });

  final String label;
  final String value;
  final String? caption;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
                color: strong ? colors.textPrimary : colors.textSecondary,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: strong ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (caption != null)
                Text(caption!, style: _secondary(colors, size: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Data quality -----------------------------------------------------------

class _QualityCard extends StatelessWidget {
  const _QualityCard({required this.strip});

  final List<QualityDay> strip;

  static const _info = ProgressInfo('Data quality', [
    InfoSection(
      'One dot per day for the last 3 weeks. A full dot is a complete day '
      '(or a day you fasted), half is a day with only some food logged, and '
      'an empty ring is a day with nothing logged. A tick under a day means '
      'you weighed in.',
    ),
    InfoSection(
      'The estimate needs at least 7 complete days and 4 weigh-ins spread '
      'over a week in the last 3 weeks. More of both makes it sharper and '
      'quicker to follow real changes.',
      heading: 'What helps',
    ),
    InfoSection(
      'A day well under your expenditure is counted as partial. If you '
      'really did eat that little, tap Finish day on Home so it counts.',
      heading: 'Partial days',
    ),
  ]);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    final tip = qualityTip(strip);
    final counted = strip.where((d) => !d.beforeLearning);
    final complete = counted
        .where((d) =>
            d.status == DayStatus.complete || d.status == DayStatus.fasting)
        .length;
    final weighIns = counted.where((d) => d.weighedIn).length;

    return ProgressCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProgressCardTitle('Data quality', info: _info),
          Text(
            '$complete complete days · $weighIns weigh-ins · last 3 weeks',
            style: _secondary(colors),
          ),
          const SizedBox(height: 14),
          Row(
            key: const Key('energy_quality_strip'),
            children: [
              for (final d in strip)
                Expanded(child: _DayDot(day: d)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_date(strip.first.day), style: _secondary(colors, size: 11)),
              Text('Yesterday', style: _secondary(colors, size: 11)),
            ],
          ),
          if (tip != null) ...[
            const SizedBox(height: 14),
            _TipLine(tip: tip),
          ],
        ],
      ),
    );
  }
}

/// One day: a full, half or empty dot, with a tick under it for a weigh-in.
class _DayDot extends StatelessWidget {
  const _DayDot({required this.day});

  final QualityDay day;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    final label = day.beforeLearning
        ? 'before learning started'
        : switch (day.status) {
            DayStatus.complete => 'complete',
            DayStatus.fasting => 'fasted',
            DayStatus.partial => 'partial',
            DayStatus.untracked || null => 'not logged',
          };
    return Semantics(
      label: '${DateFormat.MMMd().format(day.day)}: $label'
          '${day.weighedIn ? ', weighed in' : ''}',
      child: Column(
        children: [
          SizedBox(
            width: 11,
            height: 11,
            child: CustomPaint(
              painter: _DotPainter(
                status: day.status,
                beforeLearning: day.beforeLearning,
                fill: colors.accentPrimary,
                empty: colors.textSecondary.withValues(alpha: 0.45),
                faint: colors.textSecondary.withValues(alpha: 0.15),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 2,
            height: 6,
            decoration: BoxDecoration(
              color: day.weighedIn
                  ? colors.textSecondary.withValues(alpha: 0.8)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter({
    required this.status,
    required this.beforeLearning,
    required this.fill,
    required this.empty,
    required this.faint,
  });

  final DayStatus? status;
  final bool beforeLearning;
  final Color fill;
  final Color empty;
  final Color faint;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    if (beforeLearning) {
      canvas.drawCircle(c, r * 0.45, Paint()..color = faint);
      return;
    }
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    switch (status) {
      case DayStatus.complete:
      case DayStatus.fasting:
        canvas.drawCircle(c, r, Paint()..color = fill);
      case DayStatus.partial:
        canvas.drawCircle(c, r - 0.75, outline..color = fill);
        canvas.drawArc(Rect.fromCircle(center: c, radius: r), math.pi / 2,
            math.pi, true, Paint()..color = fill);
      case DayStatus.untracked:
      case null:
        canvas.drawCircle(c, r - 0.75, outline..color = empty);
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) =>
      old.status != status ||
      old.beforeLearning != beforeLearning ||
      old.fill != fill ||
      old.empty != empty;
}

class _TipLine extends StatelessWidget {
  const _TipLine({required this.tip});

  final QualityTip tip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    final style = GoogleFonts.inter(
        fontSize: 13, color: colors.textPrimary, height: 1.4);
    final text = switch (tip) {
      QualityTip.weighIn => TextSpan(
          text: 'Weigh in 3+ times a week to sharpen this', style: style),
      QualityTip.finishDay => TextSpan(style: style, children: [
          const TextSpan(text: 'Tap '),
          TextSpan(
              text: 'Finish day',
              style: style.copyWith(fontWeight: FontWeight.w600)),
          const TextSpan(text: ' on Home when you\'ve logged everything'),
        ]),
    };
    return Container(
      key: Key('energy_tip_${tip.name}'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: colors.accentPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded,
              size: 18, color: colors.accentPrimary),
          const SizedBox(width: 8),
          Expanded(child: Text.rich(text)),
        ],
      ),
    );
  }
}

// --- Reset learning ---------------------------------------------------------

class _ResetLearning extends StatelessWidget {
  const _ResetLearning({required this.formulaTdee});

  final double formulaTdee;

  Future<void> _reset(BuildContext context) async {
    HapticFeedback.lightImpact();
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialog) => CupertinoAlertDialog(
        title: const Text('Reset learning?'),
        content: Text(
          'Your expenditure goes back to the starting estimate of '
          '${_cals.format(formulaTdee.round())} cals and is learned again '
          'from today. Your history is kept.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final goals = Provider.of<GoalsProvider>(context, listen: false);
    final energy = Provider.of<EnergyProvider>(context, listen: false);
    goals.startLearning();
    PostHogService.trackEvent('learning_reset');
    await energy.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    return Column(
      children: [
        TextButton(
          onPressed: () => _reset(context),
          style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
          child: Text(
            'Reset learning',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Starts again from the formula estimate. Useful after an illness, '
            'a pregnancy, a new medication or months of not logging.',
            textAlign: TextAlign.center,
            style: _secondary(colors, size: 12),
          ),
        ),
      ],
    );
  }
}
