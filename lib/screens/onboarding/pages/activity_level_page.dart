import 'package:flutter/material.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/theme/typography.dart';
import 'package:flutter/services.dart';

class ActivityLevelPage extends StatelessWidget {
  final int currentActivityLevel;
  final ValueChanged<int> onActivityLevelChanged;

  const ActivityLevelPage({
    super.key,
    required this.currentActivityLevel,
    required this.onActivityLevelChanged,
  });

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight =
            constraints.maxHeight - padding.top - padding.bottom;
        final headerHeight = size.height * 0.1; // Reduced from 0.12
        final contentHeight = availableHeight - headerHeight;
        final itemHeight =
            (contentHeight / 5.5).clamp(75.0, 100.0); // Adjusted values

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.scaffoldBackgroundColor,
                theme.scaffoldBackgroundColor.withOpacity(0.95),
              ],
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(24, size.height * 0.01, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How active are you?',
                      style: AppTypography.h2.copyWith(
                        color: customColors?.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select the option that best describes your typical week.',
                      style: AppTypography.body2.copyWith(
                        color: customColors?.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8), // Reduced from 12
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Column(
                      children: [
                        _buildActivityCard(
                          context: context,
                          level: MacroCalculatorService.SEDENTARY,
                          title: 'Sedentary',
                          description: 'Little or no exercise, desk job',
                          icon: Icons.weekend_outlined,
                          height: itemHeight,
                        ),
                        SizedBox(
                            height: contentHeight * 0.015), // Reduced spacing
                        _buildActivityCard(
                          context: context,
                          level: MacroCalculatorService.LIGHTLY_ACTIVE,
                          title: 'Lightly Active',
                          description: 'Light exercise 1-3 days/week',
                          icon: Icons.directions_walk,
                          height: itemHeight,
                        ),
                        SizedBox(
                            height: contentHeight * 0.015), // Reduced spacing
                        _buildActivityCard(
                          context: context,
                          level: MacroCalculatorService.MODERATELY_ACTIVE,
                          title: 'Moderately Active',
                          description: 'Moderate exercise 3-5 days/week',
                          icon: Icons.directions_run,
                          height: itemHeight,
                        ),
                        SizedBox(
                            height: contentHeight * 0.015), // Reduced spacing
                        _buildActivityCard(
                          context: context,
                          level: MacroCalculatorService.VERY_ACTIVE,
                          title: 'Very Active',
                          description: 'Heavy exercise 6-7 days/week',
                          icon: Icons.fitness_center,
                          height: itemHeight,
                        ),
                        SizedBox(
                            height: contentHeight * 0.015), // Reduced spacing
                        _buildActivityCard(
                          context: context,
                          level: MacroCalculatorService.EXTRA_ACTIVE,
                          title: 'Extra Active',
                          description:
                              'Very heavy exercise, physical job or training twice a day',
                          icon: Icons.sports_gymnastics,
                          height: itemHeight,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityCard({
    required BuildContext context,
    required int level,
    required String title,
    required String description,
    required IconData icon,
    required double height,
  }) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);
    final isSelected = currentActivityLevel == level;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isSelected
              ? [
                  theme.colorScheme.primary.withOpacity(0.1),
                  theme.colorScheme.primary.withOpacity(0.2),
                ]
              : [
                  customColors?.cardBackground ?? theme.cardColor,
                  customColors?.cardBackground ?? theme.cardColor,
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.dividerColor.withOpacity(0.1),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? theme.colorScheme.primary.withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: isSelected ? 8 : 4,
            offset: Offset(0, isSelected ? 4 : 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onActivityLevelChanged(level);
          },
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 300),
                      tween: Tween<double>(begin: 0, end: isSelected ? 1 : 0),
                      builder: (context, value, child) => Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color.lerp(
                                theme.colorScheme.primary.withOpacity(0.1),
                                theme.colorScheme.primary,
                                value,
                              )!,
                              Color.lerp(
                                theme.colorScheme.primary.withOpacity(0.05),
                                theme.colorScheme.primary.withOpacity(0.8),
                                value,
                              )!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          color: Color.lerp(
                            theme.colorScheme.primary,
                            theme.colorScheme.onPrimary,
                            value,
                          ),
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 300),
                            tween: Tween<double>(
                                begin: 0, end: isSelected ? 1 : 0),
                            builder: (context, value, child) => Text(
                              title,
                              style: AppTypography.h3.copyWith(
                                color: customColors?.textPrimary,
                                fontWeight: FontWeight.lerp(
                                  FontWeight.w600,
                                  FontWeight.bold,
                                  value,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            description,
                            style: AppTypography.body2.copyWith(
                              color: customColors?.textSecondary,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 300),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, value, child) => Positioned(
                    right: 16 + (1 - value) * 20,
                    top: 0,
                    bottom: 0,
                    child: Opacity(
                      opacity: value,
                      child: Center(
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary,
                          ),
                          child: Icon(
                            Icons.check,
                            size: 14,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
