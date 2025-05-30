import 'dart:async';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

enum SubscriptionStatus {
  unknown,
  free,
  premium,
}

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;

  SubscriptionService._internal();

  // Stream to broadcast subscription status changes
  final _subscriptionStatusController =
      StreamController<SubscriptionStatus>.broadcast();
  Stream<SubscriptionStatus> get subscriptionStatusStream =>
      _subscriptionStatusController.stream;

  SubscriptionStatus _currentStatus = SubscriptionStatus.unknown;
  SubscriptionStatus get currentStatus => _currentStatus;

  CustomerInfo? _customerInfo;
  CustomerInfo? get customerInfo => _customerInfo;

  // Entitlement ID that grants premium access
  static const String _premiumEntitlementId = 'pro';

  // Initialize the service and set up listeners
  Future<void> initialize() async {
    try {
      // First check if RevenueCat is configured by testing a simple call
      await Purchases.getCustomerInfo();

      // Set up listener for customer info updates
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _processCustomerInfo(customerInfo);
      });

      // Get current customer info
      final customerInfo = await Purchases.getCustomerInfo();
      _processCustomerInfo(customerInfo);
    } catch (e) {
      debugPrint('Error initializing subscription service: $e');
      debugPrint(
          'RevenueCat may not be configured yet. Will retry when needed.');
      _updateStatus(SubscriptionStatus.free);
    }
  }

  // Process customer info and update subscription status
  void _processCustomerInfo(CustomerInfo info) {
    _customerInfo = info;
    final hasPremium = _checkIfHasPremium(info);
    _updateStatus(
        hasPremium ? SubscriptionStatus.premium : SubscriptionStatus.free);
    debugPrint('Subscription status updated: ${_currentStatus.name}');
  }

  // Check if customer has premium access
  bool _checkIfHasPremium(CustomerInfo info) {
    // Check all active entitlements for any that might grant premium access
    final entitlements = info.entitlements.active.keys;

    // Look for any entitlement containing 'pro' in case there are different naming conventions
    return entitlements.any((key) =>
        key.toLowerCase() == _premiumEntitlementId ||
        key.toLowerCase().contains(_premiumEntitlementId));
  }

  // Update subscription status and notify listeners
  void _updateStatus(SubscriptionStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _subscriptionStatusController.add(status);
    }
  }

  // Check if user has premium access
  bool hasPremiumAccess() {
    return _currentStatus == SubscriptionStatus.premium;
  }

  // Force refresh customer info
  Future<void> refreshPurchaserInfo() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _processCustomerInfo(customerInfo);
    } catch (e) {
      debugPrint('Error refreshing purchaser info: $e');
      // If RevenueCat isn't configured, maintain current status
    }
  }

  // Restore purchases
  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      _processCustomerInfo(customerInfo);
      return hasPremiumAccess();
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
      // Return current status if restore fails
      return hasPremiumAccess();
    }
  }

  // Get offerings
  Future<Offering?> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current;
    } catch (e) {
      debugPrint('Error getting offerings: $e');
      return null;
    }
  }

  // Purchase a package
  Future<bool> purchasePackage(Package package) async {
    try {
      final purchaseResult = await Purchases.purchasePackage(package);
      _processCustomerInfo(purchaseResult);
      return hasPremiumAccess();
    } catch (e) {
      debugPrint('Error purchasing package: $e');
      rethrow; // Rethrow to allow caller to handle PurchasesErrorCode
    }
  }

  // Clean up resources
  void dispose() {
    _subscriptionStatusController.close();
  }
}
