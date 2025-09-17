import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final _supabase = Supabase.instance.client;
  late FirebaseMessaging _firebaseMessaging;

  bool _isInitialized = false;
  String? _fcmToken;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('[NotificationService] Starting initialization...');
      
      // Initialize timezone data
      tz.initializeTimeZones();

      // Initialize Firebase Messaging
      _firebaseMessaging = FirebaseMessaging.instance;
      
      // Initialize platform-specific settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Request permissions
      await _requestPermissions();

      // Setup FCM
      await _setupFirebaseMessaging();

      _isInitialized = true;
      debugPrint('[NotificationService] Initialization completed successfully');
    } catch (e) {
      debugPrint('[NotificationService] Error during initialization: $e');
    }
  }

  Future<void> _requestPermissions() async {
    debugPrint('[NotificationService] Requesting permissions...');
    
    if (Platform.isIOS) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      await Permission.notification.request();
    }

    // Request FCM permissions
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('[NotificationService] Notification permission status: ${settings.authorizationStatus}');
  }

  Future<void> _setupFirebaseMessaging() async {
    debugPrint('[NotificationService] Setting up Firebase Messaging...');
    
    try {
      // Get FCM token
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('[NotificationService] FCM Token obtained: ${_fcmToken?.substring(0, 20)}...');

      // Save token to database if user is logged in
      if (_fcmToken != null && _supabase.auth.currentUser != null) {
        await _saveFCMTokenToDatabase(_fcmToken!);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        debugPrint('[NotificationService] FCM Token refreshed');
        _fcmToken = newToken;
        if (_supabase.auth.currentUser != null) {
          await _saveFCMTokenToDatabase(newToken);
        }
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[NotificationService] Received foreground message: ${message.messageId}');
        _handleForegroundMessage(message);
      });

      // Handle background messages when app is opened
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[NotificationService] App opened from background message: ${message.messageId}');
        _handleMessageTap(message);
      });

      // Handle app opened from terminated state
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[NotificationService] App opened from terminated state: ${initialMessage.messageId}');
        _handleMessageTap(initialMessage);
      }

    } catch (e) {
      debugPrint('[NotificationService] Error setting up Firebase Messaging: $e');
    }
  }

  Future<void> _saveFCMTokenToDatabase(String token) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      debugPrint('[NotificationService] Saving FCM token to database for user: $userId');

      await _supabase.from('user_notification_tokens').upsert({
        'user_id': userId,
        'fcm_token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('[NotificationService] FCM token saved successfully');
    } catch (e) {
      debugPrint('[NotificationService] Error saving FCM token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // Show local notification when app is in foreground
    showNotification(
      id: message.hashCode,
      title: message.notification?.title ?? 'New Notification',
      body: message.notification?.body ?? 'You have a new message',
      payload: message.data.toString(),
    );
  }

  void _handleMessageTap(RemoteMessage message) {
    debugPrint('[NotificationService] Handling message tap: ${message.data}');
    // Handle navigation based on message data
    // You can add navigation logic here based on message.data
  }

  void _onNotificationTap(NotificationResponse notificationResponse) {
    debugPrint('[NotificationService] Local notification tapped: ${notificationResponse.payload}');
    // Handle local notification tap
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    debugPrint('[NotificationService] Showing local notification: $title');

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'macrotracker_channel',
      'MacroTracker Notifications',
      channelDescription: 'Notifications for MacroTracker app',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    debugPrint('[NotificationService] Scheduling notification for: $scheduledDate');

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'macrotracker_scheduled_channel',
      'MacroTracker Scheduled Notifications',
      channelDescription: 'Scheduled notifications for MacroTracker app',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // Convert DateTime to TZDateTime
    final tz.TZDateTime scheduledTZDateTime = tz.TZDateTime.from(
      scheduledDate,
      tz.local,
    );

          await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTZDateTime,
      platformChannelSpecifics,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // NEW TEST METHODS
  Future<void> scheduleTestLocalNotification() async {
    debugPrint('[NotificationService] Scheduling test local notification...');
    
    try {
      await showNotification(
        id: DateTime.now().millisecondsSinceEpoch,
        title: 'Test Local Notification',
        body: 'Your local notifications are working perfectly! 🎉',
        payload: 'test_local_notification',
      );
      
      // Also schedule one for 5 seconds from now
      await scheduleNotification(
        id: DateTime.now().millisecondsSinceEpoch + 1,
        title: 'Scheduled Test Notification',
        body: 'This scheduled notification proves your timing works! ⏰',
        scheduledDate: DateTime.now().add(const Duration(seconds: 5)),
        payload: 'test_scheduled_notification',
      );
      
      debugPrint('[NotificationService] Test local notifications sent successfully');
    } catch (e) {
      debugPrint('[NotificationService] Error sending test local notification: $e');
      rethrow;
    }
  }

  Future<void> testFirebaseCloudMessaging() async {
    debugPrint('[NotificationService] Testing Firebase Cloud Messaging...');
    
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in. Please log in to test FCM.');
      }

      if (_fcmToken == null) {
        throw Exception('FCM token not available. Please check your internet connection and try again.');
      }

      // Save the current token to database first
      await _saveFCMTokenToDatabase(_fcmToken!);

      // Call the Supabase Edge Function to send test notification
      final response = await _supabase.functions.invoke(
        'send-notifications',
        body: {
          'type': 'test_notification',
          'userId': userId,
        },
      );

      if (response.data == null) {
        throw Exception('Failed to send test FCM: No response data received');
      }

      debugPrint('[NotificationService] Test FCM sent successfully: ${response.data}');
    } catch (e) {
      debugPrint('[NotificationService] Error sending test FCM: $e');
      rethrow;
    }
  }

  // USER PREFERENCE METHODS
  Future<void> saveNotificationPreferences({
    required bool enabled,
    required bool mealReminders,
    required bool weeklyReports,
    String? mealReminderTime,
    int? weeklyReportDay,
    String? weeklyReportTime,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      debugPrint('[NotificationService] Saving notification preferences for user: $userId');

      await _supabase.from('user_notification_preferences').upsert({
        'user_id': userId,
        'enabled': enabled,
        'meal_reminders': mealReminders,
        'weekly_reports': weeklyReports,
        'meal_reminder_time': mealReminderTime,
        'weekly_report_day': weeklyReportDay,
        'weekly_report_time': weeklyReportTime,
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('[NotificationService] Notification preferences saved successfully');
    } catch (e) {
      debugPrint('[NotificationService] Error saving notification preferences: $e');
    }
  }

  // Convenience method for updating notification preferences with simplified parameters
  Future<void> updateNotificationPreferences(
    bool mealReminders,
    bool weeklyReports, {
    String? mealReminderTime,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      debugPrint('[NotificationService] Updating notification preferences for user: $userId');

      // Get current preferences to preserve other settings
      Map<String, dynamic>? currentPrefs;
      try {
        currentPrefs = await getNotificationPreferences();
      } catch (e) {
        debugPrint('[NotificationService] Could not get current preferences, using defaults: $e');
      }

      await _supabase.from('user_notification_preferences').upsert({
        'user_id': userId,
        'enabled': mealReminders || weeklyReports, // Enable if any notification type is enabled
        'meal_reminders': mealReminders,
        'weekly_reports': weeklyReports,
        'meal_reminder_time': mealReminderTime ?? currentPrefs?['meal_reminder_time'] ?? '19:00:00',
        'weekly_report_day': currentPrefs?['weekly_report_day'] ?? 0, // Sunday default
        'weekly_report_time': currentPrefs?['weekly_report_time'] ?? '09:00:00',
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('[NotificationService] Notification preferences updated successfully');
    } catch (e) {
      debugPrint('[NotificationService] Error updating notification preferences: $e');
    }
  }

  Future<Map<String, dynamic>?> getNotificationPreferences() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('user_notification_preferences')
          .select()
          .eq('user_id', userId)
          .single();

      return response;
    } catch (e) {
      debugPrint('[NotificationService] Error getting notification preferences: $e');
      return null;
    }
  }

  // UTILITY METHODS
  Future<String?> getFCMToken() async {
    if (_fcmToken == null) {
      _fcmToken = await _firebaseMessaging.getToken();
    }
    return _fcmToken;
  }

  Future<void> refreshFCMToken() async {
    debugPrint('[NotificationService] Refreshing FCM token...');
    try {
      await _firebaseMessaging.deleteToken();
      _fcmToken = await _firebaseMessaging.getToken();
      
      if (_fcmToken != null && _supabase.auth.currentUser != null) {
        await _saveFCMTokenToDatabase(_fcmToken!);
      }
      
      debugPrint('[NotificationService] FCM token refreshed successfully');
    } catch (e) {
      debugPrint('[NotificationService] Error refreshing FCM token: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
    debugPrint('[NotificationService] Cancelled notification with ID: $id');
  }

  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
    debugPrint('[NotificationService] Cancelled all notifications');
  }

  // CLEANUP
  Future<void> dispose() async {
    debugPrint('[NotificationService] Disposing notification service...');
    // Cancel all notifications
    await cancelAllNotifications();
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[NotificationService] Background message received: ${message.messageId}');
  // Handle background message here if needed
}