import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:flutter/foundation.dart'; // Import for debugPrint

class PostHogService {
  static const String _apiKey =
      'phc_msu4KagunERf8QZvyEDNaF55LcRRAZ61tRzgTs7ot2I'; // Replace with your actual PostHog API key
  static const String _host =
      'https://us.i.posthog.com'; // Use the US ingestion endpoint

  static final _instance = Posthog();

  static Future<void> initialize() async {
    debugPrint("[PostHogService] Starting initialization...");
    try {
      final config = PostHogConfig(_apiKey);
      config.host = _host;

      // Enable session replay
      config.sessionReplay = true;
      // Enable PostHog SDK debug logging
      config.debug = true;

      debugPrint("[PostHogService] Calling Posthog().setup()...");
      await _instance.setup(config);
      debugPrint("[PostHogService] Posthog().setup() completed.");
      // Add extra logging post-setup
      debugPrint("[PostHogService] Configured Host: ${_instance.config?.host}");
      debugPrint(
          "[PostHogService] Session Replay Enabled in Config: ${_instance.config?.sessionReplay}");
      debugPrint(
          "[PostHogService] Debug Enabled in Config: ${_instance.config?.debug}");
      debugPrint("[PostHogService] Forcing initial flush...");
      _instance.flush(); // Force an immediate flush after setup
    } catch (e, stackTrace) {
      debugPrint("[PostHogService] ERROR during Posthog().setup(): $e");
      debugPrint("[PostHogService] StackTrace: $stackTrace");
      // Optionally rethrow or handle the error appropriately
    }
    debugPrint("[PostHogService] Initialization finished.");
  }

  // Enable/disable session replay
  static void setSessionReplayEnabled(bool enabled) {
    _instance.capture(
      eventName: 'session_replay_toggle',
      properties: {
        'enabled': enabled,
      }.map((key, value) => MapEntry(key, value as Object)),
    );
  }

  // Set session replay properties
  static void setSessionReplayProperties(Map<String, dynamic> properties) {
    _instance.capture(
      eventName: 'session_replay_properties',
      properties:
          properties.map((key, value) => MapEntry(key, value as Object)),
    );
  }

  // Track custom events
  static void trackEvent(String eventName, {Map<String, dynamic>? properties}) {
    debugPrint("[PostHogService] Capturing event: $eventName with properties: $properties"); // Added log
    _instance.capture(
      eventName: eventName,
      properties:
          properties?.map((key, value) => MapEntry(key, value as Object)),
    );
  }

  // Identify users
  static void identifyUser(
    String userId, {
    Map<String, dynamic>? userProperties,
    Map<String, dynamic>? userPropertiesSetOnce,
  }) {
    debugPrint("[PostHogService] Identifying user: $userId with properties: $userProperties"); // Added log
    _instance.identify(
      userId: userId,
      userProperties:
          userProperties?.map((key, value) => MapEntry(key, value as Object)),
      userPropertiesSetOnce: userPropertiesSetOnce
          ?.map((key, value) => MapEntry(key, value as Object)),
    );
  }

  // Set user properties
  static void setUserProperties(Map<String, dynamic> properties) {
    _instance.capture(
      eventName: '\$set',
      properties:
          properties.map((key, value) => MapEntry(key, value as Object)),
    );
  }

  // Reset user identification
  static void resetUser() {
    debugPrint("[PostHogService] Resetting user identification."); // Added log
    _instance.reset();
  }

  // Track screen views
  static void trackScreen(String screenName) {
    debugPrint("[PostHogService] Tracking screen: $screenName");
    _instance.screen(screenName: screenName);
    debugPrint("[PostHogService] Screen tracked. Forcing event flush."); // Slightly modified log
    _instance.flush(); // Force send events immediately
  }

  // Enable/disable debug mode
  static void setDebugMode(bool enabled) {
    _instance.debug(enabled);
  }

  // Product Analytics Events
  static void trackFeatureUsage(String featureName,
      {Map<String, dynamic>? properties}) {
    trackEvent('feature_used', properties: {
      'feature_name': featureName,
      ...?properties,
    });
  }

  static void trackButtonClick(String buttonName,
      {Map<String, dynamic>? properties}) {
    trackEvent('button_clicked', properties: {
      'button_name': buttonName,
      ...?properties,
    });
  }

  static void trackSearch(String query, {Map<String, dynamic>? properties}) {
    trackEvent('search_performed', properties: {
      'search_query': query,
      ...?properties,
    });
  }

  static void trackFoodEntry({
    required String foodName,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    Map<String, dynamic>? properties,
  }) {
    trackEvent('food_entry_added', properties: {
      'food_name': foodName,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      ...?properties,
    });
  }

