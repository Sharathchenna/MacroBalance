import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/foodEntryProvider.dart';
import '../providers/goals_provider.dart';
import '../providers/weight_unit_provider.dart';
import '../services/posthog_service.dart';
import '../theme/macro_colors.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/nutrition_stats.dart';
import '../utils/weight_range.dart';
import '../utils/weight_trend.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/intake_bar_chart.dart';
import '../widgets/progress_card.dart';
import '../widgets/weight_range_selector.dart';

/// Progress › Nutrition: how eating has gone over the past week, month or
/// three months — average intake against the goal, how consistent it's
/// been, the average macro split — and, once there are a few weeks of food
/// logs and weigh-ins, what maintenance actually is.
class NutritionTrendsScreen extends StatefulWidget {
  const NutritionTrendsScreen({super.key, this.hideAppBar = false});

  final bool hideAppBar;

  @override
  State<NutritionTrendsScreen> createState() => _NutritionTrendsScreenState();
}

const _proteinColor = MacroColors.protein;
const _carbsColor = MacroColors.carbs;
const _fatColor = MacroColors.fat;

class _NutritionTrendsScreenState extends State<NutritionTrendsScreen> {
  static const _ranges = [
    WeightRange.week,
    WeightRange.month,
    WeightRange.threeMonths,
  ];

  WeightRange _range = WeightRange.week;
  int? _scrubbed;

  @override
  void initState() {
    super.initState();
    PostHogService.trackScreen('nutrition_trends_screen');
  }

  int get _length => switch (_range) {
        WeightRange.week => 7,
        WeightRange.month => 30,
        _ => 91,
      };

  String get _rangePhrase => switch (_range) {
        WeightRange.week => 'past week',
        WeightRange.month => 'past 30 days',
        _ => 'past 3 months',
      };

  /// Everything logged, totalled per day.
  Map<DateTime, DayIntake> _intakeByDay(FoodEntryProvider food) {
    final totals = <DateTime, List<double>>{};
    for (final entry in food.entries) {
      final day = dayOf(entry.date.toLocal());
      final t = totals.putIfAbsent(day, () => [0, 0, 0, 0]);
      t[0] += food.calculateNutrientForEntry(entry, 'calories');
      t[1] += food.calculateNutrientForEntry(entry, 'Protein');
      t[2] += food.calculateNutrientForEntry(entry, 'Carbohydrate, by difference');
      t[3] += food.calculateNutrientForEntry(entry, 'Total lipid (fat)');
    }
    return {
      for (final e in totals.entries)
        e.key: DayIntake(
            cals: e.value[0],
            protein: e.value[1],
            carbs: e.value[2],
            fat: e.value[3]),
    };
  }

  List<WeightEntry> _weights() {
    final stored = StorageService().get('weight_history');
    if (stored is! String || stored.isEmpty) return const [];
    try {
      return parseWeightHistory(json.decode(stored) as List);
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<CustomColors>()!;
    final food = context.watch<FoodEntryProvider>();
    final goals = context.watch<GoalsProvider>();
    final units = context.watch<WeightUnitProvider>();
    final now = DateTime.now();

    final intake = _intakeByDay(food);
    final summary = NutritionSummary.lastDays(_length, intake, today: now);
    final maintenance = MaintenanceEstimate.compute(
        intake: intake, weights: _weights(), today: now);
    final bars = _bars(summary);

    final body = ListView(
      physics: const BouncingScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(16, 16, 16, AppBottomBar.scrollClearance),
      children: [
        WeightRangeSelector(
          selected: _range,
          ranges: _ranges,
          onChanged: (r) {
            HapticFeedback.selectionClick();
            setState(() {
              _range = r;
              _scrubbed = null;
            });
          },
        ),
        const SizedBox(height: 16),
        _buildIntakeCard(colors, summary, bars, goals.caloriesGoal),
        const SizedBox(height: 16),
        _buildConsistencyCard(colors, summary, goals),
        const SizedBox(height: 16),
        _buildMacrosCard(colors, summary, goals),
        const SizedBox(height: 16),
        _buildMaintenanceCard(colors, maintenance, goals, units),
      ],
    );

    if (widget.hideAppBar) return body;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nutrition',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: theme.brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: SafeArea(bottom: false, child: body),
    );
  }

