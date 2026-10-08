import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/goals_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/adaptive_choice.dart';
import '../../widgets/progress_card.dart';

/// Energy tab → the targets and how they're kept up to date (spec 7.1 R5).
///
/// Adaptive on: the current target and the next check-in day. Adaptive off:
/// the fixed target. Both have the "Weekly updates" switch, which confirms
/// with the onboarding question before changing anything.
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
    final cals = NumberFormat.decimalPattern().format(goals.caloriesGoal.round());
    final adaptive = goals.adaptiveGoals;
    final secondary =
        GoogleFonts.inter(fontSize: 13, color: colors.textSecondary, height: 1.4);

    return ProgressCard(
      key: const Key('energy_goals_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProgressCardTitle('Your targets', info: _info),
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
                                    goals.nextCheckinDay, DateTime.now()),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const TextSpan(
                                  text: '. Your targets will update from this '
                                      'estimate.'),
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
          Semantics(
            toggled: adaptive,
            label: 'Weekly updates',
            excludeSemantics: true,
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

/// "Today", "Tomorrow", or e.g. "Monday, Oct 12".
@visibleForTesting
String checkinDayText(DateTime day, DateTime now) {
  final d = DateTime(day.year, day.month, day.day);
  if (d == DateTime(now.year, now.month, now.day)) return 'Today';
  if (d == DateTime(now.year, now.month, now.day + 1)) return 'Tomorrow';
  return DateFormat('EEEE, MMM d').format(d);
}
