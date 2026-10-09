import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/theme/app_theme.dart';

/// A shared target headline for reviewing and finishing a plan.
class SimplePlanSummary extends StatelessWidget {
  const SimplePlanSummary(
      {super.key,
      required this.targets,
      this.goalDate,
      this.goalWeightKg,
      this.isMetric = true,
      this.previousCalories,
      this.learned = false,
      this.adaptive = true});
  final GoalTargets targets;
  final DateTime? goalDate;
  final double? goalWeightKg;
  final bool isMetric;
  final double? previousCalories;
  final bool learned;
  final bool adaptive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<CustomColors>();
    final goal = goalWeightKg == null
        ? null
        : isMetric
            ? '${goalWeightKg!.toStringAsFixed(1)} kg'
            : '${(goalWeightKg! * 2.20462).round()} lbs';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: colors?.cardBackground ?? theme.cardColor,
          borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your daily target', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Text('${NumberFormat('#,###').format(targets.calories.round())} cals',
            key: const Key('simple_plan_calories'),
            style: theme.textTheme.headlineLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        if (previousCalories != null) ...[
          const SizedBox(height: 4),
          Text(
              'Previously ${NumberFormat('#,###').format(previousCalories!.round())} cals a day',
              style: TextStyle(color: colors?.textSecondary)),
        ],
        const SizedBox(height: 14),
        Text(
            goal == null
                ? 'Aim to hold your weight steady.'
                : goalDate == null
                    ? 'Working towards $goal.'
                    : 'Reach $goal around ${DateFormat('MMM d').format(goalDate!)}.',
            key: const Key('simple_plan_goal'),
            style: theme.textTheme.bodyLarge),
        const SizedBox(height: 20),
        Wrap(spacing: 20, runSpacing: 8, children: [
          Text('Protein ${targets.protein.round()} g'),
          Text('Carbs ${targets.carbs.round()} g'),
          Text('Fat ${targets.fat.round()} g'),
        ]),
        const SizedBox(height: 16),
        Text(
            learned
                ? 'Based on how your body has responded so far.'
                : adaptive
                    ? 'Your targets adjust as we get to know you.'
                    : 'Your targets stay the same until you change them.',
            style: TextStyle(color: colors?.textSecondary, height: 1.4)),
      ]),
    );
  }
}
