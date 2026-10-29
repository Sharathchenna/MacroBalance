import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:macrotracker/theme/ob_theme.dart';

/// The MB monogram, traced from assets/icons/MacroBalance_Logo.png
/// (docs/onboarding-redesign/mb_mark.svg). Use this instead of the PNG or
/// any stand-in icon.
class MbMark extends StatelessWidget {
  const MbMark({super.key, this.height = 24, this.color});

  final double height;

  /// Defaults to the onboarding text colour.
  final Color? color;

  static const _aspect = 640 / 484;

  static const _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="200 262 640 484">'
      '<path fill="#000" fill-rule="evenodd" d="M208 274a4 4 0 0 1 4-4h70l126 170 '
      '122-170h160c78 0 128 52 128 122 0 44-22 76-61 93 47 17 75 56 75 109 0 82-60 '
      '143-150 143H479a4 4 0 0 1-4-4v-64a4 4 0 0 1 4-4h48V416L408 577 287 416v317a4 '
      '4 0 0 1-4 4h-71a4 4 0 0 1-4-4z M605 345v108h68c40 0 67-22 67-54s-27-54-67-54z '
      'M605 527v138h75c46 0 77-27 77-69s-31-69-77-69z"/></svg>';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      _svg,
      height: height,
      width: height * _aspect,
      colorFilter: ColorFilter.mode(
          color ?? ObColors.of(context).text, BlendMode.srcIn),
      semanticsLabel: 'MacroBalance',
    );
  }
}

/// The app-icon tile: the monogram on a rounded square.
class MbLogoTile extends StatelessWidget {
  const MbLogoTile({super.key, this.size = 64, this.background, this.color});

  final double size;
  final Color? background;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? c.surface,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: c.line),
      ),
      alignment: Alignment.center,
      child: MbMark(height: size * 0.42, color: color),
    );
  }
}
