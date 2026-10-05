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

/// Floating bottom bar shared by every section: a blurred pill with the
/// sections (the selected one shows its name) and, when [onAdd] is set, a
/// round add button beside it.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.current,
    required this.onSelect,
    this.onAdd,
    this.onAddLongPress,
  });

  final AppTab current;
  final ValueChanged<AppTab> onSelect;
  final VoidCallback? onAdd;
  final VoidCallback? onAddLongPress;

  static const double height = 52;

  /// Space to leave at the end of a tab's scrolling content so its last
  /// item can scroll clear of the bar.
  static const double scrollClearance = 110;

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
              padding: const EdgeInsets.all(5),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
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
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: onAdd == null
              ? const SizedBox.shrink()
              : Padding(
                  key: const ValueKey('add'),
                  padding: const EdgeInsets.only(left: 10),
                  child: _AddButton(onTap: onAdd!, onLongPress: onAddLongPress),
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
    final idle = isLight ? Colors.black54 : Colors.white60;
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: selected ? 14 : 16),
          decoration: BoxDecoration(
            color: selected ? _accent.withOpacity(isLight ? 0.22 : 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppBottomBar.height / 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? tab.selectedIcon : tab.icon,
                size: 22,
                color: selected ? (isLight ? const Color(0xFF9A7300) : _accent) : idle,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isLight ? const Color(0xFF9A7300) : _accent,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap, this.onLongPress});

  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Log food',
      hint: onLongPress == null ? null : 'Long press to open the camera',
      excludeSemantics: true,
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
          child: const SizedBox(
            width: AppBottomBar.height,
            height: AppBottomBar.height,
            child: Icon(CupertinoIcons.add, color: Colors.black, size: 26),
          ),
        ),
      ),
    );
  }
}
