import 'package:flutter/material.dart';
import 'package:macrotracker/theme/app_theme.dart'; // Assuming theme is needed

class UnitSelector extends StatelessWidget {
  final bool isMetric;
  final String metricUnit;
  final String imperialUnit;
  final ValueChanged<bool> onChanged;

  const UnitSelector({
    super.key,
    required this.isMetric,
    required this.metricUnit,
    required this.imperialUnit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildUnitOption(
            context: context,
            isSelected: isMetric,
            label: metricUnit,
            onTap: () => onChanged(true),
          ),
          _buildUnitOption(
            context: context,
            isSelected: !isMetric,
            label: imperialUnit,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitOption({
    required BuildContext context,
    required bool isSelected,
    required String label,
    required VoidCallback onTap,
  }) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? (customColors?.textPrimary ?? theme.colorScheme.primary) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? theme.colorScheme.onPrimary : (customColors?.textSecondary ?? theme.textTheme.bodySmall?.color),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
