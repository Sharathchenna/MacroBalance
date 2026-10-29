import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/storage_service.dart';

/// The parts of the app the first-run tour points at.
enum TourTarget { summary, meals, moveCopy, dateBar, addButton, progressTab, profileTab }

/// One stop on the tour.
class TourStep {
  const TourStep(this.target, this.title, this.body);

  final TourTarget target;
  final String title;
  final String body;
}

/// What the tour says, and whether this account has seen it.
class HomeTour {
  HomeTour._();

  static const steps = <TourStep>[
    TourStep(TourTarget.summary, 'Your day at a glance',
        'Calories left and your macros update the moment you log something.'),
    TourStep(TourTarget.meals, 'Your meals',
        'Tap a food to edit it, swipe it left to remove it. Have the same thing most days? The meal offers your usual in one tap.'),
    TourStep(TourTarget.moveCopy, 'Move or copy food',
        'Hold a food and drag it onto another meal to move it, or onto Copy to paste it into any meal on any day.'),
    TourStep(TourTarget.dateBar, 'Move between days',
        'Use the arrows or tap the date to log or review any day.'),
    TourStep(TourTarget.addButton, 'Log food',
        'Tap + to scan a meal, search, pick a saved food or just describe what you ate. Hold it to jump straight to the camera.'),
    TourStep(TourTarget.progressTab, 'Progress',
        'Weight, calories, steps and workouts over time.'),
    TourStep(TourTarget.profileTab, 'Profile',
        'Goals, units and your account. You can replay this tour from here.'),
  ];

  static String _key(String userId) => 'home_tour_seen_$userId';

  /// True when [userId] hasn't finished or skipped the tour on this device.
  static bool shouldShow(String? userId) =>
      userId != null && StorageService().get(_key(userId)) != true;

  static Future<void> markSeen(String? userId) async {
    if (userId == null) return;
    await StorageService().put(_key(userId), true);
  }
}

/// Lets screens inside the shell tag their widgets as tour targets without
/// knowing about the tour. Each shell has its own keys, so two shells never
/// share a GlobalKey.
class TourTargets extends InheritedWidget {
  const TourTargets({super.key, required this.keys, required super.child});

  final Map<TourTarget, GlobalKey> keys;

  /// Wraps [child] so the tour can find it; a no-op outside the shell.
  static Widget mark(BuildContext context, TourTarget? target, Widget child) {
    if (target == null) return child;
    final scope = context.dependOnInheritedWidgetOfExactType<TourTargets>();
    final key = scope?.keys[target];
    return key == null ? child : KeyedSubtree(key: key, child: child);
  }

  @override
  bool updateShouldNotify(TourTargets oldWidget) => keys != oldWidget.keys;
}

/// The tour overlay: dims the screen, cuts a soft spotlight around the
/// current target and shows a card next to it. The spotlight glides between
/// targets.
class HomeTourOverlay extends StatefulWidget {
  const HomeTourOverlay({
    super.key,
    required this.keys,
    required this.onFinish,
    this.bottomInset = 0,
  });

  final Map<TourTarget, GlobalKey> keys;

  /// Called with true when the tour was completed, false when skipped.
  final ValueChanged<bool> onFinish;

  /// Space at the bottom covered by the floating bar; targets above it are
  /// cropped to stay clear of it.
  final double bottomInset;

  @override
  State<HomeTourOverlay> createState() => _HomeTourOverlayState();
}

