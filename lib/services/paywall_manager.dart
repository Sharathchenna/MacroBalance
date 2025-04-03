import 'package:flutter/material.dart';
import 'package:macrotracker/screens/RevenueCat/custom_paywall_screen.dart';
import 'package:macrotracker/services/subscription_service.dart';
import 'package:macrotracker/services/storage_service.dart'; // Import StorageService

/// Class to manage paywall presentation throughout the app
class PaywallManager {
  static final PaywallManager _instance = PaywallManager._internal();
  factory PaywallManager() => _instance;

  PaywallManager._internal();

  final SubscriptionService _subscriptionService = SubscriptionService();

  // Keys for shared preferences
  static const String _lastPaywallShownKey = 'last_paywall_shown_timestamp';
  static const String _paywallShowCountKey = 'paywall_show_count';
  static const String _appSessionCountKey = 'app_session_count';

  // Time limits
  static const Duration _minTimeBetweenPaywalls = Duration(days: 3);
  static const int _maxPaywallShowPerMonth = 5;

  // Increment app session count (now synchronous)
  void incrementAppSession() {
    try {
      // Assuming StorageService is initialized
      final currentCount = StorageService().get(_appSessionCountKey, defaultValue: 0);
      StorageService().put(_appSessionCountKey, currentCount + 1);
    } catch (e) {
      debugPrint('Error incrementing app session count: $e');
    }
  }

  // Check if it's appropriate to show the paywall (now synchronous)
  bool shouldShowPaywall() {
    // Don't show paywall if user already has premium
    if (_subscriptionService.hasPremiumAccess()) {
      return false;
    }

    try {
      // Assuming StorageService is initialized

      // Get last shown timestamp
      final lastShownTimestamp = StorageService().get(_lastPaywallShownKey);
      final now = DateTime.now().millisecondsSinceEpoch;

      // Check if minimum time has passed since last shown
      if (lastShownTimestamp != null) {
        final lastShown =
            DateTime.fromMillisecondsSinceEpoch(lastShownTimestamp);
        final timeSinceLastShown = DateTime.now().difference(lastShown);

        if (timeSinceLastShown < _minTimeBetweenPaywalls) {
          return false;
        }
      }

      // Check monthly show count
      final currentMonthYear = '${DateTime.now().month}-${DateTime.now().year}';
      final monthlyShowCountKey = '${_paywallShowCountKey}_$currentMonthYear';
      final monthlyShowCount = StorageService().get(monthlyShowCountKey, defaultValue: 0);

      if (monthlyShowCount >= _maxPaywallShowPerMonth) {
        return false;
      }

      // Check app session count for showing on specific sessions
      final sessionCount = StorageService().get(_appSessionCountKey, defaultValue: 0);

      // Show on 3rd session, 7th session, and every 5th session thereafter
      return sessionCount == 3 ||
          sessionCount == 7 ||
          (sessionCount > 7 && (sessionCount - 7) % 5 == 0);
    } catch (e) {
      debugPrint('Error checking if should show paywall: $e');
      return false;
    }
  }

  // Show paywall and record the event
  Future<void> showPaywall(BuildContext context,
      {bool forcedShow = false}) async {
    if (!forcedShow && _subscriptionService.hasPremiumAccess()) {
      return;
    }

    try {
      // Update paywall shown timestamp and count (now synchronous)
      if (!forcedShow) {
        // Assuming StorageService is initialized

        // Update last shown timestamp
        final now = DateTime.now().millisecondsSinceEpoch;
        StorageService().put(_lastPaywallShownKey, now);

        // Update monthly show count
        final currentMonthYear =
            '${DateTime.now().month}-${DateTime.now().year}';
        final monthlyShowCountKey = '${_paywallShowCountKey}_$currentMonthYear';
        final monthlyShowCount = StorageService().get(monthlyShowCountKey, defaultValue: 0);
        StorageService().put(monthlyShowCountKey, monthlyShowCount + 1);
      }

      // Show the custom paywall
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: forcedShow,
        enableDrag: forcedShow,
        builder: (BuildContext context) {
          return CustomPaywallScreen(
            onDismiss: () => Navigator.of(context).pop(),
            allowDismissal: forcedShow,
          );
        },
      );
    } catch (e) {
      debugPrint('Error showing paywall: $e');
    }
  }
}
