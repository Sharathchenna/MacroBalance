# Superwall Native Redemption Implementation

This document describes how to create a custom action named "redeem" in Superwall that invokes the iOS native redemption sheet in your Flutter app.

## Overview

The implementation provides:
- **Native iOS redemption sheet** using `in_app_purchase` package for the best user experience
- **URL fallback method** for reliability and Android support
- **Custom action handler** that integrates with Superwall paywalls
- **Automatic platform detection** and appropriate method selection

## Architecture

```
Superwall Dashboard → Custom Action "redeem" → SuperwallService → CustomSuperwallDelegate → Native Redemption Sheet
```

## Implementation Details

### 1. Dependencies Added

```yaml
# pubspec.yaml
dependencies:
  in_app_purchase: ^3.2.2  # For native iOS redemption sheet
  url_launcher: ^6.3.1     # For URL fallback (already present)
  superwallkit_flutter: ^2.4.2  # Superwall SDK (already present)
```

### 2. Enhanced CustomSuperwallDelegate

The delegate now supports both native redemption sheet and URL fallback:

```dart
class CustomSuperwallDelegate {
  /// Handle the 'redeem' custom action with native sheet option
  void handleRedeemAction({bool useNativeSheet = true}) {
    if (Platform.isIOS) {
      if (useNativeSheet) {
        _presentNativeIOSRedemptionSheet();  // Primary method
      } else {
        _openIOSRedeemPage();  // Fallback method
      }
    } else if (Platform.isAndroid) {
      _openAndroidRedeemPage();
    }
  }

  /// Present native iOS App Store redemption sheet
  Future<void> _presentNativeIOSRedemptionSheet() async {
    try {
      InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
          InAppPurchase.instance.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      
      await iosPlatformAddition.presentCodeRedemptionSheet();
      debugPrint('[SuperwallDelegate] Native iOS redemption sheet presented successfully');
    } catch (e) {
      debugPrint('[SuperwallDelegate] Native redemption sheet failed: $e');
      _openIOSRedeemPage(); // Automatic fallback to URL method
    }
  }
}
```

### 3. SuperwallService Integration

The service now includes a generic custom action handler:

```dart
class SuperwallService {
  /// Handle custom action from Superwall paywall
  void handleCustomAction(String actionName, {Map<String, dynamic>? parameters}) {
    switch (actionName.toLowerCase()) {
      case 'redeem':
        final useNativeSheet = parameters?['useNativeSheet'] as bool? ?? true;
        handleRedeemAction(useNativeSheet: useNativeSheet);
        break;
      case 'restore':
        handleRestoreAction();
        break;
      default:
        debugPrint('[SuperwallService] Unknown custom action: $actionName');
    }
  }
}
```

## Setup Instructions

### Step 1: Configure Superwall Dashboard

1. **Login to your Superwall Dashboard**
2. **Navigate to your Paywall**
3. **Add a Button or Interactive Element**
4. **Configure the Button Action:**
   - Set Action Type to "Custom Action"
   - Set Action Name to "redeem"
   - Optionally add parameters like `{"useNativeSheet": true}`

### Step 2: Paywall HTML Configuration

If you're using custom HTML in your paywall, add this JavaScript:

```javascript
// In your paywall HTML
function handleRedeemClick() {
  // This will trigger the custom action in your Flutter app
  window.webkit.messageHandlers.superwall.postMessage({
    action: 'custom_action',
    name: 'redeem',
    parameters: {
      useNativeSheet: true
    }
  });
}
```

```html
<!-- Button in your paywall HTML -->
<button onclick="handleRedeemClick()">
  Redeem Code
</button>
```

### Step 3: Flutter App Integration

The integration is already complete with your current implementation. The custom action will be automatically handled when triggered from the paywall.

## Usage Examples

### Programmatic Usage

```dart
// Direct method calls
final superwallService = SuperwallService();

// Use native sheet (default)
superwallService.handleRedeemAction();

// Use URL method
superwallService.handleRedeemAction(useNativeSheet: false);

// Handle generic custom action
superwallService.handleCustomAction('redeem', parameters: {
  'useNativeSheet': true
});
```

### From Paywall Interactions

