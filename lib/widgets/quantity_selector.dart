import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class QuantitySelector extends StatelessWidget {
  final List<double> presetMultipliers;
  final double selectedMultiplier;
  final Function(double) onMultiplierSelected;

  const QuantitySelector({
    super.key,
    required this.presetMultipliers,
    required this.selectedMultiplier,
    required this.onMultiplierSelected,
  });

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();

    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: presetMultipliers.length,
        separatorBuilder: (context, index) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          final multiplier = presetMultipliers[index];
          final isSelected = multiplier == selectedMultiplier;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onMultiplierSelected(multiplier);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected
                    ? customColors!.calorieTrackerBackground
                    : customColors!.cardBackground,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFBBC05).withAlpha(((0.8) * 255).round())
                          : customColors.textPrimary
                      : customColors.dateNavigatorBackground,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '${multiplier}x',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : customColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
