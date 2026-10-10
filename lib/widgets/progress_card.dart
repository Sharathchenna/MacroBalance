import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrotracker/theme/app_theme.dart';

/// The card every Progress section sits in.
class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (light)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: child,
    );
  }
}

/// A small label over a value, e.g. "Weekly rate" / "−0.4 kg".
class ProgressStat extends StatelessWidget {
  const ProgressStat({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.caption,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: valueColor ?? colors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(
            caption!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// One part of an info sheet: an optional heading over a paragraph.
class InfoSection {
  const InfoSection(this.body, {this.heading});

  final String? heading;
  final String body;
}

/// The explanation behind a card, opened from its info button so the card
/// itself can stay to the numbers.
class ProgressInfo {
  const ProgressInfo(this.title, this.sections, {this.footer});

  final String title;
  final List<InfoSection> sections;

  /// Optional content under the sections (e.g. an action), built with the
  /// sheet's context so it can close the sheet.
  final Widget Function(BuildContext sheet)? footer;

  Future<void> show(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: colors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheet).size.height * 0.75),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                for (final section in sections) ...[
                  const SizedBox(height: 16),
                  if (section.heading != null) ...[
                    Text(
                      section.heading!,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    section.body,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.5,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
                if (footer != null) footer!(sheet),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small ⓘ that opens [info].
class InfoButton extends StatelessWidget {
  const InfoButton(this.info, {super.key});

  final ProgressInfo info;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    return Semantics(
      button: true,
      label: 'About ${info.title}',
      child: InkResponse(
        onTap: () => info.show(context),
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(Icons.info_outline_rounded,
              size: 18, color: colors.textSecondary),
        ),
      ),
    );
  }
}

/// Section heading inside a card, with an info button when there's more to
/// explain.
class ProgressCardTitle extends StatelessWidget {
  const ProgressCardTitle(this.text, {super.key, this.trailing, this.info});

  final String text;
  final Widget? trailing;
  final ProgressInfo? info;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (info != null) InfoButton(info!),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// The big value over a chart, e.g. "−1.2 kg" / "trend over the past month",
/// or the touched point while scrubbing.
class ChartHeader extends StatelessWidget {
  const ChartHeader(
      {super.key, required this.value, required this.detail, this.valueColor});

  final String value;
  final String detail;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: valueColor ?? colors.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
        ),
      ],
    );
  }
}

/// Legend swatch for points: a dot, or a ring for hollow markers.
class LegendDot extends StatelessWidget {
  const LegendDot({super.key, required this.color, this.ring = false});

  final Color color;
  final bool ring;

  @override
  Widget build(BuildContext context) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: ring ? Border.all(color: color, width: 1.8) : null,
          color: ring ? null : color,
        ),
      );
}

/// Legend swatch for a line, solid or dashed.
class LegendLine extends StatelessWidget {
  const LegendLine({super.key, required this.color, this.dashed = false});

  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 16,
        height: 3,
        child: dashed
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(width: 4, height: 1.5, color: color),
                ],
              )
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
      );
}

/// Legend swatch for a shaded range.
class LegendBand extends StatelessWidget {
  const LegendBand({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 16,
        height: 10,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

/// A legend entry: a swatch and its label.
class LegendItem extends StatelessWidget {
  const LegendItem({super.key, required this.swatch, required this.label});

  final Widget swatch;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: 6),
        Text(label,
            style:
                GoogleFonts.inter(fontSize: 12, color: colors.textSecondary)),
      ],
    );
  }
}

/// The "+ Log" pill at the top right of a card.
class ProgressAddButton extends StatelessWidget {
  const ProgressAddButton({super.key, required this.onTap, this.label = 'Log'});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    return Material(
      color: colors.accentPrimary.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 18, color: colors.accentPrimary),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.accentPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
