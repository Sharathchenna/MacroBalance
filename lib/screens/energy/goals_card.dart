import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/energy_provider.dart';
import '../../providers/goals_provider.dart';
import '../../providers/weight_unit_provider.dart';
import '../../services/energy/checkin.dart';
import '../../services/energy/phase_engine.dart';
import '../../services/energy/phase_timeline.dart';
import '../../services/macro_calculator_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/adaptive_choice.dart';
import '../../widgets/plan_style_choice.dart';
import '../../widgets/progress_card.dart';

/// Energy tab → the targets and how they're kept up to date (spec 7.1 R5).
///
/// Adaptive on: the current target, the next check-in day and what a
/// check-in would likely do if it ran today (plan 9.2 item 5). Adaptive off:
/// the fixed target. Both have the "Weekly updates" switch, which confirms
/// with the onboarding question before changing anything.
///
/// Phased and diet-break plans also get the phase timeline with its status
/// line, and an overflow menu with "End phase early" (plan 9.6).
class GoalsCard extends StatelessWidget {
  const GoalsCard({super.key});

  static const _info = ProgressInfo('Your targets', [
    InfoSection(
      'With weekly updates on, your targets follow the expenditure above. '
      'Once a week, on your check-in day, we compare it with what your '
      'targets were set from and adjust them so you keep your chosen pace. '
      'Each check-in tells you what changed and why.',
    ),
    InfoSection(
      'Changes are gradual: at most 150 cals a week, and never below a safe '
      'minimum.',
      heading: 'How big the changes are',
    ),
    InfoSection(
      'With them off, your targets stay as calculated until you change them '
      'or recalculate. The expenditure here keeps learning either way.',
      heading: 'Fixed targets',
    ),
    InfoSection(
      'You can change your check-in day in Profile → Nutrition & Goals.',
      heading: 'Check-in day',
    ),
  ]);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    final goals = context.watch<GoalsProvider>();
    final energy = context.watch<EnergyProvider>();
    final likely = goals.adaptiveGoals ? likelyChangeText(energy.previewCheckin()) : null;
    final cals = NumberFormat.decimalPattern().format(goals.caloriesGoal.round());
    final adaptive = goals.adaptiveGoals;
    final secondary =
        GoogleFonts.inter(fontSize: 13, color: colors.textSecondary, height: 1.4);
    final units = context.watch<WeightUnitProvider>();
    final settings = goals.checkinSettings;
    final trendKg = energy.latest?.trendWeightKg;
    final timeline = buildPhaseTimeline(
      phases: energy.phases,
      style: goals.planStyle,
      goal: MacroCalculatorService.goalKindOf(goals.goalType),
      now: DateTime.now(),
      trendKg: trendKg,
      goalWeightKg: goals.goalWeightKg > 0 ? goals.goalWeightKg : null,
      pacePct: goals.pacePctPerWeek,
      tdee: planTdee(
          settings: settings,
          latest: energy.latest,
          weightKg: trendKg ?? goals.currentWeightKg),
      body: settings.body,
      adaptive: adaptive,
      cals: goals.caloriesGoal,
      settings: goals.phaseSettings,
    );

