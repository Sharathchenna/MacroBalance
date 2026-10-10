import 'package:flutter/material.dart';
import 'package:macrotracker/theme/app_theme.dart';

class TooltipIcon extends StatelessWidget {
  final String message;

  const TooltipIcon({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<CustomColors>();
    // Neutral in both themes: the dark theme's primary is a stray blue.
    final ink = colors?.textPrimary ?? theme.colorScheme.onSurface;
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 3),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: TextStyle(
        color: theme.scaffoldBackgroundColor,
        fontSize: 12,
      ),
      child: Icon(
        Icons.info_outline_rounded,
        size: 16,
        color: colors?.textSecondary ?? theme.colorScheme.onSurface,
      ),
    );
  }
}
