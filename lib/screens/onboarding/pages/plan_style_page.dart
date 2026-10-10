import 'package:flutter/material.dart';
import 'package:macrotracker/services/energy/phase_engine.dart';
import 'package:macrotracker/services/energy/projection.dart';
import 'package:macrotracker/theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<CustomColors>();
    final o = outline;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            PlanStyleCopy.question,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          PlanStyleOptions(
            style: style,
            lossPct: lossPct,
            recommended: recommended,
            onChanged: onChanged,
          ),
          if (o != null && style != PlanStyle.steady) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.timeline_rounded, size: 18, color: colors?.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    PlanStyleCopy.outline(o),
                    key: const Key('plan_style_outline'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors?.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
