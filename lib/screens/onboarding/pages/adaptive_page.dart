import 'package:provider/provider.dart';
import 'package:macrotracker/providers/detailed_stats_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/widgets/adaptive_choice.dart';

/// "Should your plan learn as you go?": adaptive goals on (recommended, the
/// default) or fixed targets (plan 10.1).
class AdaptivePage extends StatelessWidget {
  const AdaptivePage({
    super.key,
    required this.adaptive,
    required this.onChanged,
  });

  final bool adaptive;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    if (!context.watch<DetailedStatsProvider>().showDetailedStats) {
      final theme = Theme.of(context);
      final colors = theme.extension<CustomColors>()!;
      final accent = colors.accentPrimary;
      final accentText = theme.brightness == Brightness.dark
          ? accent
          : const Color(0xFF2E6A3D);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BUILT AROUND YOU',
                style: GoogleFonts.onest(
                    color: accentText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.8)),
            const SizedBox(height: 14),
            Text('A plan that\nkeeps up.',
                style: GoogleFonts.onest(
                    color: colors.textPrimary,
                    fontSize: 36,
                    height: 1.12,
                    letterSpacing: -1.4,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Text(
                'Your food logs and weigh-ins help us find what works for you.',
                style: TextStyle(
                    color: colors.textSecondary, fontSize: 16, height: 1.5)),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: accent.withValues(alpha: .16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A weekly rhythm, rather than a made-up progress chart.
                  ExcludeSemantics(
                    child: Row(children: [
                      for (var day = 0; day < 7; day++) ...[
                        if (day > 0) const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 32,
                            decoration: BoxDecoration(
                              color:
                                  accent.withValues(alpha: day == 6 ? 1 : .12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              day == 6
                                  ? adaptive
                                      ? Icons.autorenew_rounded
                                      : Icons.lock_outline_rounded
                                  : Icons.check_rounded,
                              size: 16,
                              color: day == 6
                                  ? theme.scaffoldBackgroundColor
                                  : accent,
                            ),
                          ),
                        ),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 18),
                  Text(
                      adaptive
                          ? 'Small updates. A better fit.'
                          : 'Your plan. Your choice.',
                      style: GoogleFonts.onest(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                      adaptive
                          ? 'Once we’ve learned enough, we review your targets at a weekly check-in.'
                          : 'Keep a fixed target, and turn on weekly updates whenever you like.',
                      style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 14,
                          height: 1.45)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SimpleAdaptiveChoice(adaptive: adaptive, onChanged: onChanged),
          ],
        ),
      );
    }
    final theme = Theme.of(context);
    final colors = theme.extension<CustomColors>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AdaptiveChoiceCopy.question,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            AdaptiveChoiceCopy.intro,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: colors?.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          AdaptiveChoiceOptions(adaptive: adaptive, onChanged: onChanged),
        ],
      ),
    );
  }
}
