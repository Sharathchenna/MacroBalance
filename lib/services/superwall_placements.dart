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
  static Future<bool> registerAppAccessGate({
    required VoidCallback onGrantAccess,
  }) async {
    final superwallService = SuperwallService();
    
    debugPrint('[SuperwallPlacements] Starting app access gate registration...');
    
    // Check if user already has access
    final hasSubscription = await superwallService.hasActiveSubscription();
    debugPrint('[SuperwallPlacements] Has active subscription: $hasSubscription');
    
    if (hasSubscription) {
      debugPrint('[SuperwallPlacements] User has subscription, granting access immediately');
      onGrantAccess();
      return true;
    }
    
    debugPrint('[SuperwallPlacements] No subscription, registering placement: $appAccess');
    
    // Register placement for app access
    try {
      await superwallService.register(
        placement: appAccess,
        params: {
          'source': 'app_access_gate',
          'access_type': 'hard_paywall',
        },
              feature: () async {
        debugPrint('[SuperwallPlacements] Paywall feature callback triggered - granting access');
        
        // When Superwall triggers this callback, it means user should have access
        // Either they just completed a purchase or already had a subscription
        onGrantAccess();
        
        // Optionally check subscription status for logging (but don't base access on it)
        final newSubscriptionStatus = await superwallService.hasActiveSubscription();
        debugPrint('[SuperwallPlacements] Post-paywall subscription status check: $newSubscriptionStatus');
      },
      );
      
      debugPrint('[SuperwallPlacements] Placement registration completed');
    } catch (e) {
      debugPrint('[SuperwallPlacements] Error registering placement: $e');
    }
    
    final finalSubscriptionStatus = await superwallService.hasActiveSubscription();
    debugPrint('[SuperwallPlacements] Final subscription status check: $finalSubscriptionStatus');
    return finalSubscriptionStatus;
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


} 