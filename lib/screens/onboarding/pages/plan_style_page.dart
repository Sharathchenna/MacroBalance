import 'package:flutter/material.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_widgets.dart';
import 'package:macrotracker/services/energy/phase_engine.dart';
import 'package:macrotracker/services/energy/projection.dart';
import 'package:macrotracker/theme/ob_theme.dart';
import 'package:macrotracker/widgets/plan_style_choice.dart';

/// "How do you want to get there?": steady, in phases or with diet breaks
/// (plan 10.3). Lose goals only. Under the options, how the chosen plan
/// unfolds: "3 loss phases + 2 breaks · about 34 weeks".
class PlanStylePage extends StatelessWidget {
  const PlanStylePage({
    super.key,
    required this.style,
    required this.lossPct,
    required this.onChanged,
    this.recommended,
    this.outline,
  });

  final PlanStyle style;

  /// X for the user's weight, in the "In phases" line.
  final double lossPct;
  final PlanStyle? recommended;

  /// How [style] unfolds, shown for phased and diet-break plans.
  final PlanOutline? outline;
  final ValueChanged<PlanStyle> onChanged;

  static IconData _icon(PlanStyle s) => switch (s) {
        PlanStyle.steady => Icons.trending_down_rounded,
        PlanStyle.phased => Icons.stairs_rounded,
        PlanStyle.breaks => Icons.pause_circle_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    final o = outline;
    return ObPageBody(
      children: [
        const ObHeader(eyebrow: 'Your approach', title: PlanStyleCopy.question),
        const SizedBox(height: 24),
        for (final s in PlanStyle.values)
          ObRise(
            index: 2 + s.index,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ObOptionTile(
                key: Key('plan_style_${s.code}'),
                leading: ObIconTile(icon: _icon(s)),
                title: PlanStyleCopy.title(s),
                subtitle: PlanStyleCopy.body(s, lossPct: lossPct),
                badge: recommended == s ? 'Recommended' : null,
                selected: style == s,
                onTap: () => onChanged(s),
              ),
            ),
          ),
        if (o != null && style != PlanStyle.steady) ...[
          const SizedBox(height: 6),
          ObNote(
            icon: Icons.timeline_rounded,
            iconColor: c.text2,
            child: Text(
              PlanStyleCopy.outline(o),
              key: const Key('plan_style_outline'),
              style: ObText.body(c.text, size: 14, weight: FontWeight.w500),
            ),
          ),
        ],
      ],
    );
  }
}
