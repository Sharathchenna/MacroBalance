import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/theme/macro_colors.dart';

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
    final fmt = NumberFormat('#,###');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: colors?.cardBackground ?? theme.cardColor,
          borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your daily target',
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colors?.textSecondary)),
        const SizedBox(height: 6),
        // Number large, unit quiet: the same headline as the Energy tab.
        Text.rich(
            key: const Key('simple_plan_calories'),
            TextSpan(children: [
              TextSpan(
                  text: fmt.format(targets.calories.round()),
                  style: GoogleFonts.inter(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                      height: 1.1,
                      color: colors?.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()])),
              TextSpan(
                  text: ' cals',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: colors?.textSecondary)),
            ])),
        if (previousCalories != null &&
            previousCalories!.round() != targets.calories.round()) ...[
          const SizedBox(height: 4),
          Text('Previously ${fmt.format(previousCalories!.round())} cals a day',
              style: GoogleFonts.inter(
                  fontSize: 13, color: colors?.textSecondary)),
        ],
        const SizedBox(height: 14),
        Text(
            goal == null
                ? 'Aim to hold your weight steady.'
                : goalDate == null
                    ? 'Working towards $goal.'
                    : 'Reach $goal around ${DateFormat('MMM d').format(goalDate!)}.',
            key: const Key('simple_plan_goal'),
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors?.textPrimary)),
        const SizedBox(height: 16),
        Divider(
            height: 1,
            color: (colors?.textSecondary ?? Colors.grey).withValues(alpha: 0.15)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: _Macro('Protein', targets.protein, MacroColors.protein)),
          Expanded(child: _Macro('Carbs', targets.carbs, MacroColors.carbs)),
          Expanded(child: _Macro('Fat', targets.fat, MacroColors.fat)),
        ]),
        const SizedBox(height: 14),
        Text(
            learned
                ? 'Based on how your body has responded so far.'
                : adaptive
                    ? 'Your targets adjust as we get to know you.'
                    : 'Your targets stay the same until you change them.',
            style: GoogleFonts.inter(
                fontSize: 13, height: 1.4, color: colors?.textSecondary)),
      ]),
    );
  }
}

/// "● Protein 128 g": a colour dot, the name, then grams.
class _Macro extends StatelessWidget {
  const _Macro(this.name, this.grams, this.color);
  final String name;
  final double grams;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>();
    return Row(children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Flexible(
        child: Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: '$name ',
                  style: TextStyle(color: colors?.textSecondary)),
              TextSpan(
                  text: '${grams.round()} g',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors?.textPrimary)),
            ]),
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 14)),
      ),
    ]);
  }
}
