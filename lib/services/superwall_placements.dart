import 'package:flutter/material.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:macrotracker/services/superwall_service.dart';

/// Superwall placement constants and helper methods
/// This replaces direct CustomPaywallScreen navigation calls with Superwall placement registration
class SuperwallPlacements {
  // Placement identifiers (to be configured in Superwall dashboard)
  static const String onboardingResults = 'onboarding_results';
  static const String subscriptionSettings = 'subscription_settings';
  static const String accountDashboard = 'account_dashboard_debug';
  static const String appAccess = 'app_access'; // Match dashboard configuration
  static const String premiumFeatures = 'premium_features'; // Feature-level gates
  static const String testPlacement = 'test_placement'; // For testing Superwall integration
  static const String onboardingResultsSecond = 'onboarding_results_second';
  
  // Chained paywall placements
  static const String firstPaywall = 'first_paywall'; // First paywall in chain
  static const String secondPaywall = 'second_paywall'; // Second paywall in chain
  static const String fallbackPaywall = 'fallback_paywall'; // Fallback if main paywall dismissed
  /// Show chained paywalls - main use case for when you want one paywall after another
  /// This is the method you'll use for your chained paywall implementation
  static Future<void> showChainedPaywalls({
    required BuildContext context,
    String firstPlacement = onboardingResults,
    String secondPlacement = onboardingResultsSecond,
    Map<String, dynamic>? firstParams,
    Map<String, dynamic>? secondParams,
    VoidCallback? onUserSubscribed,
    VoidCallback? onBothPaywallsDismissed,
  }) async {
    final superwallService = SuperwallService();
    
    debugPrint('[SuperwallPlacements] Initiating chained paywall sequence');
    
    await superwallService.showChainedPaywalls(
      firstPlacement: firstPlacement,
      secondPlacement: secondPlacement,
      firstParams: firstParams ?? {
        'source': 'chained_paywall_sequence',
      },
      secondParams: secondParams ?? {
        'source': 'chained_paywall_sequence',
      },
      onUserSubscribed: onUserSubscribed,
      onBothPaywallsDismissed: onBothPaywallsDismissed,
    );
  }

