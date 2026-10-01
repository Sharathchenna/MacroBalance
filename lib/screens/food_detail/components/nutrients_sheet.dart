import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/typography.dart';

/// Bottom sheet widget for displaying detailed nutrient information.
/// Shows a list of all nutrients with their values and units.
class NutrientsSheet extends StatelessWidget {
  final Map<String, String> nutrients;

  const NutrientsSheet({
    super.key,
    required this.nutrients,
  });

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>()!;
    final primaryColor = Theme.of(context).primaryColor;

    // Separate macros from other nutrients
    final macros = ['Calories', 'Protein', 'Carbohydrates', 'Fat'];
    final otherNutrients = nutrients.entries
        .where((entry) => !macros.contains(entry.key))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: customColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: customColors.cardBackground,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: customColors.textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.bar_chart_rounded,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Detailed Nutrition",
                            style: AppTypography.h3.copyWith(
                              color: customColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${nutrients.length} nutrients tracked",
                            style: AppTypography.body2.copyWith(
                              color: customColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Macros Section
          if (nutrients.entries.any((e) => macros.contains(e.key))) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "MACROS",
                  style: AppTypography.caption.copyWith(
                    color: primaryColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            ...nutrients.entries
                .where((e) => macros.contains(e.key))
                .map((entry) => _buildNutrientTile(context, entry.key, entry.value, isMacro: true)),
          ],

          // Other Nutrients Section
          if (otherNutrients.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "OTHER NUTRIENTS",
                  style: AppTypography.caption.copyWith(
                    color: customColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: otherNutrients.length,
                itemBuilder: (context, index) {
                  final entry = otherNutrients[index];
                  return _buildNutrientTile(context, entry.key, entry.value);
                },
              ),
            ),
          ],

          // Done button
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: customColors.cardBackground,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Theme.of(context).brightness == Brightness.dark
                        ? customColors.dateNavigatorBackground
                        : customColors.textPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                "Done",
                style: AppTypography.button.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientTile(BuildContext context, String name, String value, {bool isMacro = false}) {
    final customColors = Theme.of(context).extension<CustomColors>()!;
    final primaryColor = Theme.of(context).primaryColor;

    // Get icon based on nutrient name
    IconData icon = _getNutrientIcon(name);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isMacro
            ? primaryColor.withOpacity(0.05)
            : customColors.dateNavigatorBackground.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: isMacro
            ? Border.all(color: primaryColor.withOpacity(0.2), width: 1)
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isMacro
                  ? primaryColor.withOpacity(0.1)
                  : customColors.cardBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isMacro ? primaryColor : customColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name,
              style: AppTypography.body1.copyWith(
                color: customColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: AppTypography.body1.copyWith(
              color: isMacro ? primaryColor : customColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getNutrientIcon(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('calorie')) return Icons.local_fire_department_rounded;
    if (lowerName.contains('protein')) return Icons.fitness_center_rounded;
    if (lowerName.contains('carb')) return Icons.grain_rounded;
    if (lowerName.contains('fat')) return Icons.water_drop_rounded;
    if (lowerName.contains('fiber')) return Icons.grass_rounded;
    if (lowerName.contains('sugar')) return Icons.cookie_rounded;
    if (lowerName.contains('sodium')) return Icons.water_rounded;
    if (lowerName.contains('cholesterol')) return Icons.monitor_heart_rounded;
    if (lowerName.contains('calcium')) return Icons.account_balance_rounded;
    if (lowerName.contains('iron')) return Icons.construction_rounded;
    if (lowerName.contains('vitamin')) return Icons.wb_sunny_rounded;
    if (lowerName.contains('potassium')) return Icons.bolt_rounded;
    return Icons.pie_chart_rounded;
  }
}
