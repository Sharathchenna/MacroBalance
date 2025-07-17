import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/subscription_provider.dart';
import 'package:macrotracker/services/superwall_placements.dart';
import 'package:macrotracker/screens/benefits_screen.dart';

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
  bool _showingBenefitsScreen = false; // Track if showing benefits screen
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _registerPlacementWithSuperwall();
    });
    
    // Listen for subscription changes to automatically transition from benefits screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupSubscriptionListener();
    });
  }

  void _setupSubscriptionListener() {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    subscriptionProvider.addListener(_onSubscriptionChanged);
  }

  void _onSubscriptionChanged() {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    
    // If user now has subscription and we're showing benefits screen, transition to app
    if (subscriptionProvider.isProUser && _showingBenefitsScreen && mounted) {
      setState(() {
        _showingBenefitsScreen = false;
        _justCompletedPurchase = true;
      });
      
      // Give a moment for the UI to update, then clear the purchase flag
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _justCompletedPurchase = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    subscriptionProvider.removeListener(_onSubscriptionChanged);
    super.dispose();
  }

  Future<void> _registerPlacementWithSuperwall() async {
    if (_isCheckingSubscription) return;

    setState(() {
      _isCheckingSubscription = true;
    });

    try {
              // Check if user already has subscription first
        final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
        if (subscriptionProvider.isProUser) {
          // User already has subscription, no need to show paywall
          return;
        }

        // User doesn't have subscription, show benefits screen instead of automatic access
        setState(() {
          _showingBenefitsScreen = true;
        });
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
        
        // For hard paywall, only grant access if user actually has subscription
        // No fallback access granting
        
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
        // For hard paywall, no fallback access - only subscription grants access
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
        // For hard paywall: ONLY grant access if user has valid subscription
        if (subscriptionProvider.isProUser) {
          return widget.child;
        }

        // Show benefits screen for non-subscribers
        if (_showingBenefitsScreen) {
          return const BenefitsScreen();
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

        // If we reach here without a subscription and not showing benefits, 
        // start the registration process which will show benefits screen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_showingBenefitsScreen && !_isCheckingSubscription) {
            _registerPlacementWithSuperwall();
          }
        });

        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading...'),
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