# Superwall Paywall Integration Guide

## Overview

This document covers the complete implementation and troubleshooting of Superwall paywall integration in MacroBalance, specifically focusing on the post-onboarding signup flow where users see their personalized nutrition results before being required to sign up and subscribe.

## User Flow

The implemented flow follows a value-first approach:

1. **Welcome Screen** → Prominent "Get Started" button
2. **Onboarding** → 15-step personalization process  
3. **Results Screen** → Shows personalized macro plan
4. **Signup Required** → User must create account to continue
5. **Paywall** → Superwall paywall presented after signup
6. **Dashboard** → Full app access after subscription

## Implementation Details

### Key Files Modified

#### 1. Results Screen (`lib/screens/onboarding/results_screen.dart`)

**Purpose**: Shows personalized nutrition results and handles transition to signup/paywall

**Key Methods**:
- `_showPaywallAndProceed()`: Main entry point, checks auth status
- `_showPaywallThenDashboard()`: Handles post-signup navigation to paywall
- `_proceedToDashboard()`: Handles existing user flow

**Critical Changes**:
```dart
void _showPaywallAndProceed() {
  // Check authentication first
  final currentUser = Supabase.instance.client.auth.currentUser;
  
  if (currentUser == null) {
    // Navigate to signup with callback
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Signup(
          fromOnboarding: true,
          onSignupSuccess: () {
            // Delayed navigation to prevent conflicts
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _showPaywallThenDashboard();
              }
            });
          },
        ),
      ),
    );
  } else {
    _proceedToDashboard();
  }
}
```

**Debug Features**:
- Red floating action button (debug mode only) for direct Superwall testing
- Comprehensive logging throughout the flow

#### 2. Signup Screen (`lib/screens/signup.dart`)

**Purpose**: Handles user registration with special flow for onboarding users

**Key Changes**:
- Added `fromOnboarding` parameter and `onSignupSuccess` callback
- Removed premature `Navigator.pop()` calls that caused navigation conflicts
- Enhanced logging for all signup methods (email, Google, Apple)

**Critical Fix**:
```dart
// OLD - Caused navigation conflicts
if (widget.fromOnboarding && widget.onSignupSuccess != null) {
  widget.onSignupSuccess!();
  Navigator.of(context).pop(); // This caused problems
}

// NEW - Let parent handle navigation
if (widget.fromOnboarding && widget.onSignupSuccess != null) {
  widget.onSignupSuccess!(); // Parent handles navigation
}
```

#### 3. Superwall Service (`lib/services/superwall_service.dart`)

**Purpose**: Manages all Superwall SDK interactions and paywall presentations

**Key Improvements**:
- Changed from `app_install` to `onboarding_paywall` placement for better reliability
- Added comprehensive test method for debugging
- Enhanced error handling and initialization logic
- Improved delegate implementation for custom actions (restore purchases)

**Critical Methods**:
```dart
// Main paywall for general use
Future<void> showMainPaywall() async {
  sw.Superwall.shared.registerPlacement(
    'onboarding_paywall',
    params: params.isNotEmpty ? params : null,
    feature: () {
      debugPrint('User has premium access - feature unlocked');
    },
  );
}

// Hard paywall for post-signup flow
Future<void> showHardPaywall() async {
  sw.Superwall.shared.registerPlacement(
    'onboarding_paywall', // Same placement, different params
    params: params,
    feature: () {
      debugPrint('User has premium access - hard paywall bypassed');
    },
  );
}

// Debug/test method
Future<void> testSuperwallConnection() async {
  // Comprehensive testing of Superwall initialization and connectivity
}
```

#### 4. Paywall Gate (`lib/auth/paywall_gate.dart`)

**Purpose**: Hard paywall component that blocks app access for non-subscribers

**Key Improvements**:
- Added fallback to main paywall if hard paywall fails
- Enhanced initialization with proper delays
- Added retry button for failed paywall presentations
- Better error handling and user feedback

**Critical Features**:
```dart
void _initializeAndShowSuperwall() {
  // Initialize with delay for stability
  if (!superwallService.isInitialized) {
    await superwallService.initialize();
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // Try hard paywall first, fallback to main paywall
  if (superwallService.isInitialized && !_superwallShown) {
    await superwallService.showHardPaywall();
  } else {
    // Fallback logic
    if (superwallService.isInitialized) {
      await superwallService.showMainPaywall();
    } else {
      _showSuperwallError();
    }
  }
}
```

