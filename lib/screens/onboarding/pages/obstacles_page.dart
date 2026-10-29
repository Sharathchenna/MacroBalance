import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_widgets.dart';
import 'package:macrotracker/theme/ob_theme.dart';

/// Codes for the obstacle options, in the order they are shown. Logged as
/// the `obstacles_selected` PostHog property and used to pick reply cards.
const kObstacleCodes = [
  'logging_slow',
  'static_target',
  'distrust_numbers',
  'weekends',
  'plateau',
  'eating_out',
  'motivation',
];

/// Pill labels, by code.
const kObstacleLabels = {
  'logging_slow': 'Logging took too long',
  'static_target': 'My target never changed',
  'distrust_numbers': 'I didn’t trust the numbers',
  'weekends': 'Weekends undo my week',
  'plateau': 'I hit a plateau',
  'eating_out': 'Eating out is hard',
  'motivation': 'I lost motivation',
};

/// "What's gotten in the way before?": optional, multi-select. Saves nothing
/// to the goals; the answers pick the reply cards on the next page.
class ObstaclesPage extends StatelessWidget {
  const ObstaclesPage({super.key, required this.selected, required this.onChanged});

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  void _toggle(String code) {
    HapticFeedback.selectionClick();
    final next = {...selected};
    if (!next.remove(code)) next.add(code);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    final count = kObstacleCodes.where(selected.contains).length;
    return ObPageBody(
      children: [
        const ObHeader(
          eyebrow: 'Be honest',
          title: 'What’s gotten in the way before?',
          subtitle: 'Pick any that sound familiar. We’ll shape your plan around them.',
        ),
        const SizedBox(height: 26),
        ObRise(
          index: 2,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final code in kObstacleCodes)
                _Pill(
                  key: Key('obstacle_$code'),
                  label: kObstacleLabels[code]!,
                  on: selected.contains(code),
                  onTap: () => _toggle(code),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text('$count selected', style: ObText.body(c.muted, size: 13)),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: on ? c.leaf.withValues(alpha: c.isDark ? 0.1 : 0.14) : c.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: on ? c.leaf : c.line, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (on) ...[
                Icon(Icons.check_rounded, size: 16, color: c.leafText),
                const SizedBox(width: 8),
              ],
              Text(label, style: ObText.body(c.text, weight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
