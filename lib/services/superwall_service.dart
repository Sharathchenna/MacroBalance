import 'package:flutter/material.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart' as sw;
import 'package:macrotracker/services/subscription_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Superwall service for handling paywalls and referral codes
class SuperwallService implements sw.SuperwallDelegate {
  static final SuperwallService _instance = SuperwallService._internal();
  factory SuperwallService() => _instance;
  SuperwallService._internal();

  bool _isInitialized = false;
  final SubscriptionService _subscriptionService = SubscriptionService();
  String? _storedReferralCode;

  /// Initialize Superwall with your API key
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('Initializing Superwall service...');

      // Configure Superwall with RevenueCat integration
      sw.Superwall.configure(
          'pk_92e7caae027e3213de436b66d1fb25996245e09c3415ef9b');

      // Set this SuperwallService instance as the delegate
      sw.Superwall.shared.setDelegate(this);

      debugPrint('Superwall delegate set successfully');

      _isInitialized = true;
      debugPrint(
          'Superwall service initialized successfully with RevenueCat integration');
    } catch (e) {
      debugPrint('Error initializing Superwall: $e');
      // Don't throw - allow app to continue
    }
  }

  /// Show main paywall for subscription
  Future<void> showMainPaywall() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      debugPrint('Showing main paywall');

      final params = <String, String>{};

      // Add referral code if available
      if (_storedReferralCode != null) {
        params['referral_code'] = _storedReferralCode!;
        params['has_referral'] = 'true';
      }

      // Use your existing onboarding_paywall campaign
      debugPrint('Attempting to show onboarding_paywall campaign');

      sw.Superwall.shared.registerPlacement(
        'onboarding_paywall',
        params: params.isNotEmpty ? params : null,
        feature: () {
          debugPrint('User has premium access - feature unlocked');
        },
      );

      debugPrint('onboarding_paywall campaign registration completed');
    } catch (e) {
      debugPrint('Error showing main paywall: $e');
    }
  }

  /// Show hard paywall for app install - no bypass option
  Future<void> showHardPaywall() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      debugPrint('Showing hard paywall for app install');

      final params = <String, String>{
        'paywall_type': 'hard',
        'trigger': 'app_install',
      };

      // Add referral code if available
      if (_storedReferralCode != null) {
        params['referral_code'] = _storedReferralCode!;
        params['has_referral'] = 'true';
      }

      // Use app_install placement for hard paywall
      debugPrint('Attempting to show app_install hard paywall');

      sw.Superwall.shared.registerPlacement(
        'app_install',
        params: params,
        feature: () {
          debugPrint('User has premium access - hard paywall bypassed');
        },
      );

      debugPrint('Hard paywall registration completed');
    } catch (e) {
      debugPrint('Error showing hard paywall: $e');
      throw e; // Re-throw to handle in PaywallGate
    }
  }

  /// Show referral-specific paywall with special pricing
  Future<void> showReferralPaywall(String referralCode) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      debugPrint('Showing referral paywall for code: $referralCode');

      // Set the referral code for this session
      setReferralCode(referralCode);

      // Create parameters for the referral paywall
      final params = <String, String>{
        'referral_code': referralCode,
        'discount_applied': 'true',
        'utm_source': 'referral',
        'utm_medium': 'promo_code',
        'utm_campaign': referralCode.toLowerCase(),
      };

      // Show the referral-specific paywall
      sw.Superwall.shared.registerPlacement(
        'referral_paywall',
        params: params,
        feature: () {
          debugPrint('User has premium access via referral');
        },
      );
    } catch (e) {
      debugPrint('Error showing referral paywall: $e');
    }
  }

  /// Validate referral code (simulate server validation)
  Future<bool> validateReferralCode(String code) async {
    try {
      // Simulate validation with predefined codes
      final validCodes = [
        'WELCOME50',
        'FRIEND20',
        'NEWUSER',
        'SAVE30',
        'TESTCODE',
        'MACRO20',
        'FITNESS50',
        'HEALTH30',
      ];

      await Future.delayed(
          const Duration(milliseconds: 500)); // Simulate network delay
      return validCodes.contains(code.toUpperCase());
    } catch (e) {
      debugPrint('Error validating referral code: $e');
      return false;
    }
  }

  /// Get referral code details (simulate server response)
  Future<Map<String, dynamic>?> getReferralCodeDetails(String code) async {
    try {
      // Return mock data based on code
      switch (code.toUpperCase()) {
        case 'WELCOME50':
          return {
            'discount_percentage': 50,
            'influencer_name': 'WelcomeInfluencer',
            'expires_at':
                DateTime.now().add(const Duration(days: 30)).toIso8601String(),
          };
        case 'FRIEND20':
          return {
            'discount_percentage': 20,
            'influencer_name': 'FriendReferral',
            'expires_at':
                DateTime.now().add(const Duration(days: 7)).toIso8601String(),
          };
        default:
          return {
            'discount_percentage': 25,
            'influencer_name': 'PromoCode',
            'expires_at':
                DateTime.now().add(const Duration(days: 14)).toIso8601String(),
          };
      }
    } catch (e) {
      debugPrint('Error getting referral code details: $e');
      return null;
    }
  }

  /// Set user identity for Superwall
  Future<void> setUserIdentity(String userId) async {
    if (!_isInitialized) return;

    try {
      await sw.Superwall.shared.identify(userId);
      debugPrint('Set Superwall user identity: $userId');
    } catch (e) {
      debugPrint('Error setting Superwall user identity: $e');
    }
  }

  /// Reset user identity (for logout)
  Future<void> resetUserIdentity() async {
    if (!_isInitialized) return;

    try {
      await sw.Superwall.shared.reset();
      clearReferralCode();
      debugPrint('Reset Superwall user identity');
    } catch (e) {
      debugPrint('Error resetting Superwall user identity: $e');
    }
  }

  /// Store referral code for this session
  void setReferralCode(String code) {
    _storedReferralCode = code;
    debugPrint('Stored referral code: $code');
  }

  /// Get stored referral code
  String? get storedReferralCode => _storedReferralCode;

  /// Clear stored referral code
  void clearReferralCode() {
    _storedReferralCode = null;
    debugPrint('Cleared stored referral code');
  }

  /// Check if Superwall is initialized and ready
  bool get isInitialized => _isInitialized;

  /// Get current subscription status
  bool get hasActiveSubscription {
    return _subscriptionService.hasPremiumAccess();
  }

  /// Update Superwall with current subscription status
  Future<void> updateSubscriptionStatus(bool isActive) async {
    if (!_isInitialized) return;

    try {
      if (isActive) {
        // User has active subscription - create entitlements set
        final entitlements = {sw.Entitlement(id: 'premium')};
        await sw.Superwall.shared.setSubscriptionStatus(
          sw.SubscriptionStatusActive(entitlements: entitlements),
        );
        debugPrint('Updated Superwall: User has active subscription');
      } else {
        // User does not have active subscription
        await sw.Superwall.shared.setSubscriptionStatus(
          sw.SubscriptionStatusInactive(),
        );
        debugPrint('Updated Superwall: User has inactive subscription');
      }
    } catch (e) {
      debugPrint('Error updating Superwall subscription status: $e');
    }
  }

  /// Set user properties for better targeting
  Future<void> setUserProperties(Map<String, dynamic> properties) async {
    if (!_isInitialized) return;

    try {
      // Convert all values to strings as required by Superwall
      final stringProperties = properties.map(
        (key, value) => MapEntry(key, value.toString()),
      );

      await sw.Superwall.shared.setUserAttributes(stringProperties);
      debugPrint('Set user properties: $stringProperties');
    } catch (e) {
      debugPrint('Error setting user properties: $e');
    }
  }

  /// Track events (simplified version)
  Future<void> trackEvent(String eventName) async {
    if (!_isInitialized) return;

    try {
      debugPrint('Tracked event: $eventName');
      // Note: Actual tracking implementation depends on Superwall SDK version
    } catch (e) {
      debugPrint('Error tracking event: $e');
    }
  }

  /// Show paywall for specific feature access
  Future<void> showFeaturePaywall(String featureName) async {
    if (!_isInitialized) await initialize();

    try {
      debugPrint('Showing feature paywall for: $featureName');

      final params = <String, String>{
        'feature': featureName,
        'trigger': 'feature_access',
      };

      if (_storedReferralCode != null) {
        params['referral_code'] = _storedReferralCode!;
      }

      sw.Superwall.shared.registerPlacement(
        'feature_paywall',
        params: params,
        feature: () {
          debugPrint('User has access to feature: $featureName');
        },
      );
    } catch (e) {
      debugPrint('Error showing feature paywall: $e');
    }
  }

  /// Validate referral code and show referral paywall if valid
  /// This is a convenience method that combines validation and paywall display
  Future<bool> validateAndShowReferralPaywall(
    String code, {
    BuildContext? context,
    String? influencerName,
    double? discountPercentage,
  }) async {
    try {
      // First validate the code
      final isValid = await validateReferralCode(code);

      if (isValid) {
        // Get additional details if not provided
        final details = await getReferralCodeDetails(code);
        final finalDiscountPercentage =
            discountPercentage ?? details?['discount_percentage'];

        debugPrint(
            'Valid referral code: $code, showing paywall with $finalDiscountPercentage% discount');

        // Show the referral paywall
        await showReferralPaywall(code);

        return true;
      } else {
        debugPrint('Invalid referral code: $code');
        return false;
      }
    } catch (e) {
      debugPrint('Error in validateAndShowReferralPaywall: $e');
      return false;
    }
  }

  /// Restore purchases through RevenueCat and update Superwall
  Future<bool> restorePurchases() async {
    try {
      debugPrint('Superwall: Starting restore purchases process');

      // Use RevenueCat to restore purchases
      final customerInfo = await Purchases.restorePurchases();

      debugPrint('Superwall: RevenueCat restore completed');

      // Check if user now has active entitlements
      final hasActiveSubscription = customerInfo.entitlements.active.isNotEmpty;

      if (hasActiveSubscription) {
        debugPrint('Superwall: Active subscription found after restore');

        // Update Superwall subscription status
        await updateSubscriptionStatus(true);

        // Update local subscription service
        await _subscriptionService.refreshPurchaserInfo();

        return true;
      } else {
        debugPrint('Superwall: No active subscriptions found after restore');
        return false;
      }
    } catch (e) {
      debugPrint('Superwall: Error during restore purchases: $e');
      return false;
    }
  }

  /// Handle Superwall custom actions - DEPRECATED - Use delegate method instead
  void handleCustomAction(String actionName) {
    debugPrint('Superwall: Handling custom action: $actionName');

    switch (actionName.toLowerCase()) {
      case 'restore':
        restorePurchases();
        break;
      default:
        debugPrint('Superwall: Unknown custom action: $actionName');
    }
  }

  // MARK: - SuperwallDelegate Implementation

  @override
  void handleCustomPaywallAction(String name) {
    debugPrint('Superwall Delegate: Handling custom paywall action: $name');

    switch (name.toLowerCase()) {
      case 'restore':
        debugPrint('Superwall Delegate: Processing restore action');
        _handleRestoreAction();
        break;
      case 'restore_purchases':
        debugPrint('Superwall Delegate: Processing restore_purchases action');
        _handleRestoreAction();
        break;
      default:
        debugPrint('Superwall Delegate: Unknown custom action: $name');
    }
  }

  /// Handle restore action from paywall
  Future<void> _handleRestoreAction() async {
    try {
      final success = await restorePurchases();
      debugPrint('Superwall Delegate: Restore completed with result: $success');

      // You could show a user message here if needed
      // The paywall should automatically dismiss if subscription is found
    } catch (e) {
      debugPrint('Superwall Delegate: Error in restore action: $e');
    }
  }

  @override
  void didDismissPaywall(sw.PaywallInfo paywallInfo) {
    debugPrint('Superwall Delegate: Paywall dismissed');
  }

  @override
  void didPresentPaywall(sw.PaywallInfo paywallInfo) {
    debugPrint('Superwall Delegate: Paywall presented');
  }

  @override
  void handleLog(String level, String scope, String? message,
      Map<dynamic, dynamic>? info, String? error) {
    // Handle Superwall logs if needed
    // debugPrint('Superwall Log: [$level] $scope: $message');
  }

  @override
  Future<void> handleSuperwallEvent(sw.SuperwallEventInfo eventInfo) async {
    // Handle Superwall events if needed for analytics
    debugPrint('Superwall Event: ${eventInfo.event.type}');
  }

  @override
  void paywallWillOpenDeepLink(Uri url) {
    debugPrint('Superwall Delegate: Will open deep link: $url');
  }

  @override
  void paywallWillOpenURL(Uri url) {
    debugPrint('Superwall Delegate: Will open URL: $url');
  }

  @override
  void subscriptionStatusDidChange(sw.SubscriptionStatus newValue) {
    debugPrint('Superwall Delegate: Subscription status changed: $newValue');
  }

  @override
  void willDismissPaywall(sw.PaywallInfo paywallInfo) {
    debugPrint('Superwall Delegate: Will dismiss paywall');

    // For hard paywall, we need to check subscription status when paywall is dismissed
    Future.microtask(() async {
      try {
        // Refresh subscription status to see if user purchased
        await _subscriptionService.refreshPurchaserInfo();
        final hasSubscription = _subscriptionService.hasPremiumAccess();

        debugPrint('Paywall dismissed - subscription status: $hasSubscription');

        // If this was a hard paywall and user still doesn't have subscription,
        // they should not be able to proceed (Superwall should handle this)
        if (!hasSubscription) {
          debugPrint(
              'Hard paywall dismissed without purchase - Superwall should handle blocking');
        }
      } catch (e) {
        debugPrint('Error checking subscription after paywall dismiss: $e');
      }
    });
  }

  @override
  void willPresentPaywall(sw.PaywallInfo paywallInfo) {
    debugPrint('Superwall Delegate: Will present paywall');
    debugPrint('Paywall ID: ${paywallInfo.identifier}');
    debugPrint('Paywall URL: ${paywallInfo.url}');
  }

  @override
  void willRedeemLink() {
    debugPrint('Superwall Delegate: Will redeem link');
  }

  @override
  void didRedeemLink(sw.RedemptionResult result) {
    debugPrint('Superwall Delegate: Did redeem link with result: $result');
  }
}