## Superwall Dashboard Configuration

### Required Setup

#### 1. Campaign and Placement Configuration

In your Superwall dashboard:

1. **Go to Campaigns** → Select your campaign
2. **Add Placement**: Create `onboarding_paywall` placement
3. **Assign Paywall**: Link your paywall to this placement
4. **Set Feature Gating**: Must be set to "Gated" for hard paywall behavior

#### 2. Products Configuration

1. **Add Products**: Configure your subscription products
2. **Match RevenueCat**: Ensure product IDs match your RevenueCat setup
3. **Set Pricing**: Configure pricing, trial periods, etc.

#### 3. Audience Rules

1. **Target Non-Subscribers**: Set rules to show paywall only to non-paying users
2. **Traffic Allocation**: Set to 100% for your paywall initially
3. **Test Users**: Ensure your test accounts aren't excluded

### Available Placements

The integration supports these placements:

1. **`onboarding_paywall`** - Primary placement for post-signup flow
2. **`referral_paywall`** - For users with referral codes
3. **`feature_paywall`** - For specific feature access
4. **Standard Superwall placements**:
   - `app_launch`
   - `session_start`
   - `app_install`
   - `transaction_abandon`

## Troubleshooting Guide

### Common Issues and Solutions

#### 1. Paywall Not Showing

**Symptoms**: User completes signup but no paywall appears

**Debug Steps**:
1. Use the red debug button in results screen (debug mode)
2. Check console logs for specific errors
3. Verify Superwall initialization logs

**Common Causes**:
- Placement `onboarding_paywall` doesn't exist in dashboard
- Campaign is paused or inactive
- Audience rules excluding test users
- Network connectivity issues
- API key configuration problems

**Solutions**:
```dart
// Test different placements
await superwallService.showMainPaywall(); // Try with 'onboarding_paywall'
await superwallService.showFeaturePaywall('test'); // Try with 'feature_paywall'

// Test built-in placements
sw.Superwall.shared.registerPlacement('app_launch');
sw.Superwall.shared.registerPlacement('session_start');
```

#### 2. Navigation Conflicts

**Symptoms**: App crashes or gets stuck during signup → paywall transition

**Debug Steps**:
1. Check for multiple `Navigator.pop()` calls
2. Verify `mounted` checks before navigation
3. Look for timing issues in callbacks

**Solutions**:
- Use `Future.delayed()` for navigation in callbacks
- Always check `if (mounted)` before navigation
- Avoid `Navigator.pop()` in success callbacks when parent handles navigation

#### 3. Superwall Initialization Failures

**Symptoms**: Superwall methods fail with initialization errors

**Debug Steps**:
```dart
// Test connection
await SuperwallService().testSuperwallConnection();

// Check logs for:
debugPrint('Superwall initialized: ${superwallService.isInitialized}');
debugPrint('API Key: pk_92e7caae027e3213de436b66d1fb25996245e09c3415ef9b');
```

**Common Causes**:
- Network issues preventing initial configuration download
- Invalid API key
- SDK version compatibility issues

#### 4. Paywall Dismiss Without Purchase

**Symptoms**: Users can dismiss paywall without subscribing

**Solutions**:
- Verify Feature Gating is set to "Gated" in Superwall dashboard
- Check that subscription status is properly synced
- Ensure delegate methods are handling dismiss events correctly

### Debug Tools

#### 1. Debug Button (Results Screen)

Located in top-right of results screen (debug mode only):
- Tests Superwall connectivity
- Verifies initialization
- Triggers paywall directly
- Shows success/error messages

#### 2. Console Logging

Comprehensive logging throughout the flow:

```bash
# Signup flow
=== RESULTS SCREEN: _showPaywallAndProceed called ===
=== SIGNUP SUCCESS CALLBACK TRIGGERED ===
=== _showPaywallThenDashboard called ===

# Paywall flow  
=== HARD PAYWALL GATE ===
✅ Showing Superwall hard paywall
Superwall Delegate: Paywall presented

# Connection testing
=== TESTING SUPERWALL CONNECTION ===
✅ Superwall connection test successful
```

#### 3. Test Methods

