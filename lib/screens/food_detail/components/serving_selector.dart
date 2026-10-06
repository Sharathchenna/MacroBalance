// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../screens/searchPage.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/typography.dart';

/// Bottom sheet widget for selecting a serving size from a list.
/// Displays all available servings in a scrollable list with detailed information.
class ServingSelectorSheet extends StatelessWidget {
  final List<Serving> servings;
  final Serving? selectedServing;
  final Function(Serving) onServingSelected;

  const ServingSelectorSheet({
    super.key,
    required this.servings,
    required this.selectedServing,
    required this.onServingSelected,
  });

  String _formatServingDescription(String description) {
    if (description.length > 18) {
      return '${description.substring(0, 15)}...';
    }
    return description;
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>()!;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
                        Icons.restaurant_menu_rounded,
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
                            "Select Serving Size",
                            style: AppTypography.h3.copyWith(
                              color: customColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${servings.length} options available",
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

          // List of servings
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: servings.length,
              itemBuilder: (context, index) {
                final serving = servings[index];
                final isSelected = selectedServing?.description == serving.description;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: isSelected
                        ? primaryColor.withOpacity(0.1)
                        : customColors.dateNavigatorBackground.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onServingSelected(serving);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? primaryColor.withOpacity(0.5)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Selection indicator
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryColor
                                    : customColors.textSecondary.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  : Text(
                                      "${index + 1}",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: customColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 16),

                            // Serving info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatServingDescription(serving.description),
                                    style: AppTypography.body1.copyWith(
                                      color: customColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${serving.metricAmount} ${serving.metricUnit}",
                                    style: AppTypography.body2.copyWith(
                                      color: customColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Calories
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "${serving.calories.toStringAsFixed(0)}",
                                  style: AppTypography.body1.copyWith(
                                    color: isSelected ? primaryColor : customColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "cals",
                                  style: AppTypography.caption.copyWith(
                                    color: customColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

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
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
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
}
