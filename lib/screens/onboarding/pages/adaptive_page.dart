import 'package:flutter/material.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_widgets.dart';
import 'package:macrotracker/theme/ob_theme.dart';
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
    final c = ObColors.of(context);
    return ObPageBody(
      children: [
        const ObHeader(eyebrow: 'Built around you', title: AdaptiveChoiceCopy.question),
        const SizedBox(height: 24),
        ObRise(
          index: 2,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: c.leaf.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: c.leaf.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WeekStrip(adaptive: adaptive),
                const SizedBox(height: 8),
                // Shrinks rather than overflows at large text sizes.
                Row(
                  children: [
                    for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'])
                      Expanded(child: _dayLabel(d, c.muted, Alignment.centerLeft)),
                    Expanded(
                        flex: 2,
                        child: _dayLabel('Check-in', c.leafText, Alignment.centerRight)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  adaptive ? 'Small updates. A better fit.' : 'Your plan. Your call.',
                  style: ObText.title(c.text, size: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  adaptive
                      ? 'Once we’ve learned enough from your logs and weigh-ins, your weekly check-in fine-tunes your targets.'
                      : 'Your targets stay where they are. The check-in still shows what we’ve learned.',
                  style: ObText.body(c.text2, size: 14).copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        ObRise(
          index: 3,
          child: Column(
            children: [
              ObOptionTile(
                key: const Key('adaptive_yes'),
                title: 'Yes, adjust weekly',
                subtitle: 'New targets apply on their own. You’ll always see why.',
                badge: 'Recommended',
                selected: adaptive,
                onTap: () => onChanged(true),
              ),
              const SizedBox(height: 10),
              ObOptionTile(
                key: const Key('adaptive_no'),
                title: 'Keep my targets fixed',
                subtitle: 'Turn on weekly updates whenever you like.',
                selected: !adaptive,
                onTap: () => onChanged(false),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _dayLabel(String text, Color color, Alignment alignment) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(text, style: _day(color)),
      );

  static TextStyle _day(Color color) =>
      ObText.body(color, size: 11, weight: FontWeight.w500).copyWith(height: 1.2);
}

/// Six days tick in one after another; the seventh lights up as the
/// check-in, spinning when targets adapt and showing a lock when fixed.
class _WeekStrip extends StatefulWidget {
  const _WeekStrip({required this.adaptive});

  final bool adaptive;

  @override
  State<_WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends State<_WeekStrip> with TickerProviderStateMixin {
  static const _totalMs = 2300.0;
  late final AnimationController _in =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2300));
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _in.value = 1;
    } else {
      _in.forward();
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _in.dispose();
    _spin.dispose();
    super.dispose();
  }

  /// Progress of a stretch starting at [startMs] and lasting [ms].
  double _seg(double startMs, double ms, Curve curve) =>
      curve.transform(((_in.value * _totalMs - startMs) / ms).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: Listenable.merge([_in, _spin]),
        builder: (context, _) => Row(
          children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i < 6
                        ? c.leaf.withValues(alpha: 0.12)
                        : Color.lerp(c.leaf.withValues(alpha: 0.12), c.leaf,
                            _seg(1800, 400, Curves.linear)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: i < 6 ? _tick(c, i) : _check(c),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tick(ObColors c, int i) {
    final t = _seg(500 + 200.0 * i, 350, Curves.easeOutBack);
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.4 + 0.6 * t,
        child: Icon(Icons.check_rounded, size: 16, color: c.leafText),
      ),
    );
  }

  Widget _check(ObColors c) {
    final t = _seg(1900, 350, Curves.easeOutBack).clamp(0.0, 1.0);
    final icon = widget.adaptive
        ? Transform.rotate(
            angle: _spin.value * 6.2831853 * (_in.value < 1 ? 0 : 1),
            child: Icon(Icons.autorenew_rounded, size: 18, color: c.onLeaf),
          )
        : Icon(Icons.lock_outline_rounded, size: 18, color: c.onLeaf);
    return Opacity(opacity: t, child: Transform.scale(scale: 0.4 + 0.6 * t, child: icon));
  }
}
