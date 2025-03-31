import 'package:flutter/material.dart';
import 'package:macrotracker/screens/RevenueCat/custom_paywall_screen.dart';
import 'package:macrotracker/services/subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Increment app session count
  Future<void> incrementAppSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentCount = prefs.getInt(_appSessionCountKey) ?? 0;
      await prefs.setInt(_appSessionCountKey, currentCount + 1);
    } catch (e) {
      debugPrint('Error incrementing app session count: $e');
    }
  }

  // Check if it's appropriate to show the paywall
  Future<bool> shouldShowPaywall() async {
    // Don't show paywall if user already has premium
    if (_subscriptionService.hasPremiumAccess()) {
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // Get last shown timestamp
      final lastShownTimestamp = prefs.getInt(_lastPaywallShownKey);
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
      final monthlyShowCount = prefs.getInt(monthlyShowCountKey) ?? 0;

      if (monthlyShowCount >= _maxPaywallShowPerMonth) {
        return false;
      }

      // Check app session count for showing on specific sessions
      final sessionCount = prefs.getInt(_appSessionCountKey) ?? 0;

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
    // Don't show if user already has premium (unless forced)
    if (!forcedShow && _subscriptionService.hasPremiumAccess()) {
      return;
    }

    try {
      // Update paywall shown timestamp and count
      if (!forcedShow) {
        final prefs = await SharedPreferences.getInstance();

        // Update last shown timestamp
        final now = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt(_lastPaywallShownKey, now);

        // Update monthly show count
        final currentMonthYear =
            '${DateTime.now().month}-${DateTime.now().year}';
        final monthlyShowCountKey = '${_paywallShowCountKey}_$currentMonthYear';
        final monthlyShowCount = prefs.getInt(monthlyShowCountKey) ?? 0;
        await prefs.setInt(monthlyShowCountKey, monthlyShowCount + 1);
      }

      // Show the paywall
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: forcedShow,
        enableDrag: forcedShow,
        builder: (BuildContext context) {
          return CustomPaywallScreen(
            onDismiss: () => Navigator.of(context).pop(),
            allowDismissal: true,
          );
        },
      );
    } catch (e) {
      debugPrint('Error showing paywall: $e');
    }
  }
}
