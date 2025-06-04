import 'package:flutter/material.dart';
import 'package:macrotracker/services/subscription_service.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/services/superwall_service.dart';

/// Simplified paywall manager that only uses Superwall
class PaywallManager {
  static final PaywallManager _instance = PaywallManager._internal();
  factory PaywallManager() => _instance;

  PaywallManager._internal();

  final SubscriptionService _subscriptionService = SubscriptionService();

  // Keys for shared preferences
  static const String _appSessionCountKey = 'app_session_count';

  // Increment app session count
  void incrementAppSession() {
    try {
      final currentCount =
          StorageService().get(_appSessionCountKey, defaultValue: 0);
      StorageService().put(_appSessionCountKey, currentCount + 1);
      debugPrint('App session count: ${currentCount + 1}');
    } catch (e) {
      debugPrint('Error incrementing app session count: $e');
    }
  }

  // Check if user has premium access
  bool hasPremiumAccess() {
    return _subscriptionService.hasPremiumAccess();
  }

  // Show Superwall paywall
  Future<void> showPaywall({bool isHardPaywall = false}) async {
    // Don't show paywall if user already has premium
    if (_subscriptionService.hasPremiumAccess()) {
      debugPrint('User already has premium access - skipping paywall');
      return;
    }

    try {
      final superwallService = SuperwallService();

      if (!superwallService.isInitialized) {
        await superwallService.initialize();
      }

      if (isHardPaywall) {
        debugPrint('Showing hard Superwall paywall');
        await superwallService.showHardPaywall();
      } else {
        debugPrint('Showing regular Superwall paywall');
        await superwallService.showMainPaywall();
      }
    } catch (e) {
      debugPrint('Error showing Superwall paywall: $e');
      throw e;
    }
  }

  // Get app session count for analytics
  int getAppSessionCount() {
    try {
      return StorageService().get(_appSessionCountKey, defaultValue: 0);
    } catch (e) {
      debugPrint('Error getting app session count: $e');
      return 0;
    }
  }
}
