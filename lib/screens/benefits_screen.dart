import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/theme/typography.dart';
import 'package:macrotracker/services/superwall_placements.dart';
import 'package:macrotracker/services/subscription_service.dart';
import 'package:macrotracker/services/posthog_service.dart';

class BenefitsScreen extends StatefulWidget {
  const BenefitsScreen({super.key});

  @override
  State<BenefitsScreen> createState() => _BenefitsScreenState();
}

class _BenefitsScreenState extends State<BenefitsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    // Track screen view
    PostHogService.trackScreen('benefits_screen');
    
    // Start animation
    _animationController.forward();
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Section with Logo and Text
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: customColors?.cardBackground ?? theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.shadow.withValues(alpha: 0.1),
                              offset: const Offset(0, 4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/icons/MacroBalance_Logo.png',
                            width: 60,
                            height: 60,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Title
                      Text(
                        'Unlock Your Fitness\nPotential',
                        style: GoogleFonts.inter(
                          color: customColors?.textPrimary ?? theme.colorScheme.onSurface,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Subtitle
                      Text(
                        'Transform your health with AI-powered macro tracking',
                        style: GoogleFonts.inter(
                          color: customColors?.textSecondary ?? theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                          letterSpacing: 0.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                // Features Section
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildFeatureCard(
                            icon: Icons.camera_alt,
                            title: 'AI Food Recognition',
                            color: Colors.blue,
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _buildFeatureCard(
                            icon: Icons.track_changes_outlined,
                            title: 'Smart Goals',
                            color: Colors.green,
                          )),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildFeatureCard(
                            icon: Icons.analytics,
                            title: 'Analytics',
                            color: Colors.orange,
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _buildFeatureCard(
                            icon: Icons.widgets,
                            title: 'Widgets',
                            color: Colors.red,
                          )),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Bottom Section with Buttons
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Primary Button
                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(alpha: 0.3),
                              offset: const Offset(0, 4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(26),
                            onTap: () async {
                              HapticFeedback.mediumImpact();
                              await _handleStartFreeTrial();
                            },
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Unlock Full Potential',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Secondary Button
                      TextButton(
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          await _handleRestorePurchases();
                        },
                        child: Text(
                          'Restore Purchases',
                          style: GoogleFonts.inter(
                            color: theme.colorScheme.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Container(
      height: 110, // Increased from 90
      padding: const EdgeInsets.all(16), // Increased from 12
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40, // Increased from 32
            height: 40, // Increased from 32
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24, // Increased from 18
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12, // Increased from 10
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _handleStartFreeTrial() async {
    try {
      PostHogService.trackEvent('benefits_screen_cta_tapped', properties: {
        'action': 'start_free_trial',
        'screen': 'benefits_screen',
      });

      // Show chained paywalls - second paywall appears if first is dismissed
      await SuperwallPlacements.showChainedPaywalls(
        context: context,
        firstPlacement: 'benefits_screen_primary',
        secondPlacement: 'benefits_screen_fallback',
        firstParams: {
          'source': 'benefits_screen',
          'action': 'start_free_trial',
          'position': 'primary',
        },
        secondParams: {
          'source': 'benefits_screen',
          'action': 'fallback_offer',
          'position': 'secondary',
        },
        onUserSubscribed: () {
          debugPrint('[BenefitsScreen] User subscribed via chained paywalls');
          PostHogService.trackEvent('chained_paywall_conversion', properties: {
            'source': 'benefits_screen',
            'flow': 'chained_paywalls',
          });
          // The SuperwallGate will automatically detect the subscription and navigate to Dashboard
        },
        onBothPaywallsDismissed: () {
          debugPrint('[BenefitsScreen] User dismissed both paywalls');
          PostHogService.trackEvent('chained_paywall_dismissed', properties: {
            'source': 'benefits_screen',
            'dismissal_count': 2,
          });
          // User stays on benefits screen - no action needed
          // _showErrorSnackBar('Premium features are just a tap away! 🚀');
        },
      );
    } catch (e) {
      debugPrint('[BenefitsScreen] Error showing chained paywalls: $e');
      _showErrorSnackBar('Unable to show subscription options. Please try again.');
    }
  }

  Future<void> _handleRestorePurchases() async {
    try {
      PostHogService.trackEvent('benefits_screen_restore_tapped', properties: {
        'action': 'restore_purchases',
        'screen': 'benefits_screen',
      });

      final restored = await SubscriptionService().restorePurchases();
      
      if (restored && mounted) {
        _showSuccessSnackBar('Purchases restored successfully!');
      } else if (mounted) {
        _showErrorSnackBar('No previous purchases found.');
      }
    } catch (e) {
      debugPrint('[BenefitsScreen] Error restoring purchases: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to restore purchases. Please try again.');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
} 