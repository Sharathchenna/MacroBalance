import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/dateProvider.dart';
import '../../../providers/day_status_provider.dart';
import '../../../providers/foodEntryProvider.dart';
import '../../../providers/goals_provider.dart';
import '../../../services/energy/day_status.dart';
import '../../../theme/app_theme.dart';

/// A quiet row at the end of the meal list: "Done logging? Finish day".
/// Once finished it reads "Day finished ✓" and opens a menu to change it.
class FinishDayRow extends StatelessWidget {
  const FinishDayRow({super.key});

  @override
  Widget build(BuildContext context) {
    final date = context.select<DateProvider, DateTime>((d) => d.selectedDate);
    final status = context.watch<DayStatusProvider>().statusFor(date);
    final colors = Theme.of(context).extension<CustomColors>();
    final muted = colors?.textSecondary;
    final isLight = Theme.of(context).brightness == Brightness.light;

    final style = GoogleFonts.poppins(fontSize: 13, color: muted);
    final Widget label = status == null
        ? Text.rich(TextSpan(style: style, children: [
            const TextSpan(text: 'Done logging? '),
            TextSpan(
              text: 'Finish day',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isLight ? Colors.black87 : const Color(0xFFFFC107),
              ),
            ),
          ]))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                switch (status) {
                  ExplicitDayStatus.complete => 'Day finished',
                  ExplicitDayStatus.fasting => 'Day finished · Fasted',
                  ExplicitDayStatus.partial => 'Day finished · Not fully logged',
                },
                style: style,
              ),
              const SizedBox(width: 4),
              Icon(Icons.check, size: 15, color: muted),
            ],
          );

    return Semantics(
      button: true,
      label: status == null ? 'Finish day' : 'Day finished. Change',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          if (status == null) {
            _set(context, date, ExplicitDayStatus.complete);
          } else {
            _showMenu(context, date, status);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Center(child: label),
        ),
      ),
    );
  }

  /// What the app would have guessed for [date], for analytics.
  static DayStatus? _inferred(BuildContext context, DateTime date) {
    final food = context.read<FoodEntryProvider>();
    final entries = food.getAllEntriesForDate(date);
    return classifyDay(
      day: date,
      today: DateTime.now(),
      explicit: null,
      hasEntries: entries.isNotEmpty,
      loggedCals: food.getTotalCaloriesForDate(date),
      // Until the estimator exists, the formula TDEE stands in.
      tdeeEstimate: context.read<GoalsProvider>().tdee,
    )?.status;
  }

  static void _set(BuildContext context, DateTime date, ExplicitDayStatus? s) {
    context.read<DayStatusProvider>().setStatus(date, s,
        inferredWas: _inferred(context, date));
  }

  void _showMenu(
      BuildContext context, DateTime date, ExplicitDayStatus current) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(sheetContext);
              _set(context, date, null);
            },
            child: const Text('Not finished'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _set(context, date, ExplicitDayStatus.fasting);
            },
            child: const Text('Fasted (ate nothing)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _set(context, date, ExplicitDayStatus.partial);
            },
            child: const Text("Didn't log everything"),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
