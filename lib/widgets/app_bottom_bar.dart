import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's main sections, in bottom bar order.
enum AppTab {
  home('Home', CupertinoIcons.house, CupertinoIcons.house_fill),
  progress('Progress', CupertinoIcons.graph_circle, CupertinoIcons.graph_circle_fill),
  profile('Profile', CupertinoIcons.person, CupertinoIcons.person_fill);

  const AppTab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _accent = Color(0xFFFFC107);

/// Motion shared by the bar and the log-food menu, so they move as one.
const kNavMotion = Duration(milliseconds: 320);
const kNavCurve = Curves.easeInOutCubic;

/// Floating bottom bar shared by every section: a blurred pill with the
/// section icons and a round add button beside it.
///
/// Switching sections slides the highlight from the old icon to the new one
/// while the icons cross-fade between outline and filled.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.current,
    required this.onSelect,
    this.onAdd,
    this.onAddLongPress,
    this.menuAnimation,
  });

  final AppTab current;
  final ValueChanged<AppTab> onSelect;
  final VoidCallback? onAdd;
  final VoidCallback? onAddLongPress;

  /// The log-food menu's open progress (0 closed, 1 open). Turns the + into a
  /// close button in step with the menu.
  final Animation<double>? menuAnimation;

  static const double height = 64;
  static const double _slot = 74;
  static const double _dot = 50;
  static const double _inset = 6;

  /// Space to leave at the end of a tab's scrolling content so its last
  /// item can scroll clear of the bar.
  static const double scrollClearance = 124;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: height,
              padding: const EdgeInsets.all(_inset),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height / 2),
                color: isLight
                    ? Colors.white.withOpacity(0.75)
                    : Colors.black.withOpacity(0.45),
                border: Border.all(
                  color: isLight
                      ? Colors.black.withOpacity(0.06)
                      : Colors.white.withOpacity(0.1),
                  width: 0.5,
                ),
              ),
              child: SizedBox(
                width: _slot * AppTab.values.length,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // The highlight glides to the selected section.
                    AnimatedPositioned(
                      duration: kNavMotion,
                      curve: kNavCurve,
                      left: current.index * _slot + (_slot - _dot) / 2,
                      top: (height - 2 * _inset - _dot) / 2,
                      width: _dot,
                      height: _dot,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x33FFC107),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (final tab in AppTab.values)
                          _TabItem(
                            tab: tab,
                            selected: tab == current,
                            isLight: isLight,
                            onTap: () {
                              if (tab != current) HapticFeedback.selectionClick();
                              onSelect(tab);
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (onAdd != null)
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: _AddButton(
              onTap: onAdd!,
              onLongPress: onAddLongPress,
              animation: menuAnimation ?? const AlwaysStoppedAnimation(0),
            ),
          ),
      ],
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.selected,
    required this.isLight,
    required this.onTap,
  });

  final AppTab tab;
  final bool selected;
  final bool isLight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final idle = isLight ? Colors.black45 : Colors.white54;
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: AppBottomBar._slot,
          height: double.infinity,
          child: Center(
            // Outline and filled icons cross-fade while the colour eases, so
            // the icon "lights up" as the highlight arrives.
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: selected ? _accent : idle),
              duration: kNavMotion,
              curve: kNavCurve,
              builder: (context, color, _) => AnimatedSwitcher(
                duration: kNavMotion,
                switchInCurve: kNavCurve,
                switchOutCurve: kNavCurve,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.85, end: 1.0).animate(animation),
                    child: child,
                  ),
                ),
                child: Icon(
                  selected ? tab.selectedIcon : tab.icon,
                  key: ValueKey(selected),
                  size: 28,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.onTap,
    required this.animation,
    this.onLongPress,
  });

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final open = animation.value > 0.5;
        return Semantics(
          button: true,
          label: open ? 'Close' : 'Log food',
          hint: onLongPress == null || open ? null : 'Long press to open the camera',
          excludeSemantics: true,
          child: child,
        );
      },
      child: Material(
        color: _accent,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: _accent.withOpacity(0.4),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          onLongPress: onLongPress == null
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  onLongPress!();
                },
          child: SizedBox(
            width: AppBottomBar.height,
            height: AppBottomBar.height,
            // Rotates with the menu itself: same timing and the same smooth
            // curve opening and closing, no overshoot.
            child: RotationTransition(
              turns: Tween(begin: 0.0, end: 0.125).animate(
                CurvedAnimation(parent: animation, curve: kNavCurve),
              ),
              child: const Icon(CupertinoIcons.add, color: Colors.black, size: 30),
            ),
          ),
        ),
      ),
    );
  }
}
