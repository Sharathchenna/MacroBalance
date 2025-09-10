# Superwall Test Placement Guide

This document explains how to use the test placement to verify your Superwall integration is working correctly.

## Overview

The test placement `test_placement` is designed to verify that:
1. Superwall SDK is properly configured
2. Placement registration works
3. Callbacks are triggered correctly
4. Error handling is functioning

## Test Placement Details

### Placement ID
```
test_placement
```

### Implementation Location
- **File**: `lib/services/superwall_placements.dart`
- **Method**: `SuperwallPlacements.showTestPaywall()`
- **UI Trigger**: Account Dashboard → "Test Superwall Integration" button

### Parameters Sent
```dart
{
  'source': 'test_integration',
  'test_type': 'basic_functionality', 
  'timestamp': DateTime.now().toIso8601String(),
}
```

## How to Test

### Step 1: Access the Test Button
1. Open the app
2. Navigate to Account Dashboard (profile tab)
3. Scroll down to find "Test Superwall Integration" button (orange flask icon)
4. Tap the button

### Step 2: Expected Behaviors

#### If Superwall is NOT configured:
- **Debug Console**: `[SuperwallService] Superwall not configured, executing feature directly`
- **UI Feedback**: Green success message "✅ Superwall test placement worked!"
- **Result**: Test passes (feature callback executes immediately)

#### If Superwall IS configured but placement doesn't exist:
- **Debug Console**: `[SuperwallService] Error registering placement test_placement: [error details]`
- **UI Feedback**: Red error message "❌ Superwall test failed: [error]"
- **Result**: Test fails with specific error message

#### If Superwall IS configured and placement exists:
- **Debug Console**: `[SuperwallService] Registering placement: test_placement`
- **UI Behavior**: Superwall paywall should appear (if campaign is set up)
- **After Paywall**: Feature callback triggers success message

### Step 3: Configure in Superwall Dashboard

To complete the integration test, you need to:

1. **Create Placement** in Superwall Dashboard:
   - Name: `test_placement`
   - Description: "Test placement for integration verification"

2. **Create a Simple Paywall** (optional for testing):
   - Add your subscription products
   - Simple design for testing purposes

3. **Create Campaign**:
   - Connect `test_placement` to your test paywall
   - Set rules (e.g., show to all users)

4. **Test Again**:
   - Use the test button
   - Should now show actual Superwall paywall

## Debug Console Messages

Monitor these log messages during testing:

```
[SuperwallPlacements] Testing Superwall integration with test placement
[SuperwallService] Registering placement: test_placement
[SuperwallPlacements] Test placement registration completed successfully
[SuperwallPlacements] Test placement feature callback triggered
```

## Troubleshooting

### Common Issues

#### 1. "Superwall not configured" 
- **Cause**: API key not set or initialization failed
- **Fix**: Check `SuperwallService._apiKey` and `configure()` method
- **Location**: `lib/services/superwall_service.dart`

#### 2. "Error registering placement"
- **Cause**: Network issues, invalid API key, or placement doesn't exist
- **Fix**: 
  - Verify internet connection
  - Check API key validity
  - Create placement in Superwall dashboard

#### 3. No paywall appears but no errors
- **Cause**: Placement exists but no campaign configured
- **Fix**: Create campaign in Superwall dashboard linking placement to paywall

#### 4. App crashes during test
- **Cause**: Missing dependencies or configuration issues
- **Fix**: 
  - Run `flutter pub get`
  - Check iOS: `cd ios && pod install`
  - Verify Superwall SDK is properly added

### Advanced Debugging

#### Enable Superwall Debug Logs
In `SuperwallService.configure()`, you can add:
```dart
// Add debug configuration if available in Superwall SDK
```

#### Check RevenueCat Integration
The test placement also verifies RevenueCat integration:
```dart
final hasSubscription = await superwallService.hasActiveSubscription();
```

## Next Steps After Testing

### If Test Passes ✅
1. Proceed to configure your main placements in Superwall dashboard
2. Set up campaigns for your production placements
3. Test with real subscription products

### If Test Fails ❌
1. Review error messages in debug console
2. Verify Superwall SDK installation
3. Check API key configuration
4. Ensure internet connectivity
5. Contact Superwall support if needed

## Test Placement Configuration Template

For Superwall Dashboard setup:

```json
{
  "placement_id": "test_placement",
  "name": "Test Placement",
  "description": "Integration test placement for Flutter app",
  "parameters": {
    "source": "test_integration",
    "test_type": "basic_functionality",
    "timestamp": "ISO_DATE_STRING"
  }
}
```

## Related Files

- `lib/services/superwall_placements.dart` - Test method implementation
- `lib/services/superwall_service.dart` - Core Superwall service
- `lib/screens/accountdashboard.dart` - Test button UI
- `docs/superwall_migration_guide.md` - Main migration documentation

## Support

If you encounter issues:
1. Check debug console for specific error messages
2. Verify all setup steps in migration guide
3. Test with different placement names
4. Consult Superwall documentation at [superwall.com/docs](https://superwall.com/docs) 