  /// Days for a week or a month; for three months, weekly averages (the
  /// last week ends today).
  List<IntakeBar> _bars(NutritionSummary s) {
    final today = s.days.last;
    if (_range != WeightRange.threeMonths) {
      return [
        for (final d in s.days)
          IntakeBar(start: d, cals: s.byDay[d]?.cals, partial: d == today),
      ];
    }
    final bars = <IntakeBar>[];
    for (var end = s.days.length - 1; end >= 6; end -= 7) {
      final week = s.days.sublist(end - 6, end + 1);
      // Today only counts if it's all there is so far this week.
      final finished = [
        for (final d in week)
          if (d != today && s.byDay[d] != null) s.byDay[d]!.cals,
      ];
      final todayCals = s.byDay[today]?.cals;
      double? avg;
      var partial = false;
      if (finished.isNotEmpty) {
        avg = finished.reduce((a, b) => a + b) / finished.length;
      } else if (week.contains(today) && todayCals != null) {
        avg = todayCals;
        partial = true;
      }
      bars.insert(0, IntakeBar(start: week.first, cals: avg, partial: partial));
    }
    return bars;
  }

  String? _barLabel(List<IntakeBar> bars, int i) {
    final d = bars[i].start;
    switch (_range) {
      case WeightRange.week:
        return DateFormat.E().format(d);
      case WeightRange.month:
        // Every 7th day, counted back from today.
        return (bars.length - 1 - i) % 7 == 0 ? DateFormat.MMMd().format(d) : null;
      default:
        return (bars.length - 1 - i) % 4 == 0 ? DateFormat.MMMd().format(d) : null;
    }
  }

  // --- Explanations behind the info buttons ---------------------------------

  static const _intakeInfo = ProgressInfo('Daily intake', [
    InfoSection(
      heading: 'The average',
      'Your average calories per day over the range you picked. Only days '
      'you logged something count: a day with nothing logged is left out, '
      'not counted as zero, so a missed day doesn\'t drag the average down.',
    ),
    InfoSection(
      heading: 'Reading the bars',
      'Each bar is one day, or one week\'s daily average on 3M. Solid bars '
      'ended within 10% of your calorie goal; faded bars were further over '
      'or under. The dashed line is your goal, and a small dot on the '
      'baseline means nothing was logged that day.',
    ),
    InfoSection(
      heading: 'Today',
      'Today is usually only partly logged, so it\'s drawn lighter and left '
      'out of the average until the day is over.',
    ),
    InfoSection(
      heading: 'See a single day',
      'Touch the chart and drag across it to read each day\'s total.',
    ),
  ]);

  ProgressInfo _consistencyInfo(GoalsProvider goals) {
    final goal = goals.caloriesGoal;
    final example = goal > 0
        ? ' With your ${_cals(goal)} goal, that\'s anything from '
            '${_cals(goal * 0.9)} to ${_cals(goal * 1.1)}.'
        : '';
    return ProgressInfo('Consistency', [
      const InfoSection(
        heading: 'Days logged',
        'Finished days in the range with at least one food logged. Logging '
        'most days is what makes every other number on this page reliable.',
      ),
      InfoSection(
        heading: 'On target',
        'Days your calories ended within 10% of your goal, over or under.'
        '$example',
      ),
      const InfoSection(
        heading: 'Protein hit',
        'Days you reached at least 90% of your protein goal.',
      ),
      const InfoSection(
        'Today isn\'t counted until it\'s over, so a half-logged day '
        'doesn\'t count against you.',
      ),
    ]);
  }

  static const _macrosInfo = ProgressInfo('Average macros', [
    InfoSection(
      'Average grams of protein, carbs and fat per logged day over the range '
      'you picked, next to your daily goal for each.',
    ),
    InfoSection(
      heading: 'Reading the bars',
      'The tick on each bar marks your goal. The bar keeps going past it '
      'when you\'re over, so you can see by how much.',
    ),
    InfoSection(
      heading: 'The percentages',
      'Each macro\'s share of the calories that come from macros. Protein '
      'and carbs have 4 cals per gram, fat has 9.',
    ),
  ]);

  ProgressInfo _maintenanceInfo(WeightUnitProvider units) {
    final perUnit = units.isMetric
        ? 'A kilo of body weight is roughly 7,700 cals'
        : 'A pound of body weight is roughly 3,500 cals';
    final example = units.isMetric
        ? 'if you averaged 2,000 cals a day and lost 0.5 kg a week, you were '
            'burning about 2,550'
        : 'if you averaged 2,000 cals a day and lost 1 lb a week, you were '
            'burning about 2,500';
    return ProgressInfo('Estimated maintenance', [
      const InfoSection(
        heading: 'What it is',
        'The calories you\'d eat to keep your weight where it is. Formulas '
        'based on age, height and activity can only guess; this is worked '
        'out from your own logs and weigh-ins.',
      ),
      InfoSection(
        heading: 'How it\'s worked out',
        'Over the last ${MaintenanceEstimate.windowDays} days, your average '
        'logged intake is compared with how your weight actually changed. '
        '$perUnit, so $example.',
      ),
      const InfoSection(
        heading: 'What it needs',
        'Food logged on at least ${MaintenanceEstimate.minLoggedDays} of the '
        'last ${MaintenanceEstimate.windowDays} days, and weigh-ins at least '
        '${MaintenanceEstimate.minWeighInSpan} days apart. More logged days '
        'and more weigh-ins make it steadier.',
      ),
      const InfoSection(
        heading: 'How accurate it is',
        'Only as accurate as your logging. Missed snacks or rough portions '
        'make it read low. If your logs and weigh-ins don\'t add up to '
        'something realistic, it waits for more data instead of guessing.',
      ),
    ]);
  }

