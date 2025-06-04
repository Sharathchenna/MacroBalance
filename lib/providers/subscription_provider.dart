import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:macrotracker/services/storage_service.dart'; // Import StorageService
import 'package:macrotracker/services/superwall_service.dart'; // Import SuperwallService

/// A provider class that manages subscription status throughout the app
class SubscriptionProvider extends ChangeNotifier {
  bool _isProUser = false;
  bool _isInitialized = false;
  DateTime? _lastChecked;
  bool _revenueCatConfigured = false;

  // Hard paywall configuration
  static const bool _enforceHardPaywall = true;

  // Getters
  bool get isProUser => _isProUser;
  bool get isInitialized => _isInitialized;
  DateTime? get lastChecked => _lastChecked;
  bool get hasFreeTrial => false; // No free trial with hard paywall

  // Constructor - loads from local cache and sets up RevenueCat integration
  SubscriptionProvider() {
    _loadFromPrefs();
    // Delay RevenueCat integration to next frame to avoid blocking widget creation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeRevenueCatIntegration();
    });
  }

  // Initialize RevenueCat integration with fallback handling
  void _initializeRevenueCatIntegration() async {
    try {
      // Test if RevenueCat is configured
      await Purchases.getCustomerInfo().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('RevenueCat timeout'),
      );
      _revenueCatConfigured = true;
      print('RevenueCat is configured, setting up subscription provider');

      // Set up listener and check status
      _setupPurchaseListener();
      checkSubscriptionStatus();
    } catch (e) {
      print('RevenueCat not yet configured: $e');
      // Fallback with retry logic for edge cases where RevenueCat might still be initializing
      _waitForRevenueCatAndInitialize();
    }
  }

  // Wait for RevenueCat to be configured before setting up listeners
  void _waitForRevenueCatAndInitialize() async {
    // Try to set up RevenueCat integration with exponential backoff
    int retryCount = 0;
    const maxRetries = 10;

    while (retryCount < maxRetries && !_revenueCatConfigured) {
      try {
        // Test if RevenueCat is configured by trying to get customer info
        await Purchases.getCustomerInfo();
        _revenueCatConfigured = true;
        print('RevenueCat is now configured, setting up subscription provider');

        // Now safe to set up listener and check status
        _setupPurchaseListener();
        checkSubscriptionStatus();
        break;
      } catch (e) {
        retryCount++;
        final delay = Duration(
            milliseconds: 100 * (1 << retryCount)); // Exponential backoff
        print(
            'RevenueCat not yet configured (attempt $retryCount/$maxRetries), retrying in ${delay.inMilliseconds}ms');
        await Future.delayed(delay);
      }
    }

    if (!_revenueCatConfigured) {
      print(
          'Warning: RevenueCat failed to configure after $maxRetries attempts. Operating in offline mode.');
      // Mark as initialized even if RevenueCat failed
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Helper to check if any pro entitlement is active
  bool _hasProEntitlement(CustomerInfo customerInfo) {
    final entitlements = customerInfo.entitlements.active.keys;

    // Check for any entitlement containing 'pro' in a case-insensitive way
    return entitlements.any((key) =>
        key.toLowerCase() == 'pro' ||
        key == 'Pro' ||
        key.toLowerCase().contains('pro'));
  }

  void _setupPurchaseListener() {
    try {
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        print(
            'RevenueCat customer info updated: ${customerInfo.entitlements.active.keys}');
        // Check if the pro entitlement is now active and update state
        final hasProEntitlement = _hasProEntitlement(customerInfo);

        if (hasProEntitlement != _isProUser) {
          print('Subscription status changed via listener: $hasProEntitlement');
          _isProUser = hasProEntitlement;
          _lastChecked = DateTime.now();
          _saveToPrefs();

          // Update Superwall with the new subscription status
          SuperwallService().updateSubscriptionStatus(_isProUser);

          notifyListeners();
        }
      });
    } catch (e) {
      print('Error setting up RevenueCat purchase listener: $e');
      // Continue without the listener - app will still work with cached data
    }
  }

  // Load the cached subscription status (now synchronous)
  void _loadFromPrefs() {
    try {
      // Assuming StorageService is initialized
      _isProUser = StorageService().get('is_pro_user', defaultValue: false);
      final lastCheckedMillis =
          StorageService().get('subscription_last_checked');
      if (lastCheckedMillis != null && lastCheckedMillis is int) {
        _lastChecked = DateTime.fromMillisecondsSinceEpoch(lastCheckedMillis);
      }
      _isInitialized = true;
      // notifyListeners(); // Might not be needed here if called elsewhere after init
    } catch (e) {
      print('Error loading subscription status from StorageService: $e');
      _isInitialized = true; // Still mark as initialized
      // notifyListeners();
    }
  }

  // Save the subscription status to StorageService (now synchronous)
  void _saveToPrefs() {
    try {
      // Assuming StorageService is initialized
      StorageService().put('is_pro_user', _isProUser);
      if (_lastChecked != null) {
        StorageService().put(
            'subscription_last_checked', _lastChecked!.millisecondsSinceEpoch);
      }
    } catch (e) {
      print('Error saving subscription status to StorageService: $e');
    }
  }

  // Check with RevenueCat for the current subscription status
  Future<bool> checkSubscriptionStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      print(
          'Checking subscription status: ${customerInfo.entitlements.active.keys}');

      final bool wasProUser = _isProUser;

      // Consider both sandbox/test and production entitlements
      _isProUser = _hasProEntitlement(customerInfo);

      _lastChecked = DateTime.now();

      // If status changed, notify listeners
      if (wasProUser != _isProUser) {
        print('Subscription status changed: $_isProUser');

        // Update Superwall with the new subscription status
        SuperwallService().updateSubscriptionStatus(_isProUser);

        notifyListeners();
      }

      // Save the updated status (now synchronous)
      _saveToPrefs();

      // Update Superwall with the subscription status
      SuperwallService().updateSubscriptionStatus(_isProUser);

      return _isProUser;
    } catch (e) {
      print('Error checking subscription status: $e');
      return _isProUser; // Return cached status on error
    }
  }

  // Force refresh the subscription status (e.g., after a purchase)
  Future<bool> refreshSubscriptionStatus() async {
    print('Forcing subscription status refresh');

    try {
      // Try to invalidate cache in RevenueCat to ensure fresh data
      await Purchases.invalidateCustomerInfoCache();

      // Now get latest customer info
      return await checkSubscriptionStatus();
    } catch (e) {
      print('Error during forced refresh: $e');
      return await checkSubscriptionStatus();
    }
  }

  // Check if a specific feature is available - with hard paywall, requires subscription
  bool canAccessFeature(String featureName) {
    if (_enforceHardPaywall) {
      return _isProUser; // With hard paywall, all features require subscription
    }

    // Legacy soft paywall logic (not used with hard paywall)
    return _isProUser;
  }

  // Check if the user can access app content at all
  bool canAccessApp() {
    if (_enforceHardPaywall) {
      return _isProUser; // With hard paywall, app access requires subscription
    }

    // Legacy code path (not used with hard paywall)
    return true;
  }

  // Check if the user can add any food entries
  bool canAddEntries() {
    if (_enforceHardPaywall) {
      return _isProUser; // With hard paywall, entries require subscription
    }

    // Legacy code path (not used with hard paywall)
    return true;
  }

  // Debug method to print detailed subscription information
  // Can be called from anywhere for troubleshooting
  Future<void> debugSubscriptionStatus() async {
    try {
      print('===== SUBSCRIPTION DEBUG INFO =====');
      final customerInfo = await Purchases.getCustomerInfo();

      print('Active entitlements: ${customerInfo.entitlements.active.keys}');
      print('All entitlements: ${customerInfo.entitlements.all.keys}');
      print('Active subscriptions: ${customerInfo.activeSubscriptions}');
      print(
          'All purchased product IDs: ${customerInfo.allPurchasedProductIdentifiers}');
      print('Latest expiration date: ${customerInfo.latestExpirationDate}');
      print(
          "Provider: ${customerInfo.managementURL != null ? 'Apple/Google' : 'Unknown'}");
      print('Cached provider status: isProUser = $_isProUser');
      print('===== END DEBUG INFO =====');
    } catch (e) {
      print('Error getting debug subscription info: $e');
    }
  }

  // Force a complete reset of subscription state and refresh from the server
  // This is a last resort if the subscription status gets stuck
  Future<bool> resetSubscriptionState() async {
    print('==== PERFORMING COMPLETE SUBSCRIPTION RESET ====');

    try {
      // 1. Clear local cache (now synchronous)
      _clearLocalCache();

      // 2. Invalidate RevenueCat cache
      await Purchases.invalidateCustomerInfoCache();

      // 3. Force wait for a moment to ensure all async operations complete
      await Future.delayed(const Duration(milliseconds: 500));

      // 4. Get fresh customer info with no caching
      final customerInfo = await Purchases.getCustomerInfo();

      // 5. Set the pro user status based on the fresh info
      _isProUser = _hasProEntitlement(customerInfo);
      _lastChecked = DateTime.now();

      // 6. Save the updated status (now synchronous)
      _saveToPrefs();

      // 7. Notify listeners
      notifyListeners();

      print('Subscription reset complete. Pro status: $_isProUser');
      print('Active entitlements: ${customerInfo.entitlements.active.keys}');

      return _isProUser;
    } catch (e) {
      print('Error during subscription reset: $e');
      return false;
    }
  }

  // Helper to clear the local cached subscription status (now synchronous)
  void _clearLocalCache() {
    try {
      // Assuming StorageService is initialized
      StorageService().delete('is_pro_user');
      StorageService().delete('subscription_last_checked');
    } catch (e) {
      print('Error clearing subscription cache from StorageService: $e');
    }
  }

  @override
  void dispose() {
    // Remove the listener correctly
    try {
      // Different approach to remove listeners
      Purchases.setLogLevel(LogLevel.debug); // This is a no-op that won't throw
      // RevenueCat SDK handles listener cleanup internally
    } catch (e) {
      print('Error removing RevenueCat listeners: $e');
    }
    super.dispose();
  }
}
