import 'package:flutter/material.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/theme/typography.dart';
import 'package:macrotracker/widgets/onboarding/feature_item.dart'; // Will create this next

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // App logo/icon with animation
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          customColors?.dateNavigatorBackground
                                  .withOpacity(0.8) ??
                              theme.colorScheme.primaryContainer,
                          theme.colorScheme.onSecondary.withOpacity(0.8),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.shadow.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        Theme.of(context).brightness == Brightness.light
                            ? 'assets/icons/icon_black.png'
                            : 'assets/icons/icon_white.png',
                        width: 200,
                        height: 200,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 40),

          // Animated title
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                  opacity: value,
                  child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Text('Welcome to MacroBalance',
                          style: AppTypography.onboardingTitle.copyWith(
                            color: customColors?.textPrimary ??
                                theme.colorScheme.onBackground,
                          ),
                          textAlign: TextAlign.center)));
            },
          ),
          const SizedBox(height: 16),

          // Animated description
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                  opacity: value,
                  child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Text(
                          'Let\'s personalize your experience by calculating your optimal macronutrients intake.',
                          style: AppTypography.onboardingBody.copyWith(
                            color: customColors?.textPrimary ??
                                theme.colorScheme.onBackground,
                          ),
                          textAlign: TextAlign.center)));
            },
          ),

          const SizedBox(height: 40),

          // Feature highlights
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                  opacity: value,
                  child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            FeatureItem(
                                icon: Icons.calculate_outlined,
                                label: 'Calculate'),
                            FeatureItem(
                                icon: Icons.track_changes_outlined,
                                label: 'Track'),
                            FeatureItem(
                                icon: Icons.trending_up_outlined,
                                label: 'Progress')
                          ])));
            },
          ),
        ],
      ),
    );
  }
}
