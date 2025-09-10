# Superwall Chained Paywalls Implementation

## Overview

This document explains how to implement chained paywalls in your MacroTracker app using Superwall. Chained paywalls allow you to show a second paywall immediately after the first one is dismissed (without purchase), giving users another chance to subscribe.

## How It Works

The implementation works by:
1. Showing the first paywall
2. When the first paywall is dismissed (without purchase), automatically showing a second paywall
3. Only proceeding if the user actually subscribes, not just dismisses the paywall

## Basic Usage

### Simple Chained Paywalls

```dart
import 'package:macrotracker/services/superwall_placements.dart';

// In any widget where you want to trigger chained paywalls
void _showChainedPaywalls() {
  SuperwallPlacements.showChainedPaywalls(
    context: context,
    onUserSubscribed: () {
      // User successfully subscribed - proceed to premium content
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardScreen()),
      );
    },
    onBothDismissed: () {
      // User dismissed both paywalls without subscribing
      // Show benefits screen or other fallback
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BenefitsScreen()),
      );
    },
  );
}
```

### Custom Placement Names

```dart
void _showCustomChainedPaywalls() {
  SuperwallPlacements.showChainedPaywalls(
    context: context,
    firstPlacementName: 'premium_upsell',
    secondPlacementName: 'last_chance_offer',
    firstParams: {
      'source': 'feature_gate',
      'feature': 'ai_food_recognition',
    },
    secondParams: {
      'source': 'fallback_upsell',
      'discount': 'last_chance_50_off',
    },
    onUserSubscribed: () {
      // Handle subscription success
    },
    onBothDismissed: () {
      // Handle both paywalls dismissed
    },
  );
}
```

### Sequential Paywalls (Immediate)

For a more direct approach where you want the second paywall to show immediately:

```dart
void _showSequentialPaywalls() {
  SuperwallPlacements.showSequentialPaywalls(
    context: context,
    firstPlacementName: 'main_paywall',
    secondPlacementName: 'backup_paywall',
    params: {
      'campaign': 'aggressive_conversion',
    },
  );
}
```

## Integration Examples

### 1. Onboarding Flow with Chained Paywalls

```dart
// In your onboarding results screen
void _showOnboardingWithChainedPaywalls() {
  SuperwallPlacements.showOnboardingChainedPaywalls(
    context: context,
    onPremiumUser: () {
      // User subscribed - go to dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => Dashboard()),
      );
    },
    onFreeUser: () {
      // User didn't subscribe - show benefits screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BenefitsScreen()),
      );
    },
  );
}
```

### 2. Feature Gate with Chained Paywalls

```dart
// When user tries to access premium feature
void _tryAccessPremiumFeature() async {
  final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
  
  if (subscriptionProvider.isProUser) {
    // User already has subscription
    _accessPremiumFeature();
    return;
  }
  
  // Show chained paywalls
  SuperwallPlacements.showChainedPaywalls(
    context: context,
    firstPlacementName: 'feature_gate_paywall',
    secondPlacementName: 'feature_gate_fallback',
    firstParams: {
      'blocked_feature': 'ai_food_analysis',
      'source': 'feature_gate',
    },
    onUserSubscribed: () {
      // User subscribed - grant access to feature
      _accessPremiumFeature();
    },
    onBothDismissed: () {
      // User dismissed both - show alternative
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This feature requires a premium subscription'),
        ),
      );
    },
  );
}

void _accessPremiumFeature() {
  // Implement your premium feature logic here
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => PremiumFeatureScreen()),
  );
}
```

### 3. Benefits Screen Integration

