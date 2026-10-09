import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/detailed_stats_provider.dart';
import '../../providers/energy_provider.dart';
import '../../providers/finish_reminder_provider.dart';
import '../../providers/weight_unit_provider.dart';
import '../../services/energy/checkin.dart';
import '../../services/energy/constants.dart';
import '../../services/energy/energy_estimator.dart';
import '../../services/energy/energy_summary.dart';
import '../../services/energy/phase_engine.dart';
import '../../services/energy/targets.dart';
import '../../services/posthog_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/finish_reminder_button.dart';
import '../../widgets/plan_style_choice.dart';
import '../onboarding/onboarding_screen.dart';

/// Where a check-in sheet was opened from, for `checkin_shown`.
enum CheckinSheetSource { auto, chip, history, chart }

/// Shows [checkin]'s sheet (plan 9.5). Dismissing it, any way, records
/// `seen_at`. Tracks `checkin_shown{variant}` and
/// `checkin_dismissed{variant, seconds}`.
Future<void> showCheckinSheet(
  BuildContext context,
  GoalCheckin checkin, {
  CheckinSheetSource source = CheckinSheetSource.auto,
}) async {
  final colors = Theme.of(context).extension<CustomColors>()!;
  final energy = Provider.of<EnergyProvider>(context, listen: false);
  final variant = checkin.variant.code;
  PostHogService.trackEvent('checkin_shown', properties: {
    'variant': variant,
    'source': source.name,
  });
  final watch = Stopwatch()..start();
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: colors.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => CheckinSheet(checkin: checkin),
  );
  PostHogService.trackEvent('checkin_dismissed', properties: {
    'variant': variant,
    'seconds': watch.elapsed.inSeconds,
  });
  await energy.markCheckinSeen(checkin);
}

/// The weekly check-in sheet: what happened to the targets and why.
///
/// A: changed, with the limit line (E) when a limit set the target.
/// B: under 25 cals, unchanged. C: not enough data. Copy is adherence-neutral
/// (plan 9.5): "you averaged", never "you went over".
/// D (plan 9.5): the goal weight was reached. The one check-in that asks
/// instead of applying: Switch to maintenance or Set a new goal, while the
/// choice is still open.
/// F and G (plan 9.6): a phase ended into a maintenance break or the next
/// loss phase. Their second choice ("Keep losing instead", "Extend break")
/// is offered while it can still be made.
class CheckinSheet extends StatelessWidget {
  const CheckinSheet({super.key, required this.checkin});

  final GoalCheckin checkin;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    final units = context.watch<WeightUnitProvider>();
    final energy = context.watch<EnergyProvider?>();
    final copy = CheckinCopy(checkin,
        isKg: units.isKg, lossPhaseNumber: lossPhaseNumber(checkin, energy?.phases ?? const []));
    final changed = checkin.variant.appliesTargets;
    final phaseChange = checkin.variant.isPhaseChange;
    final canChange = phaseChange && (energy?.canChangePhase(checkin) ?? false);
    final phaseBody = copy.phaseBody;
    final alternative = canChange ? copy.secondaryAction : null;
    final goalReached = checkin.variant == CheckinVariant.goalReached;
    final canChoose = goalReached && (energy?.canChooseGoal(checkin) ?? false);
    final maintenance = canChoose ? energy!.maintenanceTargets(checkin) : null;
    final secondary =
        GoogleFonts.inter(fontSize: 14, height: 1.45, color: colors.textSecondary);
    final limitLine = copy.limitLine;
    final missing = copy.missing;
    final why = copy.whyLines;
    final footer = copy.footer;

