import 'package:flutter/material.dart';

class TooltipIcon extends StatelessWidget {
  final String message;

  const TooltipIcon({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: TextStyle(
        color: theme.colorScheme.onPrimary,
        fontSize: 12,
      ),
      child: Icon(
        Icons.info_outline_rounded,
        size: 16,
        color: theme.colorScheme.primary,
      ),
    );
  }
}
