# Superwall Hard Paywall Setup

This document describes the hard paywall implementation using Superwall in MacroBalance.

## Overview

MacroBalance now uses a **hard paywall** approach where:
- Users MUST subscribe to access any app features
- No fallback to custom paywall
- Superwall handles all paywall presentation
- No bypass options available

## Implementation Details

### Hard Paywall Gate
The `PaywallGate` component:
1. Checks subscription status via `SubscriptionProvider`
2. If no subscription: Shows Superwall hard paywall
3. If subscription active: Allows access to app content
4. Handles app lifecycle events to detect external purchases

### Superwall Integration

#### Key Placements
- `app_install` - Hard paywall shown on first app launch
- `onboarding_paywall` - Regular paywall for upgrade prompts

#### Hard Paywall Features
- Uses `app_install` placement for new users
- No dismiss/close option (configured in Superwall dashboard)
- Automatically refreshes subscription status after purchase
- Monitors app lifecycle for external purchase completion

### Required Superwall Dashboard Configuration

#### 1. Create Hard Paywall Campaign
```
Campaign Name: Hard Paywall
Placement: app_install
Audience: All Users
Paywall: [Your hard paywall design]
```

#### 2. Paywall Settings
```
Feature Gating: GATED
Allow Dismissal: NO
Show Close Button: NO
```

#### 3. Audience Rules
```
- Include: All users
- Exclude: Users with active subscription
```

## Key Changes Made

### Removed Components
- ❌ `CustomPaywallScreen` - Completely removed
- ❌ Old paywall timing logic in `PaywallManager`
- ❌ Fallback paywall UI in `PaywallGate`

### Updated Components
- ✅ `PaywallGate` - Now only uses Superwall
- ✅ `SuperwallService` - Added `showHardPaywall()` method
- ✅ `SubscriptionProvider` - Enabled hard paywall enforcement
- ✅ `PaywallManager` - Simplified to only use Superwall

### New Behavior
1. **App Install**: Immediately shows hard paywall
2. **No Bypass**: Users cannot access app without subscription
3. **External Purchases**: Automatically detected via app lifecycle monitoring
4. **Debug Testing**: Account dashboard includes Superwall paywall test

## Testing Checklist

### Required Superwall Dashboard Setup
- [ ] `app_install` placement exists
- [ ] Hard paywall campaign is active
- [ ] Paywall is set to GATED mode
- [ ] Close button is disabled
- [ ] Products are properly configured

### App Testing
- [ ] Fresh install shows hard paywall immediately
- [ ] Cannot dismiss paywall without purchase
- [ ] Purchase completes successfully
- [ ] App unlocks after successful purchase
- [ ] Subscription status persists across app restarts
- [ ] External purchase detection works

## Troubleshooting

### Paywall Not Showing
1. Check Superwall API key in `SuperwallService`
2. Verify `app_install` placement exists in dashboard
3. Check campaign is active and has traffic allocation
4. Ensure user is not already subscribed

### Paywall Can Be Dismissed
1. Check paywall settings in Superwall dashboard
2. Ensure Feature Gating is set to "GATED"
3. Verify "Allow Dismissal" is disabled

### Purchase Not Detected
1. Check RevenueCat integration
2. Verify Superwall delegate methods are called
3. Check subscription status refresh logic
4. Test app lifecycle state changes

## Benefits

### For Users
- Clear subscription requirement
- No confusing free/premium distinctions
- Streamlined onboarding experience

### For Business
- Higher conversion rates
- Reduced support complexity
- Clear monetization strategy
- Better user value alignment

### For Development
- Simplified codebase
- No complex paywall timing logic
- Centralized paywall management via Superwall
- A/B testing capabilities without app updates

# Superwall Hybrid Integration Setup Guide

This guide walks you through setting up Superwall with your existing RevenueCat infrastructure using a hybrid approach.

## Overview

The hybrid approach allows you to:
- Keep your existing RevenueCat subscription logic
- Use Superwall's powerful paywall presentation and A/B testing
- Have a fallback to your custom paywall if Superwall is unavailable
- Maintain all your existing subscription entitlements

## What's Been Implemented

### 1. Dependencies Added
- `superwallkit_flutter: ^2.0.5` added to `pubspec.yaml`

### 2. Platform Configuration

#### iOS (Already Compatible)
- Minimum deployment target: iOS 16.0 ✅
- No additional changes needed

#### Android
- Added Superwall activities to `AndroidManifest.xml`:
  - `SuperwallPaywallActivity` (main paywall activity)
  - Debug activities for development
- Minimum SDK: 26 ✅
- Compile SDK: 34 ✅

### 3. Services Created

#### SuperwallService (`lib/services/superwall_service.dart`)
- Singleton service for Superwall integration
- Handles initialization, paywall presentation, and user management
- Includes fallback to your existing custom paywall
- Key methods:
  - `initialize()` - Configure Superwall
  - `showPaywall(placement)` - Show paywall for specific placement
  - `setUserIdentity(userId)` - Sync user identity
  - `resetUserIdentity()` - Clear user on logout

### 4. Integration Points

#### Main App (`lib/main.dart`)
- Added Superwall service initialization in background
- Non-blocking startup to maintain app performance

