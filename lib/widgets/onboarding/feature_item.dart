import 'package:flutter/material.dart';
import 'package:macrotracker/theme/app_theme.dart'; // Assuming theme is needed
import 'package:macrotracker/theme/typography.dart';

class FeatureItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const FeatureItem({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Icon(
              icon,
              color: (customColors?.textPrimary ?? theme.colorScheme.primary)
                  .withOpacity(0.8),
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: customColors?.textPrimary ?? theme.colorScheme.onBackground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
