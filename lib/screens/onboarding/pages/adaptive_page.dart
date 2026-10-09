import 'package:provider/provider.dart';
import 'package:macrotracker/providers/detailed_stats_provider.dart';
import 'package:flutter/material.dart';
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
      return Padding(padding: const EdgeInsets.all(24), child: SimpleAdaptiveChoice(adaptive: adaptive, onChanged: onChanged));
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
