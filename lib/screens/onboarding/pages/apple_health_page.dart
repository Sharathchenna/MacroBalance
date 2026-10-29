import 'package:flutter/material.dart';
import 'package:macrotracker/Health/Health.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_widgets.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/theme/ob_theme.dart';
import 'package:macrotracker/widgets/brand/mb_logo.dart';

/// Primer shown before the iOS Health sheet. "Connect" opens the real
/// permission; "Not now" skips without using up the one-time iOS prompt.
/// Has its own buttons, so the onboarding shell hides its Continue here.
class AppleHealthPage extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const AppleHealthPage({
    super.key,
    required this.onNext,
    required this.onSkip,
  });

  Future<void> _handleConnect() async {
    try {
      final granted = await HealthService().requestPermissions();
      StorageService().put('healthConnected', granted);
    } catch (_) {
      // Carry on either way; Settings can connect it later.
    } finally {
      onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Column(
      children: [
        Expanded(
          child: ObPageBody(
            top: 28,
            children: [
              ObRise(
                child: Semantics(
                  label: 'Apple Health and MacroBalance syncing both ways',
                  child: const ExcludeSemantics(child: _SyncIllustration()),
                ),
              ),
              const SizedBox(height: 4),
              const ObHeader(
                title: 'Let your steps and burn count.',
                subtitle:
                    'Connecting Apple Health lets your plan learn faster, and puts your activity right next to your food.',
              ),
              const SizedBox(height: 22),
              ObRise(
                index: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: ColoredBox(
                    color: c.surface,
                    child: Column(
                      children: [
                        _Row(label: 'We read', color: c.text2, text: 'Weight · Height · Steps · Active and resting energy'),
                        Divider(height: 1, thickness: 1, color: c.raised),
                        _Row(label: 'We save', color: c.leafText, text: 'Your meals and macros'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ObRise(
                index: 3,
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Next, iOS asks what to share. Choose '),
                    TextSpan(text: 'Turn On All', style: TextStyle(color: c.text)),
                    const TextSpan(
                        text: ' for the best estimate. You can change it any time in Settings.'),
                  ]),
                  style: ObText.body(c.muted, size: 13),
                ),
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
              ObPrimaryButton(label: 'Connect Apple Health', onPressed: _handleConnect),
              const SizedBox(height: 6),
              ObTextButton(label: 'Not now', onPressed: onSkip),
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.color, required this.text});

  final String label;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(label.toUpperCase(),
                style: ObText.body(color, size: 12, weight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: ObText.body(c.text))),
        ],
      ),
    );
  }
}

/// Health tile on the left, the MacroBalance tile on the right, two lanes
/// between them. Dots travel only across the gap and fade before either
/// tile.
class _SyncIllustration extends StatefulWidget {
  const _SyncIllustration();

  @override
  State<_SyncIllustration> createState() => _SyncIllustrationState();
}

class _SyncIllustrationState extends State<_SyncIllustration>
    with SingleTickerProviderStateMixin {
  // One cycle of the dots, glow and heartbeat.
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 4800));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!MediaQuery.of(context).disableAnimations) _ctl.repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return SizedBox(
      height: 140,
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        const tile = 84.0;
        const inset = 8.0;
        const laneLeft = inset + tile + 8;
        final laneW = w - 2 * laneLeft;
        final travel = laneW - 24;
        return AnimatedBuilder(
          animation: _ctl,
          builder: (context, _) {
            // 2.4 s dot loop, 1.6 s heartbeat, 2.4 s glow, as in the mock.
            final t = _ctl.value * 4800;
            final loop = (t % 2400) / 2400;
            final glow = (1 - (2 * ((t % 2400) / 2400) - 1).abs());
            final beat = _beat((t % 1600) / 1600);
            final still = MediaQuery.of(context).disableAnimations;
            return Stack(
              children: [
                Positioned(
                  left: inset,
                  top: 20,
                  child: Container(
                    width: tile,
                    height: tile,
                    decoration: BoxDecoration(
                      color: c.isDark ? c.text : c.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: c.isDark ? null : Border.all(color: c.line),
                    ),
                    alignment: Alignment.center,
                    child: Transform.scale(
                      scale: still ? 1 : beat,
                      child: Icon(Icons.favorite_rounded, size: 46, color: c.protein),
                    ),
                  ),
                ),
                Positioned(
                  right: inset,
                  top: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(tile * 0.28),
                      boxShadow: [
                        BoxShadow(
                          color: c.leaf.withValues(alpha: still ? 0 : 0.14 * glow),
                          spreadRadius: 6 * glow,
                        ),
                      ],
                    ),
                    child: const MbLogoTile(size: tile),
                  ),
                ),
                Positioned(
                  left: laneLeft,
                  top: 24,
                  child: CustomPaint(
                    size: Size(laneW, 76),
                    painter: _LanePainter(
                      phase: still ? 0 : (t % 800) / 800,
                      top: c.muted.withValues(alpha: 0.5),
                      bottom: c.leaf.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                Positioned(
                  left: laneLeft,
                  width: laneW,
                  top: 22,
                  child: Text('Steps, weight, burn',
                      textAlign: TextAlign.center,
                      style: ObText.body(c.text2, size: 11, weight: FontWeight.w500)
                          .copyWith(height: 1.2)),
                ),
                Positioned(
                  left: laneLeft,
                  width: laneW,
                  top: 86,
                  child: Text('Meals and macros',
                      textAlign: TextAlign.center,
                      style: ObText.body(c.leafText, size: 11, weight: FontWeight.w500)
                          .copyWith(height: 1.2)),
                ),
                if (!still)
                  for (var k = 0; k < 3; k++) ...[
                    _dot(c.text, laneLeft + 4, 45, travel, (loop + k / 3) % 1, 1),
                    _dot(c.leaf, laneLeft + laneW - 14, 69, travel, (loop + k / 3) % 1, -1),
                  ],
              ],
            );
          },
        );
      }),
    );
  }

  /// A dot at lane position [p] (0..1), fading in over the first 20% and out
  /// over the last 20% of its trip, moving [dir] (1 right, -1 left).
  Widget _dot(Color color, double x, double y, double travel, double p, int dir) {
    final e = Curves.easeInOut.transform(p);
    final o = p < 0.2 ? p / 0.2 : (p > 0.8 ? (1 - p) / 0.2 : 1.0);
    return Positioned(
      left: x + dir * travel * e,
      top: y,
      child: Opacity(
        opacity: o.clamp(0.0, 1.0),
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }

  /// The mock's beat keyframes: 1 -> 1.12 -> 1 -> 1.08 -> 1 over 45%.
  static double _beat(double p) {
    double ease(double a, double b, double t) =>
        a + (b - a) * Curves.easeInOut.transform(t.clamp(0.0, 1.0));
    if (p < 0.15) return ease(1, 1.12, p / 0.15);
    if (p < 0.30) return ease(1.12, 1, (p - 0.15) / 0.15);
    if (p < 0.45) return ease(1, 1.08, (p - 0.30) / 0.15);
    if (p < 0.6) return ease(1.08, 1, (p - 0.45) / 0.15);
    return 1;
  }
}

/// Two dotted lanes whose dashes drift in opposite directions.
class _LanePainter extends CustomPainter {
  _LanePainter({required this.phase, required this.top, required this.bottom});

  final double phase;
  final Color top;
  final Color bottom;

  @override
  void paint(Canvas canvas, Size size) {
    void lane(double y, Color color, double dir) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      // Dash 2, gap 6: a period of 8 that shifts by one period per cycle.
      final shift = dir * phase * 8;
      for (var x = -8 + (shift % 8); x < size.width; x += 8) {
        final a = x.clamp(0.0, size.width);
        final b = (x + 2).clamp(0.0, size.width);
        if (b > a) canvas.drawLine(Offset(a, y), Offset(b, y), paint);
      }
    }

    lane(26, top, 1);
    lane(50, bottom, -1);
  }

  @override
  bool shouldRepaint(_LanePainter old) =>
      old.phase != phase || old.top != top || old.bottom != bottom;
}
