# Superwall Custom Actions Implementation - Redeem & Restore

This document describes the implementation of custom actions in the Superwall SDK: a "redeem" action that opens the App Store redeem page, and a "restore" action that restores previous purchases via RevenueCat.

## Overview

The implementation provides a way to handle custom actions from Superwall paywalls:
- **"redeem" action**: Opens the appropriate store's redeem page (App Store for iOS, Play Store for Android)
- **"restore" action**: Restores previous purchases via RevenueCat

## Implementation Details

### Files Created/Modified

1. **`lib/services/superwall_delegate.dart`** - Custom delegate class to handle redeem actions
2. **`lib/services/superwall_service.dart`** - Updated to integrate the custom action handler

### Key Components

#### CustomSuperwallDelegate Class

The `CustomSuperwallDelegate` class handles both custom actions:

**Redeem Action:**
- Detecting the platform (iOS/Android)
- Opening the appropriate store redeem page
- Handling errors gracefully

**Restore Action:**
- Restoring previous purchases via RevenueCat
- Handling success/failure cases
- Logging appropriate debug messages

```dart
class CustomSuperwallDelegate {
  void handleRedeemAction() {
    if (Platform.isIOS) {
      _openIOSRedeemPage();
    } else if (Platform.isAndroid) {
      _openAndroidRedeemPage();
    }
  }
  
  void handleRestoreAction() {
    _restorePurchases();
  }
}
```

#### Platform-Specific URLs

- **iOS**: `itms-apps://apps.apple.com/account/balance/redeem`
- **Android**: `https://play.google.com/store/gift`

#### SuperwallService Integration

The `SuperwallService` now includes both custom action handlers:

```dart
void handleRedeemAction() {
  if (!_isConfigured) return;
  _delegate.handleRedeemAction();
}

void handleRestoreAction() {
  if (!_isConfigured) return;
  _delegate.handleRestoreAction();
}
```

## Usage

### In Superwall Dashboard

1. Create a paywall in the Superwall dashboard
2. Add buttons or interactive elements
3. Set the tap action to "Custom Action"
4. Name the actions "redeem" or "restore"

### In Your App Code

When you need to trigger the custom actions programmatically:

```dart
// Get the SuperwallService instance
final superwallService = SuperwallService();

// Handle the redeem action
superwallService.handleRedeemAction();

// Handle the restore action
superwallService.handleRestoreAction();
```

### From Paywall Interactions

The custom actions will be automatically triggered when users interact with the "redeem" or "restore" buttons in your Superwall paywall, provided you've configured them correctly in the dashboard.

## Error Handling

The implementation includes error handling for:

**Redeem Action:**
- Unsupported platforms
- URL launch failures
- Network connectivity issues

**Restore Action:**
- RevenueCat API errors
- Network connectivity issues
- No previous purchases found

Errors are logged using `debugPrint()` for debugging purposes.

## Dependencies

- `url_launcher: ^6.3.1` - Already included in pubspec.yaml
- `superwallkit_flutter: ^2.4.2` - Already included in pubspec.yaml
- `purchases_flutter: ^6.0.0` - Already included in pubspec.yaml

## Testing

To test the implementation:

1. Ensure Superwall is properly configured
2. Call `SuperwallService().handleRedeemAction()` to test redeem functionality
3. Call `SuperwallService().handleRestoreAction()` to test restore functionality
4. Verify that the appropriate store redeem page opens for redeem action
5. Verify that purchases are restored for restore action
6. Test on both iOS and Android devices

## Notes

- The Flutter Superwall package doesn't support the same delegate pattern as the iOS version
- This implementation provides a workaround by creating a custom handler class
- The implementation is platform-aware and opens the correct store for each platform
- Error handling is basic and can be enhanced based on your app's requirements

## Future Enhancements

Consider adding:

- User feedback dialogs for failed launches
- Analytics tracking for redeem action usage
- Fallback options if the store page fails to open
- Custom error messages for different failure scenarios