```dart
// Test Superwall connectivity
await SuperwallService().testSuperwallConnection();

// Test specific placements
await SuperwallService().showMainPaywall();
await SuperwallService().showHardPaywall();
await SuperwallService().showFeaturePaywall('test_feature');

// Test with different parameters
final params = {'test_mode': 'true', 'user_type': 'debug'};
sw.Superwall.shared.registerPlacement('onboarding_paywall', params: params);
```

## Performance Considerations

### Initialization Strategy

Superwall is initialized in background during app startup to avoid blocking:

```dart
// main.dart
void _initializeSuperwallServiceInBackground() {
  Future.microtask(() async {
    try {
      await SuperwallService().initialize();
    } catch (e) {
      debugPrint('Superwall initialization failed: $e');
      // App continues without Superwall
    }
  });
}
```

### Memory Management

- Superwall service uses singleton pattern
- Paywall presentations are one-time events
- Delegate callbacks are lightweight
- No persistent UI components

### Network Optimization

- Configuration downloaded once on app launch
- Paywall assets cached locally
- Graceful fallbacks for network issues

## Security Considerations

### API Key Management

- Public API key is safe to include in app
- No sensitive data exposed in client
- All purchase validation happens server-side through RevenueCat

### User Data

- Minimal user data sent to Superwall
- User identity synced securely
- No PII stored in Superwall parameters

## Testing Strategy

### Development Testing

1. **Debug Mode**: Use debug button for immediate testing
2. **Console Logs**: Monitor flow with comprehensive logging
3. **Network Simulation**: Test with poor/no connectivity
4. **Multiple Accounts**: Test with different user states

### Production Testing

1. **TestFlight**: Test full flow with real App Store environment
2. **A/B Testing**: Use Superwall's built-in experimentation
3. **Analytics**: Monitor conversion rates and user behavior
4. **Error Tracking**: Monitor for paywall presentation failures

### Test Scenarios

1. **New User Flow**:
   - Complete onboarding
   - See results
   - Sign up with email
   - See paywall
   - Complete purchase

2. **Existing User Flow**:
   - Sign in from welcome screen
   - Navigate normally
   - Paywall only if not subscribed

3. **Social Login Flow**:
   - Use Google/Apple sign in
   - Verify callback handling
   - Confirm paywall presentation

4. **Error Scenarios**:
   - Network disconnection
   - Superwall service failure
   - Navigation interruption
   - Payment failure

## Monitoring and Analytics

### Key Metrics to Track

1. **Conversion Funnel**:
   - Onboarding completion rate
   - Results screen → Signup rate
   - Signup → Paywall presentation rate
   - Paywall → Purchase conversion rate

2. **Technical Metrics**:
   - Superwall initialization success rate
   - Paywall presentation failure rate
   - Navigation flow completion rate
   - Error occurrence frequency

3. **User Experience**:
   - Time from signup to paywall
   - Paywall dismissal rate
   - Retry button usage
   - Flow abandonment points

### Implementation

```dart
// Track key events
await SuperwallService().trackEvent('onboarding_completed');
await SuperwallService().trackEvent('results_viewed');
await SuperwallService().trackEvent('signup_initiated');
await SuperwallService().trackEvent('paywall_presented');

// Set user properties for targeting
await SuperwallService().setUserProperties({
  'onboarding_source': 'organic',
  'signup_method': 'email',
  'user_segment': 'health_focused',
});
```

## Future Enhancements

### Planned Improvements

1. **Smart Timing**: Dynamic paywall timing based on user engagement
2. **Personalization**: Customized paywall content based on onboarding data
3. **A/B Testing**: Multiple paywall variants for optimization
4. **Retention**: Win-back campaigns for churned users
5. **Referrals**: Enhanced referral code integration

### Technical Roadmap

1. **Error Recovery**: More sophisticated fallback mechanisms
2. **Offline Support**: Cached paywall presentations
3. **Performance**: Faster initialization and presentation
4. **Analytics**: Enhanced tracking and attribution
5. **Testing**: Automated UI testing for paywall flows

## Conclusion

The Superwall integration provides a robust, value-first monetization strategy that:

- Shows users the value before asking for payment
- Provides seamless signup → paywall transition
- Includes comprehensive error handling and fallbacks
- Offers extensive debugging and testing capabilities
- Maintains high performance and user experience standards

The implementation is production-ready with proper error handling, comprehensive logging, and extensive testing capabilities. The modular design allows for easy updates and enhancements as needed. 