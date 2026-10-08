import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/theme/app_theme.dart';

/// Each of the four daily targets, old → new: the profile-edit confirm and
/// the recalculate summary.
class TargetsChangeRows extends StatelessWidget {
  const TargetsChangeRows({super.key, required this.before, required this.after});

  final GoalTargets before;
  final GoalTargets after;

  static final _grouped = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>();

    Widget row(String label, double old, double next, String unit) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: customColors?.textSecondary)),
              ),
              Text(
                '${_grouped.format(old.round())} → ${_grouped.format(next.round())} $unit',
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600, color: customColors?.textPrimary),
              ),
            ],
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row('Calories', before.calories, after.calories, 'cals'),
        row('Protein', before.protein, after.protein, 'g'),
        row('Carbs', before.carbs, after.carbs, 'g'),
        row('Fat', before.fat, after.fat, 'g'),
      ],
    );
  }
}
