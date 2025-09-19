# iOS App Store Redemption Methods in Flutter

This document explains the different ways to call the App Store native redemption page in Flutter for iOS applications.

## Overview

There are two main approaches to present the App Store redemption functionality in Flutter iOS apps:

1. **Native Redemption Sheet (Recommended)** - Using `in_app_purchase` package
2. **URL Scheme Redirect** - Using `url_launcher` package (current implementation)

## Method 1: Native Redemption Sheet (Recommended)

The native redemption sheet provides the best user experience by presenting Apple's built-in code redemption interface directly within your app without leaving the application.

### Dependencies Required

Add to your `pubspec.yaml`:

```yaml
dependencies:
  in_app_purchase: ^3.2.2
```

### Implementation

```dart
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

class RedemptionService {
  /// Present the native iOS App Store code redemption sheet
  static Future<void> presentNativeRedemptionSheet() async {
    try {
      // Get the iOS platform addition
      InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
          InAppPurchase.instance.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      
      // Present the native redemption sheet
      await iosPlatformAddition.presentCodeRedemptionSheet();
      
      debugPrint('[RedemptionService] Native redemption sheet presented successfully');
    } catch (e) {
      debugPrint('[RedemptionService] Error presenting native redemption sheet: $e');
    }
  }
}
```

### Usage

```dart
// Call from any widget or service
await RedemptionService.presentNativeRedemptionSheet();
```

### Advantages
- ✅ Native iOS interface
- ✅ User stays within the app
- ✅ Better user experience
- ✅ Handles success/failure states automatically
- ✅ Works with iOS 14+ offer codes

### Limitations
- ❌ iOS only (requires platform-specific handling for Android)
- ❌ Requires `in_app_purchase` dependency

## Method 2: URL Scheme Redirect (Current Implementation)

This method redirects users to the App Store app using URL schemes.

### Dependencies Required

```yaml
dependencies:
  url_launcher: ^6.2.2
```

### Implementation

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class RedemptionService {
  /// Open iOS App Store redeem page using URL scheme
  static Future<void> openIOSRedeemPage() async {
    try {
      // iOS App Store redeem URL
      const String redeemUrl = 'itms-apps://apps.apple.com/account/balance/redeem';
      
      final Uri uri = Uri.parse(redeemUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('[RedemptionService] Successfully opened iOS App Store redeem page');
      } else {
        debugPrint('[RedemptionService] Could not launch iOS App Store redeem page');
        throw Exception('Could not launch App Store redeem page');
      }
    } catch (e) {
      debugPrint('[RedemptionService] Error opening iOS App Store redeem page: $e');
      rethrow;
    }
  }
}
```

### Alternative URL Schemes

```dart
// Different URL schemes you can use:
const String redeemUrlScheme1 = 'itms-apps://apps.apple.com/account/balance/redeem';
const String redeemUrlScheme2 = 'https://apps.apple.com/redeem';
const String redeemUrlScheme3 = 'itms://apps.apple.com/redeem';
```

### Advantages
- ✅ Works on all iOS versions
- ✅ Simple implementation
- ✅ Cross-platform compatible (can handle Android separately)
- ✅ Lightweight dependency

### Limitations
- ❌ User leaves the app
- ❌ Less integrated user experience
- ❌ URL schemes might change over time

## Platform-Specific Implementation

### Complete Cross-Platform Solution

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

class UniversalRedemptionService {
  /// Present redemption interface based on platform and preference
  static Future<void> presentRedemption({bool useNativeSheet = true}) async {
    if (Platform.isIOS) {
      if (useNativeSheet) {
        await _presentNativeIOSRedemptionSheet();
      } else {
        await _openIOSRedeemPageWithURL();
      }
    } else if (Platform.isAndroid) {
      await _openAndroidRedeemPage();
    } else {
      throw UnsupportedError('Redemption not supported on this platform');
    }
  }

  /// Present native iOS redemption sheet
  static Future<void> _presentNativeIOSRedemptionSheet() async {
    try {
      InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
          InAppPurchase.instance.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      
      await iosPlatformAddition.presentCodeRedemptionSheet();
      debugPrint('[RedemptionService] Native iOS redemption sheet presented');
    } catch (e) {
      debugPrint('[RedemptionService] Native sheet failed, falling back to URL: $e');
      await _openIOSRedeemPageWithURL();
    }
  }

  /// Open iOS App Store using URL scheme
  static Future<void> _openIOSRedeemPageWithURL() async {
    const String redeemUrl = 'itms-apps://apps.apple.com/account/balance/redeem';
    final Uri uri = Uri.parse(redeemUrl);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch iOS App Store redeem page');
    }
  }

  /// Open Android Play Store redeem page
  static Future<void> _openAndroidRedeemPage() async {
    const String redeemUrl = 'https://play.google.com/store/gift';
    final Uri uri = Uri.parse(redeemUrl);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch Play Store redeem page');
    }
  }
}
```

## Integration with Your Current Implementation

### Updating SuperwallDelegate

```dart
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

class CustomSuperwallDelegate {
  /// Handle the 'redeem' custom action with native sheet option
  void handleRedeemAction({bool useNativeSheet = true}) {
    debugPrint('[SuperwallDelegate] Opening App Store redeem page...');
    
    if (Platform.isIOS) {
      if (useNativeSheet) {
        _presentNativeIOSRedemptionSheet();
      } else {
        _openIOSRedeemPage(); // Your existing implementation
      }
    } else if (Platform.isAndroid) {
      _openAndroidRedeemPage();
    } else {
      debugPrint('[SuperwallDelegate] Redeem action not supported on this platform');
    }
  }

  /// Present native iOS redemption sheet
  Future<void> _presentNativeIOSRedemptionSheet() async {
    try {
      InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
          InAppPurchase.instance.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      
      await iosPlatformAddition.presentCodeRedemptionSheet();
      debugPrint('[SuperwallDelegate] Native redemption sheet presented successfully');
    } catch (e) {
      debugPrint('[SuperwallDelegate] Native sheet failed, falling back to URL: $e');
      _openIOSRedeemPage(); // Fallback to your existing URL method
    }
  }

  // Your existing _openIOSRedeemPage() method remains the same as fallback
}
```

## Recommendations

### For MacroTracker App

Based on your current implementation, I recommend:

1. **Add `in_app_purchase` dependency** to enable native redemption sheet
2. **Keep your current URL-based method as fallback**
3. **Use native sheet as primary method** for better UX
4. **Update your SuperwallDelegate** to support both methods

### Migration Steps

1. Add `in_app_purchase: ^3.2.2` to `pubspec.yaml`
2. Update your `CustomSuperwallDelegate` class
3. Test both methods thoroughly
4. Consider adding user preference for redemption method

## Testing

### Test Cases

```dart
// Test native redemption sheet
await UniversalRedemptionService.presentRedemption(useNativeSheet: true);

// Test URL fallback
await UniversalRedemptionService.presentRedemption(useNativeSheet: false);

// Test platform detection
if (Platform.isIOS) {
  // Test iOS-specific functionality
}
```

### Error Handling

```dart
try {
  await UniversalRedemptionService.presentRedemption();
} catch (e) {
  // Handle redemption errors
  showErrorDialog('Could not open redemption page: $e');
}
```

## Conclusion

The **native redemption sheet** using `in_app_purchase` package is the recommended approach for iOS as it provides the best user experience. Your current URL-based implementation works well as a fallback method and for maintaining cross-platform compatibility.

Both methods are valid, and you can choose based on your specific needs:
- Use **native sheet** for premium user experience
- Use **URL scheme** for simplicity and cross-platform consistency
