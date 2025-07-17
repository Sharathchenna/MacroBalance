# MacroBalance - Macro Tracking App

A modern, feature-rich macro and nutrition tracking application built with Flutter.

## Features

- 📊 Track daily macronutrients (proteins, carbs, fats)
- 📱 Cross-platform support (iOS, Android, macOS)
- 📸 AI-powered food recognition
- 🔄 Health app integration
- 🎯 Custom goal setting
- 📈 Progress tracking
- 🌙 Light/Dark theme support
- 🔐 Secure authentication
- ☁️ Cloud data sync

## Getting Started

### Prerequisites

- Flutter (latest version)
- Dart SDK
- Xcode (for iOS/macOS development)
- Android Studio (for Android development)
- An Apple Developer account (for iOS/macOS deployment)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/macrotracker.git
cd macrotracker
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Configuration

To use all features of the app, you'll need to set up:
- Supabase for backend services
- Google Sign-In credentials
- Apple Sign-In configuration
- PostHog for analytics

## Project Structure

```
lib/
├── AI/          # AI-related functionality
├── auth/        # Authentication logic
├── camera/      # Camera and image processing
├── Health/      # Health app integration
├── models/      # Data models
├── providers/   # State management
├── screens/     # UI screens
├── services/    # Backend services
├── theme/       # App theming
├── utils/       # Utility functions
└── widgets/     # Reusable widgets
```

## Development

This project follows Flutter best practices and uses:
- Provider for state management
- Supabase for backend services
- PostHog for analytics
- Google's Gemini AI for food recognition
- Custom UI components for a consistent experience

## Building for Production

### iOS
```bash
flutter build ios --release
```

### Android
```bash
flutter build apk --release
```

### macOS
```bash
flutter build macos --release
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Flutter team for the amazing framework
- Supabase for backend services
- PostHog for analytics
- All contributors and users of the app

# MacroTracker Superwall + RevenueCat Hard Paywall Implementation

## Overview

MacroTracker implements a hard paywall approach using **Superwall** for paywall presentation and **RevenueCat** for subscription management. A hard paywall blocks access to the entire app until a subscription is purchased.

## Implementation Details

### SuperwallGate Component

The implementation uses a `SuperwallGate` component that wraps all routes in the app. This gate integrates with Superwall to present paywalls and checks RevenueCat for subscription validation.

Key features:
- Blocks all app functionality until a subscription is purchased
- Remote paywall configuration via Superwall dashboard
- A/B testing and analytics through Superwall
- RevenueCat handles subscription management
- Proper subscription status management

### Superwall + RevenueCat Integration

**Superwall** is used for:
1. Remote paywall configuration
2. A/B testing capabilities
3. Paywall presentation and UI
4. Analytics and conversion tracking

**RevenueCat** is used for:
1. In-app purchase management
2. Subscription validation
3. Cross-platform subscription handling
4. Subscription status monitoring

## Code Structure

### Key Components

1. **SuperwallGate**: Wraps all routes and manages paywall presentation
2. **SuperwallService**: Handles Superwall SDK integration
3. **SuperwallPlacements**: Defines placement constants and helper methods
4. **SubscriptionProvider**: Manages subscription state throughout the app

### Configuration

Both SDKs are initialized in `main.dart`:
- Superwall SDK with API key for paywall presentation
- RevenueCat SDK with API keys for subscription management

## App Store Submission Guidelines

When submitting an app with a hard paywall, ensure:

1. The full billed amount is clearly shown
2. Introductory offer details (if any) are clearly disclosed
3. Opportunity to cancel is clearly stated
4. Terms & conditions and privacy policy are accessible
5. No misleading marketing text

## Testing

To test the paywall:
1. Use RevenueCat sandbox mode for iOS
2. Use Google Play testing tracks for Android
3. Verify all subscription states are handled correctly

## Development Notes

- The `allowDismissal: false` parameter ensures users cannot dismiss the paywall without subscribing
- Subscription status is refreshed after any interaction with the paywall
- A snackbar message informs users that subscription is required if they attempt to dismiss the paywall

## Resources

- [RevenueCat Documentation](https://www.revenuecat.com/docs/welcome/overview)
- [RevenueCat Paywalls](https://www.revenuecat.com/docs/tools/paywalls)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Google Play Policies](https://play.google.com/about/developer-content-policy/)
