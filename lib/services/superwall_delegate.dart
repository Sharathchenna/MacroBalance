import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';

/// Custom SuperwallDelegate implementation to handle custom paywall actions
/// Extends the official SuperwallDelegate to handle custom actions from paywalls
class CustomSuperwallDelegate extends SuperwallDelegate {
  // Prevent duplicate calls by tracking the last action time
  DateTime? _lastRedeemActionTime;
  static const Duration _debounceDelay = Duration(seconds: 2);
  /// Override the official SuperwallDelegate method to handle custom paywall actions
  @override
  void handleCustomPaywallAction(String name) {
    debugPrint('[SuperwallDelegate] Received custom paywall action: $name');
    
    switch (name.toLowerCase()) {
      case 'redeem':
        _handleRedeemAction();
        break;
      case 'restore':
        _handleRestoreAction();
        break;
      default:
        debugPrint('[SuperwallDelegate] Unknown custom paywall action: $name');
    }
  }

  // Required abstract method implementations (minimal implementations)
  @override
  void didDismissPaywall(PaywallInfo paywallInfo) {
    debugPrint('[SuperwallDelegate] Paywall dismissed');
  }

  @override
  void didPresentPaywall(PaywallInfo paywallInfo) {
    debugPrint('[SuperwallDelegate] Paywall presented');
  }

  @override
  void handleLog(String level, String scope, String? message, Map<dynamic, dynamic>? info, String? error) {
    // Optional: implement custom logging if needed
  }

  @override
  void handleSuperwallDeepLink(Uri url, List<String> pathComponents, Map<String, String> queryItems) {
    debugPrint('[SuperwallDelegate] Deep link received: $url');
  }

  @override
  void handleSuperwallEvent(SuperwallEventInfo eventInfo) {
    debugPrint('[SuperwallDelegate] Superwall event: ${eventInfo.event}');
  }

  @override
  void paywallWillOpenDeepLink(Uri url) {
    debugPrint('[SuperwallDelegate] Paywall will open deep link: $url');
  }

  @override
  void paywallWillOpenURL(Uri url) {
    debugPrint('[SuperwallDelegate] Paywall will open URL: $url');
  }

  @override
  void subscriptionStatusDidChange(SubscriptionStatus status) {
    debugPrint('[SuperwallDelegate] Subscription status changed: $status');
  }

  @override
  void willDismissPaywall(PaywallInfo paywallInfo) {
    debugPrint('[SuperwallDelegate] Paywall will dismiss');
  }

  @override
  void willPresentPaywall(PaywallInfo paywallInfo) {
    debugPrint('[SuperwallDelegate] Paywall will present');
  }

  /// Handle the 'redeem' custom action by opening App Store redeem page
  /// Uses native redemption sheet on iOS for better UX, with URL fallback
  void _handleRedeemAction() {
    // Check for duplicate calls within debounce period
    final now = DateTime.now();
    if (_lastRedeemActionTime != null && 
        now.difference(_lastRedeemActionTime!) < _debounceDelay) {
      debugPrint('[SuperwallDelegate] Redeem action ignored - too soon after last call (${now.difference(_lastRedeemActionTime!).inMilliseconds}ms ago)');
      return;
    }
    
    // Update last action time
    _lastRedeemActionTime = now;
    
    debugPrint('[SuperwallDelegate] Opening App Store redeem page...');
    
    if (Platform.isIOS) {
      _presentNativeIOSRedemptionSheet();
    } else if (Platform.isAndroid) {
      _openAndroidRedeemPage();
    } else {
      debugPrint('[SuperwallDelegate] Redeem action not supported on this platform');
    }
  }

  /// Present native iOS App Store redemption sheet
  Future<void> _presentNativeIOSRedemptionSheet() async {
    try {
      debugPrint('[SuperwallDelegate] Presenting native iOS redemption sheet...');
      
      // Get the iOS platform addition for in-app purchase
      InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
          InAppPurchase.instance.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      
      // Present the native redemption sheet
      await iosPlatformAddition.presentCodeRedemptionSheet();
      
      debugPrint('[SuperwallDelegate] Native iOS redemption sheet presented successfully');
    } catch (e) {
      debugPrint('[SuperwallDelegate] Native redemption sheet failed: $e');
      debugPrint('[SuperwallDelegate] Falling back to URL-based redemption...');
      
      // Fallback to URL-based redemption
      _openIOSRedeemPageViaURL();
    }
  }

  /// Open iOS App Store redeem page using URL scheme (fallback method)
  void _openIOSRedeemPageViaURL() async {
    try {
      const String redeemUrl = 'itms-apps://apps.apple.com/account/balance/redeem';
      final Uri uri = Uri.parse(redeemUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('[SuperwallDelegate] Successfully opened iOS App Store redeem page via URL');
      } else {
        debugPrint('[SuperwallDelegate] Could not launch iOS App Store redeem page via URL');
      }
    } catch (e) {
      debugPrint('[SuperwallDelegate] Error opening iOS App Store redeem page via URL: $e');
    }
  }

  /// Open Android Play Store redeem page
  void _openAndroidRedeemPage() async {
    try {
      const String redeemUrl = 'https://play.google.com/store/gift';
      final Uri uri = Uri.parse(redeemUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('[SuperwallDelegate] Successfully opened Android Play Store redeem page');
      } else {
        debugPrint('[SuperwallDelegate] Could not launch Android Play Store redeem page');
      }
    } catch (e) {
      debugPrint('[SuperwallDelegate] Error opening Android Play Store redeem page: $e');
    }
  }

  /// Handle the 'restore' custom action by restoring purchases via RevenueCat
  void _handleRestoreAction() {
    debugPrint('[SuperwallDelegate] Handling restore purchases action...');
    _restorePurchases();
  }

  /// Restore purchases via RevenueCat
  Future<void> _restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      
      if (customerInfo.entitlements.active.isNotEmpty) {
        debugPrint('[SuperwallDelegate] Purchases restored successfully');
      } else {
        debugPrint('[SuperwallDelegate] No previous purchases found to restore');
      }
    } catch (e) {
      debugPrint('[SuperwallDelegate] Error restoring purchases: $e');
    }
  }
}