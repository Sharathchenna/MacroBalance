import 'package:flutter/material.dart';

/// Marks nutrition that comes from an AI estimate rather than a database or
/// label. Used the same way in search, Ask AI and photo results.
class AIEstimateBadge extends StatelessWidget {
  /// Adds a one-line accuracy note under the badge.
  final bool showNote;

  const AIEstimateBadge({super.key, this.showNote = false});

  static const String note =
      'Estimated by AI. Check the label or adjust the serving if it looks off.';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? const Color(0xFFFFD54F) : const Color(0xFF8A6D00);
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107).withOpacity(isDark ? 0.2 : 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            'AI estimate',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
    if (!showNote) return badge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(height: 4),
        Text(
          note,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }
}
