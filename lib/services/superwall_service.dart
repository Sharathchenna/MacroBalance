import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:macrotracker/services/posthog_service.dart';
import 'package:macrotracker/services/storage_service.dart';

/// Service to manage Superwall integration and replace custom paywall functionality
class SuperwallService {
  static final SuperwallService _instance = SuperwallService._internal();
  factory SuperwallService() => _instance;
  SuperwallService._internal();

  // Configuration
  static const String _apiKey = 'pk_92e7caae027e3213de436b66d1fb25996245e09c3415ef9b'; // TODO: Replace with actual API key
  bool _isConfigured = false;
  bool _isInitializing = false;

  // Session tracking (migrated from PaywallManager)
  static const String _lastPaywallShownKey = 'superwall_last_paywall_shown_timestamp';
  static const String _paywallShowCountKey = 'superwall_paywall_show_count';
  static const String _appSessionCountKey = 'superwall_app_session_count';
  
  // Time limits (same as PaywallManager)
  static const Duration _minTimeBetweenPaywalls = Duration(days: 3);
  static const int _maxPaywallShowPerMonth = 5;

  // Getters
  bool get isConfigured => _isConfigured;
  
  /// Initialize Superwall SDK with RevenueCat integration
  Future<void> configure() async {
    if (_isConfigured || _isInitializing) return;
    
    _isInitializing = true;
    
    try {
      debugPrint('[SuperwallService] Configuring Superwall SDK with API key: ${_apiKey.substring(0, 10)}...');
      
      // Configure Superwall with API key (simple configuration)
      Superwall.configure(_apiKey);
      
      _isConfigured = true;
      debugPrint('[SuperwallService] Superwall configured successfully');
      
      // Test basic Superwall functionality
      try {
        final userId = await Superwall.shared.getUserId();
        debugPrint('[SuperwallService] Current user ID: $userId');
      } catch (e) {
        debugPrint('[SuperwallService] Could not get user ID: $e');
      }
      
    } catch (e) {
      debugPrint('[SuperwallService] Error configuring Superwall: $e');
      _isConfigured = false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Show chained paywalls - when first paywall is dismissed, show the second
  /// This is the main method you'll use to implement chained paywalls
  Future<void> showChainedPaywalls({
    required String firstPlacement,
    required String secondPlacement,
    Map<String, dynamic>? firstParams,
    Map<String, dynamic>? secondParams,
    VoidCallback? onFirstPaywallPresented,
    VoidCallback? onSecondPaywallPresented,
    VoidCallback? onUserSubscribed,
    VoidCallback? onBothPaywallsDismissed,
  }) async {
    if (!_isConfigured) {
      debugPrint('[SuperwallService] Superwall not configured - cannot show chained paywalls');
      onBothPaywallsDismissed?.call();
      return;
    }

    debugPrint('[SuperwallService] Starting chained paywall sequence: $firstPlacement -> $secondPlacement');

    try {
      // Show first paywall
      onFirstPaywallPresented?.call();
      await Superwall.shared.registerPlacement(
        firstPlacement,
        params: firstParams?.cast<String, Object>(),
        feature: () async {
          // This callback is triggered when user completes the first paywall successfully
          debugPrint('[SuperwallService] First paywall completed - checking subscription status');
          
          // Check if user actually subscribed
          final hasSubscription = await hasActiveSubscription();
          if (hasSubscription) {
            debugPrint('[SuperwallService] User subscribed after first paywall');
            onUserSubscribed?.call();
            return;
          }

          // If no subscription, wait a moment then show second paywall
          debugPrint('[SuperwallService] First paywall dismissed without subscription, showing second paywall');
          await Future.delayed(const Duration(milliseconds: 800));
          
          // Show second paywall
          onSecondPaywallPresented?.call();
          await Superwall.shared.registerPlacement(
            secondPlacement,
            params: secondParams?.cast<String, Object>(),
            feature: () async {
              // Check subscription after second paywall
              debugPrint('[SuperwallService] Second paywall completed - checking subscription status');
              final hasSubscriptionAfterSecond = await hasActiveSubscription();
              if (hasSubscriptionAfterSecond) {
                debugPrint('[SuperwallService] User subscribed after second paywall');
                onUserSubscribed?.call();
              } else {
                debugPrint('[SuperwallService] User dismissed both paywalls without subscribing');
                onBothPaywallsDismissed?.call();
              }
            },
          );
        },
      );

      // Track the chained paywall sequence
      PostHogService.trackEvent('superwall_chained_paywalls_initiated', properties: {
        'first_placement': firstPlacement,
        'second_placement': secondPlacement,
        'first_params': firstParams?.toString() ?? 'none',
        'second_params': secondParams?.toString() ?? 'none',
      });

    } catch (e) {
      debugPrint('[SuperwallService] Error in chained paywall sequence: $e');
      onBothPaywallsDismissed?.call();
    }
  }

  /// Simple method to show a single paywall and then immediately show another one
  /// This is a more straightforward approach for your use case
  Future<void> showSequentialPaywalls({
    required BuildContext context,
    required String firstPlacement,
    required String secondPlacement,
    Map<String, dynamic>? params,
  }) async {
    if (!_isConfigured) {
      debugPrint('[SuperwallService] Superwall not configured');
      return;
    }

    debugPrint('[SuperwallService] Showing sequential paywalls: $firstPlacement then $secondPlacement');

    try {
      // Show first paywall
      await register(
        placement: firstPlacement,
        params: params,
        feature: () {
          debugPrint('[SuperwallService] First paywall dismissed, proceeding to second');
        },
      );

      // Wait a brief moment for the first paywall to fully dismiss
      await Future.delayed(const Duration(milliseconds: 500));

      // Show second paywall immediately
      await register(
        placement: secondPlacement,
        params: params,
        feature: () {
          debugPrint('[SuperwallService] Second paywall completed');
        },
      );

    } catch (e) {
      debugPrint('[SuperwallService] Error in sequential paywalls: $e');
    }
  }
  
  /// Register a placement for paywall presentation
  /// This replaces the need for PaywallManager.showPaywall()
  Future<void> register({
    required String placement,
    Map<String, dynamic>? params,
    VoidCallback? feature,
  }) async {
    if (!_isConfigured) {
      debugPrint('[SuperwallService] Superwall not configured - hard paywall will be enforced via benefits screen');
      // For hard paywall: DO NOT execute feature callback when Superwall fails
      // The UI will handle showing benefits screen instead
      return;
    }
    
    try {
      debugPrint('[SuperwallService] Registering placement: $placement');
      
      // Use actual Superwall.shared.registerPlacement() API
      await Superwall.shared.registerPlacement(
        placement,
        params: params?.cast<String, Object>(),
        feature: feature,
      );
      
      // Track the placement registration
      PostHogService.trackEvent('superwall_placement_registered', properties: {
        'placement': placement,
        'params': params?.toString() ?? 'none',
      });
      
    } catch (e) {
      debugPrint('[SuperwallService] Error registering placement $placement: $e');
      // For hard paywall: DO NOT fallback to executing feature on error
      // Let the UI handle showing benefits screen instead
    }
  }
  
  /// Check if user has active subscription via RevenueCat
  /// This replaces the subscription checks in PaywallGate
  Future<bool> hasActiveSubscription() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.isNotEmpty;
    } catch (e) {
      debugPrint('[SuperwallService] Error checking subscription status: $e');
      return false;
    }
  }
  
