import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/theme/ob_theme.dart';

/// Shared building blocks for the intro and onboarding screens
/// (docs/onboarding-redesign/mock). Pages use these so spacing, type and
/// motion match the mock everywhere.

/// Fades and lifts its child in once, [index] steps after the page appears.
class ObRise extends StatefulWidget {
  const ObRise({super.key, this.index = 0, required this.child});

  final int index;
  final Widget child;

  @override
  State<ObRise> createState() => _ObRiseState();
}

class _ObRiseState extends State<ObRise> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: ObMotion.rise);
  late final Animation<double> _t =
      CurvedAnimation(parent: _c, curve: ObMotion.curve);

  @override
  void initState() {
    super.initState();
    final delay = ObMotion.stagger * widget.index;
    if (delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
            offset: Offset(0, 16 * (1 - _t.value)), child: child),
      ),
      child: widget.child,
    );
  }
}

/// Round back button in the top bar.
class ObBackButton extends StatelessWidget {
  const ObBackButton({super.key, required this.onPressed, this.close = false});

  final VoidCallback? onPressed;

  /// Shows a cross instead of an arrow (leaving the flow).
  final bool close;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Semantics(
      button: true,
      label: close ? 'Close' : 'Back',
      child: Material(
        color: c.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                },
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(close ? Icons.close_rounded : Icons.chevron_left_rounded,
                color: c.text, size: 26),
          ),
        ),
      ),
    );
  }
}

/// Progress in four sections (goal and body, plan, habits, permissions),
/// weighted 3:3:2:1 as in the mock. [value] runs from 0 to 1 overall.
class ObProgress extends StatelessWidget {
  const ObProgress({super.key, required this.value});

  final double value;

  static const _weights = [3, 3, 2, 1];

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    final total = _weights.reduce((a, b) => a + b);
    var start = 0.0;
    final segments = <Widget>[];
    for (final w in _weights) {
      final share = w / total;
      final fill = ((value - start) / share).clamp(0.0, 1.0);
      start += share;
      segments.add(Expanded(
        flex: w,
        child: Container(
          height: 6,
          decoration: BoxDecoration(
              color: c.line, borderRadius: BorderRadius.circular(3)),
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: fill),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, f, _) => FractionallySizedBox(
              widthFactor: f,
              child: Container(
                decoration: BoxDecoration(
                    color: c.leaf, borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ),
        ),
      ));
    }
    return Semantics(
      label: 'Progress ${(value * 100).round()}%',
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            segments[i],
          ]
        ],
      ),
    );
  }
}

/// The top bar: back button and progress.
class ObTopBar extends StatelessWidget {
  const ObTopBar({super.key, this.onBack, this.progress, this.close = false, this.trailing});

  final VoidCallback? onBack;

  /// Null hides the progress bar.
  final double? progress;
  final bool close;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          if (onBack != null) ObBackButton(onPressed: onBack, close: close) else const SizedBox(width: 44),
          const SizedBox(width: 14),
          Expanded(child: progress == null ? const SizedBox() : ObProgress(value: progress!)),
          if (trailing != null) ...[const SizedBox(width: 14), trailing!],
        ],
      ),
    );
  }
}

/// Eyebrow, title and optional subtitle at the top of a page.
class ObHeader extends StatelessWidget {
  const ObHeader({super.key, this.eyebrow, required this.title, this.subtitle});

  final String? eyebrow;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null)
          ObRise(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(eyebrow!.toUpperCase(), style: ObText.eyebrow(c.leafText)),
            ),
          ),
        ObRise(index: 1, child: Text(title, style: ObText.h1(c.text))),
        if (subtitle != null)
          ObRise(
            index: 1,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(subtitle!, style: ObText.body(c.text2)),
            ),
          ),
      ],
    );
  }
}

/// The scrolling content area of an onboarding page: 24px sides, space
/// above for the header.
class ObPageBody extends StatelessWidget {
  const ObPageBody({super.key, required this.children, this.top = 26});

