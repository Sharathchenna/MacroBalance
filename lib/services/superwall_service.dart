import 'package:flutter/material.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart' as sw;
import 'package:macrotracker/services/subscription_service.dart';

/// Superwall service for handling paywalls and referral codes
class SuperwallService {
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
      // For Flutter, we use the simpler configuration that integrates with RevenueCat automatically
      sw.Superwall.configure(
          'pk_92e7caae027e3213de436b66d1fb25996245e09c3415ef9b');

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
}
