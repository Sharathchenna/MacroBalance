# PostHog Screen Tracking Implementation

## Overview

This document outlines the comprehensive PostHog screen tracking implementation across the MacroTracker Flutter app. PostHog is integrated to provide detailed analytics on user navigation patterns, screen engagement, and user journey insights.

## Architecture

### Core Components

1. **PostHogService** (`lib/services/posthog_service.dart`)
   - Centralized service for all PostHog interactions
   - Handles initialization, event tracking, and screen tracking
   - Provides wrapper methods for common analytics events

2. **PostHogObserver** (configured in `main.dart`)
   - Automatically tracks named route navigation
   - Handles route-based screen tracking

3. **Manual Screen Tracking**
   - Individual `PostHogService.trackScreen()` calls in screen `initState()` methods
   - Ensures tracking for screens accessed via `Navigator.push()`

## Implementation Details

### 1. Service Integration

PostHog is initialized in `main.dart`:

```dart
// Initialize PostHog
await PostHogService.initialize();

// MaterialApp configuration
MaterialApp(
  navigatorObservers: [
    MyRouteObserver(),
    PosthogObserver(), // Automatic route tracking
  ],
  child: PostHogWidget( // Wraps entire app
    child: MaterialApp(...)
  )
)
```

### 2. Screen Tracking Coverage

#### ✅ Fully Tracked Screens

| Screen | PostHog Screen Name | Implementation |
|--------|-------------------|---------------|
| Dashboard | `dashboard` | Manual tracking in `initState()` |
| Account Dashboard | `account_dashboard` | Manual tracking in `initState()` |
| Food Search Page | `food_search_page` | Manual tracking in `initState()` |
| Food Detail Page | `food_detail_page` | Manual tracking in `initState()` |
| Weight Tracking | `weight_tracking_screen` | Manual tracking in `initState()` |
| Macro Tracking | `macro_tracking_screen` | Manual tracking in `initState()` |
| Steps Tracking | `steps_tracking_screen` | Manual tracking in `initState()` |
| Workout Tracking | `workout_tracking_screen` | Manual tracking in `initState()` |
| Ask AI Screen | `ask_ai_screen` | Manual tracking in `initState()` |
| Login Screen | `login_screen` | Manual tracking in `initState()` |
| Welcome Screen | `welcome_screen` | Manual tracking in `initState()` |
| Onboarding Screen | `onboarding_screen` | Manual tracking in `initState()` |
| Tracking Pages Screen | `tracking_pages_screen` | Manual tracking in `initState()` |
| Saved Foods Screen | `saved_foods_screen` | Manual tracking in `initState()` |
| Custom Paywall Screen | `CustomPaywallScreen` | Manual tracking in `initState()` |

#### 🔄 Automatically Tracked Screens (via PosthogObserver)

These screens are tracked automatically when accessed via named routes:

- `/onboarding` → Onboarding Screen
- `/dashboard` → Dashboard
- `/search` → Food Search Page
- `/account` → Account Dashboard
- `/weightTracking` → Weight Tracking Screen
- `/macroTracking` → Macro Tracking Screen
- `/savedFoods` → Saved Foods Screen

### 3. Implementation Pattern

Each screen follows this consistent pattern:

```dart
import '../services/posthog_service.dart';

class ExampleScreen extends StatefulWidget {
  // ... widget definition
}

class _ExampleScreenState extends State<ExampleScreen> {
  @override
  void initState() {
    super.initState();
    
    // Track screen view
    PostHogService.trackScreen('example_screen');
    
    // ... rest of initialization
  }
}
```

### 4. Event Tracking Integration

Beyond screen tracking, the app also tracks specific user actions:

#### Food-Related Events
- `food_entry_added` - When user adds food to diary
- `search_performed` - When user searches for food
- `acquisition_source_selected` - During onboarding

#### Navigation Events
- `button_clicked` - UI interaction tracking
- `feature_used` - Feature usage analytics
- `error_occurred` - Error tracking with context

#### Subscription Events
- `subscription_started` - New subscription
- `subscription_cancelled` - Subscription cancellation

## Configuration

