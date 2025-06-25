import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/subscription_provider.dart';
import 'package:macrotracker/screens/RevenueCat/custom_paywall_screen.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// A component that forces users to subscribe before they can access the app
/// This implements a hard paywall approach where no features are accessible without payment
class PaywallGate extends StatelessWidget {
  final Widget child;

  // TEMPORARY: Debug flag to disable paywall
  static const bool _DISABLE_PAYWALL_DEBUG = false;

  const PaywallGate({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // TEMPORARY: If debug flag is enabled, bypass paywall entirely
    if (_DISABLE_PAYWALL_DEBUG) {
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
