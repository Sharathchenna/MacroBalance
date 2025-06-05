import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/services/notification_service.dart';

class NotificationPermissionPage extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const NotificationPermissionPage({
    super.key,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<NotificationPermissionPage> createState() =>
      _NotificationPermissionPageState();
}

class _NotificationPermissionPageState extends State<NotificationPermissionPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleAllowNotifications() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    HapticFeedback.mediumImpact();

    try {
      await NotificationService().initialize();

      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifications enabled successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      }

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        widget.onNext();
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error setting up notifications: ${e.toString()}'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onNext();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleSkip() {
    HapticFeedback.lightImpact();
    widget.onSkip();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>();
    final size = MediaQuery.of(context).size;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: size.width * 0.06,
          vertical: size.height * 0.03,
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Header section with icon and title
                Column(
                  children: [
                    Container(
                      width: size.width * 0.18,
                      height: size.width * 0.18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            (customColors?.accentPrimary ?? theme.primaryColor)
                                .withValues(alpha: 0.15),
                            (customColors?.accentPrimary ?? theme.primaryColor)
                                .withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(
                        Icons.notifications_active_rounded,
                        size: size.width * 0.09,
                        color: customColors?.accentPrimary ?? theme.primaryColor,
                      ),
                    ),
                    SizedBox(height: size.height * 0.025),
                    Text(
                      'Stay on Track',
                      style: GoogleFonts.inter(
                        fontSize: size.width * 0.065,
                        fontWeight: FontWeight.w700,
                        color: customColors?.textPrimary ?? theme.colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: size.height * 0.008),
                    Text(
                      'Get reminders to stay consistent with your nutrition goals',
                      style: GoogleFonts.inter(
                        fontSize: size.width * 0.038,
                        color: customColors?.textSecondary ?? theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),

                // Features section - compact horizontal layout
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width * 0.04,
                    vertical: size.height * 0.025,
                  ),
                  decoration: BoxDecoration(
                    color: customColors?.cardBackground ?? theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCompactFeature(
                        icon: Icons.schedule_rounded,
                        title: 'Meal\nReminders',
                        theme: theme,
                        customColors: customColors,
                        size: size,
                      ),
                      _buildCompactFeature(
                        icon: Icons.insights_rounded,
                        title: 'Progress\nUpdates',
                        theme: theme,
                        customColors: customColors,
                        size: size,
                      ),
                      _buildCompactFeature(
                        icon: Icons.tune_rounded,
                        title: 'Custom\nSettings',
                        theme: theme,
                        customColors: customColors,
                        size: size,
                      ),
                    ],
                  ),
                ),

                // Buttons section
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: size.height * 0.065,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleAllowNotifications,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: customColors?.accentPrimary ?? theme.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Enable Notifications',
                                style: GoogleFonts.inter(
                                  fontSize: size.width * 0.04,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: size.height * 0.015),
                    SizedBox(
                      width: double.infinity,
                      height: size.height * 0.065,
                      child: TextButton(
                        onPressed: _isLoading ? null : _handleSkip,
                        style: TextButton.styleFrom(
                          foregroundColor: customColors?.textSecondary ?? theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: theme.colorScheme.outline.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Text(
                          'Maybe Later',
                          style: GoogleFonts.inter(
                            fontSize: size.width * 0.04,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactFeature({
    required IconData icon,
    required String title,
    required ThemeData theme,
    required CustomColors? customColors,
    required Size size,
  }) {
    return Column(
      children: [
        Container(
          width: size.width * 0.12,
          height: size.width * 0.12,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                (customColors?.accentPrimary ?? theme.primaryColor)
                    .withValues(alpha: 0.15),
                (customColors?.accentPrimary ?? theme.primaryColor)
                    .withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: size.width * 0.06,
            color: customColors?.accentPrimary ?? theme.primaryColor,
          ),
        ),
        SizedBox(height: size.height * 0.01),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: size.width * 0.03,
            fontWeight: FontWeight.w600,
            color: customColors?.textPrimary ?? theme.colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
