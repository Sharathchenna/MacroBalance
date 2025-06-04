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

        // If the user has a subscription, let them access the app
        if (subscriptionProvider.isProUser) {
          return child;
        }

        // If the user doesn't have a subscription, show the hard paywall
        return _HardSuperwallPaywall(
          onSubscriptionDetected: () {
            // Refresh subscription status when purchase is detected
            subscriptionProvider.refreshSubscriptionStatus();
          },
        );
      },
    );
  }
}

/// Internal widget that shows only Superwall paywall - no fallback, no dismiss option
class _HardSuperwallPaywall extends StatefulWidget {
  final VoidCallback onSubscriptionDetected;

  const _HardSuperwallPaywall({
    required this.onSubscriptionDetected,
  });

  @override
  State<_HardSuperwallPaywall> createState() => _HardSuperwallPaywallState();
}

class _HardSuperwallPaywallState extends State<_HardSuperwallPaywall>
    with WidgetsBindingObserver {
  bool _superwallShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAndShowSuperwall();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When app becomes active again, check subscription status
    // This handles the case where user completes purchase outside the app
    if (state == AppLifecycleState.resumed) {
      debugPrint('App resumed - checking subscription status');
      widget.onSubscriptionDetected();
    }
  }

  void _initializeAndShowSuperwall() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final superwallService = SuperwallService();

        debugPrint('=== HARD PAYWALL GATE ===');
        debugPrint('Initializing Superwall for hard paywall...');

        // Initialize Superwall if not already done
        if (!superwallService.isInitialized) {
          await superwallService.initialize();
        }

        if (superwallService.isInitialized && !_superwallShown) {
          debugPrint('✅ Showing Superwall hard paywall');
          _superwallShown = true;

          // Show the hard paywall - use app_install placement for first-time users
          await superwallService.showHardPaywall();
        } else {
          debugPrint('❌ Superwall failed to initialize');
          // Show error message instead of fallback
          _showSuperwallError();
        }
      } catch (e) {
        debugPrint('Error in hard paywall: $e');
        _showSuperwallError();
      }
    });
  }

  void _showSuperwallError() {
    if (mounted) {
      setState(() {
        // Will show error UI in build method
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo or icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  color: Colors.white,
                  size: 40,
                ),
              ),

              const SizedBox(height: 32),

              // App name
              const Text(
                'MacroBalance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              // Loading message
              const Text(
                'Loading premium features...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 32),

              const CircularProgressIndicator(
                color: Colors.white,
              ),

              const SizedBox(height: 32),

              // Small disclaimer
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'A subscription is required to use this app',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
