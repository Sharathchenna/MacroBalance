import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macrotracker/screens/loginscreen.dart';
import 'package:macrotracker/screens/signup.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/theme/typography.dart';
import 'dart:io' show Platform;

class Welcomescreen extends StatefulWidget {
  const Welcomescreen({super.key});

  @override
  State<Welcomescreen> createState() => _WelcomescreenState();
}

class _WelcomescreenState extends State<Welcomescreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  void updateStatusBarForIOS(bool isDark) {
    if (Platform.isIOS) {
      SystemChrome.setSystemUIOverlayStyle(
        isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      _animationController.forward();
    });

    if (Platform.isIOS) {
      updateStatusBarForIOS(false);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (customColors == null) {
      return const Scaffold(
        body: Center(child: Text('Theme error')),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),

            // Logo and App Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Hero(
                      tag: 'app_logo',
                      child: Container(
                        height: 60,
                        width: 60,
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF242428) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withAlpha(((0.3) * 255).round())
                                  : Colors.black.withAlpha(((0.08) * 255).round()),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Image.asset(
                            isDark
                                ? 'assets/icons/icon_white.png'
                                : 'assets/icons/icon_black.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'MacroBalance',
                      style: AppTypography.h1.copyWith(
                        color: customColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Tagline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'Smart nutrition tracking made simple',
                  textAlign: TextAlign.center,
                  style: AppTypography.body1.copyWith(
                    color: customColors.textSecondary,
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Features showcase
            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildFeature(
                        isDark: isDark,
                        icon: CupertinoIcons.camera,
                        title: 'AI Food Recognition',
                        description: 'Just snap a photo to log your meals',
                        backgroundColor: isDark
                            ? const Color(0xFF242428)
                            : customColors.dateNavigatorBackground,
                        iconColor: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      _buildFeature(
                        isDark: isDark,
                        icon: CupertinoIcons.chart_pie,
                        title: 'Effortless Tracking',
                        description: 'Monitor calories, macros, and nutrients',
                        backgroundColor: isDark
                            ? const Color(0xFF242428)
                            : customColors.dateNavigatorBackground,
                        iconColor: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      _buildFeature(
                        isDark: isDark,
                        icon: CupertinoIcons.heart,
                        title: 'Health Integration',
                        description: 'Sync with Apple Health & Google Fit',
                        backgroundColor: isDark
                            ? const Color(0xFF242428)
                            : customColors.dateNavigatorBackground,
                        iconColor: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Buttons
            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Sign In Button
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Sign In',
                          style: AppTypography.onboardingButton.copyWith(
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Create Account Button
                      OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => const Signup(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: customColors.textPrimary,
                          side: BorderSide(
                            color: isDark
                                ? Colors.white.withAlpha(((0.2) * 255).round())
                                : Colors.black.withAlpha(((0.1) * 255).round()),
                            width: 1,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Create Account',
                          style: AppTypography.onboardingButton.copyWith(
                            color: customColors.textPrimary,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeature({
    required bool isDark,
    required IconData icon,
    required String title,
    required String description,
    required Color backgroundColor,
    required Color iconColor,
  }) {
    final customColors = Theme.of(context).extension<CustomColors>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(((0.1) * 255).round())
              : Colors.black.withAlpha(((0.05) * 255).round()),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(((0.15) * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.h3.copyWith(
                    color: customColors?.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTypography.body2.copyWith(
                    color: customColors?.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
