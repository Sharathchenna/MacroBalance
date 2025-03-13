import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/typography.dart';

class NutrientRow extends StatelessWidget {
  final String name;
  final String value;
  final bool isHighlighted;

  const NutrientRow({
    super.key,
    required this.name,
    required this.value,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: isHighlighted
                ? AppTypography.body1.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor,
                  )
                : AppTypography.body2.copyWith(
                    color: customColors!.textSecondary,
                  ),
          ),
          Text(
            value,
            style: isHighlighted
                ? AppTypography.body1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  )
                : AppTypography.body2.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor,
                  ),
          ),
        ],
      ),
    );
  }
}
