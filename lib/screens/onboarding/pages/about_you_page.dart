import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_ruler.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_widgets.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/theme/ob_theme.dart';

const int kMinAge = 18;
const int kMaxAge = 100;
const double kMinHeightCm = 120;
const double kMaxHeightCm = 230;
const int _minInches = 48; // 4'0"
const int _maxInches = 90; // 7'6"

/// Step: sex, age and height. Height is always reported in cm; the feet and
/// inches view only changes how it is shown and typed.
class AboutYouPage extends StatelessWidget {
  final String gender;
  final ValueChanged<String> onGenderChanged;
  final int age;
  final ValueChanged<int> onAgeChanged;
  final double heightCm;
  final bool isMetricHeight;
  final ValueChanged<double> onHeightChanged;
  final ValueChanged<bool> onHeightUnitChanged;

  const AboutYouPage({
    super.key,
    required this.gender,
    required this.onGenderChanged,
    required this.age,
    required this.onAgeChanged,
    required this.heightCm,
    required this.isMetricHeight,
    required this.onHeightChanged,
    required this.onHeightUnitChanged,
  });

  int get _inches => (heightCm / 2.54).round().clamp(_minInches, _maxInches);

  void _setInches(int total) =>
      onHeightChanged(
          (total.clamp(_minInches, _maxInches) * 2.54).roundToDouble());

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return ObPageBody(
      top: 22,
      children: [
        const ObHeader(
          eyebrow: 'About you',
          title: 'A few basics',
          subtitle: 'These set your starting burn. Your own logs take over within a few weeks.',
        ),
        const SizedBox(height: 20),
        ObRise(
          index: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sex', style: ObText.body(c.text2, size: 14, weight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _SexChoice(
                    label: 'Male',
                    selected: gender == MacroCalculatorService.MALE,
                    onTap: () => onGenderChanged(MacroCalculatorService.MALE),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _SexChoice(
                    label: 'Female',
                    selected: gender == MacroCalculatorService.FEMALE,
                    onTap: () => onGenderChanged(MacroCalculatorService.FEMALE),
                  )),
                ],
              ),
              const SizedBox(height: 8),
              Text('Used for the metabolism formula and safe minimum targets.',
                  style: ObText.body(c.muted, size: 12)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ObRise(index: 3, child: _ageCard(c)),
        const SizedBox(height: 10),
        ObRise(index: 4, child: _heightCard(c)),
      ],
    );
  }

  Widget _ageCard(ObColors c) {
    return _Card(
      padding: const EdgeInsets.only(top: 14, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('Age', style: ObText.body(c.text2, size: 14, weight: FontWeight.w600)),
                Text('Swipe or tap to type', style: ObText.body(c.muted, size: 12)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                ObNumberField(
                  value: age.toDouble(),
                  min: kMinAge.toDouble(),
                  max: kMaxAge.toDouble(),
                  decimals: 0,
                  fontSize: 34,
                  textAlign: TextAlign.left,
                  semanticLabel: 'Age in years',
                  onChanged: (v) => onAgeChanged(v.round()),
                ),
                const SizedBox(width: 6),
                Text('years', style: ObText.body(c.text2, size: 14, weight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            slider: true,
            value: '$age',
            increasedValue: '${(age + 1).clamp(kMinAge, kMaxAge)}',
            decreasedValue: '${(age - 1).clamp(kMinAge, kMaxAge)}',
            onIncrease: () => onAgeChanged((age + 1).clamp(kMinAge, kMaxAge)),
            onDecrease: () => onAgeChanged((age - 1).clamp(kMinAge, kMaxAge)),
            child: ObSnapStrip(
              count: kMaxAge - kMinAge + 1,
              index: (age - kMinAge).clamp(0, kMaxAge - kMinAge),
              itemExtent: 56,
              height: 44,
              fadeColor: c.surface,
              onChanged: (i) => onAgeChanged(kMinAge + i),
              indicator: Container(
                width: 56,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.leaf, width: 2),
                ),
              ),
              itemBuilder: (context, i, _) {
                final d = (kMinAge + i - age).abs();
                return Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 150),
                    style: ObText.display(d == 0 ? 22 : 17,
                            color: d == 0
                                ? c.leafText
                                : d == 1
                                    ? c.text2
                                    : c.muted.withValues(alpha: 0.7))
                        .copyWith(fontWeight: d == 0 ? FontWeight.w600 : FontWeight.w500),
                    child: Text('${kMinAge + i}'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _heightCard(ObColors c) {
    final feet = _inches ~/ 12;
    final inch = _inches % 12;
    final unitStyle = ObText.body(c.text2, size: 14, weight: FontWeight.w500);
    return _Card(
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Height', style: ObText.body(c.text2, size: 14, weight: FontWeight.w600)),
                ObSegmented<bool>(
                  compact: true,
                  options: const {true: 'cm', false: 'ft'},
                  value: isMetricHeight,
                  onChanged: onHeightUnitChanged,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: isMetricHeight
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      ObNumberField(
                        value: heightCm,
                        min: kMinHeightCm,
                        max: kMaxHeightCm,
                        decimals: 0,
                        fontSize: 34,
                        textAlign: TextAlign.left,
                        semanticLabel: 'Height in centimetres',
                        onChanged: onHeightChanged,
                      ),
                      const SizedBox(width: 6),
                      Text('cm', style: unitStyle),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      ObNumberField(
                        value: feet.toDouble(),
                        min: 4,
                        max: 7,
                        decimals: 0,
                        fontSize: 34,
                        textAlign: TextAlign.left,
                        semanticLabel: 'Feet',
                        onChanged: (v) => _setInches(v.round() * 12 + inch),
                      ),
                      const SizedBox(width: 6),
                      Text('ft', style: unitStyle),
                      const SizedBox(width: 10),
                      ObNumberField(
                        value: inch.toDouble(),
                        min: 0,
                        max: 11,
                        decimals: 0,
                        fontSize: 34,
                        textAlign: TextAlign.left,
                        semanticLabel: 'Inches',
                        onChanged: (v) => _setInches(feet * 12 + v.round()),
                      ),
                      const SizedBox(width: 6),
                      Text('in', style: unitStyle),
                      const Spacer(),
                      Text('≈ ${heightCm.round()} cm', style: ObText.body(c.muted, size: 12)),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          isMetricHeight
              ? ObRuler(
                  key: const ValueKey('height_cm_ruler'),
                  value: heightCm,
                  min: kMinHeightCm,
                  max: kMaxHeightCm,
                  step: 1,
                  majorEvery: 10,
                  midEvery: 5,
                  tickWidth: 8,
                  height: 58,
                  fadeColor: c.surface,
                  onChanged: onHeightChanged,
                )
              : ObRuler(
                  key: const ValueKey('height_in_ruler'),
                  value: _inches.toDouble(),
                  min: _minInches.toDouble(),
                  max: _maxInches.toDouble(),
                  step: 1,
                  majorEvery: 12,
                  midEvery: 6,
                  tickWidth: 12,
                  height: 58,
                  fadeColor: c.surface,
                  label: (v) => '${v ~/ 12}′',
                  onChanged: (v) => _setInches(v.round()),
                ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ObColors.of(context).surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

class _SexChoice extends StatelessWidget {
  const _SexChoice({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.leaf.withValues(alpha: c.isDark ? 0.08 : 0.12) : c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? c.leaf : c.line, width: 2),
          ),
          child: Text(label, style: ObText.title(c.text, size: 16)),
        ),
      ),
    );
  }
}
