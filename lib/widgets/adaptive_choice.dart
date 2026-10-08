import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/goals_provider.dart';
import '../services/posthog_service.dart';
import '../theme/app_theme.dart';

/// "Should your plan learn as you go?" (plan 10.1): the copy and the two
/// options, shared by the onboarding step, Settings and the Energy tab so the
/// choice reads the same everywhere.
abstract final class AdaptiveChoiceCopy {
  static const question = 'Should your plan learn as you go?';
  static const intro = 'Everyone\'s metabolism is different. Formulas can be '
      'off by 300 cals a day or more.';
  static const yesTitle = 'Yes, adjust my targets weekly';
  static const yesBody = 'We\'ll learn what you actually burn from your logs '
      'and weigh-ins, then update your targets every week and tell you why.';
  static const noTitle = 'No, keep my targets fixed';
  static const noBody = 'Your targets stay as calculated today. You can turn '
      'this on anytime in Settings.';

  /// The one line under the target on the results screen.
  static String resultLine(bool adaptive) => adaptive
      ? 'Updates weekly as we learn your metabolism'
      : 'Fixed target';
}

/// Where the choice was made, for `adaptive_choice_made{choice, context}`.
enum AdaptiveChoiceContext { onboarding, settings, recalculate }

/// Sends `adaptive_choice_made`.
void trackAdaptiveChoice(bool adaptive, AdaptiveChoiceContext context) =>
    PostHogService.trackEvent('adaptive_choice_made', properties: {
      'choice': adaptive ? 'adaptive' : 'fixed',
      'context': context.name,
    });

/// The weekday's full name, e.g. "Monday", for an ISO weekday (1 = Monday).
String weekdayName(int weekday) =>
    DateFormat.EEEE().format(DateTime(2024, 1, weekday)); // Jan 1 2024: Monday

/// Yes (recommended) and No as a radio list, in the pace picker's style.
class AdaptiveChoiceOptions extends StatelessWidget {
  const AdaptiveChoiceOptions({
    super.key,
    required this.adaptive,
    required this.onChanged,
  });

  final bool adaptive;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<CustomColors>();
    return Container(
      decoration: BoxDecoration(
        color: colors?.cardBackground ?? theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          ChoiceOption(
            key: const Key('adaptive_yes'),
            title: AdaptiveChoiceCopy.yesTitle,
            body: AdaptiveChoiceCopy.yesBody,
            selected: adaptive,
            recommended: true,
            onTap: () => onChanged(true),
          ),
          Divider(
              height: 1, indent: 52, color: Colors.grey.withValues(alpha: 0.15)),
          ChoiceOption(
            key: const Key('adaptive_no'),
            title: AdaptiveChoiceCopy.noTitle,
            body: AdaptiveChoiceCopy.noBody,
            selected: !adaptive,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

/// One row of a radio list: a radio, a title (with an optional Recommended
/// badge) and a line of explanation. Shared by the adaptive and plan-style
/// choices.
class ChoiceOption extends StatelessWidget {
  const ChoiceOption({
    super.key,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
    this.recommended = false,
  });

  final String title;
  final String body;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<CustomColors>();
    final accent = colors?.accentPrimary ?? theme.colorScheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: selected
                    ? accent
                    : (colors?.textSecondary ?? Colors.grey)
                        .withValues(alpha: 0.6),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors?.textPrimary,
                          ),
                        ),
                        if (recommended)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Recommended',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: colors?.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks the adaptive question again, outside onboarding, with [initial]
/// picked. Returns the confirmed choice, or null when dismissed.
Future<bool?> showAdaptiveChoiceSheet(BuildContext context,
    {required bool initial}) {
  final colors = Theme.of(context).extension<CustomColors>()!;
  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: colors.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AdaptiveChoiceSheet(initial: initial),
  );
}

class _AdaptiveChoiceSheet extends StatefulWidget {
  const _AdaptiveChoiceSheet({required this.initial});

  final bool initial;

  @override
  State<_AdaptiveChoiceSheet> createState() => _AdaptiveChoiceSheetState();
}

class _AdaptiveChoiceSheetState extends State<_AdaptiveChoiceSheet> {
  late bool _adaptive = widget.initial;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              AdaptiveChoiceCopy.question,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AdaptiveChoiceCopy.intro,
              style: GoogleFonts.inter(
                  fontSize: 14, height: 1.4, color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            AdaptiveChoiceOptions(
              adaptive: _adaptive,
              onChanged: (v) => setState(() => _adaptive = v),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('adaptive_confirm'),
                onPressed: () => Navigator.pop(context, _adaptive),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accentPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _adaptive ? 'Turn on weekly updates' : 'Keep my targets fixed',
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A toggle outside onboarding (Settings, the Energy tab): confirms with the
/// onboarding copy, [to] picked, then saves whatever was chosen. Returns
/// whether adaptive goals changed.
Future<bool> changeAdaptiveGoals(BuildContext context, {required bool to}) async {
  HapticFeedback.lightImpact();
  final goals = Provider.of<GoalsProvider>(context, listen: false);
  final choice = await showAdaptiveChoiceSheet(context, initial: to);
  if (choice == null || choice == goals.adaptiveGoals) return false;
  goals.adaptiveGoals = choice;
  trackAdaptiveChoice(choice, AdaptiveChoiceContext.settings);
  return true;
}
