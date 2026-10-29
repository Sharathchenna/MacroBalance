import 'package:flutter/material.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_widgets.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/theme/ob_theme.dart';

/// Step: how active a normal week is. The level becomes the starting burn.
class ActivityLevelPage extends StatelessWidget {
  final int currentActivityLevel;
  final ValueChanged<int> onActivityLevelChanged;

  const ActivityLevelPage({
    super.key,
    required this.currentActivityLevel,
    required this.onActivityLevelChanged,
  });

  static const _levels = [
    (MacroCalculatorService.SEDENTARY, 'Sedentary', 'Little or no exercise, desk job'),
    (MacroCalculatorService.LIGHTLY_ACTIVE, 'Lightly active', 'Light exercise 1–3 days a week'),
    (MacroCalculatorService.MODERATELY_ACTIVE, 'Moderately active',
        'Moderate exercise 3–5 days a week'),
    (MacroCalculatorService.VERY_ACTIVE, 'Very active', 'Hard exercise 6–7 days a week'),
    (MacroCalculatorService.EXTRA_ACTIVE, 'Extra active', 'Physical job, or training twice a day'),
  ];

  @override
  Widget build(BuildContext context) {
    return ObPageBody(
      top: 22,
      children: [
        const ObHeader(
          eyebrow: 'About you',
          title: 'How active is a normal week?',
          subtitle: 'Your best guess is fine. Once you log for a while, your real burn replaces it.',
        ),
        const SizedBox(height: 20),
        ObRise(
          index: 2,
          child: Column(
            children: [
              for (var i = 0; i < _levels.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                ObOptionTile(
                  title: _levels[i].$2,
                  subtitle: _levels[i].$3,
                  selected: currentActivityLevel == _levels[i].$1,
                  onTap: () => onActivityLevelChanged(_levels[i].$1),
                  trailing: const SizedBox.shrink(),
                  leading: _ActivityBars(
                    level: i + 1,
                    selected: currentActivityLevel == _levels[i].$1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Five rising bars, lit up to [level]; they pulse on the chosen row.
class _ActivityBars extends StatefulWidget {
  const _ActivityBars({required this.level, required this.selected});

  final int level;
  final bool selected;

  @override
  State<_ActivityBars> createState() => _ActivityBarsState();
}

class _ActivityBarsState extends State<_ActivityBars> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.selected) _c.repeat();
  }

  @override
  void didUpdateWidget(_ActivityBars old) {
    super.didUpdateWidget(old);
    if (widget.selected && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.selected && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 1 down to 0.6 and back, offset by 0.1 of the loop per bar.
  double _scale(int bar) {
    if (!widget.selected || MediaQuery.of(context).disableAnimations) return 1;
    final t = (_c.value - bar * 0.1) % 1.0;
    final wave = t < 0.5 ? t * 2 : (1 - t) * 2;
    return 1 - 0.4 * Curves.easeInOut.transform(wave);
  }

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(13)),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var k = 1; k <= 5; k++) ...[
                if (k > 1) const SizedBox(width: 3),
                Transform.scale(
                  scaleY: _scale(k - 1),
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: 4,
                    height: 2.0 + 4 * k,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: k <= widget.level
                          ? (widget.selected ? c.leaf : c.muted)
                          : c.line,
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
}
