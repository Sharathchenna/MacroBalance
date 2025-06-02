import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/subscription_provider.dart';
import 'package:macrotracker/services/superwall_service.dart';

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
        return _SuperwallPaywallGate(
          onDismiss: () async {
            // Check if subscription status changed
            final hasSubscription =
                await subscriptionProvider.refreshSubscriptionStatus();

            // If we now have a subscription, force a rebuild of this widget
            // This ensures we immediately show the app content after purchase
            if (hasSubscription) {
              debugPrint('Subscription detected - refreshing PaywallGate');
            }
          },
        );
      },
    );
  }
}

/// Internal widget that tries Superwall first, then falls back to custom paywall
class _SuperwallPaywallGate extends StatefulWidget {
  final VoidCallback onDismiss;

  const _SuperwallPaywallGate({
    required this.onDismiss,
  });

  @override
  State<_SuperwallPaywallGate> createState() => _SuperwallPaywallGateState();
}

class _SuperwallPaywallGateState extends State<_SuperwallPaywallGate> {
  @override
  void initState() {
    super.initState();
    _tryShowSuperwallPaywall();
  }

  void _tryShowSuperwallPaywall() {
    // Try to show Superwall paywall after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final superwallService = SuperwallService();

      // Add detailed debug logging
      debugPrint('=== PAYWALL GATE DEBUG ===');
      debugPrint('Superwall initialized: ${superwallService.isInitialized}');

      if (superwallService.isInitialized) {
        debugPrint('✅ PaywallGate: Using Superwall paywall for onboarding');
        await superwallService.showMainPaywall();
      } else {
        debugPrint(
            '❌ PaywallGate: Superwall not available, using custom paywall');
        debugPrint('This means either:');
        debugPrint('1. API key not set correctly');
        debugPrint('2. Superwall failed to initialize');
        debugPrint('3. Network connection issue');
      }
      debugPrint('=== END PAYWALL GATE DEBUG ===');
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show a simple loading screen while Superwall loads
    // Superwall will overlay on top when ready
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            CircularProgressIndicator(
              color: Colors.white,
            ),
            SizedBox(height: 24),
            Text(
              'Loading Premium Features...',
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
}
