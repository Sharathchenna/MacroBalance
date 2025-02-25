import 'package:flutter/material.dart';

class AppAnimations {
  static const Duration shortDuration = Duration(milliseconds: 200);
  static const Duration mediumDuration = Duration(milliseconds: 300);
  static const Duration longDuration = Duration(milliseconds: 500);

  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve bounceCurve = Curves.elasticOut;
}

extension AnimationExtensions on Widget {
  Widget fadeIn({Duration? duration}) {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: duration ?? AppAnimations.mediumDuration,
      child: this,
    );
  }

  Widget slideFromBottom({Duration? duration}) {
    return AnimatedSlide(
      offset: Offset.zero,
      duration: duration ?? AppAnimations.mediumDuration,
      child: this,
    );
  }
}