  /// Set user attributes for paywall personalization
  Future<void> setUserAttributes(Map<String, dynamic> attributes) async {
    if (!_isConfigured) return;
    
    try {
      await Superwall.shared.setUserAttributes(attributes.cast<String, Object>());
      debugPrint('[SuperwallService] Setting user attributes: $attributes');
    } catch (e) {
      debugPrint('[SuperwallService] Error setting user attributes: $e');
    }
  }
  
  /// Identify user for personalized paywalls
  Future<void> identify(String userId) async {
    if (!_isConfigured) return;
    
    try {
      await Superwall.shared.identify(userId);
      debugPrint('[SuperwallService] Identifying user: $userId');
    } catch (e) {
      debugPrint('[SuperwallService] Error identifying user: $e');
    }
  }
  
  /// Handle deep links for Superwall
  Future<bool> handleDeepLink(String url) async {
    if (!_isConfigured) return false;
    
    try {
      // TODO: Implement actual Superwall deep link handling
      // return await Superwall.shared.handleDeepLink(Uri.parse(url));
      debugPrint('[SuperwallService] Handling deep link: $url');
      return false;
    } catch (e) {
      debugPrint('[SuperwallService] Error handling deep link: $e');
      return false;
    }
  }
  
  /// Reset user data (for logout)
  Future<void> reset() async {
    if (!_isConfigured) return;
    
    try {
      await Superwall.shared.reset();
      debugPrint('[SuperwallService] Resetting Superwall user data');
    } catch (e) {
      debugPrint('[SuperwallService] Error resetting Superwall: $e');
    }
  }
  
  /// Sync subscription status from RevenueCat to Superwall
  void _syncSubscriptionStatusWithRevenueCat() {
    Purchases.addCustomerInfoUpdateListener((customerInfo) async {
      try {
        final hasActiveEntitlementOrSubscription = 
            customerInfo.entitlements.active.isNotEmpty;
        
        // TODO: Update Superwall subscription status when API is available
        // if (hasActiveEntitlementOrSubscription) {
        //   await Superwall.shared.setSubscriptionStatus(SubscriptionStatusActive(...));
        // } else {
        //   await Superwall.shared.setSubscriptionStatus(SubscriptionStatusInactive());
        // }
        
        debugPrint('[SuperwallService] Synced subscription status: $hasActiveEntitlementOrSubscription');
        
      } catch (e) {
        debugPrint('[SuperwallService] Error syncing subscription status: $e');
      }
    });
  }
  
