# MacroBalance - Advanced Nutrition & Fitness Tracking

## Latest Updates

### Workout Execution Screen Improvements ✨

The workout execution screen has been completely redesigned with premium UX features and consistent design system integration:

#### 🎨 Design System Integration
- **Premium Colors**: Consistent use of the app's color palette (PremiumColors.slate900, emerald500, etc.)
- **Typography**: Proper use of PremiumTypography system for all text elements
- **Animations**: Smooth transitions using PremiumAnimations timing and curves
- **Shadows & Elevation**: Consistent with AppTheme shadow system

#### 🚀 UX Enhancements Implemented

1. **Enhanced Progress Visualization**
   - Dual progress bars: overall workout progress + current exercise set progress
   - Real-time visual feedback with smooth animations
   - Set completion tracking with emerald progress indicators

2. **Advanced Haptic Feedback System**
   - Light impact for navigation and minor actions
   - Medium impact for set completions and transitions
   - Heavy impact for exercise completion and workout finish
   - Countdown alerts with haptic cues (10s warning, 3s final countdown)
   - Celebration double-haptic on workout completion

3. **Rest Period Customization**
   - +15s / -15s adjustment buttons during rest
   - Visual feedback for time modifications
   - Smooth animations for rest circle progress

4. **Exercise Instructions Toggle**
   - Optional exercise instructions display
   - Clean, readable instructions in overlay format
   - Toggleable via info button in app bar

5. **Swipe Gesture Controls**
   - Swipe right to complete sets (velocity-based detection)
   - Visual hint showing swipe gesture availability
   - Immediate haptic feedback on gesture completion

6. **Enhanced Rest Screen**
   - Animated rest circle with countdown
   - Color-coded urgency (amber → red for final countdown)
   - "Get Ready" alerts for final 3 seconds
   - Next exercise preview during rest periods

7. **Improved Visual Hierarchy**
   - Better contrast and readability
   - Consistent spacing and padding
   - Premium card designs with proper elevation
   - Clean, modern button designs

8. **Smart Pause States**
   - Clear visual indicators when paused
   - Proper timer state management
   - Consistent pause/play controls

#### 🔮 Additional UX Suggestions for Future Implementation

1. **Audio & Voice Features**
   - Optional voice coaching and countdown announcements
   - Audio cues for rest periods and exercise transitions
   - Background music integration with auto-ducking

2. **Smart Watch Integration**
   - Apple Watch/WearOS companion app
   - Heart rate monitoring integration
   - Haptic feedback on watch for hands-free operation

3. **Advanced Analytics**
   - Real-time calorie burn estimation
   - Form analysis using device sensors
   - Recovery time recommendations based on performance

4. **Social & Gamification**
   - Workout sharing with friends
   - Achievement badges and milestones
   - Leaderboards and challenges

5. **Accessibility Enhancements**
   - VoiceOver support for visually impaired users
   - Larger touch targets option
   - High contrast mode support
   - Voice command integration

6. **Smart Adaptations**
   - Auto-adjust rest times based on performance
   - Smart exercise substitutions based on available equipment
   - Fatigue detection and workout modifications

7. **Environmental Awareness**
   - Auto-pause when phone is face down
   - Ambient light sensor integration for UI brightness
   - Noise level detection for audio cue adjustments

8. **Recovery & Health Integration**
   - Sleep quality integration affecting workout intensity
   - Stress level monitoring integration
   - Recovery recommendations between workouts

9. **Advanced Customization**
   - Custom rest period templates per exercise type
   - Personalized motivation messages
   - Custom haptic feedback patterns

10. **Offline & Sync Features**
    - Complete offline workout capability
    - Cloud sync with conflict resolution
    - Backup and restore workout data

The current implementation focuses on the most impactful improvements that enhance the core workout experience while maintaining the app's premium design language.

## Features

- **Calorie Tracking**: Monitor daily caloric intake with precision
- **Macro Balance**: Track proteins, carbohydrates, and fats
- **Meal Planning**: AI-powered meal suggestions
- **Recipe Management**: Custom recipes with nutritional analysis
- **Workout Planning**: Comprehensive exercise routines
- **Progress Analytics**: Detailed insights and trends
- **Premium UI**: Modern, accessible design system

## Getting Started

### Prerequisites
- Flutter 3.0+
- Dart 3.0+
- iOS 12.0+ / Android API 21+

### Installation
```bash
git clone https://github.com/yourusername/macrobalance.git
cd macrobalance
flutter pub get
flutter run
```

## Architecture

The app follows a clean architecture pattern with:
- **Models**: Data structures and business logic
- **Services**: API integrations and data processing
- **Providers**: State management using Provider pattern
- **Widgets**: Reusable UI components
- **Screens**: App pages and navigation
- **Theme**: Consistent design system

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

# MacroTracker RevenueCat Hard Paywall Implementation

## Overview

MacroTracker implements a hard paywall approach using RevenueCat. A hard paywall blocks access to the entire app until a subscription is purchased. This is different from a soft paywall, which would allow partial access to app features.

## Implementation Details

### PaywallGate Component

The implementation uses a `PaywallGate` component that wraps all routes in the app. This gate checks if the user has a valid subscription before allowing access to any screen.

Key features:
- Blocks all app functionality until a subscription is purchased
- No trial or free tier access
- Clear subscription options with RevenueCat's PaywallView
- Proper subscription status management

### RevenueCat Integration

RevenueCat is used for:
1. In-app purchase management
2. Subscription validation
3. Cross-platform subscription handling
4. Paywall presentation

## Code Structure

### Key Components

1. **PaywallGate**: Wraps all routes and checks subscription status
2. **PaywallScreen**: Handles displaying the RevenueCat paywall UI
3. **SubscriptionProvider**: Manages subscription state throughout the app

### Configuration

The RevenueCat SDK is initialized in `main.dart` with the appropriate API keys for each platform.

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
