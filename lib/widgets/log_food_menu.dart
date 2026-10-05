import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

const _accent = Color(0xFFFFC107);

/// The log-food menu that grows out of the add button.
///
/// The screen behind blurs, then a frosted panel scales up from the button's
/// corner with its options arriving one after another. Scanning is the big
/// tile; saved foods, search and describing a meal sit below it.
class LogFoodMenu extends StatelessWidget {
  const LogFoodMenu({
    super.key,
    required this.animation,
    required this.onClose,
    required this.onScan,
    required this.onSaved,
    required this.onSearch,
    required this.onDescribe,
    required this.bottomOffset,
  });

  /// 0 = closed, 1 = open. Drives every part of the menu.
  final Animation<double> animation;
  final VoidCallback onClose;
  final VoidCallback onScan;
  final VoidCallback onSaved;
  final VoidCallback onSearch;
  final VoidCallback onDescribe;

  /// Distance from the bottom of the screen to the top of the bottom bar.
  final double bottomOffset;

  /// [index]'s slice of the open animation, so tiles arrive in turn. On the
  /// way out every tile fades with the panel, all together.
  Animation<double> _stagger(int index) => CurvedAnimation(
        parent: animation,
        curve: Interval(0.2 + index * 0.08, (0.75 + index * 0.08).clamp(0, 1),
            curve: Curves.easeOutQuart),
        reverseCurve: Curves.easeInCubic,
      );

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    // Smooth deceleration in, quick ease out: no overshoot anywhere.
    final panel = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
        reverseCurve: Curves.easeInCubic);
    final backdrop = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic);

    return Stack(
      children: [
        // Blurred, dimmed background. Tap anywhere to close.
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: AnimatedBuilder(
              animation: backdrop,
              builder: (context, _) => BackdropFilter(
                filter: ImageFilter.blur(
                    sigmaX: 8 * backdrop.value, sigmaY: 8 * backdrop.value),
                child: ColoredBox(
                  color: Colors.black.withOpacity(0.35 * backdrop.value),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: bottomOffset + 14,
          // Rises a little and settles from the + button's corner while it
          // fades in; sinks back and fades on the way out.
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
                .animate(panel),
            child: ScaleTransition(
              scale: Tween(begin: 0.92, end: 1.0).animate(panel),
              alignment: Alignment.bottomRight,
              child: FadeTransition(
                opacity: panel,
                child: _GlassPanel(
                  isLight: isLight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Arrive(
                        animation: _stagger(0),
                        child: _ScanTile(onTap: onScan),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          for (final (i, option) in [
                            (
                              CupertinoIcons.bookmark,
                              'Saved',
                              'Your foods',
                              onSaved
                            ),
                            (
                              CupertinoIcons.search,
                              'Search',
                              'Database',
                              onSearch
                            ),
                            (
                              CupertinoIcons.text_bubble,
                              'Describe',
                              'Tell AI',
                              onDescribe
                            ),
                          ].indexed) ...[
                            if (i > 0) const SizedBox(width: 10),
                            Expanded(
                              child: _Arrive(
                                animation: _stagger(i + 1),
                                child: _OptionTile(
                                  icon: option.$1,
                                  title: option.$2,
                                  subtitle: option.$3,
                                  onTap: option.$4,
                                  isLight: isLight,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Slides a tile up into place while fading it in.
class _Arrive extends StatelessWidget {
  const _Arrive({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.15), end: Offset.zero)
            .animate(animation),
        child: child,
      ),
    );
  }
}

/// The frosted card from the original add menu.
class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.isLight, required this.child});

  final bool isLight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isLight
                  ? [
                      Colors.white.withOpacity(0.92),
                      Colors.grey.shade50.withOpacity(0.85)
                    ]
                  : [
                      Colors.grey.shade900.withOpacity(0.7),
                      Colors.grey.shade900.withOpacity(0.88)
                    ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isLight
                  ? Colors.white.withOpacity(0.6)
                  : Colors.white.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The big camera tile: the fastest way to log.
class _ScanTile extends StatelessWidget {
  const _ScanTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Scan a meal',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          height: 92,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFD54F), _accent, Color(0xFFFFA000)],
            ),
            boxShadow: [
              BoxShadow(
                color: _accent.withOpacity(0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // A large, faint viewfinder for texture.
              Positioned(
                right: -12,
                top: -14,
                child: Icon(CupertinoIcons.viewfinder,
                    size: 120, color: Colors.black.withOpacity(0.07)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(CupertinoIcons.camera_fill,
                          color: _accent, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Scan',
                              style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black)),
                          Text('Snap your meal or a barcode',
                              style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  color: Colors.black.withOpacity(0.7))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the smaller glass tiles, styled like the original menu buttons.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.isLight,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isLight
                    ? [Colors.white, Colors.grey.shade50]
                    : [
                        Colors.white.withOpacity(0.07),
                        Colors.white.withOpacity(0.03)
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isLight
                    ? Colors.black.withOpacity(0.08)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 22,
                    color:
                        isLight ? Colors.grey.shade900 : Colors.grey.shade200),
                const SizedBox(height: 8),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isLight
                            ? Colors.black87
                            : Colors.white.withOpacity(0.95))),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: isLight
                            ? Colors.grey.shade600
                            : Colors.grey.shade400)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
