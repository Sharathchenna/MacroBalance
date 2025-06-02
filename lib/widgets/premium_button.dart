import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

enum PremiumButtonStyle {
  primary,
  secondary,
  outlined,
  text,
  danger,
  success,
}

enum PremiumButtonSize {
  small,
  medium,
  large,
}

/// Premium button widget with sophisticated styling and interactions
class PremiumButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final PremiumButtonStyle style;
  final PremiumButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool loading;
  final bool expanded;
  final EdgeInsets? customPadding;
  final double? customBorderRadius;

  const PremiumButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.style = PremiumButtonStyle.primary,
    this.size = PremiumButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expanded = false,
    this.customPadding,
    this.customBorderRadius,
  });

  /// Creates a primary button
  factory PremiumButton.primary({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    IconData? trailingIcon,
    bool loading = false,
    bool expanded = false,
    PremiumButtonSize size = PremiumButtonSize.medium,
  }) {
    return PremiumButton(
      text: text,
      onPressed: onPressed,
      style: PremiumButtonStyle.primary,
      size: size,
      icon: icon,
      trailingIcon: trailingIcon,
      loading: loading,
      expanded: expanded,
    );
  }

  /// Creates a secondary button
  factory PremiumButton.secondary({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    IconData? trailingIcon,
    bool loading = false,
    bool expanded = false,
    PremiumButtonSize size = PremiumButtonSize.medium,
  }) {
    return PremiumButton(
      text: text,
      onPressed: onPressed,
      style: PremiumButtonStyle.secondary,
      size: size,
      icon: icon,
      trailingIcon: trailingIcon,
      loading: loading,
      expanded: expanded,
    );
  }

  /// Creates an outlined button
  factory PremiumButton.outlined({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    IconData? trailingIcon,
    bool loading = false,
    bool expanded = false,
    PremiumButtonSize size = PremiumButtonSize.medium,
  }) {
    return PremiumButton(
      text: text,
      onPressed: onPressed,
      style: PremiumButtonStyle.outlined,
      size: size,
      icon: icon,
      trailingIcon: trailingIcon,
      loading: loading,
      expanded: expanded,
    );
  }

  /// Creates a text button
  factory PremiumButton.text({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    IconData? trailingIcon,
    bool loading = false,
    PremiumButtonSize size = PremiumButtonSize.medium,
  }) {
    return PremiumButton(
      text: text,
      onPressed: onPressed,
      style: PremiumButtonStyle.text,
      size: size,
      icon: icon,
      trailingIcon: trailingIcon,
      loading: loading,
      expanded: false,
    );
  }

  /// Creates a danger button
  factory PremiumButton.danger({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    IconData? trailingIcon,
    bool loading = false,
    bool expanded = false,
    PremiumButtonSize size = PremiumButtonSize.medium,
  }) {
    return PremiumButton(
      text: text,
      onPressed: onPressed,
      style: PremiumButtonStyle.danger,
      size: size,
      icon: icon,
      trailingIcon: trailingIcon,
      loading: loading,
      expanded: expanded,
    );
  }

  /// Creates a success button
  factory PremiumButton.success({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    IconData? trailingIcon,
    bool loading = false,
    bool expanded = false,
    PremiumButtonSize size = PremiumButtonSize.medium,
  }) {
    return PremiumButton(
      text: text,
      onPressed: onPressed,
      style: PremiumButtonStyle.success,
      size: size,
      icon: icon,
      trailingIcon: trailingIcon,
      loading: loading,
      expanded: expanded,
    );
  }

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: PremiumAnimations.fast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: PremiumAnimations.smooth,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.loading) {
      setState(() => _isPressed = true);
      _animationController.forward();
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    _handleTapEnd();
  }

  void _handleTapCancel() {
    _handleTapEnd();
  }

  void _handleTapEnd() {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }

  ButtonConfig _getButtonConfig(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    switch (widget.style) {
      case PremiumButtonStyle.primary:
        return ButtonConfig(
          backgroundColor: PremiumColors.slate900,
          foregroundColor: Colors.white,
          borderColor: PremiumColors.slate900,
          elevation: 2,
          shadowColor: PremiumColors.slate900.withAlpha(((0.2) * 255).round()),
        );

      case PremiumButtonStyle.secondary:
        return ButtonConfig(
          backgroundColor:
              isDark ? PremiumColors.slate700 : PremiumColors.slate100,
          foregroundColor:
              isDark ? PremiumColors.slate100 : PremiumColors.slate700,
          borderColor: isDark ? PremiumColors.slate600 : PremiumColors.slate200,
          elevation: 1,
          shadowColor: PremiumColors.slate900.withAlpha(((0.1) * 255).round()),
        );

      case PremiumButtonStyle.outlined:
        return ButtonConfig(
          backgroundColor: Colors.transparent,
          foregroundColor:
              isDark ? PremiumColors.slate200 : PremiumColors.slate700,
          borderColor: isDark ? PremiumColors.slate600 : PremiumColors.slate300,
          elevation: 0,
        );

      case PremiumButtonStyle.text:
        return ButtonConfig(
          backgroundColor: Colors.transparent,
          foregroundColor:
              isDark ? PremiumColors.slate300 : PremiumColors.slate600,
          borderColor: Colors.transparent,
          elevation: 0,
        );

      case PremiumButtonStyle.danger:
        return ButtonConfig(
          backgroundColor: PremiumColors.red500,
          foregroundColor: Colors.white,
          borderColor: PremiumColors.red500,
          elevation: 2,
          shadowColor: PremiumColors.red500.withAlpha(((0.2) * 255).round()),
        );

      case PremiumButtonStyle.success:
        return ButtonConfig(
          backgroundColor: PremiumColors.emerald500,
          foregroundColor: Colors.white,
          borderColor: PremiumColors.emerald500,
          elevation: 2,
          shadowColor:
              PremiumColors.emerald500.withAlpha(((0.2) * 255).round()),
        );
    }
  }

  EdgeInsets _getPadding() {
    if (widget.customPadding != null) return widget.customPadding!;

    switch (widget.size) {
      case PremiumButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
      case PremiumButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 14);
      case PremiumButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 18);
    }
  }

  TextStyle _getTextStyle(BuildContext context) {
    final theme = Theme.of(context);
    switch (widget.size) {
      case PremiumButtonSize.small:
        return theme.textTheme.labelMedium ?? PremiumTypography.buttonSmall;
      case PremiumButtonSize.medium:
        return theme.textTheme.labelLarge ?? PremiumTypography.button;
      case PremiumButtonSize.large:
        return theme.textTheme.titleMedium ??
            PremiumTypography.button.copyWith(fontSize: 18);
    }
  }

  double _getIconSize() {
    switch (widget.size) {
      case PremiumButtonSize.small:
        return 16;
      case PremiumButtonSize.medium:
        return 18;
      case PremiumButtonSize.large:
        return 20;
    }
  }

  double _getBorderRadius() {
    return widget.customBorderRadius ?? 12;
  }

  @override
  Widget build(BuildContext context) {
    final config = _getButtonConfig(context);
    final isEnabled = widget.onPressed != null && !widget.loading;

    Widget content = Row(
      mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading) ...[
          SizedBox(
            width: _getIconSize(),
            height: _getIconSize(),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(config.foregroundColor),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (widget.icon != null) ...[
          Icon(
            widget.icon,
            size: _getIconSize(),
            color: config.foregroundColor,
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.text,
            style: _getTextStyle(context).copyWith(
              color: config.foregroundColor,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (!widget.loading && widget.trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(
            widget.trailingIcon,
            size: _getIconSize(),
            color: config.foregroundColor,
          ),
        ],
      ],
    );

    Widget button = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: AnimatedContainer(
            duration: PremiumAnimations.fast,
            padding: _getPadding(),
            decoration: BoxDecoration(
              color: isEnabled
                  ? config.backgroundColor
                  : config.backgroundColor.withAlpha(((0.5) * 255).round()),
              borderRadius: BorderRadius.circular(_getBorderRadius()),
              border: Border.all(
                color: isEnabled
                    ? config.borderColor
                    : config.borderColor.withAlpha(((0.5) * 255).round()),
                width: widget.style == PremiumButtonStyle.outlined ? 1.5 : 0,
              ),
              boxShadow: config.elevation > 0 && isEnabled
                  ? [
                      BoxShadow(
                        color: config.shadowColor ?? Colors.transparent,
                        blurRadius: config.elevation * 4,
                        offset: Offset(0, config.elevation),
                      ),
                    ]
                  : null,
            ),
            child: content,
          ),
        );
      },
    );

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: isEnabled ? widget.onPressed : null,
      child: Semantics(
        button: true,
        enabled: isEnabled,
        child: button,
      ),
    );
  }
}

class ButtonConfig {
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final double elevation;
  final Color? shadowColor;

  ButtonConfig({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.elevation,
    this.shadowColor,
  });
}

/// Premium floating action button with enhanced styling
class PremiumFloatingActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double size;
  final bool mini;

  const PremiumFloatingActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    this.size = 56,
    this.mini = false,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final finalSize = mini ? 40.0 : size;

    return Container(
      width: finalSize,
      height: finalSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            backgroundColor ?? PremiumColors.slate900,
            (backgroundColor ?? PremiumColors.slate900)
                .withAlpha(((0.8) * 255).round()),
          ],
        ),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          splashColor: Colors.white.withAlpha(((0.2) * 255).round()),
          highlightColor: Colors.white.withAlpha(((0.1) * 255).round()),
          child: Center(
            child: Icon(
              icon,
              color: foregroundColor ?? Colors.white,
              size: mini ? 18 : 24,
            ),
          ),
        ),
      ),
    );
  }
}
