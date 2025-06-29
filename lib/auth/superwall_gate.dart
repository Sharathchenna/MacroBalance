import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/subscription_provider.dart';
import 'package:macrotracker/services/superwall_placements.dart';

/// A component that enforces subscriptions using Superwall
/// This replaces the custom PaywallGate with Superwall-powered paywalls
class SuperwallGate extends StatelessWidget {
  final Widget child;
  final String? placement; // Superwall placement name for this gate

  // Configuration flag to enable/disable Superwall gate
  static const bool _enableSuperwallGate = true; // ✅ ENABLED: Ready for migration testing

  const SuperwallGate({
    super.key,
    required this.child,
    this.placement = 'app_access', // Default placement for app access
  });

  @override
  Widget build(BuildContext context) {
    // If Superwall gate is disabled, show child directly (migration safety)
    if (!_enableSuperwallGate) {
      return child;
    }

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

        // If the user doesn't have a subscription, register the placement with Superwall
        return _SuperwallGateContent(
          placement: placement!,
          onSubscriptionChanged: () async {
            // Refresh subscription status when user completes paywall flow
            await subscriptionProvider.refreshSubscriptionStatus();
          },
          child: child,
        );
      },
    );
  }
}

/// Internal widget that handles the Superwall placement registration
class _SuperwallGateContent extends StatefulWidget {
  final String placement;
  final Future<void> Function() onSubscriptionChanged;
  final Widget child;

  const _SuperwallGateContent({
    required this.placement,
    required this.onSubscriptionChanged,
    required this.child,
  });

  @override
  State<_SuperwallGateContent> createState() => _SuperwallGateContentState();
}

class _SuperwallGateContentState extends State<_SuperwallGateContent> {
  bool _isCheckingSubscription = false;
  bool _justCompletedPurchase = false;
  bool _accessGrantedByPaywall = false; // Track if access was granted by Superwall
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _registerPlacementWithSuperwall();
    });
  }

  Future<void> _registerPlacementWithSuperwall() async {
    if (_isCheckingSubscription) return;

    setState(() {
      _isCheckingSubscription = true;
    });

    try {
      // Use the new placement helper for app access gate
      final hasAccess = await SuperwallPlacements.registerAppAccessGate(
        onGrantAccess: () async {
          debugPrint('[SuperwallGate] User gained access through paywall');
          
          if (mounted) {
            setState(() {
              _accessGrantedByPaywall = true;
              _justCompletedPurchase = true;
            });
          }
          
          // Add delay before checking subscription status to allow RevenueCat to update
          await Future.delayed(const Duration(seconds: 2));
          
          await _refreshSubscriptionWithRetry();
        },
      );

      // If user already has access, show the child directly
      if (hasAccess && mounted) {
        setState(() {
          // User has access, the widget will rebuild and show child
        });
      }
    } catch (e) {
      debugPrint('[SuperwallGate] Error registering placement: $e');
      // Show fallback content on error
      _showFallbackPaywall();
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingSubscription = false;
        });
      }
    }
  }

  /// Refresh subscription status with retry logic
  Future<void> _refreshSubscriptionWithRetry() async {
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        debugPrint('[SuperwallGate] Refreshing subscription status (attempt ${attempt + 1}/${_maxRetries + 1})');
        
        await widget.onSubscriptionChanged();
        
        // Give a moment for the subscription provider to update
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Check if user now has access after refresh
        final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
        
        if (subscriptionProvider.isProUser) {
          debugPrint('[SuperwallGate] Subscription status updated successfully');
          if (mounted) {
            setState(() {
              _justCompletedPurchase = false;
            });
          }
          return; // Success - exit retry loop
        }
        
        // If access was granted by Superwall (even without subscription), stop retrying
        if (_accessGrantedByPaywall) {
          debugPrint('[SuperwallGate] Access granted by Superwall, stopping retry attempts');
          if (mounted) {
            setState(() {
              _justCompletedPurchase = false;
            });
          }
          return; // Access granted - exit retry loop
        }
        
        // If still no access and we have more retries, wait and try again
        if (attempt < _maxRetries) {
          final delaySeconds = (attempt + 1) * 2; // 2s, 4s, 6s
          debugPrint('[SuperwallGate] Still no access, retrying in ${delaySeconds}s...');
          await Future.delayed(Duration(seconds: delaySeconds));
        }
        
      } catch (e) {
        debugPrint('[SuperwallGate] Error refreshing subscription status (attempt ${attempt + 1}): $e');
        
        if (attempt < _maxRetries) {
          await Future.delayed(Duration(seconds: (attempt + 1) * 2));
        }
      }
    }
    
    // If we get here, all retries failed
    debugPrint('[SuperwallGate] Failed to refresh subscription status after ${_maxRetries + 1} attempts');
    if (mounted) {
      setState(() {
        _justCompletedPurchase = false;
        // Don't reset _accessGrantedByPaywall here - it should remain true if Superwall granted access
      });
    }
  }

  void _showFallbackPaywall() {
    // Show a simple message when Superwall is not available
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Subscription Required'),
        content: const Text(
          'A subscription is required to access this feature. '
          'Please check your subscription status or contact support.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await widget.onSubscriptionChanged(); // Trigger refresh
            },
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, _) {
        // Check subscription status OR if access was granted by Superwall
        if (subscriptionProvider.isProUser || _accessGrantedByPaywall) {
          return widget.child;
        }

        if (_isCheckingSubscription) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Checking subscription status...'),
                ],
              ),
            ),
          );
        }

        // If we just completed a purchase, show a different message
        if (_justCompletedPurchase) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing your purchase...'),
                ],
              ),
            ),
          );
        }

        // If we reach here without a subscription, show a loading state
        // The actual paywall should be handled by Superwall
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading paywall...'),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A simplified version of SuperwallGate for feature-level gating
/// Use this for individual features rather than app-level access
class SuperwallFeatureGate extends StatelessWidget {
  final Widget child;
  final Widget? lockedChild; // Widget to show when feature is locked
  final String placement;
  final Map<String, dynamic>? params;

  const SuperwallFeatureGate({
    super.key,
    required this.child,
    required this.placement,
    this.lockedChild,
    this.params,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, _) {
        if (subscriptionProvider.isProUser) {
          return child;
        }

        // Show locked state or register placement
        return GestureDetector(
          onTap: () => _registerFeaturePlacement(context),
          child: lockedChild ?? _buildDefaultLockedWidget(),
        );
      },
    );
  }

  Widget _buildDefaultLockedWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock, color: Colors.grey),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Premium feature - Tap to upgrade',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _registerFeaturePlacement(BuildContext context) async {
    try {
      // Use the new placement helper for premium feature gate
      await SuperwallPlacements.registerPremiumFeatureGate(
        featureName: placement,
        onGrantAccess: () {
          debugPrint('[SuperwallFeatureGate] User gained access to feature: $placement');
          // Feature access will be handled by the parent widget listening to subscription changes
        },
        additionalParams: {
          'feature_type': 'feature_gate',
          ...?params,
        },
      );
    } catch (e) {
      debugPrint('[SuperwallFeatureGate] Error registering feature placement: $e');
      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load paywall. Please try again.'),
        ),
      );
    }
  }
} 