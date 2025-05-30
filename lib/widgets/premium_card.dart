import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/app_theme.dart';

/// Premium card widget with sophisticated styling and optional effects
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final bool elevated;
  final bool glassmorphism;
  final VoidCallback? onTap;
  final double borderRadius;
  final Border? border;
  final List<BoxShadow>? customShadow;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.elevated = true,
    this.glassmorphism = false,
    this.onTap,
    this.borderRadius = 16,
    this.border,
    this.customShadow,
  });

  /// Creates a premium card with subtle elevation
  factory PremiumCard.subtle({
    required Widget child,
    EdgeInsets? padding,
    Color? backgroundColor,
    VoidCallback? onTap,
  }) {
    return PremiumCard(
      child: child,
      padding: padding,
      backgroundColor: backgroundColor,
      elevated: false,
      onTap: onTap,
      customShadow: AppTheme.subtleShadow,
    );
  }

  /// Creates a premium card with glassmorphism effect
  factory PremiumCard.glass({
    required Widget child,
    EdgeInsets? padding,
    VoidCallback? onTap,
  }) {
    return PremiumCard(
      child: child,
      padding: padding,
      glassmorphism: true,
      elevated: false,
      onTap: onTap,
    );
  }

  /// Creates a highly elevated premium card
  factory PremiumCard.elevated({
    required Widget child,
    EdgeInsets? padding,
    Color? backgroundColor,
    VoidCallback? onTap,
  }) {
    return PremiumCard(
      child: child,
      padding: padding,
      backgroundColor: backgroundColor,
      elevated: true,
      onTap: onTap,
      customShadow: AppTheme.elevatedShadow,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine background color
    Color finalBackgroundColor;
    if (glassmorphism) {
      finalBackgroundColor = isDark
          ? Colors.white.withOpacity(0.05)
          : Colors.white.withOpacity(0.1);
    } else {
      finalBackgroundColor =
          backgroundColor ?? (isDark ? PremiumColors.slate800 : Colors.white);
    }

    // Determine shadow
    List<BoxShadow> finalShadow;
    if (customShadow != null) {
      finalShadow = customShadow!;
    } else if (elevated) {
      finalShadow = isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow;
    } else {
      finalShadow = [];
    }

    // Determine border
    Border finalBorder = border ??
        Border.all(
          color: glassmorphism
              ? (isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white.withOpacity(0.2))
              : (isDark
                  ? PremiumColors.slate600.withOpacity(0.3)
                  : PremiumColors.slate200.withOpacity(0.6)),
          width: glassmorphism ? 1.5 : 1,
        );

    Widget cardContent = Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: finalBackgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: finalBorder,
        boxShadow: finalShadow,
      ),
      child: glassmorphism
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: child,
            )
          : child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: theme.colorScheme.primary.withOpacity(0.1),
          highlightColor: theme.colorScheme.primary.withOpacity(0.05),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}

/// Premium section card for grouping related content
class PremiumSectionCard extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget child;
  final IconData? icon;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsets? padding;
  final bool collapsible;
  final bool initiallyExpanded;

  const PremiumSectionCard({
    super.key,
    this.title,
    this.titleWidget,
    required this.child,
    this.icon,
    this.subtitle,
    this.trailing,
    this.padding,
    this.collapsible = false,
    this.initiallyExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>();

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null || titleWidget != null || icon != null) ...[
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget ??
                        (title != null
                            ? Text(
                                title!,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: customColors?.textPrimary,
                                ),
                              )
                            : const SizedBox.shrink()),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: customColors?.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
        ],
        child,
      ],
    );

    if (collapsible) {
      return PremiumCard(
        padding: padding,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            title: titleWidget ??
                (title != null
                    ? Text(
                        title!,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: customColors?.textPrimary,
                        ),
                      )
                    : const SizedBox.shrink()),
            subtitle: subtitle != null
                ? Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: customColors?.textSecondary,
                    ),
                  )
                : null,
            leading: icon != null
                ? Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  )
                : null,
            trailing: trailing,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: child,
              ),
            ],
          ),
        ),
      );
    }

    return PremiumCard(
      padding: padding,
      child: content,
    );
  }
}