  final List<Widget> children;
  final double top;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, top, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// The main green button (56 high, 18 radius).
class ObPrimaryButton extends StatelessWidget {
  const ObPrimaryButton({super.key, required this.label, this.onPressed, this.loading = false, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    final enabled = onPressed != null && !loading;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: enabled ? c.leaf : c.leaf.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                }
              : null,
          child: SizedBox(
            height: 56,
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: c.onLeaf))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[icon!, const SizedBox(width: 10)],
                        Text(label, style: ObText.button(c.onLeaf)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A full-width button on a surface fill (Apple, Google, secondary actions).
class ObSecondaryButton extends StatelessWidget {
  const ObSecondaryButton({super.key, required this.label, this.onPressed, this.icon, this.inverted = false});

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;

  /// Text colour fill with background-coloured text (the Apple button).
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    final fg = inverted ? c.bg : c.text;
    return Material(
      color: inverted ? c.text : c.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onPressed!();
              },
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 10)],
              Text(label, style: ObText.button(fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet text button under the main one ("Not now", "Skip").
class ObTextButton extends StatelessWidget {
  const ObTextButton({super.key, required this.label, this.onPressed, this.color});

  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return SizedBox(
      height: 48,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(foregroundColor: color ?? c.text2),
        child: Text(label,
            style: ObText.body(color ?? c.text2, weight: FontWeight.w500)),
      ),
    );
  }
}

/// Selectable option row: icon tile, title and description, and a check
/// dot. Used for goal, activity, pace, adaptive and similar choices.
class ObOptionTile extends StatelessWidget {
  const ObOptionTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    required this.selected,
    required this.onTap,
    this.multi = false,
    this.badge,
  });

  final String title;
  final String? subtitle;

  /// Usually an [ObIconTile].
  final Widget? leading;

  /// Replaces the check dot (e.g. a cals figure).
  final Widget? trailing;
  final bool selected;
  final VoidCallback onTap;

  /// Square check box instead of a round dot.
  final bool multi;

  /// Small pill after the title ("Recommended").
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: !multi,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? c.leaf.withValues(alpha: c.isDark ? 0.08 : 0.12) : c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? c.leaf : Colors.transparent, width: 2),
          ),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(title, style: ObText.title(c.text)),
                        if (badge != null) ObPill(label: badge!),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!, style: ObText.body(c.text2, size: 14)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trailing ?? ObCheckDot(selected: selected, square: multi),
            ],
          ),
        ),
      ),
    );
  }
}

/// The round (or square) selection mark on an option.
class ObCheckDot extends StatelessWidget {
  const ObCheckDot({super.key, required this.selected, this.square = false});

  final bool selected;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? c.leaf : Colors.transparent,
        borderRadius: BorderRadius.circular(square ? 7 : 12),
        border: Border.all(color: selected ? c.leaf : c.line, width: 2),
      ),
      child: selected ? Icon(Icons.check_rounded, size: 16, color: c.onLeaf) : null,
    );
  }
}

/// A 48px rounded tile holding an icon (or any small drawing).
class ObIconTile extends StatelessWidget {
  const ObIconTile({super.key, this.icon, this.color, this.child, this.size = 48});

  final IconData? icon;
  final Color? color;
  final Widget? child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(size / 3)),
      alignment: Alignment.center,
      child: child ?? Icon(icon, color: color ?? c.leaf, size: size / 2),
    );
  }
}

/// Small rounded label, e.g. "Recommended".
class ObPill extends StatelessWidget {
  const ObPill({super.key, required this.label, this.color, this.textColor});

  final String label;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color ?? c.leaf.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: ObText.body(textColor ?? c.leafText, size: 12, weight: FontWeight.w600)
              .copyWith(height: 1.2)),
    );
  }
}

/// Two or more pill-shaped choices in a track (kg / lb, cm / ft).
class ObSegmented<T> extends StatelessWidget {
  const ObSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  /// Value → label.
  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// Smaller, for use inside cards.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Container(
      padding: EdgeInsets.all(compact ? 2 : 4),
      decoration: BoxDecoration(
        color: compact ? c.bg : c.surface,
        borderRadius: BorderRadius.circular(compact ? 16 : 22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in options.entries)
            Semantics(
              button: true,
              selected: e.key == value,
              child: GestureDetector(
                onTap: () {
                  if (e.key == value) return;
                  HapticFeedback.selectionClick();
                  onChanged(e.key);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: compact ? 30 : 36,
                  padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: e.key == value ? c.leaf : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(e.value,
                      style: ObText.body(e.key == value ? c.onLeaf : c.text2,
                              size: 14, weight: FontWeight.w600)
                          .copyWith(height: 1.2)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A rounded surface card.
class ObCard extends StatelessWidget {
  const ObCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.radius = 22});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? ObColors.of(context).surface,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// A note card: small icon and a line or two of text.
class ObNote extends StatelessWidget {
  const ObNote({super.key, required this.child, this.icon = Icons.show_chart_rounded, this.iconColor, this.color});

  /// Usually a [Text] or [Text.rich].
  final Widget child;
  final IconData icon;
  final Color? iconColor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return ObCard(
      radius: 18,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 20, color: iconColor ?? c.leaf),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DefaultTextStyle.merge(style: ObText.body(c.text2, size: 14), child: child),
          ),
        ],
      ),
    );
  }
}
