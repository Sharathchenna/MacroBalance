import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/firebase_options.dart'; // Import firebase_options

// Add this top-level function for the background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, like Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
  // You can add custom logic here if needed in the future
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // For handling notification when app is in background/terminated and tapped
  final selectNotificationSubject = ValueNotifier<String?>(null);

  Future<void> initialize() async {
    // Initialize local notification plugin
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestSoundPermission: true, // Request sound permission during init
      requestBadgePermission: true,  // Request badge permission during init
      requestAlertPermission: true, // Request alert permission during init
      // onDidReceiveLocalNotification is deprecated here, handled in initialize()
    );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap when app is in foreground/background
        debugPrint('Local notification tapped with payload: ${response.payload}');
        selectNotificationSubject.value = response.payload;
      },
    );

    // Request foreground presentation options for iOS (needed for iOS 10+)
    // This ensures foreground notifications are shown using flutter_local_notifications
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true, // Required to display a heads up notification
      badge: true,
      sound: true,
    );

    // Request permission for iOS (redundant if requested in iosSettings, but safe)
    if (Platform.isIOS) {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Configure notification channels for Android
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'meal_reminders', // id
        'Meal Reminders', // title
        description: 'Notifications to remind you to log your meals',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
       debugPrint('Foreground FCM message received: ${message.notification?.title}');
      _showNotification(message); // Use local notifications to display foreground FCM
    });

    // Set the background messaging handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle notification tap when app is opened from terminated state
    final RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
       debugPrint('App opened from terminated state via FCM: ${initialMessage.notification?.title}');
       // Handle initial message payload if needed, e.g., navigate
       // selectNotificationSubject.value = initialMessage.data['type']; // Example
    }

    // Handle notification tap when app is opened from background state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
       debugPrint('App opened from background state via FCM: ${message.notification?.title}');
       // Handle message payload if needed, e.g., navigate
       // selectNotificationSubject.value = message.data['type']; // Example
    });


    // Get FCM token and save to Supabase
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveFcmToken(token);
    }

    // Listen for token refreshes
    _messaging.onTokenRefresh.listen(_saveFcmToken);

    // Remove the potentially redundant method channel handler unless specifically needed
    // const platform = MethodChannel('app.macrobalance.com/fcm');
    // platform.setMethodCallHandler((MethodCall call) async {
    //   debugPrint('FCM method channel received: ${call.method}');
    //   if (call.method == 'updateFCMToken') {
    //     final token = call.arguments as String;
    //     debugPrint('Received FCM token from iOS: $token');
    //     await _saveFcmToken(token);
    //     return;
    //   }
    //   return;
    // });
  }

  // Handler for older iOS versions (before iOS 10) receiving local notifications
  void onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) async {
    // display a dialog with the notification details, tap ok to go to another page
     debugPrint('Received local notification on older iOS: $title');
     selectNotificationSubject.value = payload;
  }


  Future<void> _saveFcmToken(String token) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
         debugPrint('Cannot save FCM token: User not logged in.');
         return;
      }

      await Supabase.instance.client.from('user_notification_tokens').upsert(
        {
          'user_id': currentUser.id,
          'fcm_token': token,
          'device_name': Platform.isIOS ? 'iOS Device' : 'Android Device',
          'updated_at': DateTime.now().toIso8601String(),
        },
        // Ensure upsert happens based on user_id and fcm_token
        onConflict: 'user_id, fcm_token', // Specify the conflict columns
      );

      debugPrint('FCM token saved/updated in Supabase: $token');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  // Renamed to reflect it's showing local notifications (also used for foreground FCM)
  Future<void> _showLocalNotification({
      required int id,
      required String title,
      required String body,
      String? payload,
      NotificationDetails? details // Allow custom details
  }) async {
     await _localNotifications.show(
        id,
        title,
        body,
        details ?? // Use default details if none provided
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'meal_reminders', // Use your channel ID
            'Meal Reminders', // Use your channel name
            channelDescription: 'Notifications to remind you to log your meals',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher', // Ensure this icon exists
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            // You can add categoryIdentifier here for actions
          ),
        ),
        payload: payload,
      );
  }

  // Handles displaying FCM messages received while the app is in the foreground
  Future<void> _showNotification(RemoteMessage message) async {
    final notification = message.notification;

    if (notification != null) {
       debugPrint('Displaying foreground FCM as local notification: ${notification.title}');
       await _showLocalNotification(
          id: notification.hashCode, // Use a unique ID
          title: notification.title ?? 'New Message',
          body: notification.body ?? '',
          payload: message.data['type'], // Example payload extraction
          // Use platform-specific details from the FCM message if available
          // details: NotificationDetails(...)
       );
    }
  }

  // --- Test Functions ---

  /// Schedules a test local notification to appear after 5 seconds.
  Future<void> scheduleTestLocalNotification() async {
    debugPrint('Scheduling test local notification...');
    await _showLocalNotification(
      id: 999, // Unique ID for the test notification
      title: 'Test Local Notification',
      body: 'This is a test local notification scheduled from the app.',
      payload: 'test_local_payload',
    );
     debugPrint('Test local notification displayed/scheduled.');
  }

  /// Tests a Firebase Cloud Messaging (FCM) notification through the server.
  /// This tests the full end-to-end flow including APN on iOS.
  Future<void> testFirebaseCloudMessaging() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        debugPrint('Cannot test FCM: User not logged in.');
        throw Exception('User not logged in');
      }

      // Get the FCM token first to ensure it's registered
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveFcmToken(token);
        debugPrint('FCM token refreshed before test: $token');
      } else {
        debugPrint('Warning: FCM token is null');
      }

      debugPrint('Sending test notification for user: ${currentUser.id}');
      
      // Define request body
      final requestBody = {
        'type': 'test_notification',
        'userId': currentUser.id,
      };
      
      debugPrint('Request body: ${requestBody.toString()}');

      // Call the Supabase Edge Function to send a test notification
      final response = await Supabase.instance.client.functions.invoke(
        'send-notifications',
        body: requestBody,
      );

      debugPrint('Response status: ${response.status}');
      debugPrint('Response data: ${response.data}');

      if (response.status != 200) {
        throw Exception('Failed to send test notification: ${response.data}');
      }

      debugPrint('Test FCM notification sent successfully: ${response.data}');
      return;
    } catch (e) {
      debugPrint('Error sending test FCM notification: $e');
      rethrow; // Rethrow to handle in the UI
    }
  }

  // --- Preference Update ---

  Future<void> updateNotificationPreferences(
      bool mealReminders, bool weeklyReports,
      {String? mealReminderTime,
      int? weeklyReportDay,
      String? weeklyReportTime}) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      final preferences = {
        'user_id': currentUser.id,
        'meal_reminders': mealReminders,
        'weekly_reports': weeklyReports,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (mealReminderTime != null) {
        preferences['meal_reminder_time'] = mealReminderTime;
      }

      if (weeklyReportDay != null) {
        preferences['weekly_report_day'] = weeklyReportDay;
      }

      if (weeklyReportTime != null) {
        preferences['weekly_report_time'] = weeklyReportTime;
      }

      await Supabase.instance.client
          .from('user_notification_preferences')
          .upsert(
            preferences,
            onConflict: 'user_id', // Specify the conflict column
          );

      debugPrint('Notification preferences updated');
    } catch (e) {
      debugPrint('Error updating notification preferences: $e');
    }
  }
}