class _HomeTourOverlayState extends State<HomeTourOverlay>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  )..forward();

  /// Steps whose target is on screen right now (e.g. meals may be missing).
  late final List<TourStep> _steps = HomeTour.steps
      .where((s) => widget.keys[s.target]?.currentContext != null)
      .toList();

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  /// Where [step]'s target is, in screen coordinates (the overlay covers the
  /// whole screen), or null if it isn't laid out.
  Rect? _targetRect(Size screen, TourStep step) {
    final box = widget.keys[step.target]?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    // Bar items get a round spotlight around their icon.
    if (_isBarItem(step)) {
      return Rect.fromCircle(center: rect.center, radius: rect.shortestSide / 2 + 6);
    }
    // Everything else stays inside the screen edges and above the bar, so
    // tall targets (the meal list) are cropped to what's visible.
    return Rect.fromLTRB(
      (rect.left - 4).clamp(8, screen.width),
      (rect.top - 4).clamp(0, screen.height),
      (rect.right + 4).clamp(0, screen.width - 8),
      (rect.bottom + 4).clamp(0, screen.height - widget.bottomInset - 12),
    );
  }

  static bool _isBarItem(TourStep step) =>
      step.target == TourTarget.addButton ||
      step.target == TourTarget.progressTab ||
      step.target == TourTarget.profileTab;

  Future<void> _finish(bool completed) async {
    await _fade.reverse();
    widget.onFinish(completed);
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_index >= _steps.length - 1) {
      _finish(true);
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_steps.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onFinish(true));
      return const SizedBox.shrink();
    }
    final step = _steps[_index];
    return FadeTransition(
      opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rect = _targetRect(constraints.biggest, step) ??
              Rect.fromCenter(
                  center: constraints.biggest.center(Offset.zero), width: 0, height: 0);
          final isBarItem = _isBarItem(step);
          final radius = isBarItem ? rect.shortestSide / 2 : 22.0;
          return Stack(
            children: [
              // Dim layer with the spotlight. Taps on it advance the tour.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _next,
                  child: TweenAnimationBuilder<Rect?>(
                    tween: RectTween(end: rect),
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeInOutCubic,
                    builder: (context, r, _) => CustomPaint(
                      painter: _SpotlightPainter(
                        hole: r ?? rect,
                        radius: radius,
                        color: Colors.black.withOpacity(0.72),
                      ),
                    ),
                  ),
                ),
              ),
              // The card sits above bar items and below everything else,
              // whichever side has room.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeInOutCubic,
                left: 20,
                right: 20,
                top: isBarItem ? null : _cardTop(rect, constraints, step),
                bottom: isBarItem ? constraints.maxHeight - rect.top + 16 : null,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _TourCard(
                    key: ValueKey(_index),
                    step: step,
                    index: _index,
                    count: _steps.length,
                    onNext: _next,
                    onSkip: () => _finish(false),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  double _cardTop(Rect rect, BoxConstraints c, TourStep step) {
    final cardHeight = 190.0 + (_hasDemo(step) ? _MoveCopyDemo.height + 12 : 0);
    final below = rect.bottom + 16;
    if (below + cardHeight < c.maxHeight - widget.bottomInset) return below;
    // Not enough room below a tall target: put the card above it, or over
    // its lower part if there's no room anywhere.
    final above = rect.top - 16 - cardHeight;
    return above > 60 ? above : c.maxHeight - widget.bottomInset - cardHeight - 24;
  }
}

bool _hasDemo(TourStep step) => step.target == TourTarget.moveCopy;

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.hole, required this.radius, required this.color});

  final Rect hole;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(radius.clamp(0, hole.shortestSide / 2));
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(hole, r));
    canvas.drawPath(path, Paint()..color = color);
    // A soft ring so the highlighted part reads as "lit".
    canvas.drawRRect(
      RRect.fromRectAndRadius(hole, r),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFFFFC107).withOpacity(0.6),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole || old.radius != radius || old.color != color;
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    super.key,
    required this.step,
    required this.index,
    required this.count,
    required this.onNext,
    required this.onSkip,
  });

  final TourStep step;
  final int index;
  final int count;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final fg = isLight ? Colors.black87 : Colors.white;
    final muted = isLight ? Colors.black54 : Colors.white60;
    final last = index == count - 1;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
          decoration: BoxDecoration(
            color: isLight ? Colors.white.withOpacity(0.95) : const Color(0xFF1C1C1E).withOpacity(0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: isLight ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(step.title,
                    style: GoogleFonts.poppins(
                        fontSize: 17, fontWeight: FontWeight.w600, color: fg)),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(step.body,
                    style: GoogleFonts.poppins(fontSize: 13.5, height: 1.4, color: muted)),
              ),
              if (_hasDemo(step)) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _MoveCopyDemo(isLight: isLight),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  // Progress dots.
                  for (var i = 0; i < count; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(right: 5),
                      width: i == index ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == index
                            ? const Color(0xFFFFC107)
                            : (isLight ? Colors.black12 : Colors.white24),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  const Spacer(),
                  if (!last)
                    TextButton(
                      onPressed: onSkip,
                      style: TextButton.styleFrom(foregroundColor: muted),
                      child: const Text('Skip'),
                    ),
                  TextButton(
                    onPressed: onNext,
                    style: TextButton.styleFrom(
                      foregroundColor: isLight ? const Color(0xFF9A7300) : const Color(0xFFFFC107),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    child: Text(last ? 'Got it' : 'Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A looping picture of the gesture: a food is held and dragged onto another
/// meal (moved), then held and dropped on Copy (copied). Still when the
/// system asks for reduced motion.
class _MoveCopyDemo extends StatefulWidget {
  const _MoveCopyDemo({required this.isLight});

  final bool isLight;

  static const double height = 128;

  @override
  State<_MoveCopyDemo> createState() => _MoveCopyDemoState();
}

class _MoveCopyDemoState extends State<_MoveCopyDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _loop
        ..stop()
        ..value = 0.3;
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  /// 0 → 1 across [from, to] of the loop, eased.
  static double _phase(double t, double from, double to) =>
      Curves.easeInOutCubic.transform(((t - from) / (to - from)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFFC107);
    final box = widget.isLight ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.06);
    final fg = widget.isLight ? Colors.black87 : Colors.white;
    final muted = widget.isLight ? Colors.black54 : Colors.white60;
    return SizedBox(
      height: _MoveCopyDemo.height,
      child: LayoutBuilder(
        builder: (context, c) => AnimatedBuilder(
          animation: _loop,
          builder: (context, _) {
            final t = _loop.value;
            final w = c.maxWidth;
            final mealW = (w - 10) / 2;
            const chipW = 92.0, chipH = 28.0;
            final start = const Offset(10, 26);
            final snacks = Offset(mealW + 20, 26);
            final copy = Offset((w - chipW) / 2, 86);
            // First half: move to Snacks. Second half: drop on Copy.
            final moving = t < 0.5;
            final local = moving ? t / 0.5 : (t - 0.5) / 0.5;
            final lift = _phase(local, 0.12, 0.24);
            final travel = _phase(local, 0.24, 0.62);
            final settle = _phase(local, 0.62, 0.7);
            final fadeOut = _phase(local, 0.9, 1.0);
            final target = moving ? snacks : copy;
            final pos = Offset.lerp(start, target, travel)!;
            final dragging = lift > 0 && settle < 1;
            final overTarget = travel > 0.85 && settle < 1;
            final done = settle >= 1;
            Widget meal(String name, double left, {bool hot = false}) => Positioned(
                  left: left,
                  top: 0,
                  width: mealW,
                  height: 66,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.fromLTRB(10, 6, 8, 0),
                    decoration: BoxDecoration(
                      color: box,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: hot ? accent : Colors.transparent, width: 1.5),
                    ),
                    alignment: Alignment.topLeft,
                    child: Text(name,
                        style: GoogleFonts.poppins(
                            fontSize: 11, fontWeight: FontWeight.w600, color: muted)),
                  ),
                );
            return Stack(
              clipBehavior: Clip.none,
              children: [
                meal('Breakfast', 0),
                meal('Snacks', mealW + 10, hot: moving && overTarget),
                // The Copy zone shows while dragging, as on the dashboard.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 78,
                  height: 44,
                  child: Opacity(
                    opacity: moving ? 0.35 + 0.65 * (dragging ? 1 : 0) * (1 - settle) : 1 - fadeOut,
                    child: Container(
                      decoration: BoxDecoration(
                        color: !moving && overTarget ? accent.withOpacity(0.2) : box,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accent.withOpacity(0.7)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      child: Row(children: [
                        const Icon(Icons.copy_rounded, size: 16, color: accent),
                        const SizedBox(width: 8),
                        Text(
                          !moving && done ? 'Copied' : 'Drop here to copy',
                          style: GoogleFonts.poppins(
                              fontSize: 12, fontWeight: FontWeight.w600, color: fg),
                        ),
                      ]),
                    ),
                  ),
                ),
                Positioned(
                  left: pos.dx,
                  top: pos.dy,
                  width: chipW,
                  height: chipH,
                  child: Opacity(
                    opacity: 1 - fadeOut,
                    child: Transform.scale(
                      scale: 1 + 0.08 * lift * (1 - settle),
                      child: Container(
                        decoration: BoxDecoration(
                          color: widget.isLight ? Colors.white : const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: dragging ? accent : Colors.transparent, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3 * lift * (1 - settle)),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.centerLeft,
                        child: Row(children: [
                          Icon(Icons.drag_indicator_rounded,
                              size: 14, color: dragging ? accent : muted),
                          const SizedBox(width: 4),
                          Text('Coffee',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
                        ]),
                      ),
                    ),
                  ),
                ),
                // The finger: a soft dot that presses, then carries the food.
                if (local > 0.04 && settle < 1)
                  Positioned(
                    left: pos.dx + chipW - 22,
                    top: pos.dy + chipH - 10,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: fg.withOpacity(0.18 + 0.12 * lift),
                        border: Border.all(color: fg.withOpacity(0.4)),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