  /// Show a placeholder paywall (temporary implementation)
  /// This can be used to replace PaywallManager.showPaywall() calls
  Future<void> showPaywall(BuildContext context, {String? placement}) async {
    debugPrint('[SuperwallService] Showing placeholder paywall for placement: $placement');
    
    // For now, show a simple dialog indicating Superwall integration is in progress
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Superwall Integration'),
        content: const Text('Superwall paywall will be implemented here. Currently showing placeholder.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ===============================================
  // Session Tracking Methods (migrated from PaywallManager)
  // ===============================================
  
  /// Increment app session count (replaces PaywallManager.incrementAppSession)
  void incrementAppSession() {
    try {
      final currentCount = StorageService().get(_appSessionCountKey, defaultValue: 0);
      StorageService().put(_appSessionCountKey, currentCount + 1);
      debugPrint('[SuperwallService] App session incremented to: ${currentCount + 1}');
    } catch (e) {
      debugPrint('[SuperwallService] Error incrementing app session count: $e');
    }
  }

  /// Check if it's appropriate to show the paywall (replaces PaywallManager.shouldShowPaywall)
  Future<bool> shouldShowPaywall() async {
    // Don't show paywall if user already has premium
    if (await hasActiveSubscription()) {
      return false;
    }

    try {
      // Get last shown timestamp
      final lastShownTimestamp = StorageService().get(_lastPaywallShownKey);

      // Check if minimum time has passed since last shown
      if (lastShownTimestamp != null) {
        final lastShown = DateTime.fromMillisecondsSinceEpoch(lastShownTimestamp);
        final timeSinceLastShown = DateTime.now().difference(lastShown);

        if (timeSinceLastShown < _minTimeBetweenPaywalls) {
          debugPrint('[SuperwallService] Too soon since last paywall (${timeSinceLastShown.inDays} days)');
          return false;
        }
      }

      // Check monthly show count
      final currentMonthYear = '${DateTime.now().month}-${DateTime.now().year}';
      final monthlyShowCountKey = '${_paywallShowCountKey}_$currentMonthYear';
      final monthlyShowCount = StorageService().get(monthlyShowCountKey, defaultValue: 0);

      if (monthlyShowCount >= _maxPaywallShowPerMonth) {
        debugPrint('[SuperwallService] Monthly paywall limit reached ($monthlyShowCount/$_maxPaywallShowPerMonth)');
        return false;
      }

      // Check app session count for showing on specific sessions
      final sessionCount = StorageService().get(_appSessionCountKey, defaultValue: 0);

      // Show on 3rd session, 7th session, and every 5th session thereafter
      final shouldShow = sessionCount == 3 ||
          sessionCount == 7 ||
          (sessionCount > 7 && (sessionCount - 7) % 5 == 0);

      debugPrint('[SuperwallService] Session count: $sessionCount, shouldShow: $shouldShow');
      return shouldShow;
    } catch (e) {
      debugPrint('[SuperwallService] Error checking if should show paywall: $e');
      return false;
    }
  }

  /// Record that a paywall was shown (replaces PaywallManager paywall tracking)
  void recordPaywallShown() {
    try {
      // Update last shown timestamp
      final now = DateTime.now().millisecondsSinceEpoch;
      StorageService().put(_lastPaywallShownKey, now);

      // Update monthly show count
      final currentMonthYear = '${DateTime.now().month}-${DateTime.now().year}';
      final monthlyShowCountKey = '${_paywallShowCountKey}_$currentMonthYear';
      final monthlyShowCount = StorageService().get(monthlyShowCountKey, defaultValue: 0);
      StorageService().put(monthlyShowCountKey, monthlyShowCount + 1);

      debugPrint('[SuperwallService] Paywall shown recorded. Monthly count: ${monthlyShowCount + 1}');
    } catch (e) {
      debugPrint('[SuperwallService] Error recording paywall shown: $e');
    }
  }

  /// Register with session awareness (enhanced version of register method)
  Future<void> registerWithSessionTracking({
    required String placement,
    Map<String, dynamic>? params,
    VoidCallback? feature,
    bool forceShow = false,
  }) async {
    // Check if we should show paywall based on session logic
    if (!forceShow && !await shouldShowPaywall()) {
      debugPrint('[SuperwallService] Session logic prevented paywall for placement: $placement');
      feature?.call(); // Execute feature without paywall
      return;
    }

    // Record that we're showing a paywall
    recordPaywallShown();

    // Register the placement
    await register(
      placement: placement,
      params: params,
      feature: feature,
    );
  }
} 