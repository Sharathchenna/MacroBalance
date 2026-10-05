import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/utils/weight_range.dart';

/// Segmented control for the weight chart's date range: one pill track with
/// a highlight that slides to the selected range.
class WeightRangeSelector extends StatelessWidget {
  const WeightRangeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final WeightRange selected;
  final ValueChanged<WeightRange> onChanged;

  static const double _height = 36;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>();
    final track = colors?.dateNavigatorBackground ?? Colors.black12;
    final thumb = colors?.cardBackground ?? Theme.of(context).cardColor;
    final active = colors?.accentPrimary ?? Theme.of(context).colorScheme.primary;
    final inactive = colors?.textSecondary ?? Colors.grey;
    const ranges = WeightRange.values;
    final index = ranges.indexOf(selected);

    return Container(
      height: _height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(_height / 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segment = constraints.maxWidth / ranges.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: segment * index,
                top: 0,
                bottom: 0,
                width: segment,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: thumb,
                    borderRadius: BorderRadius.circular(_height / 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final range in ranges)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: range == selected,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: range == selected ? null : () => onChanged(range),
                          child: Center(
                            child: Text(
                              range.label,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: range == selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: range == selected ? active : inactive,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