  static final _number = NumberFormat.decimalPattern();
  String _cals(double v) => _number.format(v.round());

  Widget _buildIntakeCard(CustomColors colors, NutritionSummary s,
      List<IntakeBar> bars, double goal) {
    final avg = s.avgCals;
    final scrubbed = _scrubbed != null && _scrubbed! < bars.length ? bars[_scrubbed!] : null;

    String bigNumber;
    String detail;
    Color? detailColor;
    if (scrubbed != null) {
      bigNumber = scrubbed.cals == null ? '—' : _cals(scrubbed.cals!);
      final when = _range == WeightRange.threeMonths
          ? 'Week of ${DateFormat.MMMd().format(scrubbed.start)} · daily average'
          : DateFormat.MMMEd().format(scrubbed.start);
      detail = scrubbed.cals == null
          ? '$when · nothing logged'
          : '$when${scrubbed.partial ? ' · so far' : ''}';
    } else if (avg == null) {
      bigNumber = '—';
      detail = 'Nothing logged in the $_rangePhrase yet';
    } else {
      bigNumber = _cals(avg);
      if (goal > 0) {
        final diff = avg - goal;
        final within = diff.abs() <= goal * 0.1;
        detail = diff.abs() < 1
            ? 'Right on your ${_cals(goal)} goal'
            : '${_cals(diff.abs())} ${diff > 0 ? 'over' : 'under'} your ${_cals(goal)} goal';
        detailColor = within ? colors.accentPrimary : Colors.orange.shade700;
      } else {
        detail = 'Daily average';
      }
    }

    return ProgressCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                scrubbed != null ? 'Logged' : 'Average per day',
                style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
              ),
              InfoButton(_intakeInfo),
            ],
          ),
          Text.rich(TextSpan(children: [
            TextSpan(
              text: bigNumber,
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
                color: colors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            TextSpan(
              text: ' cals',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
          ])),
          const SizedBox(height: 2),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: detailColor == null ? FontWeight.w400 : FontWeight.w600,
              color: scrubbed == null ? (detailColor ?? colors.textSecondary) : colors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 190,
            child: IntakeBarChart(
              bars: bars,
              goal: goal,
              label: (i) => _barLabel(bars, i),
              colors: colors,
              onScrub: (i) => setState(() => _scrubbed = i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsistencyCard(
      CustomColors colors, NutritionSummary s, GoalsProvider goals) {
    final days = s.completeDays;
    return ProgressCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProgressCardTitle('Consistency', info: _consistencyInfo(goals)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ProgressStat(
                  label: 'Days logged',
                  value: '${s.loggedDays} of $days',
                ),
              ),
              Expanded(
                child: ProgressStat(
                  label: 'On target',
                  value: goals.caloriesGoal > 0
                      ? '${s.daysOnTarget(goals.caloriesGoal)} days'
                      : '—',
                ),
              ),
              Expanded(
                child: ProgressStat(
                  label: 'Protein hit',
                  value: goals.proteinGoal > 0
                      ? '${s.daysProteinHit(goals.proteinGoal)} days'
                      : '—',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacrosCard(
      CustomColors colors, NutritionSummary s, GoalsProvider goals) {
    final p = s.avgProtein, c = s.avgCarbs, f = s.avgFat;
    final macroCals = p == null ? 0.0 : p * 4 + c! * 4 + f! * 9;
    String share(double? g, int perGram) => macroCals <= 0 || g == null
        ? ''
        : '${(g * perGram / macroCals * 100).round()}%';

    return ProgressCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProgressCardTitle('Average macros', info: _macrosInfo),
          const SizedBox(height: 14),
          _MacroRow(
              name: 'Protein',
              grams: p,
              goal: goals.proteinGoal,
              share: share(p, 4),
              color: _proteinColor),
          const SizedBox(height: 14),
          _MacroRow(
              name: 'Carbs',
              grams: c,
              goal: goals.carbsGoal,
              share: share(c, 4),
              color: _carbsColor),
          const SizedBox(height: 14),
          _MacroRow(
              name: 'Fat',
              grams: f,
              goal: goals.fatGoal,
              share: share(f, 9),
              color: _fatColor),
        ],
      ),
    );
  }

  Widget _buildMaintenanceCard(CustomColors colors, MaintenanceEstimate m,
      GoalsProvider goals, WeightUnitProvider units) {
    final body = GoogleFonts.inter(
        fontSize: 14, height: 1.45, color: colors.textSecondary);

    if (!m.ready) {
      final enoughLogs = m.loggedDays >= MaintenanceEstimate.minLoggedDays;
      final enoughWeighIns =
          m.weighInSpanDays >= MaintenanceEstimate.minWeighInSpan;
      return ProgressCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProgressCardTitle('Estimated maintenance',
                info: _maintenanceInfo(units)),
            const SizedBox(height: 12),
            _Requirement(
              done: enoughLogs,
              text: 'Log food on ${MaintenanceEstimate.minLoggedDays} of the '
                  'last ${MaintenanceEstimate.windowDays} days',
              progress: '${m.loggedDays.clamp(0, MaintenanceEstimate.minLoggedDays)}'
                  '/${MaintenanceEstimate.minLoggedDays}',
            ),
            const SizedBox(height: 8),
            _Requirement(
              done: enoughWeighIns,
              text: 'Weigh-ins at least 2 weeks apart',
              progress: '${m.weighInSpanDays.clamp(0, MaintenanceEstimate.minWeighInSpan)}'
                  '/${MaintenanceEstimate.minWeighInSpan} days',
            ),
            if (enoughLogs && enoughWeighIns) ...[
              const SizedBox(height: 12),
              Text(
                'Your logs and weigh-ins don\'t add up yet.',
                style: body.copyWith(fontSize: 13),
              ),
            ],
          ],
        ),
      );
    }

    final goal = goals.caloriesGoal;
    final diff = goal - m.cals!;
    final weeklyKg = m.weeklyKgAt(goal)!;
    final weekly = units.convertFromKg(weeklyKg.abs()).toStringAsFixed(1);
    final String outlook;
    if (goal <= 0) {
      outlook = 'Set a calorie goal to see what it means for your weight.';
    } else if (diff.abs() < 100) {
      outlook = 'Your ${_cals(goal)} goal is about maintenance, so your '
          'weight should hold steady.';
    } else {
      outlook = 'Your ${_cals(goal)} goal is ${_cals(diff.abs())} '
          '${diff < 0 ? 'below' : 'above'} that: about $weekly '
          '${units.unitLabel} a week ${diff < 0 ? 'down' : 'up'} if you stick to it.';
    }

    return ProgressCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProgressCardTitle('Estimated maintenance',
              info: _maintenanceInfo(units)),
          const SizedBox(height: 4),
          Text.rich(TextSpan(children: [
            TextSpan(
              text: _cals(m.cals!),
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                color: colors.textPrimary,
              ),
            ),
            TextSpan(
              text: ' cals / day',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
          ])),
          const SizedBox(height: 8),
          Text(outlook, style: body.copyWith(color: colors.textPrimary)),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.name,
    required this.grams,
    required this.goal,
    required this.share,
    required this.color,
  });

  final String name;
  final double? grams;
  final double goal;
  final String share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    final g = grams ?? 0;
    // Scale so the goal sits at 80% of the track and overshoot still shows.
    final scale = goal > 0 ? goal / 0.8 : (g > 0 ? g : 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(name,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary)),
            if (share.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(share,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: colors.textSecondary)),
            ],
            const Spacer(),
            Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: grams == null ? '—' : '${g.round()}',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary),
                ),
                TextSpan(
                  text: goal > 0 ? ' / ${goal.round()} g' : ' g',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: colors.textSecondary),
                ),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          return SizedBox(
            height: 12,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (g / scale).clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Container(
                    width: w * v,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                if (goal > 0)
                  Positioned(
                    left: w * 0.8 - 1,
                    child: Container(
                      width: 2,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors.textPrimary.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _Requirement extends StatelessWidget {
  const _Requirement({
    required this.done,
    required this.text,
    required this.progress,
  });

  final bool done;
  final String text;
  final String progress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 18,
          color: done ? colors.accentPrimary : colors.textSecondary.withOpacity(0.6),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: GoogleFonts.inter(fontSize: 14, color: colors.textPrimary)),
        ),
        Text(progress,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: colors.textSecondary,
              fontFeatures: const [FontFeature.tabularFigures()],
            )),
      ],
    );
  }
}
