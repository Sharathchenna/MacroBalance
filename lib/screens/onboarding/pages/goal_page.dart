import 'package:flutter/material.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_widgets.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/theme/ob_theme.dart';

/// Step: what the user wants to change. Content only; the shell owns the
/// top bar and Continue.
class GoalPage extends StatelessWidget {
  final String currentGoal;
  final ValueChanged<String> onGoalChanged;

  const GoalPage({
    super.key,
    required this.currentGoal,
    required this.onGoalChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    final options = [
      (MacroCalculatorService.GOAL_LOSE, 'Lose fat', 'Drop weight and keep your muscle',
          Icons.trending_down_rounded, c.leaf),
      (MacroCalculatorService.GOAL_MAINTAIN, 'Maintain', 'Hold steady and eat with intent',
          Icons.balance_rounded, c.carbs),
      (MacroCalculatorService.GOAL_GAIN, 'Build muscle', 'Gain lean weight, slowly and on purpose',
          Icons.trending_up_rounded, c.fat),
    ];
    return ObPageBody(
      children: [
        const ObHeader(
          eyebrow: 'Your goal',
          title: 'What do you want to change?',
          subtitle: 'This sets the direction of your plan. You can change it any time.',
        ),
        const SizedBox(height: 28),
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          ObRise(
            index: 2 + i,
            child: ObOptionTile(
              title: options[i].$2,
              subtitle: options[i].$3,
              selected: currentGoal == options[i].$1,
              onTap: () => onGoalChanged(options[i].$1),
              leading: _Bob(
                phase: i * 0.27,
                child: ObIconTile(icon: options[i].$4, color: options[i].$5),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Floats its child up and down 3px on a slow loop.
class _Bob extends StatefulWidget {
  const _Bob({required this.child, this.phase = 0});

  final Widget child;
  /// Where in the loop it starts, 0 to 1, so the icons don't move in step.
  final double phase;

  @override
  State<_Bob> createState() => _BobState();
}

class _BobState extends State<_Bob> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));

  @override
  void initState() {
    super.initState();
    _c.value = widget.phase;
    _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -3 * Curves.easeInOut.transform(_c.value)),
        child: child,
      ),
      child: widget.child,
    );
  }
}
