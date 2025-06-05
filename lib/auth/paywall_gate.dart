import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/subscription_provider.dart';
import 'package:macrotracker/services/superwall_service.dart';

/// A hard paywall component that forces users to subscribe before they can access the app
/// This implements a strict paywall approach where no features are accessible without payment
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
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 24),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // CRITICAL: Only show child if user has active subscription
        if (subscriptionProvider.isProUser) {
          return child;
        }

        // NEVER show app content - always show blocking paywall screen
        return _BlockingPaywallScreen(
          subscriptionProvider: subscriptionProvider,
        );
      },
    );
  }
}

/// A completely blocking screen that prevents any app access without subscription
/// This screen cannot be dismissed and blocks all app functionality
class _BlockingPaywallScreen extends StatefulWidget {
  final SubscriptionProvider subscriptionProvider;

  const _BlockingPaywallScreen({
    required this.subscriptionProvider,
  });

  @override
  State<_BlockingPaywallScreen> createState() => _BlockingPaywallScreenState();
}

class _BlockingPaywallScreenState extends State<_BlockingPaywallScreen>
    with WidgetsBindingObserver {
  bool _paywallShown = false;
  bool _isProcessingPurchase = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start monitoring subscription status for real-time updates
    widget.subscriptionProvider.startHardPaywallMonitoring();
    _showSuperwallPaywall();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Stop monitoring subscription status
    widget.subscriptionProvider.stopHardPaywallMonitoring();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When app becomes active again, check subscription status and re-show paywall if needed
    if (state == AppLifecycleState.resumed) {
      debugPrint(
          'App resumed - checking subscription and re-enforcing paywall');
      _checkSubscriptionAndReshow();
    }
  }

  void _showSuperwallPaywall() async {
    if (_paywallShown || _isProcessingPurchase) return;

    try {
      final superwallService = SuperwallService();

      debugPrint('=== SHOWING SUPERWALL PAYWALL ===');

      // Initialize Superwall if not already done
      if (!superwallService.isInitialized) {
        debugPrint('Initializing Superwall...');
        await superwallService.initialize();
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      if (superwallService.isInitialized) {
        debugPrint('✅ Showing Superwall paywall');
        _paywallShown = true;

        // Show the paywall using Superwall
        await superwallService.showHardPaywall();

        debugPrint('Superwall paywall shown');
      } else {
        debugPrint('❌ Superwall failed to initialize');
      }
    } catch (e) {
      debugPrint('Error showing Superwall paywall: $e');
    }
  }

  void _checkSubscriptionAndReshow() async {
    try {
      await widget.subscriptionProvider.refreshSubscriptionStatus();

      if (!widget.subscriptionProvider.isProUser) {
        debugPrint('No active subscription detected - re-showing paywall');
        _paywallShown = false; // Reset flag to allow re-showing
        _showSuperwallPaywall();
      } else {
        debugPrint('Active subscription detected - paywall no longer needed');
      }
    } catch (e) {
      debugPrint('Error checking subscription status: $e');
      // On error, re-show paywall to be safe
      _showSuperwallPaywall();
    }
  }

  void _retryPaywall() {
    _paywallShown = false;
    _showSuperwallPaywall();
  }

  // // Override the back button to prevent users from escaping
  // Future<bool> _onWillPop() async {
  //   debugPrint('❌ Back button pressed - BLOCKING exit from paywall');
  //   return false; // Prevent back navigation
  // }

  @override
  Widget build(BuildContext context) {
    // This is a BLOCKING screen that prevents any app access
    // Users cannot dismiss it without subscribing
    return PopScope(
      canPop: false, // Block back button
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo or icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.restaurant_menu,
                    color: Theme.of(context).primaryColor,
                    size: 50,
                  ),
                ),

                const SizedBox(height: 32),

                // App name
                const Text(
                  'MacroBalance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                // Subscription required message
                const Text(
                  'Subscription Required',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 24),

                // Description
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Get personalized nutrition plans, macro tracking, and unlimited access to all premium features.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 16,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 40),

                // Primary action button
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  child: ElevatedButton(
                    onPressed: _isProcessingPurchase ? null : _retryPaywall,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: _isProcessingPurchase
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Processing...',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'View Subscription Options',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Security notice
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.security,
                        color: Colors.white54,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Secure payment • Cancel anytime • 7-day free trial',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Debug info (only in debug mode)
                if (widget.subscriptionProvider.isInitialized)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Subscription Status: ${widget.subscriptionProvider.isProUser ? "Active" : "Required"}',
                      style: const TextStyle(
                        color: Colors.white30,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
