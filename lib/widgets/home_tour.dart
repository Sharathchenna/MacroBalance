import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/storage_service.dart';

/// The parts of the app the first-run tour points at.
enum TourTarget { summary, meals, dateBar, addButton, progressTab, profileTab }

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
        'Tap a food to edit it, swipe it left to remove it. Eating the same as yesterday? An empty meal offers to repeat it in one tap.'),
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
                top: isBarItem ? null : _cardTop(rect, constraints),
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

  double _cardTop(Rect rect, BoxConstraints c) {
    const cardHeight = 190.0;
    final below = rect.bottom + 16;
    if (below + cardHeight < c.maxHeight - widget.bottomInset) return below;
    // Not enough room below a tall target: put the card above it, or over
    // its lower part if there's no room anywhere.
    final above = rect.top - 16 - cardHeight;
    return above > 60 ? above : c.maxHeight - widget.bottomInset - cardHeight - 24;
  }
}

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
