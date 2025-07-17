# Superwall Migration Guide

This document outlines the step-by-step process to migrate from your custom paywall implementation to Superwall.

## Overview

Superwall is a paywall platform that allows you to remotely configure and A/B test paywalls without app store updates. This migration will replace your custom `CustomPaywallScreen` with Superwall's platform while maintaining RevenueCat for subscription management.

## Migration Phases

### Phase 1: Setup & Foundation ✅ COMPLETED

**What we've done:**
- ✅ Added `superwallkit_flutter: ^2.0.5` to `pubspec.yaml`
- ✅ Verified iOS deployment target (16.0 - meets Superwall's requirement of 14.0+)
- ✅ Verified Android SDK versions (minSdk 26, compileSdk 34)
- ✅ Added Superwall activities to `AndroidManifest.xml`
- ✅ Created `SuperwallService` with RevenueCat integration
- ✅ Added Superwall initialization to `main.dart`
- ✅ Created `SuperwallGate` and `SuperwallFeatureGate` components

### Phase 2: Configuration & Setup

**Next steps to complete:**

#### 2.1 Get Superwall API Key
1. Sign up for Superwall at [superwall.com](https://superwall.com)
2. Create a new app in the Superwall dashboard
3. Get your API key from the dashboard
4. Replace `YOUR_SUPERWALL_API_KEY` in `lib/services/superwall_service.dart`

#### 2.2 Install Dependencies
```bash
flutter pub get
cd ios && pod install
```

#### 2.3 Configure Superwall Dashboard
1. In Superwall dashboard, create placements:
   - `app_access` - For overall app access
   - `premium_features` - For premium feature access
   - `onboarding_complete` - For post-onboarding paywall
   - `food_tracking_limit` - For food entry limits

2. Create paywalls in the dashboard with your subscription products
3. Set up campaigns to connect placements to paywalls

### Phase 3: Gradual Migration

#### 3.1 Test Superwall Integration
1. Enable Superwall in `SuperwallGate`:
   ```dart
   // In lib/auth/superwall_gate.dart
   static const bool _enableSuperwallGate = true; // Change to true
   ```

2. Test with a simple placement:
   ```dart
   // In any screen where you want to test
   SuperwallService().register(
     placement: 'test_placement',
     feature: () {
       print('User has access!');
     },
   );
   ```

#### 3.2 Replace PaywallManager Calls
Find instances of `PaywallManager().showPaywall()` and replace with Superwall placements:

**Before:**
```dart
PaywallManager().showPaywall(context);
```

**After:**
```dart
SuperwallService().register(
  placement: 'feature_access',
  params: {'source': 'feature_button'},
  feature: () {
    // Execute the premium feature
  },
);
```

#### 3.3 Update Feature Gates
Replace custom paywall checks with Superwall feature gates:

**Before:**
```dart
if (subscriptionProvider.isProUser) {
  // Show premium feature
} else {
  // Show paywall
}
```

**After:**
```dart
SuperwallFeatureGate(
  placement: 'premium_feature',
  child: PremiumFeatureWidget(),
)
```

### Phase 4: Replace Custom Paywall Components

#### 4.1 Replace PaywallGate Usage
Gradually replace `PaywallGate` with `SuperwallGate`:

**Current usage in main.dart:**
```dart
Routes.home: (context) => const PaywallGate(child: Dashboard()),
```

**New usage:**
```dart
Routes.home: (context) => const SuperwallGate(
  placement: 'dashboard_access',
  child: Dashboard(),
),
```

#### 4.2 Replace CustomPaywallScreen Calls
Find all instances of `CustomPaywallScreen` and replace with Superwall placements:

**Files to update:**
- `lib/screens/onboarding/results_screen.dart`
- `lib/screens/accountdashboard.dart`
- `lib/screens/setting_screens/subscription_settings_screen.dart`

**Example replacement:**
```dart
// Before
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => CustomPaywallScreen(onDismiss: () {})),
);

// After
SuperwallService().register(
  placement: 'subscription_upsell',
  feature: () {
    // User subscribed, continue flow
  },
);
```

### Phase 5: Advanced Integration

#### 5.1 User Identification
Add user identification for personalized paywalls:

```dart
// When user logs in
SuperwallService().identify(userId);

// Set user attributes for targeting
SuperwallService().setUserAttributes({
  'user_type': 'free',
  'onboarding_completed': true,
  'last_active': DateTime.now().toIso8601String(),
});
```

#### 5.2 Analytics Integration
Superwall automatically tracks paywall events, but you can add custom tracking:

```dart
// The service already tracks placement registrations
// Additional custom events can be added as needed
```

#### 5.3 A/B Testing Setup
1. In Superwall dashboard, create experiments
2. Set up audience rules and targeting
3. Configure paywall variants
4. Monitor performance metrics

### Phase 6: Clean Up Legacy Code

#### 6.1 Remove Custom Paywall Files
Once migration is complete and tested, remove:
- `lib/screens/RevenueCat/custom_paywall_screen.dart`
- `lib/services/paywall_manager.dart`
- `lib/auth/paywall_gate.dart` (keep as backup initially)

#### 6.2 Update Dependencies
Remove unused dependencies from `pubspec.yaml`:
- Any custom paywall-specific packages (if any)

#### 6.3 Clean Up Routes
Remove custom paywall routes from app routes.

## Testing Strategy

### 6.1 Local Testing
1. Test with Superwall's sandbox environment
2. Verify paywall presentation and dismissal
3. Test subscription flow with RevenueCat
4. Validate analytics events

### 6.2 Staged Rollout
1. Release to internal testers first
2. Monitor Superwall dashboard for errors
3. A/B test against current paywall (if possible)
4. Gradual rollout to production users

## Key Configuration Files

### SuperwallService API Key
File: `lib/services/superwall_service.dart`
```dart
static const String _apiKey = 'YOUR_ACTUAL_SUPERWALL_API_KEY';
```

### Enable/Disable SuperwallGate
File: `lib/auth/superwall_gate.dart`
```dart
static const bool _enableSuperwallGate = true; // Set to true when ready
```

## Superwall Dashboard Setup

### Required Placements
Create these placements in your Superwall dashboard:

1. **app_access** - Controls overall app access
2. **premium_features** - For premium feature gates
3. **onboarding_complete** - Post-onboarding paywall
4. **food_tracking_limit** - When user hits free tier limits
5. **subscription_settings** - From settings screen
6. **dashboard_access** - Dashboard entry point

### Campaign Rules
Set up campaigns to show paywalls based on:
- User subscription status
- Number of app sessions
- Feature usage count
- User attributes (free vs paid)

## Migration Checklist

- [ ] Phase 1: Setup & Foundation (✅ COMPLETED)
- [ ] Get Superwall API key and update service
- [ ] Install dependencies (`flutter pub get`, `pod install`)
- [ ] Configure Superwall dashboard (placements, paywalls, campaigns)
- [ ] Enable SuperwallGate and test basic integration
- [ ] Replace PaywallManager calls with Superwall placements
- [ ] Update feature gates to use SuperwallFeatureGate
- [ ] Replace PaywallGate with SuperwallGate in routes
- [ ] Replace CustomPaywallScreen calls with placements
- [ ] Add user identification and attributes
- [ ] Test thoroughly in sandbox environment
- [ ] Stage rollout to production
- [ ] Monitor metrics and performance
- [ ] Clean up legacy paywall code

## Rollback Strategy

If issues arise during migration:

1. **Immediate rollback**: Set `_enableSuperwallGate = false`
2. **Partial rollback**: Keep SuperwallService but use custom paywall as fallback
3. **Complete rollback**: Revert to previous git commit

## Support & Resources

- [Superwall Documentation](https://superwall.com/docs)
- [Flutter SDK Documentation](https://superwall.com/docs/installation-via-pubspec)
- [RevenueCat Integration](https://superwall.com/docs/using-revenuecat)
- Your Superwall dashboard for configuration and analytics

## Next Steps

1. **Complete Phase 2**: Get API key and configure dashboard
2. **Test basic integration**: Enable SuperwallGate and test simple placement
3. **Gradual migration**: Replace components one by one
4. **Full testing**: Comprehensive testing before production rollout

This migration provides several benefits:
- Remote paywall configuration without app updates
- A/B testing capabilities
- Better analytics and insights
- Reduced client-side paywall code maintenance
- Professional paywall templates and optimization 