When users interact with the "redeem" button in your Superwall paywall:

1. **User taps "Redeem Code" button**
2. **Superwall triggers custom action "redeem"**
3. **SuperwallService.handleCustomAction() is called**
4. **Native iOS redemption sheet is presented**
5. **If native sheet fails, automatically falls back to URL method**

## Platform-Specific Behavior

### iOS
- **Primary**: Native redemption sheet using `in_app_purchase`
- **Fallback**: URL scheme `itms-apps://apps.apple.com/account/balance/redeem`
- **User Experience**: Users stay within the app (native sheet) or are redirected to App Store app (URL)

### Android
- **Method**: URL redirect to Play Store
- **URL**: `https://play.google.com/store/gift`
- **User Experience**: Users are redirected to Play Store app

### Other Platforms
- **Behavior**: Logs unsupported platform message
- **Fallback**: No action taken

## Error Handling

The implementation includes comprehensive error handling:

```dart
try {
  // Attempt native redemption sheet
  await iosPlatformAddition.presentCodeRedemptionSheet();
} catch (e) {
  // Automatic fallback to URL method
  _openIOSRedeemPage();
}
```

**Error Scenarios Handled:**
- Native sheet API unavailable
- Network connectivity issues
- Platform-specific failures
- URL launch failures

## Testing

### Test Cases

1. **Native Sheet Test (iOS)**
```dart
SuperwallService().handleRedeemAction(useNativeSheet: true);
```

2. **URL Fallback Test (iOS)**
```dart
SuperwallService().handleRedeemAction(useNativeSheet: false);
```

3. **Android Test**
```dart
SuperwallService().handleRedeemAction();
```

4. **Custom Action Test**
```dart
SuperwallService().handleCustomAction('redeem');
```

### Testing Checklist

- [ ] Native redemption sheet opens on iOS
- [ ] URL fallback works when native sheet fails
- [ ] Android redirects to Play Store correctly
- [ ] Custom action from paywall triggers correctly
- [ ] Error handling works properly
- [ ] Debug logs are informative

## Debugging

### Enable Debug Logging

All methods include comprehensive debug logging:

```dart
debugPrint('[SuperwallDelegate] Presenting native iOS redemption sheet...');
debugPrint('[SuperwallService] Handling custom action: redeem');
```

### Common Issues

1. **Native Sheet Not Appearing**
   - Check iOS version (requires iOS 14+)
   - Verify `in_app_purchase` package is properly installed
   - Check device logs for StoreKit errors

2. **URL Fallback Not Working**
   - Verify `url_launcher` package permissions
   - Check if device has App Store app installed
   - Test URL scheme manually

3. **Custom Action Not Triggered**
   - Verify Superwall dashboard configuration
   - Check paywall HTML/JavaScript
   - Ensure SuperwallService is properly initialized

## Advantages

### Native Redemption Sheet
✅ **Better User Experience** - Users stay within your app  
✅ **Native iOS Interface** - Consistent with system design  
✅ **Automatic Validation** - Built-in code validation  
✅ **Success/Failure Handling** - Automatic result handling  

### URL Fallback
✅ **Universal Compatibility** - Works on all iOS versions  
✅ **Reliable** - Doesn't depend on API availability  
✅ **Cross-Platform** - Same approach works for Android  

### Combined Approach
✅ **Best of Both Worlds** - Premium UX with reliable fallback  
✅ **Automatic Fallback** - Seamless error recovery  
✅ **Platform Aware** - Optimized for each platform  

## Future Enhancements

Consider adding:
- **Success/failure callbacks** for better UX feedback
- **Analytics tracking** for redemption attempts
- **Custom UI indicators** during redemption process
- **A/B testing** between native sheet and URL methods
- **User preference storage** for redemption method choice

## Conclusion

This implementation provides a robust, user-friendly way to handle code redemption in your Flutter app through Superwall custom actions. The native iOS redemption sheet offers the best user experience, while the URL fallback ensures reliability across all scenarios.

The setup is straightforward:
1. Configure "redeem" custom action in Superwall dashboard
2. The Flutter implementation is already complete
3. Test thoroughly on both iOS and Android devices

Users will now have a seamless code redemption experience directly from your paywalls!
