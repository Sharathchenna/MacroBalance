import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_widgets.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/theme/ob_theme.dart';
import 'package:macrotracker/widgets/brand/mb_logo.dart';

/// "Building your plan" (docs/onboarding-redesign/mock/Building.dc.html).
///
/// Runs [work] once (the real calculation and save) while four steps play in
/// turn: the burn estimate, the safe pace, the macro split and the first
/// check-in day. It never finishes before [work] does. It ends on the
/// plan-ready check (assets/animations/plan_ready.json), then calls [onDone].
class BuildingScreen extends StatefulWidget {
  const BuildingScreen({
    super.key,
    required this.work,
    required this.onDone,
    this.goal = MacroCalculatorService.GOAL_LOSE,
  });

  final Future<void> Function() work;
  final VoidCallback onDone;
  final String goal;

  @override
  State<BuildingScreen> createState() => _BuildingScreenState();
}

class _BuildingScreenState extends State<BuildingScreen>
    with TickerProviderStateMixin {
  static const _stepCount = 4;
  static const _stepTime = Duration(milliseconds: 1600);
  static const _quickStepTime = Duration(milliseconds: 350);

  /// How long the finished check holds before moving on.
  static const _hold = Duration(milliseconds: 2200);

  late final AnimationController _breathe = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));
  late final AnimationController _titles = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));

  /// Steps finished so far, 0 to 4.
  int _done = 0;
  bool _ready = false;
  bool _finished = false;
  bool _started = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _breathe.repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion) _breathe.stop();
    if (!_started) {
      _started = true;
      _run();
    }
  }

  @override
  void dispose() {
    _breathe.dispose();
    _titles.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final work = widget.work().catchError((Object e, StackTrace s) {
      debugPrint('[Building] work failed: $e');
    });
    final stepTime = _reduceMotion ? _quickStepTime : _stepTime;
    for (var i = 0; i < _stepCount; i++) {
      await Future<void>.delayed(stepTime);
      // The last step is the one that waits for the real work.
      if (i == _stepCount - 1) await work;
      if (!mounted) return;
      setState(() => _done = i + 1);
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() => _ready = true);
    _titles.forward();
    await Future<void>.delayed(_hold);
    _finish();
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onDone();
  }

  String _paceLine() => switch (widget.goal) {
        MacroCalculatorService.GOAL_GAIN =>
          'A small surplus, inside our safety limits',
        MacroCalculatorService.GOAL_MAINTAIN =>
          'Holding steady, no deficit or surplus',
        _ => 'A weekly pace inside our safety limits',
      };

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    final stepTime = _reduceMotion ? _quickStepTime : _stepTime;
    final checkIn = DateTime.now().add(const Duration(days: 7));
    final steps = [
      (
        'Estimating your starting burn',
        'Mifflin–St Jeor, from your age, height, weight and sex'
      ),
      ('Setting a safe pace', _paceLine()),
      ('Splitting your macros', 'Protein first, to protect your muscle'),
      (
        'Scheduling your first check-in',
        DateFormat('EEEE, MMM d').format(checkIn)
      ),
    ];

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 34),
                child: Column(
                  children: [
                    _Ring(
                      done: _done,
                      ready: _ready,
                      stepTime: stepTime,
                      breathe: _breathe,
                    ),
                    const SizedBox(height: 18),
                    _Titles(controller: _titles),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                      decoration: BoxDecoration(
                          color: c.surface, borderRadius: BorderRadius.circular(24)),
                      child: Column(
                        children: [
                          for (var i = 0; i < steps.length; i++)
                            _StepRow(
                              title: steps[i].$1,
                              subtitle: steps[i].$2,
                              // Waiting, running or finished.
                              state: i < _done
                                  ? _RowState.done
                                  : i == _done
                                      ? _RowState.running
                                      : _RowState.waiting,
                              last: i == steps.length - 1,
                              animate: !_reduceMotion,
                            ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 16),
                    AnimatedOpacity(
                      opacity: _ready ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: IgnorePointer(
                        ignoring: !_ready,
                        child: ObPrimaryButton(
                            label: 'See my plan', onPressed: _finish),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The two titles never share the screen: "Building" is gone before "ready"
/// starts to appear.
class _Titles extends StatelessWidget {
  const _Titles({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    Widget block(String title, String sub) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: ObText.display(30, color: c.text, height: 1.15)),
            const SizedBox(height: 8),
            Text(sub,
                textAlign: TextAlign.center, style: ObText.body(c.text2)),
          ],
        );
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        final a = (1 - t / 0.35).clamp(0.0, 1.0);
        final b = ((t - 0.5) / 0.35).clamp(0.0, 1.0);
        return SizedBox(
          height: 66,
          child: Stack(
            children: [
              if (a > 0)
                Positioned.fill(
                  child: Opacity(
                    opacity: a,
                    child: Transform.translate(
                        offset: Offset(0, -6 * (1 - a)),
                        child: block('Building your plan',
                            'Using your answers, not a template.')),
                  ),
                ),
              if (b > 0)
                Positioned.fill(
                  child: Opacity(
                    opacity: b,
                    child: Transform.translate(
                        offset: Offset(0, 6 * (1 - b)),
                        child: block('Your plan is ready',
                            'Made from your answers. Tuned by your data.')),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The progress ring with the logo inside. When the plan is ready the logo
/// gives way to the check (plan_ready.json).
class _Ring extends StatelessWidget {
  const _Ring({
    required this.done,
    required this.ready,
    required this.stepTime,
    required this.breathe,
  });

  final int done;
  final bool ready;
  final Duration stepTime;
  final Animation<double> breathe;

  static const _size = 168.0;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    final target = ready ? 1.0 : math.min(done + 1, 4) / 4;
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: target),
            duration: stepTime,
            curve: const Cubic(.45, .05, .55, .95),
            builder: (context, v, _) => CustomPaint(
              size: const Size(_size, _size),
              painter: _RingPainter(
                  progress: v, track: c.raised, color: c.leaf),
            ),
          ),
          AnimatedOpacity(
            opacity: ready ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: AnimatedBuilder(
              animation: breathe,
              builder: (context, child) => Transform.scale(
                  scale: 1 + 0.06 * Curves.easeInOut.transform(breathe.value),
                  child: child),
              child: MbMark(height: 42, color: c.text),
            ),
          ),
          if (ready)
            // The animation's ring is 98 of 120 wide; scale it to the painted one.
            SizedBox(
              width: 175,
              height: 175,
              child: Lottie.asset(
                'assets/animations/plan_ready.json',
                repeat: false,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) =>
                    Icon(Icons.check_circle_rounded, size: 96, color: c.leaf),
              ),
            ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.track, required this.color});

  final double progress;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 160;
    final center = size.center(Offset.zero);
    final radius = 68 * k;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10 * k
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, stroke..color = track);
    if (progress <= 0) return;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, 2 * math.pi * progress.clamp(0.0, 1.0), false, stroke..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.color != color;
}

enum _RowState { waiting, running, done }

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.title,
    required this.subtitle,
    required this.state,
    required this.last,
    required this.animate,
  });

  final String title;
  final String subtitle;
  final _RowState state;
  final bool last;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return AnimatedOpacity(
      opacity: state == _RowState.waiting ? 0.45 : 1,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: c.raised)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: switch (state) {
                _RowState.done => TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.4, end: 1),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    builder: (context, s, child) =>
                        Transform.scale(scale: s, child: child),
                    child: Container(
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                          color: c.leaf, borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.check_rounded, size: 16, color: c.onLeaf),
                    ),
                  ),
                _RowState.running => Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: animate
                          ? CircularProgressIndicator(
                              strokeWidth: 3,
                              color: c.leaf,
                              backgroundColor: c.line,
                              value: null,
                            )
                          : CircularProgressIndicator(
                              strokeWidth: 3,
                              color: c.leaf,
                              backgroundColor: c.line,
                              value: 0.25),
                    ),
                  ),
                _RowState.waiting => Center(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: c.line, width: 2),
                      ),
                    ),
                  ),
              },
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ObText.title(c.text, size: 15)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: ObText.body(c.text2, size: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
