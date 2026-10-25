import 'package:flutter/material.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_ruler.dart';
import 'package:macrotracker/theme/ob_theme.dart';

const double _lbPerKg = 2.20462;

/// Lets [child] run edge to edge inside a page that pads its sides by 24.
class ObFullBleed extends StatelessWidget {
  const ObFullBleed({super.key, required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SizedBox(
        height: height,
        child: OverflowBox(
          minWidth: box.maxWidth + 48,
          maxWidth: box.maxWidth + 48,
          child: child,
        ),
      ),
    );
  }
}

/// The big typed weight with a 0.1 ruler under it, shared by the weight and
/// goal weight steps. Works in kg or lb but always reports kg.
class ObWeightInput extends StatelessWidget {
  const ObWeightInput({
    super.key,
    required this.valueKg,
    required this.minKg,
    required this.maxKg,
    required this.isMetric,
    required this.onChanged,
    this.fontSize = 76,
    this.numberWidth = 190,
    this.unitWidth = 120,
    this.unitSize = 22,
    this.rulerHeight = 74,
    this.gap = 18,
    this.label = 'Weight',
    this.rulerValueKg,
  });

  final double valueKg;
  final double minKg;
  final double maxKg;
  final bool isMetric;
  final ValueChanged<double> onChanged;
  final double fontSize;
  final double numberWidth;
  final double unitWidth;
  final double unitSize;
  final double rulerHeight;

  /// Space between the number and the ruler.
  final double gap;
  final String label;

  /// Where the ruler sits when it should differ from [valueKg] for a moment
  /// (the goal weight step glides it from today's weight).
  final double? rulerValueKg;

  double _round1(double v) => double.parse(v.toStringAsFixed(1));

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    // Whole-number ends keep the labelled ticks on multiples of 5.
    final min = isMetric ? minKg.ceilToDouble() : (minKg * _lbPerKg).ceilToDouble();
    final max = isMetric ? _round1(maxKg) : (maxKg * _lbPerKg).floorToDouble();
    final shown = _round1(isMetric ? valueKg : valueKg * _lbPerKg).clamp(min, max).toDouble();
    final rulerShown = _round1(isMetric ? (rulerValueKg ?? valueKg) : (rulerValueKg ?? valueKg) * _lbPerKg)
        .clamp(min, max)
        .toDouble();
    final unit = isMetric ? 'kg' : 'lb';

    void report(double v) => onChanged(
        isMetric ? _round1(v) : double.parse((v / _lbPerKg).toStringAsFixed(2)));

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            ObNumberField(
              value: shown,
              min: min,
              max: max,
              fontSize: fontSize,
              width: numberWidth,
              semanticLabel: '$label in $unit',
              onChanged: report,
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: unitWidth,
              child: Text(unit,
                  style: ObText.display(unitSize, color: c.text2)
                      .copyWith(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        SizedBox(height: gap),
        ObFullBleed(
          height: rulerHeight,
          child: ObRuler(
            // A new key per unit rebuilds the strip at the right place.
            key: ValueKey(unit),
            value: rulerShown,
            min: min,
            max: max,
            height: rulerHeight,
            onChanged: report,
          ),
        ),
      ],
    );
  }
}
