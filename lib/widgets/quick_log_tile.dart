import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/typography.dart';

/// A food row with a one-tap "+" to log it. Tapping the row opens details.
class QuickLogTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? trailingLabel;
  final VoidCallback onOpen;
  final VoidCallback onAdd;
  final String addTooltip;

  const QuickLogTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onOpen,
    required this.onAdd,
    this.trailingLabel,
    this.addTooltip = 'Log again',
  });

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    const accent = Color(0xFFFFC107);
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body1.copyWith(
                      color: customColors?.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(color: customColors?.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailingLabel != null) ...[
              const SizedBox(width: 8),
              Text(
                trailingLabel!,
                style: AppTypography.body2.copyWith(
                  color: customColors?.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(width: 4),
            IconButton(
              tooltip: addTooltip,
              onPressed: () {
                HapticFeedback.lightImpact();
                onAdd();
              },
              icon: const Icon(Icons.add_circle, color: accent, size: 28),
            ),
          ],
        ),
      ),
    );
  }
}
