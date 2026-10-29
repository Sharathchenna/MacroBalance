import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_widgets.dart';
import 'package:macrotracker/services/macro_calculator_service.dart'; // For gender constants
import 'package:macrotracker/theme/ob_theme.dart';

/// "Fine-tune your macros": optional body fat, protein and fat settings,
/// shown only with detailed stats on. Skipping keeps the recommended values.
class AdvancedSettingsPage extends StatelessWidget {
  final bool showBodyFatInput;

  /// Null until the user sets a value: no body fat is ever assumed.
  final double? bodyFatPercentage;

  /// Null means the default for the goal, [defaultProteinRatio].
  final double? proteinRatio;
  final double defaultProteinRatio;
  final double fatRatio;
  final String gender; // Where the body fat stepper starts
  final ValueChanged<bool> onShowBodyFatChanged;
  final ValueChanged<double> onBodyFatChanged;
  final ValueChanged<double> onProteinRatioChanged;
  final ValueChanged<double> onFatRatioChanged;

  const AdvancedSettingsPage({
    super.key,
    required this.showBodyFatInput,
    required this.bodyFatPercentage,
    required this.proteinRatio,
    required this.defaultProteinRatio,
    required this.fatRatio,
    required this.gender,
    required this.onShowBodyFatChanged,
    required this.onBodyFatChanged,
    required this.onProteinRatioChanged,
    required this.onFatRatioChanged,
  });

  // Where the body fat stepper starts before the user has set a value.
  double get _bodyFatStart => gender == MacroCalculatorService.MALE ? 20 : 28;

  static double _r1(double v) => double.parse(v.toStringAsFixed(1));
  static double _r2(double v) => double.parse(v.toStringAsFixed(2));

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    final bodyFat = bodyFatPercentage;
    final bf = bodyFat ?? _bodyFatStart;
    final protein = proteinRatio ?? defaultProteinRatio;

    return ObPageBody(
      top: 20,
      children: [
        const ObHeader(
          eyebrow: 'Optional · detailed stats on',
          title: 'Fine-tune your macros',
          subtitle: 'The recommended settings suit most people. Change them only if you know what you want.',
        ),
        const SizedBox(height: 18),
        ObRise(
          index: 2,
          child: _SettingCard(
            title: 'Body fat',
            value: Text(
              !showBodyFatInput
                  ? 'Not used'
                  : bodyFat == null
                      ? 'Set your %'
                      : '${bodyFat.round()}%',
              style: ObText.body(c.text2, size: 13),
            ),
            footer: 'Only from a DEXA scan or smart scale. Guesses by eye are often 5% off.',
            children: [
              const SizedBox(height: 10),
              _TwoWay(
                left: 'Skip',
                right: 'From a scan',
                rightOn: showBodyFatInput,
                onChanged: onShowBodyFatChanged,
              ),
              if (showBodyFatInput) ...[
                const SizedBox(height: 12),
                _Stepper(
                  label: 'body fat',
                  fraction: (bf - 5) / 45,
                  color: c.text,
                  onDown: () {
                    if (bf > 5) onBodyFatChanged(bf - 1);
                  },
                  onUp: () {
                    if (bf < 50) onBodyFatChanged(bf + 1);
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        ObRise(
          index: 3,
          child: _SettingCard(
            title: 'Protein',
            value: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '${protein.toStringAsFixed(1)} g/kg',
                  style: TextStyle(color: c.protein, fontWeight: FontWeight.w600),
                ),
                if (proteinRatio == null) const TextSpan(text: ' · recommended'),
              ]),
              style: ObText.body(c.text2, size: 13),
            ),
            footer: '1.2–2.6 g per kg. Higher helps keep muscle while losing.',
            children: [
              const SizedBox(height: 12),
              _Stepper(
                label: 'protein',
                fraction: (protein - 1.2) / 1.4,
                color: c.protein,
                onDown: () {
                  if (protein > 1.2) onProteinRatioChanged(_r1(protein - 0.1));
                },
                onUp: () {
                  if (protein < 2.6) onProteinRatioChanged(_r1(protein + 0.1));
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ObRise(
          index: 3,
          child: _SettingCard(
            title: 'Fat',
            value: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '${(fatRatio * 100).round()}%',
                  style: TextStyle(color: c.fat, fontWeight: FontWeight.w600),
                ),
                const TextSpan(text: ' of cals'),
              ]),
              style: ObText.body(c.text2, size: 13),
            ),
            footer: '20–40%. Carbs fill whatever is left.',
            children: [
              const SizedBox(height: 12),
              _Stepper(
                label: 'fat',
                fraction: (fatRatio - 0.2) / 0.2,
                color: c.fat,
                onDown: () {
                  if (fatRatio > 0.20) onFatRatioChanged(_r2(fatRatio - 0.01));
                },
                onUp: () {
                  if (fatRatio < 0.40) onFatRatioChanged(_r2(fatRatio + 0.01));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.title,
    required this.value,
    required this.footer,
    required this.children,
  });

  final String title;
  final Widget value;
  final String footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return ObCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(title, style: ObText.title(c.text, size: 15)),
              Flexible(child: value),
            ],
          ),
          ...children,
          const SizedBox(height: 10),
          Text(footer, style: ObText.body(c.muted, size: 12).copyWith(height: 1.45)),
        ],
      ),
    );
  }
}

/// Two full-width choices in a track (Skip / From a scan).
class _TwoWay extends StatelessWidget {
  const _TwoWay({required this.left, required this.right, required this.rightOn, required this.onChanged});

  final String left;
  final String right;
  final bool rightOn;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    Widget seg(String label, bool on, bool value) => Expanded(
          child: Semantics(
            button: true,
            selected: on,
            child: GestureDetector(
              onTap: () {
                if (on) return;
                HapticFeedback.selectionClick();
                onChanged(value);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? c.text : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(label,
                    style: ObText.body(on ? c.bg : c.text2, size: 14, weight: FontWeight.w600)
                        .copyWith(height: 1.2)),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        seg(left, !rightOn, false),
        const SizedBox(width: 6),
        seg(right, rightOn, true),
      ]),
    );
  }
}

/// A round minus, a bar and a round plus.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.fraction,
    required this.color,
    required this.onDown,
    required this.onUp,
  });

  final String label;
  final double fraction;
  final Color color;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Row(
      children: [
        _StepButton(icon: Icons.remove_rounded, label: 'Less $label', onTap: onDown),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(4)),
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: fraction.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 300),
              curve: ObMotion.curve,
              builder: (context, f, _) => FractionallySizedBox(
                widthFactor: f,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _StepButton(icon: Icons.add_rounded, label: 'More $label', onTap: onUp),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: c.raised,
            shape: BoxShape.circle,
            border: Border.all(color: c.line),
          ),
          child: Icon(icon, size: 18, color: c.text),
        ),
      ),
    );
  }
}