#### PaywallManager (`lib/services/paywall_manager.dart`)
- Updated to try Superwall first, fallback to custom paywall
- Maintains all existing paywall logic and session tracking

## Setup Steps

### 1. Get Your Superwall API Keys

1. Sign up for a free account at [superwall.com](https://superwall.com)
2. Create your app in the Superwall dashboard
3. Go to **Settings > Keys > Public API Key**
4. Copy your API key

### 2. Configure API Key

Update the API key in `lib/services/superwall_service.dart`:

```dart
// Replace this line:
await Superwall.configure("YOUR_SUPERWALL_API_KEY");

// With your actual API key:
await Superwall.configure("pk_your_actual_api_key_here");
```

### 3. Create Your First Campaign

1. In the Superwall dashboard, go to **Campaigns**
2. Create a new campaign
3. Add a placement called `onboarding_paywall` (this matches your hard paywall)
4. Design your paywall using Superwall's templates
5. Set up your audience rules (e.g., show to non-subscribers)

**Important**: Since you have a hard paywall strategy, create the `onboarding_paywall` placement first. This will be shown to users who haven't subscribed when they try to access your app.

### 4. Configure Products

1. In Superwall dashboard, go to **Settings > Products**
2. Add your existing RevenueCat product IDs
3. Make sure they match exactly with your RevenueCat configuration

### 5. Test the Integration

#### Development Testing
```dart
// In your app, trigger a paywall:
final superwallService = SuperwallService();
await superwallService.showPaywall('premium_upgrade', context: context);
```

#### Placement Testing
The integration uses these placements for your hard paywall strategy:
- `onboarding_paywall` - Hard paywall that blocks app access (main placement)
- `premium_upgrade` - Optional secondary paywall trigger
- You can add more placements in Superwall dashboard

### 6. User Identity Sync

The service automatically syncs user identity with your existing auth:

```dart
// When user logs in:
await SuperwallService().setUserIdentity(userId);

// When user logs out:
await SuperwallService().resetUserIdentity();
```

## How It Works

### Hard Paywall Flow
1. User opens app without subscription
2. `PaywallGate` blocks access and shows paywall
3. System checks if Superwall is initialized
4. If yes: Shows Superwall paywall for `onboarding_paywall` placement
5. If no: Falls back to your existing `CustomPaywallScreen`
6. All purchases still go through RevenueCat
7. After successful purchase, user gains access to the app
8. Subscription status managed by your existing `SubscriptionService`

### Fallback Strategy
- If Superwall fails to initialize: Uses custom paywall
- If Superwall API is down: Uses custom paywall
- If placement doesn't exist: Uses custom paywall
- Your app continues working normally in all scenarios

## Advanced Configuration

### Custom Placements
Add more placements for different contexts:

```dart
// For specific features
await superwallService.showPaywall('ai_meal_planning', context: context);
await superwallService.showPaywall('premium_analytics', context: context);
```

### A/B Testing
- Create multiple paywalls in Superwall dashboard
- Set up audience rules and traffic allocation
- Test different designs, copy, and pricing
- All without app updates!

### Analytics Integration
Superwall automatically tracks:
- Paywall impressions
- Conversion rates
- Revenue attribution
- A/B test performance

## Troubleshooting

### Common Issues

1. **Superwall not initializing**
   - Check API key is correct
   - Verify internet connection
   - Check logs for initialization errors

2. **Paywall not showing**
   - Verify placement exists in dashboard
   - Check audience rules (might be excluding test users)
   - Ensure campaign is active

3. **Purchases not working**
   - RevenueCat handles all purchases
   - Check RevenueCat configuration
   - Verify product IDs match

### Debug Mode
Enable debug logging in development:
```dart
// Add to SuperwallService initialization
debugPrint('Superwall Debug Mode: Enabled');
```

### Testing Checklist
- [ ] API key configured correctly
- [ ] Campaign created with `premium_upgrade` placement
- [ ] Products added to Superwall dashboard
- [ ] Paywall shows in app
- [ ] Fallback to custom paywall works
- [ ] Purchases complete successfully
- [ ] Subscription status updates correctly

## Benefits of This Setup

### For Development
- **No Code Changes**: Update paywalls remotely
- **A/B Testing**: Test multiple designs simultaneously
- **Analytics**: Built-in conversion tracking
- **Fallback Safety**: Always works even if Superwall is down

### For Business
- **Faster Iteration**: No app store reviews for paywall changes
- **Better Conversion**: Use proven high-converting templates
- **Data-Driven**: Make decisions based on real conversion data
- **Risk-Free**: Existing paywall always available as backup

## Next Steps

1. **Set up your API key** (required)
2. **Create your first campaign** in Superwall dashboard
3. **Test the integration** in development
4. **Deploy and monitor** conversion rates
5. **Iterate and optimize** using A/B tests

## Support

- **Superwall Docs**: [docs.superwall.com](https://docs.superwall.com)
- **Superwall Support**: [support@superwall.com](mailto:support@superwall.com)
- **RevenueCat Integration**: Already handled in this setup

---

**Note**: This is a hybrid approach - your existing RevenueCat infrastructure remains unchanged. Superwall only handles paywall presentation, while RevenueCat continues to manage subscriptions, entitlements, and purchases. 