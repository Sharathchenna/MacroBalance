import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Rebuilds [builder] every frame with the seconds since it started. The
/// intro animations are looping timelines taken from the mock's CSS
/// keyframes, so one running clock drives each of them. With [animate] off
/// nothing ticks and [builder] gets 0.
class IntroClock extends StatefulWidget {
  const IntroClock({super.key, required this.builder, this.animate = true});

  final Widget Function(BuildContext context, double seconds) builder;
  final bool animate;

  @override
  State<IntroClock> createState() => _IntroClockState();
}

class _IntroClockState extends State<IntroClock>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((d) {
    _seconds.value = d.inMicroseconds / 1e6;
  });
  final _seconds = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    if (widget.animate) _ticker.start();
  }

  @override
  void didUpdateWidget(IntroClock old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_ticker.isActive) _ticker.start();
    if (!widget.animate && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
        valueListenable: _seconds,
        builder: (context, s, _) => widget.builder(context, widget.animate ? s : 0),
      );
}

/// Progress 0..1 of [t] between [a] and [b], eased by [curve].
double seg(double t, double a, double b, [Curve curve = Curves.linear]) {
  if (t <= a) return 0;
  if (t >= b) return 1;
  return curve.transform((t - a) / (b - a));
}
