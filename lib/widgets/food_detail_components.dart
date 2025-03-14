import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/typography.dart';
import 'nutrient_row.dart';

class NutrientSection extends StatelessWidget {
  final String title;
  final List<MapEntry<String, String>> nutrients;
  final Color accentColor;
  final Color dividerColor;

  const NutrientSection({
    super.key,
    required this.title,
    required this.nutrients,
    required this.accentColor,
    required this.dividerColor,
  });

  @override
  Widget build(BuildContext context) {
    if (nutrients.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTypography.body1.copyWith(
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: nutrients.map((entry) {
              return Column(
                children: [
                  NutrientRow(
                    name: entry.key,
                    value: entry.value,
                  ),
                  if (nutrients.last.key != entry.key)
                    Divider(color: dividerColor.withOpacity(0.5)),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

String formatServingDescription(String description) {
  if (description.length > 18) {
    return '${description.substring(0, 15)}...';
  }
  return description;
}
