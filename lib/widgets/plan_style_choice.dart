import 'package:flutter/material.dart';

import '../services/energy/phase_engine.dart';
import '../services/energy/projection.dart';
import '../services/posthog_service.dart';
import '../theme/app_theme.dart';
import 'adaptive_choice.dart';

/// "How do you want to get there?" (plan 10.3): the copy for the plan styles,
/// shared by the onboarding step, the summary and the results screen.
abstract final class PlanStyleCopy {
  static const question = 'How do you want to get there?';

  static String title(PlanStyle style) => switch (style) {
        PlanStyle.steady => 'Steady',
        PlanStyle.phased => 'In phases',
        PlanStyle.breaks => 'With diet breaks',
      };

  /// [lossPct] is X for the user's weight (5% or 10%).
  static String body(
    PlanStyle style, {
    required double lossPct,
    PhaseSettings settings = const PhaseSettings(),
  }) =>
      switch (style) {
        PlanStyle.steady => 'Lose at a constant pace until you reach your goal.',
        PlanStyle.phased => 'Lose ${_n(lossPct)}% at a time, then take a '
            '${settings.maintenanceWeeks}-week maintenance break before the next phase. '
            'Same results, and many people find it easier to stick with.',
        PlanStyle.breaks => 'A ${settings.breakWeeks}-week break every '
            '${settings.breakEveryWeeks} weeks.',
      };

  /// "3 loss phases + 2 breaks · about 34 weeks".
  static String outline(PlanOutline o) {
    String n(int v, String one) => '$v $one${v == 1 ? '' : 's'}';
    final phases = n(o.lossPhases, 'loss phase');
    final breaks = o.breaks == 0 ? '' : ' + ${n(o.breaks, 'break')}';
    return '$phases$breaks · about ${o.weeks} week${o.weeks == 1 ? '' : 's'}';
  }

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

/// Sends `plan_style_chosen{style}`.
void trackPlanStyleChosen(PlanStyle style) =>
    PostHogService.trackEvent('plan_style_chosen', properties: {'style': style.code});

/// What the user did about a phase (spec §9).
enum PhaseAction {
  startBreak('start_break'),
  keepLosing('keep_losing'),
  extend('extend'),
  endEarly('end_early');

  const PhaseAction(this.code);

  final String code;
}

/// Sends `phase_action{action}`.
void trackPhaseAction(PhaseAction action) =>
    PostHogService.trackEvent('phase_action', properties: {'action': action.code});

/// Steady, In phases and With diet breaks as a radio list, in the adaptive
/// choice's style. [recommended] gets the badge (in phases for big goals).
class PlanStyleOptions extends StatelessWidget {
  const PlanStyleOptions({
    super.key,
    required this.style,
    required this.lossPct,
    required this.onChanged,
    this.recommended,
  });

  final PlanStyle style;
  final double lossPct;
  final PlanStyle? recommended;
  final ValueChanged<PlanStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<CustomColors>();
    return Container(
      decoration: BoxDecoration(
        color: colors?.cardBackground ?? theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          for (final s in PlanStyle.values) ...[
            if (s != PlanStyle.values.first)
              Divider(height: 1, indent: 52, color: Colors.grey.withValues(alpha: 0.15)),
            ChoiceOption(
              key: Key('plan_style_${s.code}'),
              title: PlanStyleCopy.title(s),
              body: PlanStyleCopy.body(s, lossPct: lossPct),
              selected: style == s,
              recommended: recommended == s,
              onTap: () => onChanged(s),
            ),
          ],
        ],
      ),
    );
  }
}
