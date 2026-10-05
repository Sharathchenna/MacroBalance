import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/dateProvider.dart';
import '../../../theme/app_theme.dart';

/// A horizontal date navigator bar with swipe gestures.
/// Displays the current selected date with navigation buttons.
class DateNavigatorBar extends StatefulWidget {
  const DateNavigatorBar({super.key});

  @override
  State<DateNavigatorBar> createState() => _DateNavigatorBarState();
}

class _DateNavigatorBarState extends State<DateNavigatorBar> {
  void _navigateDate(int days) {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final newDate = dateProvider.selectedDate.add(Duration(days: days));
    dateProvider.setDate(newDate);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final tomorrow = now.add(const Duration(days: 1));

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    if (date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day) {
      return 'Tomorrow';
    }
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Yesterday';
    }
    // Locale-aware, e.g. "Thu, Oct 2" or "jeu. 2 oct.".
    return date.year == now.year
        ? DateFormat.MMMEd().format(date)
        : DateFormat.yMMMd().format(date);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! > 0) {
          HapticFeedback.lightImpact();
          _navigateDate(-1);
        } else if (details.primaryVelocity! < 0) {
          HapticFeedback.lightImpact();
          _navigateDate(1);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: _buildNavigationButton(
                icon: Icons.chevron_left,
                onTap: () => _navigateDate(-1),
              ),
            ),
            Expanded(
              child: _buildDateButton(),
            ),
            Expanded(
              child: _buildNavigationButton(
                icon: Icons.chevron_right,
                onTap: () => _navigateDate(1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).extension<CustomColors>()?.dateNavigatorBackground,
      shape: const CircleBorder(),
      elevation: 0.6,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(7.0),
          child: Icon(
            icon,
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildDateButton() {
    return Consumer<DateProvider>(
      builder: (context, dateProvider, child) {
        final isToday = DateUtils.isSameDay(dateProvider.selectedDate, DateTime.now());
        const accent = Color(0xFFFFC107);
        final dateChip = InkWell(
            borderRadius: BorderRadius.circular(18.0),
            onTap: () => _showCalendarPopup(context, dateProvider),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
              decoration: BoxDecoration(
                // Tinted when you're looking at a day other than today, so
                // food isn't logged to the wrong day by accident.
                color: isToday
                    ? Theme.of(context).extension<CustomColors>()?.dateNavigatorBackground
                    : accent.withOpacity(0.25),
                border: isToday ? null : Border.all(color: accent, width: 1),
                borderRadius: BorderRadius.circular(18.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.calendar_today,
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.black
                        : Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 6.0),
                  Text(
                    _formatDate(dateProvider.selectedDate),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.black
                          : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              dateChip,
              if (!isToday)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    dateProvider.setDate(DateTime.now());
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Back to today',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.black87
                            : accent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showCalendarPopup(BuildContext context, DateProvider dateProvider) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.4,
          padding: const EdgeInsets.only(top: 6.0),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          color: Theme.of(context).brightness == Brightness.light
              ? CupertinoColors.systemBackground.resolveFrom(context)
              : CupertinoColors.darkBackgroundGray,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    CupertinoButton(
                      child: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: dateProvider.selectedDate,
                    maximumDate: DateTime.now().add(const Duration(days: 365)),
                    minimumDate: DateTime.now().subtract(const Duration(days: 365)),
                    onDateTimeChanged: (DateTime newDate) {
                      dateProvider.setDate(newDate);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