```dart
// In your BenefitsScreen widget
class BenefitsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ... benefits content ...
          
          ElevatedButton(
            onPressed: () => _startChainedPaywallFlow(),
            child: Text('Start Free Trial'),
          ),
        ],
      ),
    );
  }
  
  void _startChainedPaywallFlow() {
    SuperwallPlacements.showChainedPaywalls(
      context: context,
      firstPlacementName: 'benefits_screen_primary',
      secondPlacementName: 'benefits_screen_secondary',
      onUserSubscribed: () {
        // Navigate to dashboard after subscription
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Dashboard()),
        );
      },
      onBothDismissed: () {
        // User still on benefits screen - no navigation needed
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Premium features are waiting for you!'),
          ),
        );
      },
    );
  }
}
```

## Superwall Dashboard Configuration

To use chained paywalls, you need to set up the placements in your Superwall dashboard:

### Required Placements

1. **first_paywall** (or your custom name)
   - Primary paywall design
   - Main subscription offers
   - Standard call-to-action

2. **second_paywall** (or your custom name)
   - Secondary paywall design
   - Maybe different messaging ("Last chance!")
   - Possibly different pricing/offers

3. **fallback_paywall** (optional)
   - Alternative design for specific scenarios
   - Could have special discounts

### Campaign Setup

1. Create campaigns for each placement
2. Set audience rules (show to non-subscribers)
3. Configure paywall designs
4. Test the flow in sandbox mode

## Advanced Customization

### Custom Parameters

You can pass custom parameters to track different scenarios:

```dart
SuperwallPlacements.showChainedPaywalls(
  context: context,
  firstParams: {
    'source': 'dashboard_cta',
    'user_segment': 'power_user',
    'feature_blocked': 'macro_insights',
    'session_number': '5',
  },
  secondParams: {
    'source': 'fallback_offer',
    'discount_code': 'SAVE50',
    'urgency': 'limited_time',
  },
  // ... callbacks
);
```

### Error Handling

The implementation includes built-in error handling:

```dart
// The methods will automatically handle:
// - Superwall not configured
// - Network errors
// - Invalid placements
// - Subscription check failures
```

## Testing Your Implementation

### 1. Test with Debug Logs

Enable debug logging to see the flow:

```
[SuperwallPlacements] Initiating chained paywall sequence
[SuperwallService] Starting chained paywall sequence: first_paywall -> second_paywall
[SuperwallService] First paywall completed - checking subscription status
[SuperwallService] First paywall dismissed without subscription, showing second paywall
[SuperwallService] Second paywall completed - checking subscription status
```

### 2. Test Different Scenarios

- User subscribes on first paywall → should not show second
- User dismisses first paywall → should show second paywall
- User subscribes on second paywall → should call onUserSubscribed
- User dismisses both → should call onBothDismissed

### 3. Subscription Status Verification

The system automatically checks actual subscription status via RevenueCat, not just paywall completion.

## Best Practices

1. **Don't Overuse**: Chained paywalls can be aggressive. Use sparingly.

2. **Different Messaging**: Make sure your second paywall has different messaging/design.

3. **Track Performance**: Monitor conversion rates for both paywalls.

4. **Respect User Choice**: After two dismissals, don't immediately show more paywalls.

5. **Test Thoroughly**: Always test the full flow before releasing.

## Analytics and Tracking

The implementation automatically tracks:
- `superwall_chained_paywalls_initiated`
- `superwall_placement_registered`

You can add custom tracking in the callbacks:

```dart
onUserSubscribed: () {
  PostHogService.trackEvent('chained_paywall_conversion', properties: {
    'conversion_point': 'second_paywall',
    'user_segment': 'free_user',
  });
},
onBothDismissed: () {
  PostHogService.trackEvent('chained_paywall_dismissed', properties: {
    'dismissal_count': 2,
    'user_segment': 'resistant_user',
  });
},
```

## Troubleshooting

### Common Issues

1. **Second paywall not showing**: Check that placements exist in Superwall dashboard
2. **Subscription not detected**: Verify RevenueCat integration is working
3. **Immediate dismissal**: Check for conflicting UI or navigation

### Debug Steps

1. Check console logs for Superwall service messages
2. Verify placement names match dashboard configuration
3. Test subscription status checking manually
4. Ensure context is still mounted for UI updates 