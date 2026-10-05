import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

const _accent = Color(0xFFFFC107);

/// The log-food menu above the add button.
///
/// The screen behind softly blurs while a frosted panel fades in, drifting up
/// a few pixels into place. Scanning is the big tile; saved foods, search and
/// describing a meal sit below it.
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

  /// How far the panel drifts up as it appears, in pixels.
  static const double _drift = 12;

  /// Tile [index] fades in a touch after the panel, barely staggered. On the
  /// way out every tile fades with the panel, all together.
  Animation<double> _tile(int index) => CurvedAnimation(
        parent: animation,
        curve: Interval(0.15 + index * 0.05, 0.85 + index * 0.05 > 1 ? 1 : 0.85 + index * 0.05,
            curve: Curves.easeOutCubic),
        reverseCurve: Curves.easeIn,
      );

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    // Gentle deceleration in, a soft quick fade out. No scaling or overshoot.
    final ease = CurvedAnimation(
        parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeIn);

    return Stack(
      children: [
        // Blurred, dimmed background. Tap anywhere to close.
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: AnimatedBuilder(
              animation: ease,
              builder: (context, _) => BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8 * ease.value, sigmaY: 8 * ease.value),
                child: ColoredBox(color: Colors.black.withOpacity(0.35 * ease.value)),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: bottomOffset + 14,
          child: AnimatedBuilder(
            animation: ease,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _drift * (1 - ease.value)),
              child: Opacity(opacity: ease.value, child: child),
            ),
            child: _GlassPanel(
              isLight: isLight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeTransition(opacity: _tile(0), child: _ScanTile(onTap: onScan)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final (i, option) in [
                        (CupertinoIcons.bookmark, 'Saved', 'Your foods', onSaved),
                        (CupertinoIcons.search, 'Search', 'Database', onSearch),
                        (CupertinoIcons.text_bubble, 'Describe', 'Tell AI', onDescribe),
                      ].indexed) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          child: FadeTransition(
                            opacity: _tile(i + 1),
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
      ],
    );
  }
}

/// The frosted card the options sit on.
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
            color: isLight
                ? Colors.white.withOpacity(0.9)
                : const Color(0xFF1C1C1E).withOpacity(0.86),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isLight ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.08),
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

/// The big camera tile: the fastest way to log. Flat accent fill.
class _ScanTile extends StatelessWidget {
  const _ScanTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Scan a meal',
      excludeSemantics: true,
      child: Material(
        color: _accent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: SizedBox(
            height: 88,
            child: Padding(
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
                    child: const Icon(CupertinoIcons.camera_fill, color: _accent, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Scan',
                            style: GoogleFonts.poppins(
                                fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black)),
                        Text('Snap your meal or a barcode',
                            style: GoogleFonts.poppins(
                                fontSize: 12.5, color: Colors.black.withOpacity(0.7))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the smaller tiles below Scan. Flat fill with a hairline border.
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
        color: isLight ? const Color(0xFFF4F4F5) : Colors.white.withOpacity(0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isLight ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.06),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: isLight ? Colors.grey.shade900 : Colors.grey.shade200),
                const SizedBox(height: 8),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isLight ? Colors.black87 : Colors.white.withOpacity(0.95))),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: isLight ? Colors.grey.shade600 : Colors.grey.shade400)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
