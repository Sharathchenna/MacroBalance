import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/providers/detailed_stats_provider.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_weight_input.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_widgets.dart';
import 'package:macrotracker/theme/ob_theme.dart';
import 'package:provider/provider.dart';

const double kMinWeightKg = 30;
const double kMaxWeightKg = 200;

/// Step: today's weight. Reports kg whichever unit is shown.
class WeightPage extends StatelessWidget {
  final double currentWeightKg;
  final bool isMetric;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<bool> onUnitChanged;

  /// The trend weight, offered as a one-tap answer when recalculating after
  /// a recent weigh-in (plan 10.4); null hides it.
  final double? trendKg;

  /// Takes [trendKg] and moves on.
  final VoidCallback? onUseTrend;

  const WeightPage({
    super.key,
    required this.currentWeightKg,
    required this.isMetric,
    required this.onWeightChanged,
    required this.onUnitChanged,
    this.trendKg,
    this.onUseTrend,
  });

  /// "81.4 kg" or "179 lbs", as the page shows it.
  String _weightText(double kg) =>
      isMetric ? '${kg.toStringAsFixed(1)} kg' : '${(kg * 2.20462).round()} lbs';

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return ObPageBody(
      children: [
        const ObHeader(eyebrow: 'About you', title: 'What do you weigh today?'),
        const SizedBox(height: 24),
        ObRise(
          index: 2,
          child: Center(
            child: ObSegmented<bool>(
              options: const {true: 'kg', false: 'lb'},
              value: isMetric,
              onChanged: onUnitChanged,
            ),
          ),
        ),
        const SizedBox(height: 26),
        ObRise(
          index: 2,
          child: ObWeightInput(
            valueKg: currentWeightKg,
            minKg: kMinWeightKg,
            maxKg: kMaxWeightKg,
            isMetric: isMetric,
            onChanged: onWeightChanged,
          ),
        ),
        const SizedBox(height: 8),
        ObRise(
          index: 2,
          child: Text('Swipe the ruler or tap the number to type',
              textAlign: TextAlign.center, style: ObText.body(c.muted, size: 12)),
        ),
        if (trendKg != null && onUseTrend != null) ...[
          const SizedBox(height: 18),
          ObRise(
            index: 3,
            child: _UseTrendCard(
              label: context.watch<DetailedStatsProvider>().showDetailedStats
                  ? 'Use ${_weightText(trendKg!)} (your trend)'
                  : 'Use ${_weightText(trendKg!)}',
              onPressed: () {
                HapticFeedback.selectionClick();
                onUseTrend!();
              },
            ),
          ),
        ],
        const SizedBox(height: 18),
        ObRise(
          index: 3,
          child: ObNote(
            icon: Icons.show_chart_rounded,
            child: Text.rich(TextSpan(children: [
              const TextSpan(text: 'We follow your '),
              TextSpan(text: 'trend', style: TextStyle(color: c.text)),
              const TextSpan(
                  text: ', not daily swings. Water and salt can move you a kilo overnight, '
                      'so today’s number is just a starting point.'),
            ])),
          ),
        ),
      ],
    );
  }
}

/// The one-tap trend weight, a soft green card.
class _UseTrendCard extends StatelessWidget {
  const _UseTrendCard({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: c.leaf.withValues(alpha: c.isDark ? 0.12 : 0.18),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.show_chart_rounded, size: 20, color: c.leafText),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(label, style: ObText.title(c.leafText, size: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
