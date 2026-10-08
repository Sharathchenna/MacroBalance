import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/energy_provider.dart';
import '../../services/energy/checkin.dart';
import '../../services/energy/estimate_rows.dart';
import '../../theme/app_theme.dart';
import '../../widgets/progress_card.dart';
import 'checkin_sheet.dart';

/// Energy tab → past check-ins, newest first (spec 7.1 R6). Each row shows
/// the day, old → new cals and why; tapping it reopens that week's sheet.
/// Hidden while there are none.
class CheckinHistoryCard extends StatefulWidget {
  const CheckinHistoryCard({super.key});

  /// Rows shown before "Show all".
  static const shown = 4;

  @override
  State<CheckinHistoryCard> createState() => _CheckinHistoryCardState();
}

class _CheckinHistoryCardState extends State<CheckinHistoryCard> {
  bool _all = false;

  static const _info = ProgressInfo('Check-ins', [
    InfoSection(
      'Once a week, on your check-in day, we compare your expenditure with '
      'what your targets were set from and update them if needed. Each '
      'check-in is kept here, with what changed and why.',
    ),
    InfoSection(
      'Tap one to see that week again. Check-in days are also marked on the '
      'chart above.',
    ),
  ]);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    final energy = context.watch<EnergyProvider>();
    final checkins = energy.checkins;
    if (checkins.isEmpty) return const SizedBox.shrink();
    final rows = _all ? checkins : checkins.take(CheckinHistoryCard.shown).toList();
    final more = checkins.length - rows.length;

    return ProgressCard(
      key: const Key('checkin_history'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProgressCardTitle('Check-ins', info: _info),
          const SizedBox(height: 4),
          for (final (i, c) in rows.indexed) ...[
            if (i > 0)
              Divider(height: 1, color: colors.textSecondary.withValues(alpha: 0.14)),
            CheckinHistoryRow(
              checkin: c,
              lossPhaseNumber: lossPhaseNumber(c, energy.phases),
            ),
          ],
          if (more > 0)
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _all = true);
              },
              style: TextButton.styleFrom(
                foregroundColor: colors.accentPrimary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 40),
              ),
              child: Text(
                'Show all ($more more)',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

/// One past check-in: "Mon, Oct 5", "2,507 → 2,451 cals" and its one-line
/// reason. Opens its sheet.
class CheckinHistoryRow extends StatelessWidget {
  const CheckinHistoryRow({super.key, required this.checkin, this.lossPhaseNumber});

  final GoalCheckin checkin;
  final int? lossPhaseNumber;

  /// "Mon, Oct 5", with the year when it isn't this year's.
  static String dateText(DateTime day, DateTime now) =>
      DateFormat(day.year == now.year ? 'EEE, MMM d' : 'EEE, MMM d, y').format(day);

  /// "2,507 → 2,451 cals" when the targets changed, else "2,451 cals".
  static String calsText(GoalCheckin c) => c.variant.appliesTargets &&
          c.oldTargets.cals != c.newTargets.cals
      ? '${fmtCals(c.oldTargets.cals)} → ${fmtCals(c.newTargets.cals)} cals'
      : '${fmtCals(c.newTargets.cals)} cals';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    final summary = CheckinCopy(checkin, lossPhaseNumber: lossPhaseNumber).summary;
    final date = dateText(checkin.weekStart, DateTime.now());
    final cals = calsText(checkin);

    return Semantics(
      button: true,
      label: 'Check-in $date, $cals, $summary',
      excludeSemantics: true,
      child: InkWell(
        key: Key('checkin_row_${dayKey(checkin.weekStart)}'),
        onTap: () {
          HapticFeedback.lightImpact();
          showCheckinSheet(context, checkin, source: CheckinSheetSource.history);
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          date,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          cals,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 13, height: 1.35, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: colors.textSecondary.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
