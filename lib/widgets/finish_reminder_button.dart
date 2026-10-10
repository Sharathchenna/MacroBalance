import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/finish_reminder_provider.dart';
import '../services/energy/finish_reminder.dart';
import '../services/energy/constants.dart';
import '../theme/app_theme.dart';

/// "Remind me in the evening": the finish-day reminder's opt-in, shown only
/// where it helps (check-in variant C and the data-quality tip). Once it's
/// on, the button gives way to a line saying when it goes out; the time can
/// be changed in Settings → Notifications.
///
/// Nothing is turned on unless the user taps, and it never asks for
/// notification permission: without it, the button says where to allow it.
class FinishReminderButton extends StatefulWidget {
  const FinishReminderButton({super.key, required this.source});

  final FinishReminderSource source;

  @override
  State<FinishReminderButton> createState() => _FinishReminderButtonState();
}

class _FinishReminderButtonState extends State<FinishReminderButton> {
  bool _blocked = false;
  bool _busy = false;

  Future<void> _enable(FinishReminderProvider reminder) async {
    if (_busy) return;
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    final ok = await reminder.enable(widget.source);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _blocked = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reminder = context.watch<FinishReminderProvider?>();
    if (reminder == null) return const SizedBox.shrink();
    final colors = Theme.of(context).extension<CustomColors>()!;
    final small = GoogleFonts.inter(fontSize: 13, height: 1.4, color: colors.textSecondary);

    if (reminder.enabled) {
      final when = reminder.mode == FinishReminderMode.mergedIntoMeal
          ? "We'll add it to your meal reminder"
          : 'Reminder set for ${formatReminderTime(reminder.minutes)}';
      return Row(
        key: const Key('finish_reminder_on'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 16, color: colors.accentPrimary),
          const SizedBox(width: 6),
          Flexible(child: Text(when, style: small)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          child: GestureDetector(
            key: const Key('finish_reminder_button'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _enable(reminder),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 18, color: colors.accentPrimary),
                  const SizedBox(width: 6),
                  Text(
                    'Remind me in the evening',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.accentPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_blocked)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              key: const Key('finish_reminder_blocked'),
              'Notifications are off for this app. Allow them in your phone\'s Settings, then try again.',
              style: small,
            ),
          )
        else
          Text(
            'A nudge at ${formatReminderTime(kFinishReminderMinutes)} to finish your day. Change it in Settings.',
            style: small,
          ),
      ],
    );
  }
}
