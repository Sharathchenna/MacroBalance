import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/energy/constants.dart';
import '../../services/energy/energy_summary.dart';
import '../../services/posthog_service.dart';
import '../../theme/app_theme.dart';

String _times(int n, String one, String many) =>
    n == 1 ? '1 more $one' : '$n more $many';

/// The one thing to do next while the estimate is learning.
String learningNextStep(int days, int weighIns) {
  final daysLeft = kMinCompleteDays - days;
  final weighLeft = kMinWeighIns - weighIns;
  if (daysLeft > 0 && weighLeft > 0) {
    return 'Log your food for ${_times(daysLeft, 'day', 'days')} and weigh '
        'in ${_times(weighLeft, 'time', 'times')}.';
  }
  if (daysLeft > 0) {
    return 'Log your food for ${_times(daysLeft, 'day', 'days')}.';
  }
  if (weighLeft > 0) return 'Weigh in ${_times(weighLeft, 'time', 'times')}.';
  return 'Almost there. Keep logging and weighing in.';
}

/// Explains a target that still rests on the formula
/// ([EnergySummary.isStartingEstimate]): where it came from, that it can be
/// off for now, and what makes it adjust. Tracks `starting_estimate_opened`.
Future<void> showStartingEstimateSheet(
  BuildContext context,
  EnergySummary summary,
) {
  PostHogService.trackEvent('starting_estimate_opened', properties: {
    'complete_days': summary.completeDays,
    'weigh_ins': summary.weighIns,
  });
  final colors = Theme.of(context).extension<CustomColors>()!;
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: colors.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => StartingEstimateSheet(summary: summary),
  );
}

class StartingEstimateSheet extends StatelessWidget {
  const StartingEstimateSheet({super.key, required this.summary});

  final EnergySummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    final days = math.min(summary.completeDays, kMinCompleteDays);
    final weighed = math.min(summary.weighIns, kMinWeighIns);
    final body = GoogleFonts.inter(
        fontSize: 15, height: 1.45, color: colors.textSecondary);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        child: Column(
          key: const Key('starting_estimate_sheet'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your target is a starting estimate',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'We worked it out from your age, height, weight and activity '
              'level. Everyone burns a different amount, so for now it may be '
              'a few hundred cals too high or too low for you.',
              style: body,
            ),
            const SizedBox(height: 10),
            Text(
              'Log your food and weigh in regularly. Within a week or two, '
              'your weekly check-in adjusts it to what your body actually '
              'burns.',
              style: body,
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.accentPrimary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'In the last 3 weeks: $days of $kMinCompleteDays days '
                    'logged, $weighed of $kMinWeighIns weigh-ins',
                    key: const Key('starting_estimate_progress'),
                    style: GoogleFonts.inter(
                        fontSize: 14, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    learningNextStep(days, weighed),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('starting_estimate_done'),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accentPrimary,
                  foregroundColor: colors.onAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Got it',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