  static void trackWeightEntry({
    required double weight,
    required String unit,
    Map<String, dynamic>? properties,
  }) {
    trackEvent('weight_entry_added', properties: {
      'weight': weight,
      'unit': unit,
      ...?properties,
    });
  }

  static void trackStepsEntry({
    required int steps,
    Map<String, dynamic>? properties,
  }) {
    trackEvent('steps_entry_added', properties: {
      'steps': steps,
      ...?properties,
    });
  }

  static void trackGoalSet({
    required String goalType,
    required double targetValue,
    required String unit,
    Map<String, dynamic>? properties,
  }) {
    trackEvent('goal_set', properties: {
      'goal_type': goalType,
      'target_value': targetValue,
      'unit': unit,
      ...?properties,
    });
  }

  static void trackGoalAchieved({
    required String goalType,
    required double achievedValue,
    required String unit,
    Map<String, dynamic>? properties,
  }) {
    trackEvent('goal_achieved', properties: {
      'goal_type': goalType,
      'achieved_value': achievedValue,
      'unit': unit,
      ...?properties,
    });
  }

  static void trackAppOpen({
    required String source,
    Map<String, dynamic>? properties,
  }) {
    trackEvent('app_opened', properties: {
      'source': source,
      ...?properties,
    });
  }

  static void trackError({
    required String errorType,
    required String errorMessage,
    required String screen,
    Map<String, dynamic>? properties,
  }) {
    trackEvent('error_occurred', properties: {
      'error_type': errorType,
      'error_message': errorMessage,
      'screen': screen,
      ...?properties,
    });
  }

  // Subscription Events
  static void trackSubscriptionStarted({
    required String planId,
    required String planName,
    required double price,
    required String currency,
    required String interval,
    Map<String, dynamic>? additionalProperties,
  }) {
    final properties = {
      'plan_id': planId,
      'plan_name': planName,
      'price': price,
      'currency': currency,
      'interval': interval,
      ...?additionalProperties,
    };
    trackEvent('subscription_started', properties: properties);
  }

  static void trackSubscriptionCancelled({
    required String planId,
    required String planName,
    required String reason,
    Map<String, dynamic>? additionalProperties,
  }) {
    final properties = {
      'plan_id': planId,
      'plan_name': planName,
      'cancellation_reason': reason,
      ...?additionalProperties,
    };
    trackEvent('subscription_cancelled', properties: properties);
  }

  static void trackSubscriptionRenewed({
    required String planId,
    required String planName,
    required double price,
    required String currency,
    Map<String, dynamic>? additionalProperties,
  }) {
    final properties = {
      'plan_id': planId,
      'plan_name': planName,
      'price': price,
      'currency': currency,
      ...?additionalProperties,
    };
    trackEvent('subscription_renewed', properties: properties);
  }

  static void trackSubscriptionPaused({
    required String planId,
    required String planName,
    required String reason,
    required DateTime resumeDate,
    Map<String, dynamic>? additionalProperties,
  }) {
    final properties = {
      'plan_id': planId,
      'plan_name': planName,
      'pause_reason': reason,
      'resume_date': resumeDate.toIso8601String(),
      ...?additionalProperties,
    };
    trackEvent('subscription_paused', properties: properties);
  }

  static void trackSubscriptionResumed({
    required String planId,
    required String planName,
    Map<String, dynamic>? additionalProperties,
  }) {
    final properties = {
      'plan_id': planId,
      'plan_name': planName,
      ...?additionalProperties,
    };
    trackEvent('subscription_resumed', properties: properties);
  }

  static void trackSubscriptionChanged({
    required String oldPlanId,
    required String oldPlanName,
    required String newPlanId,
    required String newPlanName,
    required double priceDifference,
    required String currency,
    Map<String, dynamic>? additionalProperties,
  }) {
    final properties = {
      'old_plan_id': oldPlanId,
      'old_plan_name': oldPlanName,
      'new_plan_id': newPlanId,
      'new_plan_name': newPlanName,
      'price_difference': priceDifference,
      'currency': currency,
      ...?additionalProperties,
    };
    trackEvent('subscription_changed', properties: properties);
  }

  static void trackPaymentFailed({
    required String planId,
    required String planName,
    required String errorCode,
    required String errorMessage,
    Map<String, dynamic>? additionalProperties,
  }) {
    final properties = {
      'plan_id': planId,
      'plan_name': planName,
      'error_code': errorCode,
      'error_message': errorMessage,
      ...?additionalProperties,
    };
    trackEvent('payment_failed', properties: properties);
  }
}