    return ProgressCard(
      key: const Key('energy_goals_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProgressCardTitle(
            'Your targets',
            info: _info,
            trailing: timeline == null ? null : _PhaseMenu(timeline: timeline),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                cals,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: colors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                ' cals a day',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Protein ${goals.proteinGoal.round()} g · '
            'Carbs ${goals.carbsGoal.round()} g · '
            'Fat ${goals.fatGoal.round()} g',
            style: secondary,
          ),
          if (timeline != null) ...[
            const SizedBox(height: 16),
            PhaseTimelineView(timeline: timeline, isKg: units.isKg),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: adaptive
                  ? colors.accentPrimary.withValues(alpha: 0.12)
                  : colors.textSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  adaptive ? Icons.event_repeat_rounded : Icons.lock_outline_rounded,
                  size: 18,
                  color: adaptive ? colors.accentPrimary : colors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: adaptive
                      ? Text.rich(
                          key: const Key('energy_next_checkin'),
                          TextSpan(
                            style: secondary.copyWith(color: colors.textPrimary),
                            children: [
                              const TextSpan(text: 'Next check-in: '),
                              TextSpan(
                                text: checkinDayText(
                                    energy.nextCheckinDay ?? goals.nextCheckinDay,
                                    DateTime.now()),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const TextSpan(
                                  text: '. Your targets will update from this '
                                      'estimate.'),
                              if (likely != null)
                                TextSpan(
                                  text: ' $likely',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                        )
                      : Text(
                          'Your targets are fixed at $cals cals. Turn on weekly '
                          'updates to have them follow your real expenditure.',
                          style: secondary.copyWith(color: colors.textPrimary),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          MergeSemantics(
            child: InkWell(
              key: const Key('energy_adaptive_toggle'),
              onTap: () => changeAdaptiveGoals(context, to: !adaptive),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Weekly updates',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    CupertinoSwitch(
                      value: adaptive,
                      activeTrackColor: colors.accentPrimary,
                      onChanged: (on) => changeAdaptiveGoals(context, to: on),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What a check-in would do if it ran today: "Likely +50 cals.", "Likely no
/// change.", or null when there isn't enough data to say.
@visibleForTesting
String? likelyChangeText(CheckinDecision? preview) {
  if (preview == null) return null;
  switch (preview.variant) {
    case CheckinVariant.changed:
      final d = preview.newTargets.cals - preview.oldTargets.cals;
      return 'Likely ${d > 0 ? '+' : '−'}${NumberFormat.decimalPattern().format(d.abs())} cals.';
    case CheckinVariant.unchanged:
      return 'Likely no change.';
    default:
      return null;
  }
}

/// "Today", "Tomorrow", or e.g. "Monday, Oct 12".
@visibleForTesting
String checkinDayText(DateTime day, DateTime now) {
  final d = DateTime(day.year, day.month, day.day);
  if (d == DateTime(now.year, now.month, now.day)) return 'Today';
  if (d == DateTime(now.year, now.month, now.day + 1)) return 'Tomorrow';
  return DateFormat('EEEE, MMM d').format(d);
}


// --- Phase timeline (plan 9.6) ---------------------------------------------

/// The plan as segments (losing in the accent, maintenance neutral), a
/// you-are-here marker, a small legend and the status line.
class PhaseTimelineView extends StatelessWidget {
  const PhaseTimelineView({super.key, required this.timeline, required this.isKg});

  final PhaseTimeline timeline;
  final bool isKg;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    return Column(
      key: const Key('phase_timeline'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TimelineBar(timeline: timeline),
        const SizedBox(height: 10),
        Text(
          phaseStatusText(timeline, isKg: isKg),
          key: const Key('phase_status'),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            LegendItem(swatch: LegendDot(color: colors.accentPrimary), label: 'Losing'),
            LegendItem(swatch: LegendDot(color: _maintainColor(colors)), label: 'Maintenance'),
          ],
        ),
      ],
    );
  }
}

Color _maintainColor(CustomColors colors) => colors.textSecondary.withValues(alpha: 0.55);

class _TimelineBar extends StatelessWidget {
  const _TimelineBar({required this.timeline});

  final PhaseTimeline timeline;

  static const _height = 10.0;
  static const _gap = 3.0;
  static const _marker = 18.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    final segments = timeline.segments;
    final total = segments.fold<double>(0, (a, s) => a + s.weeks);
    // A short break still needs to be visible and tappable-looking.
    final floor = total * 0.05;
    final weights = [for (final s in segments) s.weeks < floor ? floor : s.weeks];
    final sum = weights.fold<double>(0, (a, w) => a + w);

    return Semantics(
      label: 'Phase timeline',
      child: LayoutBuilder(builder: (context, box) {
        final usable = box.maxWidth - _gap * (segments.length - 1);
        // The marker sits in its own segment, as far along as the phase is.
        var x = 0.0;
        var markerX = 0.0;
        for (var i = 0; i < segments.length; i++) {
          final w = usable * weights[i] / sum;
          if (segments[i].state == SegmentState.current) {
            final elapsed = timeline.marker * total -
                segments
                    .where((s) => s.state == SegmentState.done)
                    .fold<double>(0, (a, s) => a + s.weeks);
            markerX = x + w * (elapsed / segments[i].weeks).clamp(0.0, 1.0);
          }
          x += w + _gap;
        }
        return SizedBox(
          height: _marker,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Row(
                children: [
                  for (var i = 0; i < segments.length; i++) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    Expanded(
                      flex: (weights[i] * 1000).round(),
                      child: Container(
                        key: Key('phase_segment_$i'),
                        height: _height,
                        decoration: BoxDecoration(
                          color: _segmentColor(colors, segments[i]),
                          borderRadius: BorderRadius.circular(_height / 2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Positioned(
                left: (markerX - _marker / 2).clamp(0.0, box.maxWidth - _marker),
                child: Container(
                  key: const Key('phase_marker'),
                  width: _marker,
                  height: _marker,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.cardBackground,
                    border: Border.all(color: colors.textPrimary, width: 2.5),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Color _segmentColor(CustomColors colors, TimelineSegment s) {
    final base = s.kind == PhaseKind.lose ? colors.accentPrimary : _maintainColor(colors);
    return s.state == SegmentState.upcoming ? base.withValues(alpha: base.a * 0.4) : base;
  }
}

/// The status line under the timeline (plan 9.6): "Phase 2 · Losing · 3.1 of
/// 4.2 kg · about 5 weeks left" or "Maintenance break · week 2 of 4 · then
/// losing resumes Nov 3".
@visibleForTesting
String phaseStatusText(PhaseTimeline t, {required bool isKg}) {
  String weight(double kg) {
    final v = isKg ? kg : kg * 2.20462;
    return v.toStringAsFixed(1);
  }

  final unit = isKg ? 'kg' : 'lbs';
  final end = t.endsAtCheckin ? 'ends at your next check-in' : null;

  if (t.kind == PhaseKind.lose) {
    final parts = ['Phase ${t.phaseNumber}', 'Losing'];
    if (t.phaseGoalKg != null && t.lostKg != null) {
      final done = t.lostKg! > t.phaseGoalKg! ? t.phaseGoalKg! : t.lostKg!;
      parts.add('${weight(done)} of ${weight(t.phaseGoalKg!)} $unit');
    } else if (t.plannedWeeks != null) {
      parts.add('week ${t.weeksIn} of ${t.plannedWeeks}');
      if (t.lostKg != null) parts.add('${weight(t.lostKg!)} $unit lost');
    } else {
      parts.add('week ${t.weeksIn}');
    }
    if (end != null) {
      parts.add(end);
    } else if (t.weeksLeft != null && t.phaseGoalKg != null) {
      parts.add('about ${_weeks(t.weeksLeft!)} left');
    } else if (t.weeksLeft != null) {
      parts.add('${_weeks(t.weeksLeft!)} until your break');
    }
    return parts.join(' · ');
  }

  final parts = ['Maintenance break'];
  if (t.plannedWeeks != null) parts.add('week ${t.weeksIn} of ${t.plannedWeeks}');
  if (end != null) {
    parts.add(end);
  } else if (t.resumesOn != null) {
    parts.add('then losing resumes ${DateFormat('MMM d').format(t.resumesOn!)}');
  }
  return parts.join(' · ');
}

String _weeks(int n) => n <= 1 ? '1 week' : '$n weeks';

/// The card's overflow menu: "End phase early", with a confirm. Once the
/// phase is going to end at the next check-in (asked for, or due anyway) the
/// item says so and does nothing.
class _PhaseMenu extends StatelessWidget {
  const _PhaseMenu({required this.timeline});

  final PhaseTimeline timeline;

  Future<void> _confirm(BuildContext context) async {
    final energy = Provider.of<EnergyProvider>(context, listen: false);
    final goals = Provider.of<GoalsProvider>(context, listen: false);
    final losing = timeline.kind == PhaseKind.lose;
    final checkin = checkinDayText(
        energy.nextCheckinDay ?? goals.nextCheckinDay, DateTime.now());
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialog) => CupertinoAlertDialog(
        title: const Text('End this phase early?'),
        content: Text(
          'At your next check-in ($checkin) '
          '${losing ? 'you will move to a maintenance break' : 'losing will start again'}'
          ', with new targets.',
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
            child: const Text('End phase'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    trackPhaseAction(PhaseAction.endEarly);
    await energy.endPhaseEarly();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    final pending = timeline.endsAtCheckin;
    return PopupMenuButton<void>(
      key: const Key('phase_menu'),
      tooltip: 'Phase options',
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_horiz_rounded, color: colors.textSecondary),
      color: colors.cardBackground,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => [
        PopupMenuItem<void>(
          key: const Key('phase_end_early'),
          enabled: !pending,
          onTap: () => _confirm(context),
          child: Text(
            pending ? 'Ends at your next check-in' : 'End phase early',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: pending ? colors.textSecondary : colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