  /// Simple sequential paywalls - show one paywall immediately after another
  /// This is a more direct approach if you just want immediate sequential display
  static Future<void> showSequentialPaywalls({
    required BuildContext context,
    String firstPlacementName = firstPaywall,
    String secondPlacementName = fallbackPaywall,
    Map<String, dynamic>? params,
  }) async {
    final superwallService = SuperwallService();
    
    debugPrint('[SuperwallPlacements] Showing sequential paywalls');
    
    await superwallService.showSequentialPaywalls(
      context: context,
      firstPlacement: firstPlacementName,
      secondPlacement: secondPlacementName,
      params: params ?? {
        'source': 'sequential_paywalls',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Show paywall during onboarding results (replaces complex paywall logic in results_screen.dart)
  static Future<void> showOnboardingPaywall(
    BuildContext context, {
    required VoidCallback onPremiumUser,
    required VoidCallback onFreeUser,
  }) async {
    final superwallService = SuperwallService();
    
    // Use session tracking for onboarding paywall
    await superwallService.registerWithSessionTracking(
      placement: onboardingResults,
      params: {
        'source': 'onboarding_results',
        'user_stage': 'post_goals_calculation',
      },
      feature: () async {
        // Check subscription status after potential paywall
        final hasSubscription = await superwallService.hasActiveSubscription();
        if (hasSubscription) {
          onPremiumUser();
        } else {
          onFreeUser();
        }
      },
    );
  }

  /// Show chained paywalls during onboarding - first show onboarding paywall, then fallback
  static Future<void> showOnboardingChainedPaywalls({
    required BuildContext context,
    required VoidCallback onPremiumUser,
    required VoidCallback onFreeUser,
  }) async {
    debugPrint('[SuperwallPlacements] Starting onboarding chained paywall sequence');
    
    await showChainedPaywalls(
      context: context,
      firstPlacement: onboardingResults,
      secondPlacement: fallbackPaywall,
      firstParams: {
        'source': 'onboarding_results_chained',
        'user_stage': 'post_goals_calculation',
        'chain_position': 'first',
      },
      secondParams: {
        'source': 'onboarding_fallback_chained',
        'user_stage': 'post_goals_calculation', 
        'chain_position': 'second',
      },
      onUserSubscribed: onPremiumUser,
      onBothPaywallsDismissed: onFreeUser,
    );
  }
  
  /// Show paywall in subscription settings (replaces modal bottom sheet)
  static Future<void> showSubscriptionSettingsPaywall(BuildContext context) async {
    await SuperwallService().register(
      placement: subscriptionSettings,
      params: {
        'source': 'subscription_settings',
        'user_intent': 'upgrade_subscription',
      },
      feature: () {
        // After paywall interaction, navigation will be handled by callback
        Navigator.of(context).pop();
      },
    );
  }
  
  /// Show debug paywall in account dashboard
  static Future<void> showDebugPaywall(BuildContext context) async {
    await SuperwallService().register(
      placement: accountDashboard,
      params: {
        'source': 'account_dashboard_debug',
        'debug_mode': true,
      },
      feature: () {
        // Debug paywall doesn't restrict feature access
        debugPrint('[SuperwallPlacements] Debug paywall completed');
      },
    );
  }
  
  /// Register hard paywall for app access (replaces PaywallGate)
  /// Returns true if user has subscription, false if they need to see benefits screen
  static Future<bool> registerAppAccessGate({
    VoidCallback? onGrantAccess, // Made optional since hard paywall doesn't auto-grant
  }) async {
    final superwallService = SuperwallService();
    
    debugPrint('[SuperwallPlacements] Starting app access gate registration...');
    
    // Check if user already has access
    final hasSubscription = await superwallService.hasActiveSubscription();
    debugPrint('[SuperwallPlacements] Has active subscription: $hasSubscription');
    
    if (hasSubscription) {
      debugPrint('[SuperwallPlacements] User has subscription, granting access immediately');
      onGrantAccess?.call();
      return true;
    }
    
    debugPrint('[SuperwallPlacements] No subscription - hard paywall will show benefits screen');
    
    // For hard paywall: Don't register placement that could grant automatic access
    // Let the UI show benefits screen instead
    return false;
  }

  /// Show paywall from benefits screen (for users who want to upgrade)
  static Future<void> showPaywallFromBenefits({
    required VoidCallback onPurchaseCompleted,
  }) async {
    final superwallService = SuperwallService();
    
    debugPrint('[SuperwallPlacements] Showing paywall from benefits screen...');
    
    try {
      await superwallService.register(
        placement: appAccess,
        params: {
          'source': 'benefits_screen',
          'access_type': 'upgrade_flow',
        },
        feature: () async {
          debugPrint('[SuperwallPlacements] Purchase completed from benefits screen');
          
          // Verify subscription status before granting access
          final hasSubscription = await superwallService.hasActiveSubscription();
          if (hasSubscription) {
            onPurchaseCompleted();
          } else {
            debugPrint('[SuperwallPlacements] Purchase callback triggered but no subscription found');
          }
        },
      );
    } catch (e) {
      debugPrint('[SuperwallPlacements] Error showing paywall from benefits: $e');
    }
  }
  
  /// Register feature-level premium gate
  static Future<void> registerPremiumFeatureGate({
    required String featureName,
    required VoidCallback onGrantAccess,
    Map<String, dynamic>? additionalParams,
  }) async {
    final superwallService = SuperwallService();
    
    // Check if user already has access
    if (await superwallService.hasActiveSubscription()) {
      onGrantAccess();
      return;
    }
    
    // Register placement for premium feature
    await superwallService.register(
      placement: premiumFeatures,
      params: {
        'source': 'premium_feature_gate',
        'feature_name': featureName,
        ...?additionalParams,
      },
      feature: () async {
        // After paywall, check again and grant access if subscribed
        if (await superwallService.hasActiveSubscription()) {
          onGrantAccess();
        }
      },
    );
  }

  /// Test placement for verifying Superwall integration
  /// This is a simple test that shows whether Superwall is working correctly
  static Future<void> showTestPaywall(
    BuildContext context, {
    VoidCallback? onSuccess,
    VoidCallback? onError,
  }) async {
    final superwallService = SuperwallService();
    
    debugPrint('[SuperwallPlacements] Testing Superwall integration with test placement');
    
    try {
      await superwallService.register(
        placement: testPlacement,
        params: {
          'source': 'test_integration',
          'test_type': 'basic_functionality',
          'timestamp': DateTime.now().toIso8601String(),
        },
        feature: () async {
          debugPrint('[SuperwallPlacements] Test placement feature callback triggered');
          
          // Show success feedback
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Superwall test placement worked!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
          
          onSuccess?.call();
        },
      );
      
      debugPrint('[SuperwallPlacements] Test placement registration completed successfully');
      
    } catch (e) {
      debugPrint('[SuperwallPlacements] Test placement failed: $e');
      
      // Show error feedback
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Superwall test failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      
      onError?.call();
    }
  }

} 