### PostHog Settings

```dart
// API Configuration
static const String _apiKey = 'phc_msu4KagunERf8QZvyEDNaF55LcRRAZ61tRzgTs7ot2I';
static const String _host = 'https://us.i.posthog.com';

// Features Enabled
config.sessionReplay = true;
config.debug = true; // Enable in development
```

### Platform-Specific Configuration

#### iOS (`ios/Runner/Info.plist`)
```xml
<key>com.posthog.posthog.API_KEY</key>
<string>phc_msu4KagunERf8QZvyEDNaF55LcRRAZ61tRzgTs7ot2I</string>
<key>com.posthog.posthog.CAPTURE_APPLICATION_LIFECYCLE_EVENTS</key>
<true/>
<key>com.posthog.posthog.DEBUG</key>
<true/>
<key>com.posthog.posthog.POSTHOG_HOST</key>
<string>https://us.i.posthog.com</string>
<key>com.posthog.posthog.AUTO_INIT</key>
<false/>
```

#### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<meta-data
    android:name="com.posthog.posthog.AUTO_INIT"
    android:value="false" />
```

## Analytics Capabilities

### User Journey Analysis
- Complete user flow from onboarding to feature usage
- Screen transition patterns and user navigation behavior
- Session duration and engagement metrics

### Feature Usage Tracking
- Which screens are most/least visited
- User interaction patterns within screens
- Feature adoption and usage frequency

### Performance Monitoring
- Screen load times and user experience metrics
- Error tracking with screen context
- User retention and churn analysis

## Data Privacy & Compliance

### User Identification
- Users are identified after authentication via `PostHogService.identifyUser()`
- Anonymous tracking before login for onboarding analytics
- User properties stored include basic profile information

### Data Collection
- Screen names and timestamps
- User interaction events (anonymized)
- Performance and error metrics
- No sensitive personal data (passwords, detailed health data)

### Session Replay
- Enabled for user experience optimization
- Sensitive input fields are automatically masked
- Can be disabled per user preference

## Monitoring & Debugging

### Development
- Debug logging enabled via `config.debug = true`
- Console output for all tracking events
- PostHog Live Events view for real-time monitoring

### Production
- Error tracking with screen context
- Performance monitoring
- User feedback correlation with analytics data

## Best Practices

### Screen Naming Convention
- Use snake_case for consistency
- Include descriptive, hierarchical names
- Avoid PII in screen names

### Event Properties
- Include relevant context (user state, feature flags)
- Use consistent property naming
- Avoid nested objects in properties

### Performance Considerations
- All tracking calls are non-blocking
- Automatic batching and retry logic
- Minimal impact on app performance

## Future Enhancements

### Planned Features
1. **Custom User Segments**: Define user cohorts based on behavior
2. **A/B Testing Integration**: Feature flag integration with PostHog
3. **Advanced Funnel Analysis**: Conversion tracking across user journeys
4. **Real-time Alerts**: Monitoring for critical user experience issues

### Maintenance Tasks
1. Regular review of tracked events and screen coverage
2. Performance impact monitoring
3. Data privacy compliance reviews
4. Analytics dashboard optimization

## Troubleshooting

### Common Issues

1. **Events Not Appearing**
   - Check API key configuration
   - Verify network connectivity
   - Confirm PostHog initialization completed

2. **Duplicate Screen Tracking**
   - Review both manual tracking and PosthogObserver coverage
   - Ensure only one tracking method per screen

3. **Missing User Identification**
   - Verify `identifyUser()` called after successful authentication
   - Check user ID format and consistency

### Debug Commands

```dart
// Enable debug mode
PostHogService.setDebugMode(true);

// Force flush events
PostHogService._instance.flush();

// Reset user session
PostHogService.resetUser();
```

## Support & Resources

- **PostHog Documentation**: https://posthog.com/docs
- **Flutter SDK**: https://posthog.com/docs/libraries/flutter
- **Internal Service**: `lib/services/posthog_service.dart`
- **Configuration**: App-level settings in `main.dart`

---

**Last Updated**: January 2025  
**Version**: 1.0.0  
**Maintainer**: Development Team 