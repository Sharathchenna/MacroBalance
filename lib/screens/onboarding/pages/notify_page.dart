import 'package:flutter/material.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_widgets.dart';
import 'package:macrotracker/services/notification_service.dart';
import 'package:macrotracker/theme/ob_theme.dart';
import 'package:macrotracker/widgets/brand/mb_logo.dart';

/// Primer before the iOS notification prompt. "Turn on reminders" asks for
/// the real permission; "Not now" skips without prompting, so we can ask
/// again later in context. Has its own buttons.
class NotifyPage extends StatefulWidget {
  const NotifyPage({
    super.key,
    required this.onNext,
    required this.onSkip,
    this.requestPermission,
  });

  final VoidCallback onNext;
  final VoidCallback onSkip;

  /// Asks for notification permission. Defaults to the notification
  /// service's own prompt; tests pass a stub.
  final Future<void> Function()? requestPermission;

  @override
  State<NotifyPage> createState() => _NotifyPageState();
}

class _NotifyPageState extends State<NotifyPage> {
  bool _asking = false;

  Future<void> _turnOn() async {
    if (_asking) return;
    setState(() => _asking = true);
    try {
      await (widget.requestPermission ?? NotificationService().requestPermissions)();
    } catch (_) {
      // Carry on; reminders can be turned on later in Settings.
    }
    if (!mounted) return;
    setState(() => _asking = false);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Column(
      children: [
        Expanded(
          child: ObPageBody(
            top: 26,
            children: [
              const _NotificationStack(),
              const SizedBox(height: 28),
              const ObHeader(
                title: 'A nudge, not a nag.',
                subtitle:
                    'Meal reminders at times you choose, plus a heads-up when your weekly check-in is ready. People who log every day get a sharper plan, sooner.',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ObPrimaryButton(
                  label: 'Turn on reminders', loading: _asking, onPressed: _turnOn),
              const SizedBox(height: 6),
              ObTextButton(label: 'Not now', color: c.text2, onPressed: widget.onSkip),
            ],
          ),
        ),
      ],
    );
  }
}

/// A bell above three example notifications that drop in one by one.
class _NotificationStack extends StatefulWidget {
  const _NotificationStack();

  @override
  State<_NotificationStack> createState() => _NotificationStackState();
}

class _NotificationStackState extends State<_NotificationStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
  bool _started = false;
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _still = MediaQuery.of(context).disableAnimations;
    if (!_still) _ctl.repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  /// Eases in the drop of the notification that starts at [delayMs].
  double _drop(int delayMs, double elapsedMs) =>
      Curves.easeOutBack.transform(((elapsedMs - delayMs) / 600).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    // The drops play once; the bell keeps ringing every 3 s after 2.4 s.
    return _OnceClock(
      builder: (context, elapsedMs) {
        final items = [
          (
            400,
            ObIconTile(
              size: 36,
              color: c.bg,
              child: MbMark(height: 15, color: c.text),
            ),
            'Lunch time',
            'now',
            'Snap your plate and it’s logged.',
            c.bg,
          ),
          (
            1100,
            null,
            'Weekly check-in ready',
            'Sun',
            'Your target moved 80 cals. Here’s why.',
            c.leaf.withValues(alpha: 0.14),
          ),
          (
            1800,
            null,
            '5 days in a row',
            '8:02 pm',
            'Finish today to keep it going.',
            c.sun.withValues(alpha: 0.14),
          ),
        ];
        final icons = <int, (IconData, Color)>{
          1100: (Icons.autorenew_rounded, c.leaf),
          1800: (Icons.local_fire_department_outlined, c.sun),
        };
        return Semantics(
          label: 'Three example notifications',
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 22, 14, 16),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: c.line),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: AnimatedBuilder(
                      animation: _ctl,
                      builder: (context, child) => Transform.rotate(
                        angle: _still ? 0 : _ring(_ctl.value),
                        alignment: const Alignment(0, -0.8),
                        child: child,
                      ),
                      child: Icon(Icons.notifications_none_rounded, size: 30, color: c.sun),
                    ),
                  ),
                  for (final it in items) ...[
                    Builder(builder: (context) {
                      final t = _still ? 1.0 : _drop(it.$1, elapsedMs);
                      final icon = icons[it.$1];
                      return Opacity(
                        opacity: t.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, -30 * (1 - t)),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _Note(
                              leading: it.$2 ??
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                        color: it.$6, borderRadius: BorderRadius.circular(10)),
                                    child: Icon(icon!.$1, size: 18, color: icon.$2),
                                  ),
                              title: it.$3,
                              time: it.$4,
                              body: it.$5,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The bell's shake: still for most of the loop, then a few swings.
  static double _ring(double p) {
    const keys = [
      (0.60, 0.0),
      (0.65, 14.0),
      (0.70, -12.0),
      (0.75, 8.0),
      (0.80, -4.0),
      (0.85, 0.0),
    ];
    if (p < keys.first.$1 || p >= keys.last.$1) return 0;
    for (var i = 1; i < keys.length; i++) {
      if (p < keys[i].$1) {
        final a = keys[i - 1];
        final b = keys[i];
        final t = (p - a.$1) / (b.$1 - a.$1);
        return (a.$2 + (b.$2 - a.$2) * t) * 3.14159265 / 180;
      }
    }
    return 0;
  }
}

/// Rebuilds its child every frame with the milliseconds since it appeared
/// (stopping once the longest entrance is over).
class _OnceClock extends StatefulWidget {
  const _OnceClock({required this.builder});

  final Widget Function(BuildContext context, double elapsedMs) builder;

  @override
  State<_OnceClock> createState() => _OnceClockState();
}

class _OnceClockState extends State<_OnceClock> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => widget.builder(context, _c.value * 2600),
      );
}

class _Note extends StatelessWidget {
  const _Note({required this.leading, required this.title, required this.time, required this.body});

  final Widget leading;
  final String title;
  final String time;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(title,
                          style: ObText.body(c.text, size: 13, weight: FontWeight.w600)
                              .copyWith(height: 1.3)),
                    ),
                    const SizedBox(width: 8),
                    Text(time,
                        style: ObText.body(c.muted, size: 13, weight: FontWeight.w500)
                            .copyWith(height: 1.3)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(body, style: ObText.body(c.text2, size: 13).copyWith(height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
