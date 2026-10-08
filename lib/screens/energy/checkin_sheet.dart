import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/energy_provider.dart';
import '../../providers/weight_unit_provider.dart';
import '../../services/energy/checkin.dart';
import '../../services/energy/constants.dart';
import '../../services/energy/energy_estimator.dart';
import '../../services/energy/phase_engine.dart';
import '../../services/energy/targets.dart';
import '../../services/posthog_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/plan_style_choice.dart';

/// Where a check-in sheet was opened from, for `checkin_shown`.
enum CheckinSheetSource { auto, chip, history }

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
        isKg: units.isKg, lossPhaseNumber: _lossPhaseNumber(energy?.phases ?? const []));
    final changed = checkin.variant.appliesTargets;
    final phaseChange = checkin.variant.isPhaseChange;
    final canChange = phaseChange && (energy?.canChangePhase(checkin) ?? false);
    final phaseBody = copy.phaseBody;
    final alternative = canChange ? copy.secondaryAction : null;
    final secondary =
        GoogleFonts.inter(fontSize: 14, height: 1.45, color: colors.textSecondary);
    final limitLine = copy.limitLine;
    final missing = copy.missing;
    final why = copy.whyLines;
    final footer = copy.footer;

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
              const SizedBox(height: 14),
              Text.rich(
                key: const Key('checkin_target'),
                TextSpan(
                  children: [
                    if (changed)
                      TextSpan(
                        text: '${fmtCals(checkin.oldTargets.cals)} → ',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    TextSpan(text: fmtCals(checkin.newTargets.cals)),
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
              Text(copy.macroLine, style: secondary),
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
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accentPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    copy.primaryAction,
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
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

  /// G's "Ready for phase N": the loss phases before the one it started, + 1.
  int? _lossPhaseNumber(List<GoalPhase> phases) {
    final next = checkin.reason.phase?.next;
    if (next == null || next.kind != PhaseKind.lose || phases.isEmpty) return null;
    return phases.where((p) => p.kind == PhaseKind.lose && p.seq < next.seq).length + 1;
  }
}

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
        CheckinVariant.phaseToMaintain => _breakTitle,
        CheckinVariant.phaseToLose =>
          lossPhaseNumber == null ? 'Ready for your next phase' : 'Ready for phase $lossPhaseNumber',
        _ => 'Weekly check-in',
      };

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
        CheckinVariant.unchanged || CheckinVariant.insufficient => 'Your targets stay the same.',
        _ => null,
      };

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
    if (checkin.variant == CheckinVariant.insufficient || checkin.variant.isPhaseChange) {
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
