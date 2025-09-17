# Notification System Setup Guide

## Overview
The MacroTracker notification system now supports both local notifications and Firebase Cloud Messaging (FCM) with full database integration.

## Features Implemented

✅ **Local Notifications**
- Immediate notifications
- Scheduled notifications
- Test functionality

✅ **Firebase Cloud Messaging (FCM)**
- Push notifications from server
- Token management
- Background message handling
- Test functionality

✅ **Database Integration**
- User notification preferences
- FCM token storage
- Supabase Edge Function integration

## Database Schema

### Required Tables

You need to create these tables in your Supabase database:

#### 1. `user_notification_tokens`
```sql
CREATE TABLE user_notification_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, fcm_token)
);

-- Enable RLS
ALTER TABLE user_notification_tokens ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can insert their own tokens" ON user_notification_tokens
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own tokens" ON user_notification_tokens
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own tokens" ON user_notification_tokens
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own tokens" ON user_notification_tokens
    FOR DELETE USING (auth.uid() = user_id);
```

#### 2. `user_notification_preferences`
```sql
CREATE TABLE user_notification_preferences (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    enabled BOOLEAN DEFAULT true,
    meal_reminders BOOLEAN DEFAULT true,
    weekly_reports BOOLEAN DEFAULT true,
    meal_reminder_time TIME DEFAULT '12:00:00',
    weekly_report_day INTEGER DEFAULT 1 CHECK (weekly_report_day >= 0 AND weekly_report_day <= 6),
    weekly_report_time TIME DEFAULT '09:00:00',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE user_notification_preferences ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can insert their own preferences" ON user_notification_preferences
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own preferences" ON user_notification_preferences
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own preferences" ON user_notification_preferences
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own preferences" ON user_notification_preferences
    FOR DELETE USING (auth.uid() = user_id);
```

## Testing the Notification System

### 1. Test Local Notifications
```dart
// This will show an immediate notification and schedule one for 5 seconds later
await NotificationService().scheduleTestLocalNotification();
```

### 2. Test Firebase Cloud Messaging
```dart
// This requires user to be logged in and calls your Supabase Edge Function
await NotificationService().testFirebaseCloudMessaging();
```

### 3. Using the Test Widget
The notification test widget is available in `lib/widgets/notification_test_widget.dart`. You can add it to any screen:

```dart
import 'package:macrotracker/widgets/notification_test_widget.dart';

// In your build method
NotificationTestWidget()
```

## Key Features

### Automatic FCM Token Management
- Tokens are automatically obtained when the service initializes
- Tokens are saved to database when user logs in
- Tokens are refreshed automatically when they change
- Multiple tokens per user are supported (for multiple devices)

### User Preferences
```dart
// Save preferences
await NotificationService().saveNotificationPreferences(
  enabled: true,
  mealReminders: true,
  weeklyReports: false,
  mealReminderTime: '12:00:00',
  weeklyReportDay: 1, // Monday
  weeklyReportTime: '09:00:00',
);

// Get preferences
final preferences = await NotificationService().getNotificationPreferences();
```

### Utility Methods
```dart
// Get current FCM token
String? token = await NotificationService().getFCMToken();

// Refresh FCM token
await NotificationService().refreshFCMToken();

// Cancel specific notification
await NotificationService().cancelNotification(123);

// Cancel all notifications
await NotificationService().cancelAllNotifications();
```

## Integration with Supabase Edge Functions

The service integrates with your existing Supabase Edge Functions:

- **send-notifications**: Sends FCM messages using stored tokens
- **schedule-notifications**: Scheduled via cron to send automated notifications

### Supported Notification Types
- `test_notification`: For testing purposes
- `meal_reminder`: Daily meal logging reminders
- `weekly_report`: Weekly nutrition reports

## Debugging

All methods include extensive logging with `[NotificationService]` prefix. Check your console for:

- Initialization status
- FCM token generation
- Database operations
- Permission requests
- Message handling

## Troubleshooting

### Common Issues

1. **FCM Token Not Generated**
   - Check internet connection
   - Verify Firebase configuration
   - Check console for initialization errors

2. **Notifications Not Received**
   - Verify permissions are granted in device settings
   - Check notification preferences in database
   - Test local notifications first

3. **Database Errors**
   - Ensure tables are created with correct schema
   - Verify RLS policies are in place
   - Check user authentication status

### Testing Steps
1. Test local notifications first (no network required)
2. Verify FCM token generation in console
3. Check database for saved tokens
4. Test FCM with edge function
5. Verify notification preferences are saved

## Security Notes

- All database operations respect Row Level Security (RLS)
- FCM tokens are user-specific and protected
- Background message handler is secure and minimal
- Edge functions validate user permissions before sending

## Platform-Specific Notes

### iOS
- Requires notification usage description in Info.plist ✅
- Supports background app refresh for notifications
- APNs certificates must be configured in Firebase Console

### Android
- Requires POST_NOTIFICATIONS permission for Android 13+ ✅
- Notification channels are automatically configured
- Google Services JSON must be properly configured ✅

The notification system is now fully functional and ready for production use! 