    final detailed = context.watch<DetailedStatsProvider?>()?.showDetailedStats ?? false;
    if (!detailed) {
      return _SimpleCheckinSheet(
        checkin: checkin,
        copy: SimpleCheckinCopy(checkin, isKg: units.isKg),
        maintenance: maintenance,
        canChoose: canChoose,
        alternative: alternative,
        primaryAction: canChoose && maintenance != null ? 'Switch to maintenance' : copy.primaryAction,
        onPrimary: () {
          HapticFeedback.lightImpact();
          if (checkin.variant == CheckinVariant.phaseToMaintain && canChange) {
            trackPhaseAction(PhaseAction.startBreak);
          }
          if (canChoose && maintenance != null) {
            _switchToMaintenance(context, energy!);
          } else {
            Navigator.pop(context);
          }
        },
        onSetNewGoal: () => _setNewGoal(context),
        onAlternative: () => _changePhase(context, energy!),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
          child: Column(
            key: Key('checkin_sheet_${checkin.variant.code}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                copy.eyebrow,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                copy.title,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              if (copy.subtitle case final subtitle?) ...[
                const SizedBox(height: 4),
                Text(subtitle, style: secondary),
              ],
              if (!goalReached || maintenance != null) ...[
                const SizedBox(height: 14),
                if (goalReached) ...[
                  Text('If you switch to maintenance', style: secondary),
                  const SizedBox(height: 2),
                ],
                Text.rich(
                  key: const Key('checkin_target'),
                  TextSpan(
                    children: [
                      if (changed || goalReached)
                        TextSpan(
                          text: '${fmtCals(checkin.oldTargets.cals)} → ',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      TextSpan(text: fmtCals((maintenance ?? checkin.newTargets).cals)),
                      TextSpan(
                        text: ' cals',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: colors.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(copy.macroLineFor(maintenance), style: secondary),
              ],
              if (phaseBody != null) ...[
                const SizedBox(height: 14),
                Text(
                  phaseBody,
                  key: const Key('checkin_phase_body'),
                  style: GoogleFonts.inter(fontSize: 14, height: 1.45, color: colors.textPrimary),
                ),
              ],
              if (limitLine != null) ...[
                const SizedBox(height: 14),
                _Note(key: const Key('checkin_limit_line'), text: limitLine),
              ],
              if (missing != null) ...[
                const SizedBox(height: 14),
                _Note(key: const Key('checkin_missing'), text: missing),
                // Variant C is about days that weren't finished: the one
                // place besides the Energy tip that offers the reminder.
                if (checkin.variant == CheckinVariant.insufficient) ...[
                  const SizedBox(height: 10),
                  const FinishReminderButton(source: FinishReminderSource.checkin),
                ],
              ],
              if (why.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  changed ? 'Why it changed' : 'This week',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                for (final line in why)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•  ', style: secondary),
                        Expanded(child: Text(line, style: secondary)),
                      ],
                    ),
                  ),
              ],
              if (footer != null) ...[
                const SizedBox(height: 14),
                Text(
                  footer,
                  key: const Key('checkin_footer'),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('checkin_done'),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    if (checkin.variant == CheckinVariant.phaseToMaintain && canChange) {
                      trackPhaseAction(PhaseAction.startBreak);
                    }
                    if (canChoose && maintenance != null) {
                      _switchToMaintenance(context, energy!);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accentPrimary,
                    foregroundColor: colors.onAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    canChoose && maintenance != null ? 'Switch to maintenance' : copy.primaryAction,
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (canChoose) ...[
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    key: const Key('checkin_set_new_goal'),
                    onPressed: () => _setNewGoal(context),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Set a new goal',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
              if (alternative != null) ...[
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    key: const Key('checkin_phase_alternative'),
                    onPressed: () => _changePhase(context, energy!),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      alternative,
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// D's "Switch to maintenance", then close.
  Future<void> _switchToMaintenance(BuildContext context, EnergyProvider energy) async {
    final navigator = Navigator.of(context);
    trackGoalReachedAction(GoalReachedAction.switchToMaintenance);
    await energy.switchToMaintenance(checkin);
    navigator.pop();
  }

  /// D's "Set a new goal": close, then the recalculate flow.
  void _setNewGoal(BuildContext context) {
    HapticFeedback.lightImpact();
    trackGoalReachedAction(GoalReachedAction.setNewGoal);
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(CupertinoPageRoute<void>(
      builder: (_) => const OnboardingScreen(recalculateOnly: true, goalReached: true),
    ));
  }

  /// "Keep losing instead" (F) or "Extend break" (G), then close.
  Future<void> _changePhase(BuildContext context, EnergyProvider energy) async {
    HapticFeedback.lightImpact();
    final navigator = Navigator.of(context);
    if (checkin.variant == CheckinVariant.phaseToMaintain) {
      trackPhaseAction(PhaseAction.keepLosing);
      await energy.keepLosing(checkin);
    } else {
      trackPhaseAction(PhaseAction.extend);
      await energy.extendBreak(checkin);
    }
    navigator.pop();
  }
}

/// Simple mode's sheet (SIMP-S4): "Weekly check-in · Oct 5", D/F/G's news,
/// "New daily target: 2,451 cals", "56 less than before", one sentence of
/// why, the macros on one quiet line, then the old bullets behind "Why?".
/// Same keys, buttons and actions as the detailed sheet.
class _SimpleCheckinSheet extends StatefulWidget {
  const _SimpleCheckinSheet({
    required this.checkin,
    required this.copy,
    required this.maintenance,
    required this.canChoose,
    required this.alternative,
    required this.primaryAction,
    required this.onPrimary,
    required this.onSetNewGoal,
    required this.onAlternative,
  });

  final GoalCheckin checkin;
  final SimpleCheckinCopy copy;

  /// D: the maintenance targets on offer while the choice is open.
  final CheckinTargets? maintenance;
  final bool canChoose;
  final String? alternative;
  final String primaryAction;
  final VoidCallback onPrimary;
  final VoidCallback onSetNewGoal;
  final VoidCallback onAlternative;

  @override
  State<_SimpleCheckinSheet> createState() => _SimpleCheckinSheetState();
}

class _SimpleCheckinSheetState extends State<_SimpleCheckinSheet> {
  bool _why = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    final copy = widget.copy;
    final checkin = widget.checkin;
    final goalReached = checkin.variant == CheckinVariant.goalReached;
    final headline = copy.headline;
    final change = copy.changeLine;
    final details = copy.details(canChooseGoal: widget.canChoose);
    // D shows the maintenance target it offers, and no target once chosen.
    final targets = goalReached ? widget.maintenance : checkin.newTargets;
    final quiet = GoogleFonts.inter(fontSize: 13, height: 1.4, color: colors.textSecondary);
    final secondaryStyle = GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
          child: Column(
            key: Key('checkin_sheet_${checkin.variant.code}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                copy.title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              if (headline != null) ...[
                const SizedBox(height: 6),
                Text(
                  headline,
                  key: const Key('checkin_headline'),
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ],
              if (targets != null) ...[
                SizedBox(height: headline == null ? 10 : 14),
                Text(
                  goalReached ? 'To stay at this weight' : copy.targetLabel,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  key: const Key('checkin_target'),
                  TextSpan(children: [
                    TextSpan(text: fmtCals(targets.cals)),
                    TextSpan(
                      text: goalReached ? ' cals a day' : ' cals',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                  ]),
                  style: GoogleFonts.inter(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                    color: colors.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (change != null)
                  Text(change, key: const Key('checkin_change'), style: quiet),
              ],
              const SizedBox(height: 14),
              Text(
                goalReached && !widget.canChoose ? copy.goalSettled : copy.why,
                key: const Key('checkin_why'),
                style: GoogleFonts.inter(fontSize: 15, height: 1.45, color: colors.textPrimary),
              ),
              if (checkin.variant == CheckinVariant.insufficient) ...[
                const SizedBox(height: 12),
                const FinishReminderButton(source: FinishReminderSource.checkin),
              ],
              if (targets != null) ...[
                const SizedBox(height: 14),
                Text(copy.macroLine(targets), key: const Key('checkin_macros'), style: quiet),
              ],
              if (details.isNotEmpty) ...[
                const SizedBox(height: 10),
                InkWell(
                  key: const Key('checkin_why_toggle'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _why = !_why);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Why?',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.accentPrimary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          _why ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          size: 20,
                          color: colors.accentPrimary,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_why)
                  Column(
                    key: const Key('checkin_why_details'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final line in details)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('•  ', style: quiet.copyWith(fontSize: 14)),
                              Expanded(child: Text(line, style: quiet.copyWith(fontSize: 14))),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('checkin_done'),
                  onPressed: widget.onPrimary,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accentPrimary,
                    foregroundColor: colors.onAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(widget.primaryAction, style: secondaryStyle),
                ),
              ),
              // D's two choices are equal: the second is a full outlined button.
              if (widget.canChoose) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: const Key('checkin_set_new_goal'),
                    onPressed: widget.onSetNewGoal,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.textSecondary.withValues(alpha: 0.35)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Set a new goal', style: secondaryStyle),
                  ),
                ),
              ],
              if (widget.alternative case final alternative?) ...[
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    key: const Key('checkin_phase_alternative'),
                    onPressed: widget.onAlternative,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(alternative, style: secondaryStyle),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// What the user did on the goal-reached check-in.
enum GoalReachedAction {
  switchToMaintenance('switch_to_maintenance'),
  setNewGoal('set_new_goal');

  const GoalReachedAction(this.code);

  final String code;
}

/// Sends `goal_reached_action{action}`.
void trackGoalReachedAction(GoalReachedAction action) =>
    PostHogService.trackEvent('goal_reached_action', properties: {'action': action.code});

/// A tinted line set apart from the rest: the limit line, what's missing.
class _Note extends StatelessWidget {
  const _Note({super.key, required this.text});

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
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: colors.textPrimary),
      ),
    );
  }
}

/// G's "Ready for phase N": the loss phases before the one [checkin]
/// started, + 1; null when it didn't start one or the phases aren't known.
int? lossPhaseNumber(GoalCheckin checkin, List<GoalPhase> phases) {
  final next = checkin.reason.phase?.next;
  if (next == null || next.kind != PhaseKind.lose || phases.isEmpty) return null;
  return phases.where((p) => p.kind == PhaseKind.lose && p.seq < next.seq).length + 1;
}

String fmtCals(num cals) => NumberFormat.decimalPattern().format(cals.round());

/// The sheet's words for a check-in (plan 9.5).
@visibleForTesting
class CheckinCopy {
  CheckinCopy(this.checkin, {this.isKg = true, this.lossPhaseNumber});

  final GoalCheckin checkin;
  final bool isKg;

  /// G: which loss phase starts, when the phases are known.
  final int? lossPhaseNumber;

  CheckinReason get _r => checkin.reason;

  String get eyebrow => 'Weekly check-in · ${DateFormat('MMM d').format(checkin.weekStart)}';

  String get title => switch (checkin.variant) {
        CheckinVariant.changed => 'Your new daily target',
        CheckinVariant.unchanged => "You're right on track",
        CheckinVariant.insufficient => 'Not enough data to update this week',
        CheckinVariant.goalReached => _goalTitle,
        CheckinVariant.phaseToMaintain => _breakTitle,
        CheckinVariant.phaseToLose =>
          lossPhaseNumber == null ? 'Ready for your next phase' : 'Ready for phase $lossPhaseNumber',
      };

  /// D's headline: "You've reached 75 kg 🎉".
  String get _goalTitle {
    final goal = _r.goalWeightKg;
    return goal == null
        ? "You've reached your goal 🎉"
        : "You've reached ${_weight(goal, places: 1)} 🎉";
  }

  /// F's headline, by why the loss phase ended.
  String get _breakTitle {
    final ended = _r.phase?.ended;
    return switch (ended?.endReason) {
      PhaseEndReason.reached when ended?.targetPct != null =>
        "You've lost ${_pctNum(ended!.targetPct!)}% — time for a maintenance break 🎉",
      PhaseEndReason.maxDuration =>
        '${ended!.weeksOn(ended.endedOn!).round()} weeks of losing done — time for a maintenance break',
      PhaseEndReason.planned =>
        '${ended!.weeksOn(ended.endedOn!).round()} weeks done — time for a diet break',
      _ => 'Time for a maintenance break',
    };
  }

  /// F and G: what the new phase holds (plan 9.6).
  String? get phaseBody {
    final next = _r.phase?.next;
    if (next == null) return null;
    final cals = fmtCals(checkin.newTargets.cals);
    final weeks = _r.phaseWeeks?.round();
    if (checkin.variant == CheckinVariant.phaseToMaintain) {
      final rise = isKg ? '0.5–1.5 kg' : '1–3 lbs';
      final up = checkin.newTargets.cals >= checkin.oldTargets.cals ? 'goes up to' : 'is';
      final span = weeks == null ? '' : ' for the next $weeks week${weeks == 1 ? '' : 's'}';
      return 'Your target $up $cals cals$span. Expect the scale to rise $rise in the '
          'first few days. That\'s water and glycogen, not fat.';
    }
    final parts = ['New target $cals cals'];
    final pct = next.targetPct;
    if (pct != null) {
      parts.add('aiming to lose ${_weight(next.startTrendKg * pct / 100, places: 1, keepZero: true)} '
          '(${_pctNum(pct)}%)');
      if (weeks != null) parts.add('about $weeks week${weeks == 1 ? '' : 's'}');
    } else if (weeks != null) {
      parts.add('$weeks weeks until your next break');
    }
    return parts.join(' · ');
  }

  /// One line for the check-in history (spec 7.1 R6): why it changed, or
  /// why it didn't.
  String get summary {
    switch (checkin.variant) {
      case CheckinVariant.changed:
        final diff = ((_r.tdee - _r.tdeePrev) / 10).round() * 10;
        return diff.abs() < 10
            ? 'Adjusted to your trend weight'
            : 'Burning about ${fmtCals(diff.abs())} cals '
                '${diff > 0 ? 'more' : 'less'} than expected';
      case CheckinVariant.unchanged:
        return 'Right on track, no change';
      case CheckinVariant.insufficient:
        return _r.state == EnergyState.paused
            ? 'Estimate paused, targets kept'
            : 'Not enough data yet, targets kept';
      case CheckinVariant.goalReached:
        return 'Goal weight reached';
      case CheckinVariant.phaseToMaintain:
        return 'Maintenance break started';
      case CheckinVariant.phaseToLose:
        return lossPhaseNumber == null
            ? 'Next loss phase started'
            : 'Phase $lossPhaseNumber started';
    }
  }

  /// The sheet's main button.
  String get primaryAction => switch (checkin.variant) {
        CheckinVariant.phaseToMaintain => 'Start break',
        CheckinVariant.phaseToLose => "Let's go",
        _ => 'Got it',
      };

  /// F and G's other choice.
  String? get secondaryAction => switch (checkin.variant) {
        CheckinVariant.phaseToMaintain => 'Keep losing instead',
        CheckinVariant.phaseToLose => 'Extend break $kExtendBreakWeeks weeks',
        _ => null,
      };

  static String _pctNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  String? get subtitle => switch (checkin.variant) {
        CheckinVariant.goalReached => _goalSubtitle,
        CheckinVariant.unchanged || CheckinVariant.insufficient => 'Your targets stay the same.',
        _ => null,
      };

  /// D: where the trend weight is, and that nothing changes until a choice.
  String get _goalSubtitle {
    final trend = _r.trendWeightKg;
    final at = trend == null
        ? ''
        : 'Your trend weight is ${_weight(trend, places: 1, keepZero: true)}. ';
    return '${at}Your targets stay as they are until you choose.';
  }

  /// [macroLine], or for D the macros of the maintenance [targets] it offers.
  String macroLineFor(CheckinTargets? targets) {
    if (targets == null) return macroLine;
    return CheckinCopy(GoalCheckin(
      weekStart: checkin.weekStart,
      variant: checkin.variant,
      oldTargets: checkin.oldTargets,
      newTargets: targets,
      reason: checkin.reason,
      createdAt: checkin.createdAt,
    )).macroLine;
  }

  /// "Protein 150 g · Carbs 220 g (+12) · Fat 65 g": a change shows only
  /// when it's 5 g or more.
  String get macroLine {
    final o = checkin.oldTargets;
    final n = checkin.newTargets;
    String part(String name, int now, int was) {
      final d = now - was;
      final delta = d.abs() >= 5 ? ' (${d > 0 ? '+' : '−'}${d.abs()})' : '';
      return '$name $now g$delta';
    }

    return [
      part('Protein', n.protein, o.protein),
      part('Carbs', n.carbs, o.carbs),
      part('Fat', n.fat, o.fat),
    ].join(' · ');
  }

  /// Variant E: the limit that set the new target (A, and F/G).
  String? get limitLine {
    if (!checkin.variant.appliesTargets) return null;
    final cals = fmtCals(checkin.newTargets.cals);
    return switch (_r.limitHit) {
      SafetyLimit.floor =>
        'We kept your target at $cals cals, our minimum, so your pace may be a little slower.',
      SafetyLimit.maxDeficit => 'We kept your target at $cals cals, no more than '
          '${(kMaxDeficitFrac * 100).round()}% below what you burn, so your pace may be a '
          'little slower.',
      SafetyLimit.maxLossPace => 'We kept your target at $cals cals so you lose no more '
          'than ${_pct(kMaxLossPct)} of your weight a week.',
      SafetyLimit.maxSurplus => 'We kept your target at $cals cals, no more than '
          '${(kMaxSurplusFrac * 100).round()}% above what you burn, so your pace may be a '
          'little slower.',
      SafetyLimit.maxGainPace => 'We kept your target at $cals cals so you gain no more '
          'than ${_pct(kMaxGainPct)} of your weight a week.',
      SafetyLimit.checkinStep => 'We moved it ${kMaxCheckinStep.round()} cals, the most we '
          'change in one week. The rest follows at your next check-in.',
      null => null,
    };
  }

  /// Variant C: what the estimate still needs.
  String? get missing {
    if (checkin.variant != CheckinVariant.insufficient) return null;
    if (_r.state == EnergyState.paused) {
      return 'Your expenditure estimate is paused. It needs at least one finished day '
          'and one weigh-in a week to keep learning.';
    }
    String n(int v, String one) => '$v $one${v == 1 ? '' : 's'}';
    return 'We need $kMinCompleteDays complete days and $kMinWeighIns weigh-ins in the '
        'last 3 weeks. So far: ${n(_r.completeDays, 'complete day')}, '
        '${n(_r.weighIns, 'weigh-in')}. Tap Finish day on Home when you\'ve logged '
        'everything.';
  }

  /// The "why" bullets (A and B).
  List<String> get whyLines {
    if (checkin.variant != CheckinVariant.changed &&
        checkin.variant != CheckinVariant.unchanged) {
      return const [];
    }
    final out = <String>[];
    final avg = _r.avgIntake;
    if (avg != null && _r.completeDays > 0) {
      out.add('You averaged ${fmtCals(avg)} cals on ${_r.completeDays} complete '
          'day${_r.completeDays == 1 ? '' : 's'} in the last 3 weeks');
    }
    final change = _r.trendChangeKg;
    if (change != null) {
      final amount = _weight(change.abs());
      final moved = change.abs() < 0.05
          ? 'Your trend weight held steady this week'
          : 'Your trend weight ${change < 0 ? 'fell' : 'rose'} $amount this week';
      out.add('$moved${_paceNote(change)}');
    }
    final diff = ((_r.tdee - _r.tdeePrev) / 10).round() * 10;
    out.add(diff.abs() < 10
        ? 'Your expenditure is about what we expected, ${fmtCals(_r.tdee)} cals a day'
        : 'Your expenditure is about ${fmtCals(diff.abs())} cals '
            '${diff > 0 ? 'higher' : 'lower'} than we thought, about '
            '${fmtCals(_r.tdee)} cals a day');
    return out;
  }

  /// "(on pace for −0.5%/wk)" when the week's change is within ±0.15%/wk of
  /// the chosen pace (the Weight tab's neutral band).
  String _paceNote(double changeKg) {
    final weight = _r.trendWeightKg;
    if (_r.pacePct <= 0 || weight == null || weight <= 0) return '';
    final goalPct = _r.goal == GoalKind.lose ? -_r.pacePct : _r.pacePct;
    final actual = changeKg / weight * 100;
    if ((actual - goalPct).abs() > 0.15) return '';
    return ' (on pace for ${goalPct < 0 ? '−' : '+'}${_pct(goalPct.abs())}/wk)';
  }

  /// "This week: −0.45 kg · Goal 75 kg · about 11 weeks to go".
  String? get footer {
    if (checkin.variant == CheckinVariant.insufficient ||
        checkin.variant == CheckinVariant.goalReached ||
        checkin.variant.isPhaseChange) {
      return null;
    }
    final parts = <String>[];
    final change = _r.trendChangeKg;
    if (change != null) {
      final sign = change.abs() < 0.005 ? '' : (change < 0 ? '−' : '+');
      parts.add('This week: $sign${_weight(change.abs())}');
    }
    final goal = _r.goalWeightKg;
    if (goal != null && _r.pacePct > 0) parts.add('Goal ${_weight(goal, places: 1)}');
    final weeks = _r.weeksToGoal;
    if (weeks != null && weeks > 0) {
      final n = weeks.round().clamp(1, 999);
      parts.add('about $n week${n == 1 ? '' : 's'} to go');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String _weight(double kg, {int places = 2, bool keepZero = false}) {
    final v = isKg ? kg : kg * 2.20462;
    var s = v.toStringAsFixed(places);
    if (s.contains('.') && !keepZero) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
    return '$s ${isKg ? 'kg' : 'lbs'}';
  }

  static String _pct(double p) {
    var s = p.toStringAsFixed(2);
    s = s.replaceFirst(RegExp(r'\.?0+$'), '');
    return '$s%';
  }
}

/// The simple sheet's words (SIMP-S4): a target, one sentence of why and
/// plain "Why?" details. Every sentence is picked from the check-in's
/// variant and reason, never free text, and none of it uses the detailed
/// words (expenditure, trend weight, %, phase).
@visibleForTesting
class SimpleCheckinCopy {
  SimpleCheckinCopy(this.checkin, {this.isKg = true});

  final GoalCheckin checkin;
  final bool isKg;

  CheckinReason get _r => checkin.reason;
  CheckinVariant get _v => checkin.variant;

  /// "Weekly check-in · Oct 5".
  String get title => 'Weekly check-in · ${DateFormat('MMM d').format(checkin.weekStart)}';

  /// D, F and G's news, above the target; null for the weekly ones.
  String? get headline => switch (_v) {
        CheckinVariant.goalReached => _r.goalWeightKg == null
            ? 'You reached your goal! 🎉'
            : 'You reached ${_weight(_r.goalWeightKg!)}! 🎉',
        CheckinVariant.phaseToMaintain => _r.phase?.ended.endReason == PhaseEndReason.planned
            ? 'Time for a diet break'
            : 'Time for a maintenance break',
        CheckinVariant.phaseToLose => 'Back to losing',
        _ => null,
      };

  /// "New daily target" when the check-in set one, else "Daily target".
  String get targetLabel => _v.appliesTargets ? 'New daily target' : 'Daily target';

  /// "56 less than before"; null when the target didn't move.
  String? get changeLine {
    if (!_v.appliesTargets) return null;
    final d = checkin.newTargets.cals - checkin.oldTargets.cals;
    if (d == 0) return null;
    return '${fmtCals(d.abs())} ${d < 0 ? 'less' : 'more'} than before';
  }

  /// "Protein 112 g · Carbs 348 g · Fat 68 g", no deltas.
  String macroLine([CheckinTargets? targets]) {
    final t = targets ?? checkin.newTargets;
    return 'Protein ${t.protein} g · Carbs ${t.carbs} g · Fat ${t.fat} g';
  }

  /// Which way the burn moved against what the old targets came from:
  /// 1 up, -1 down, 0 about the same (under 10 cals).
  int get _burnMove {
    final diff = ((_r.tdee - _r.tdeePrev) / 10).round() * 10;
    return diff.abs() < 10 ? 0 : diff.sign;
  }

  /// Which way the target moved: 1 up, -1 down, 0 not at all.
  int get _targetMove => (checkin.newTargets.cals - checkin.oldTargets.cals).sign;

  /// The one sentence of why, by variant and the reason's limit and burn.
  String get why {
    switch (_v) {
      case CheckinVariant.changed:
        final burnAgrees = _burnMove != 0 && _burnMove == _targetMove;
        return switch (_r.limitHit) {
          SafetyLimit.floor =>
            "This is the lowest target we recommend, so progress may be a little slower.",
          SafetyLimit.maxDeficit || SafetyLimit.maxLossPace =>
            "We've kept your target here so you lose weight at a safe pace.",
          SafetyLimit.maxSurplus || SafetyLimit.maxGainPace =>
            "We've kept your target here so you gain weight at a steady pace.",
          SafetyLimit.checkinStep => !burnAgrees
              ? "We're moving your target a little at a time to match what you burn."
              : _burnMove > 0
                  ? "You burn more than we thought, so we're raising your target a little at a time."
                  : "You burn less than we thought, so we're lowering your target a little at a time.",
          null => burnAgrees
              ? _burnMove > 0
                  ? 'You burn a bit more than we thought, so you can eat a little more.'
                  : "You burn a bit less than we thought, so we've eased your target down a little."
              : _burnMove == 0
                  ? "Your weight has changed, so we've adjusted your target to match."
                  : "We've fine-tuned your target to match what you burn.",
        };
      case CheckinVariant.unchanged:
        return _r.limitHit == SafetyLimit.floor
            ? 'Your target is already the lowest we recommend, so it stays the same.'
            : 'Your target still fits your plan, so no change this week.';
      case CheckinVariant.insufficient:
        return _r.state == EnergyState.paused
            ? "You haven't logged much lately, so your target stays the same for now."
            : 'We need a few more days of logging to adjust. Your target stays the same.';
      case CheckinVariant.goalReached:
        return 'Great work! Choose what comes next: stay at this weight or set a new goal.';
      case CheckinVariant.phaseToMaintain:
        final ended = _r.phase?.ended;
        return switch (ended?.endReason) {
          PhaseEndReason.reached when ended?.targetPct != null =>
            "You've lost about ${_weight(ended!.startTrendKg * ended.targetPct! / 100)}, "
                'so it\'s time to give your body a rest.',
          PhaseEndReason.maxDuration =>
            "You've been losing for ${ended!.weeksOn(ended.endedOn!).round()} weeks, "
                'so it\'s time to give your body a rest.',
          PhaseEndReason.planned =>
            '${ended!.weeksOn(ended.endedOn!).round()} weeks done, so it\'s time for a '
                'short break from dieting.',
          _ => "It's time to give your body a rest from dieting.",
        };
      case CheckinVariant.phaseToLose:
        final goal = _r.goalWeightKg;
        return goal == null
            ? 'Your break is over, so your target goes back to losing weight.'
            : 'Your break is over, so your target goes back to losing toward ${_weight(goal)}.';
    }
  }

  /// D: what's said instead of [why] once the choice is no longer open.
  String get goalSettled => 'Great work reaching your goal!';

  String? get _limitNote => switch (_r.limitHit) {
        SafetyLimit.floor => 'This is the lowest daily target we recommend.',
        SafetyLimit.maxDeficit || SafetyLimit.maxLossPace =>
          "We've kept your target here so you lose weight at a safe pace.",
        SafetyLimit.maxSurplus || SafetyLimit.maxGainPace =>
          "We've kept your target here so you gain weight at a steady pace.",
        SafetyLimit.checkinStep =>
          'We change your target by at most ${kMaxCheckinStep.round()} cals a week.',
        null => null,
      };

  /// The "Why?" details: the old sheet's bullets in plain words.
  List<String> details({bool canChooseGoal = true}) {
    String n(int v, String one) => '$v $one${v == 1 ? '' : 's'}';
    switch (_v) {
      case CheckinVariant.changed:
      case CheckinVariant.unchanged:
        final out = <String>[];
        final avg = _r.avgIntake;
        if (avg != null && _r.completeDays > 0) {
          out.add('You averaged ${fmtCals(avg)} cals on ${n(_r.completeDays, 'fully logged day')} '
              'in the last 3 weeks.');
        }
        final change = _r.trendChangeKg;
        if (change != null) {
          out.add(change.abs() < 0.05
              ? 'Your weight held steady this week.'
              : 'Your weight ${change < 0 ? 'went down' : 'went up'} '
                  '${_weight(change.abs())} this week.');
        }
        out.add('You burn about ${fmtCals(roundToTen(_r.tdee))} cals a day.');
        if (_v == CheckinVariant.changed && _r.limitHit == SafetyLimit.checkinStep) {
          out.add('We change your target by at most ${kMaxCheckinStep.round()} cals a week. '
              "We'll check again next week.");
        }
        return out;
      case CheckinVariant.insufficient:
        if (_r.state == EnergyState.paused) {
          return const [
            'Log your food and weigh in at least once a week to keep your target up to date.'
          ];
        }
        return [
          'In the last 3 weeks: ${_r.completeDays.clamp(0, kMinCompleteDays)} of '
              '$kMinCompleteDays days fully logged and '
              '${_r.weighIns.clamp(0, kMinWeighIns)} of ${n(kMinWeighIns, 'weigh-in')}.',
          "Tap Finish day on Home when you've logged everything.",
        ];
      case CheckinVariant.goalReached:
        return [
          if (_r.trendWeightKg != null)
            'Your weight at this check-in was ${_weight(_r.trendWeightKg!)}.',
          if (canChooseGoal) 'Your target stays as it is until you choose.',
        ];
      case CheckinVariant.phaseToMaintain:
        final weeks = _r.phaseWeeks?.round();
        return [
          if (_limitNote case final note?) note,
          if (weeks != null)
            'Your new target lasts about ${n(weeks, 'week')}, then you go back to losing.',
          "Weight often jumps for a few days after a change. That's water, not fat.",
        ];
      case CheckinVariant.phaseToLose:
        final next = _r.phase?.next;
        final weeks = _r.phaseWeeks?.round();
        final pct = next?.targetPct;
        return [
          if (_limitNote case final note?) note,
          if (next != null && pct != null)
            'Aim to lose about ${_weight(next.startTrendKg * pct / 100)}'
                '${weeks == null ? '' : ' over about ${n(weeks, 'week')}'}.'
          else if (weeks != null)
            'Your next break is in about ${n(weeks, 'week')}.',
          "Weight often jumps for a few days after a change. That's water, not fat.",
        ];
    }
  }

  /// "65 kg" / "143.3 lbs": one decimal, dropped when it's .0.
  String _weight(double kg) {
    final v = isKg ? kg : kg * 2.20462;
    var s = v.toStringAsFixed(1);
    if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
    return '$s ${isKg ? 'kg' : 'lbs'}';
  }
}
