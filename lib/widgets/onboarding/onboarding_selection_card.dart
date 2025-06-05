import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/theme/app_theme.dart'; // Assuming theme is needed

class OnboardingSelectionCard extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final String? description; // Optional description for activity/goal cards
  final bool isCompact; // New property for compact mode

  const OnboardingSelectionCard({
    super.key,
    required this.isSelected,
    required this.onTap,
    required this.icon,
    required this.label,
    this.description,
    this.isCompact = false, // Default to normal size
  });

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);
    final Color primaryColor =
        customColors?.textPrimary ?? theme.colorScheme.primary;
    final Color cardBgColor = customColors?.cardBackground ?? theme.cardColor;
    final Color textColor =
        customColors?.textPrimary ?? theme.textTheme.bodyLarge!.color!;
    final Color secondaryTextColor =
        customColors?.textSecondary ?? theme.textTheme.bodyMedium!.color!;
    final Color iconColor = isSelected ? primaryColor : Colors.grey;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick(); // Keep haptic feedback consistent
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? primaryColor.withAlpha(((0.2) * 255).round())
                  : Colors.black.withAlpha(((0.05) * 255).round()),
              blurRadius: isSelected ? 8 : 3,
              offset: Offset(0, isSelected ? 3 : 1),
              spreadRadius: isSelected ? 1 : 0,
            ),
          ],
          border: Border.all(
            color: isSelected
                ? primaryColor
                : Colors.grey.withAlpha(((0.2) * 255).round()),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          // Adjust padding based on compact mode
          padding: isCompact
              ? const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0)
              : const EdgeInsets.all(16.0),
          child: description != null
              ? _buildDetailedLayout(context, primaryColor, textColor,
                  secondaryTextColor, iconColor) // Layout for Activity/Goal
              : _buildSimpleLayout(context, primaryColor, textColor,
                  iconColor), // Layout for Gender
        ),
      ),
    );
  }

  // Layout similar to original _buildSelectionCard (for Gender)
  Widget _buildSimpleLayout(BuildContext context, Color primaryColor,
      Color textColor, Color iconColor) {
    Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          // Adjust height and width based on compact mode
          height: isCompact ? 60 : 80,
          width: isCompact ? 60 : 80,
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withAlpha(((0.1) * 255).round())
                : Colors.grey.withAlpha(((0.05) * 255).round()),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: AnimatedScale(
              scale: isSelected ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 300),
              // Adjust icon size based on compact mode
              child: Icon(icon, size: isCompact ? 36 : 48, color: iconColor),
            ),
          ),
        ),
        // Adjust spacing based on compact mode
        SizedBox(height: isCompact ? 10 : 16),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style:
              (isCompact ? PremiumTypography.bodyLarge : PremiumTypography.h4)
                  .copyWith(
            color: isSelected ? primaryColor : textColor,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: isSelected ? -0.3 : -0.2,
          ),
          child: Text(label),
        ),
      ],
    );
  }

  // Layout similar to original _buildActivityLevelCard / _buildGoalCard
  Widget _buildDetailedLayout(BuildContext context, Color primaryColor,
      Color textColor, Color secondaryTextColor, Color iconColor) {
    Theme.of(context);
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          // Adjust height and width based on compact mode
          width: isCompact ? 44 : 56,
          height: isCompact ? 44 : 56,
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withAlpha(((0.15) * 255).round())
                : Colors.grey.withAlpha(((0.08) * 255).round()),
            borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
          ),
          child: Center(
            child: AnimatedScale(
              scale: isSelected ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 300),
              // Adjust icon size based on compact mode
              child: Icon(icon, size: isCompact ? 22 : 28, color: iconColor),
            ),
          ),
        ),
        // Adjust spacing based on compact mode
        SizedBox(width: isCompact ? 12 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: (isCompact
                        ? PremiumTypography.bodyLarge
                        : PremiumTypography.h4)
                    .copyWith(
                  color: isSelected ? primaryColor : textColor,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: isSelected ? -0.3 : -0.2,
                ),
                child: Text(label),
              ),
              if (description != null) ...[
                // Adjust spacing based on compact mode
                SizedBox(height: isCompact ? 2 : 4),
                Text(
                  description!,
                  style: PremiumTypography.bodyMedium.copyWith(
                    color: secondaryTextColor,
                    height: isCompact ? 1.3 : 1.4,
                    letterSpacing: 0.1,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: isCompact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ]
            ],
          ),
        ),
        // Optional: Add a small check indicator for selected items in compact mode
        if (isSelected && isCompact)
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor,
            ),
            child: const Icon(
              Icons.check,
              size: 10,
              color: Colors.white,
            ),
          ),
      ],
    );
  }
}
