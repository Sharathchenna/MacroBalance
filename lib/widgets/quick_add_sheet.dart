import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/screens/askAI.dart';
import 'package:macrotracker/screens/searchPage.dart';
import 'package:macrotracker/theme/app_theme.dart';

/// The "Log food" sheet behind the add button. Scanning is the main action;
/// search, saved foods and describing a meal sit below it.
Future<void> showQuickAddSheet(BuildContext context, {required VoidCallback onScan}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).extension<CustomColors>()?.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => QuickAddSheet(onScan: onScan),
  );
}

class QuickAddSheet extends StatelessWidget {
  const QuickAddSheet({super.key, required this.onScan});

  final VoidCallback onScan;

  void _open(BuildContext context, Widget Function() screen) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(CupertinoPageRoute(builder: (_) => screen()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>();
    final textPrimary = colors?.textPrimary ?? Theme.of(context).colorScheme.onSurface;
    final textSecondary = colors?.textSecondary ?? Colors.grey;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Log food',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
          ),
          const SizedBox(height: 16),
          // Primary: the camera.
          Material(
            color: const Color(0xFFFFC107),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
                onScan();
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.camera_fill, color: Colors.black, size: 26),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Scan a meal',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black)),
                          SizedBox(height: 2),
                          Text('Take a photo or scan a barcode',
                              style: TextStyle(fontSize: 13, color: Colors.black87)),
                        ],
                      ),
                    ),
                    Icon(CupertinoIcons.chevron_right, color: Colors.black54, size: 18),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Option(
                  icon: CupertinoIcons.search,
                  label: 'Search',
                  textColor: textPrimary,
                  iconColor: textSecondary,
                  onTap: () => _open(context, () => const FoodSearchPage()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Option(
                  icon: CupertinoIcons.bookmark,
                  label: 'Saved',
                  textColor: textPrimary,
                  iconColor: textSecondary,
                  onTap: () {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    navigator.pushNamed('/savedFoods');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Option(
                  icon: CupertinoIcons.text_bubble,
                  label: 'Describe',
                  textColor: textPrimary,
                  iconColor: textSecondary,
                  onTap: () => _open(context, () => const Askai()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.label,
    required this.textColor,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color textColor;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Material(
      color: isLight ? Colors.black.withOpacity(0.04) : Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
            ],
          ),
        ),
      ),
    );
  }
}
