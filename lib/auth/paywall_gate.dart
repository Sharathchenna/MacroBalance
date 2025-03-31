import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/subscription_provider.dart';
import 'package:macrotracker/screens/RevenueCat/custom_paywall_screen.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// A component that forces users to subscribe before they can access the app
/// This implements a hard paywall approach where no features are accessible without payment
class PaywallGate extends StatelessWidget {
  final Widget child;

  const PaywallGate({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, _) {
        // If the provider is still initializing, show a loading screen
        if (!subscriptionProvider.isInitialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If the user has a subscription, let them access the app
        if (subscriptionProvider.isProUser) {
          return child;
        }

        // If the user doesn't have a subscription, show the paywall
        return CustomPaywallScreen(
          onDismiss: () async {
            // Check if subscription status changed
            final hasSubscription =
                await subscriptionProvider.refreshSubscriptionStatus();

            // If we now have a subscription, force a rebuild of this widget
            // This ensures we immediately show the app content after purchase
            if (hasSubscription) {
              print("Subscription detected - refreshing PaywallGate");
            }
          },
          allowDismissal: false, // Don't allow dismissal without subscribing
        );
      },
    );
  }
}

/// A hard paywall screen that forces users to subscribe
/// This is a fullscreen paywall with no option to skip or proceed without paying
class _HardPaywallScreen extends StatefulWidget {
  final VoidCallback onSubscriptionChanged;

  const _HardPaywallScreen({
    required this.onSubscriptionChanged,
  });

  @override
  _HardPaywallScreenState createState() => _HardPaywallScreenState();
}

class _HardPaywallScreenState extends State<_HardPaywallScreen>
    with WidgetsBindingObserver {
  Offering? _offering;
  bool _isLoading = true;
  bool _isDisposed = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchOffering();

    // Force an immediate check of subscription status on initialization
    _checkSubscriptionStatus();
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // When app resumes, check subscription status again
      if (!_isDisposed) {
        _checkSubscriptionStatus();
      }
    }
  }

  // Helper to check if user has Pro access, regardless of entitlement format
  bool _hasProEntitlement(CustomerInfo customerInfo) {
    final entitlements = customerInfo.entitlements.active.keys;

    // Check for any entitlement containing 'pro' in a case-insensitive way
    return entitlements.any((key) =>
        key.toLowerCase() == 'pro' ||
        key == 'Pro' ||
        key.toLowerCase().contains('pro'));
  }

  Future<void> _checkSubscriptionStatus() async {
    if (_isDisposed) return;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      print(
          "Initial subscription check: ${customerInfo.entitlements.active.keys}");

      if (_hasProEntitlement(customerInfo)) {
        print(
            "Subscription already active on paywall load - notifying PaywallGate");
        widget.onSubscriptionChanged();
      }
    } catch (e) {
      print("Error checking initial subscription status: $e");
    }
  }

  Future<void> _fetchOffering() async {
    if (_isDisposed) return;

    try {
      // Fetch the offering from RevenueCat
      final offerings = await Purchases.getOfferings();

      if (_isDisposed) return;

      if (offerings.current != null) {
        setState(() {
          _offering = offerings.current;
          _isLoading = false;
          _retryCount = 0; // Reset retry count on success
        });
      } else {
        setState(() {
          _isLoading = false;
          // Will show the error UI
        });
      }
    } catch (e) {
      if (_isDisposed) return;

      print("Error fetching offerings: $e");

      // Implement exponential backoff for retries
      if (_retryCount < _maxRetries) {
        _retryCount++;
        final delay = Duration(seconds: 1 << _retryCount); // 2, 4, 8 seconds
        print("Retry $_retryCount in ${delay.inSeconds} seconds");

        Future.delayed(delay, () {
          if (!_isDisposed) {
            _fetchOffering();
          }
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Separate method to print debug info
  void _printDebugInfo() {
    if (_isDisposed) return;

    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    // Fire and forget - we don't care about the completion
    subscriptionProvider.debugSubscriptionStatus();
  }

  // Helper method to force UI update
  Future<void> _forceSubscriptionRefresh() async {
    if (_isDisposed) return;

    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);

    // Print debug info in a fire-and-forget way
    _printDebugInfo();

    // First try normal refresh
    final hasSubscription =
        await subscriptionProvider.refreshSubscriptionStatus();
    if (hasSubscription) {
      print("Subscription detected - normal refresh successful");
      return;
    }

    if (_isDisposed) return;

    // If that doesn't work, try a double-check with delay
    await Future.delayed(const Duration(milliseconds: 300));
    final stillHasSubscription =
        await subscriptionProvider.refreshSubscriptionStatus();

    if (stillHasSubscription) {
      print("Double-confirmed subscription - UI should update");
      return;
    }

    if (_isDisposed) return;

    // If we still don't have a subscription but logs indicate we should,
    // try the nuclear option - complete reset
    print("Attempting subscription reset as last resort...");
    final resetResult = await subscriptionProvider.resetSubscriptionState();

    if (resetResult && mounted) {
      print("Subscription reset successful - subscription is now active");
      // No need to do anything else, the UI should update via the provider
    } else {
      print(
          "Warning: Reset failed or no subscription found. Manual intervention may be needed.");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show custom paywall
    return CustomPaywallScreen(
      onDismiss: _handleDismiss,
      allowDismissal: false, // Don't allow dismissal for hard paywall
    );
  }

  // Handle dismissal (this won't be called for hard paywall, but implemented for safety)
  void _handleDismiss() {
    if (!_isDisposed) {
      widget.onSubscriptionChanged();
    }
  }
}
