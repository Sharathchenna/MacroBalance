import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/posthog_service.dart';

void main() {
  group('PostHogService', () {
    setUp(() async {
      await PostHogService.initialize();
      PostHogService.setDebugMode(true);
    });

    group('Session Replay', () {
      test('setSessionReplayEnabled sends correct event', () {
        PostHogService.setSessionReplayEnabled(true);
      });

      test('setSessionReplayProperties sends correct event', () {
        PostHogService.setSessionReplayProperties({
          'mask_sensitive_data': true,
          'record_canvas': true,
          'mask_text_inputs': true,
        });
      });
    });

    group('Product Analytics Events', () {
      test('trackFeatureUsage sends correct event', () {
        PostHogService.trackFeatureUsage(
          'meal_planner',
          properties: {
            'time_spent_seconds': 120,
            'success': true,
          },
        );
      });

      test('trackButtonClick sends correct event', () {
        PostHogService.trackButtonClick(
          'add_food_button',
          properties: {
            'screen': 'food_diary',
            'time_of_day': 'morning',
          },
        );
      });

      test('trackSearch sends correct event', () {
        PostHogService.trackSearch(
          'chicken breast',
          properties: {
            'result_count': 15,
            'selected_item': 'chicken_breast_100g',
          },
        );
      });

      test('trackFoodEntry sends correct event', () {
        PostHogService.trackFoodEntry(
          foodName: 'Chicken Breast',
          calories: 165,
          protein: 31,
          carbs: 0,
          fat: 3.6,
          properties: {
            'meal_type': 'lunch',
            'portion_size': '100g',
          },
        );
      });

      test('trackWeightEntry sends correct event', () {
        PostHogService.trackWeightEntry(
          weight: 75.5,
          unit: 'kg',
          properties: {
            'time_of_day': 'morning',
            'trend': 'decreasing',
          },
        );
      });

      test('trackStepsEntry sends correct event', () {
        PostHogService.trackStepsEntry(
          steps: 10000,
          properties: {
            'date': DateTime.now().toIso8601String(),
            'goal_achieved': true,
          },
        );
      });

      test('trackGoalSet sends correct event', () {
        PostHogService.trackGoalSet(
          goalType: 'weight_loss',
          targetValue: 70,
          unit: 'kg',
          properties: {
            'timeline_months': 3,
            'current_weight': 75.5,
          },
        );
      });

      test('trackGoalAchieved sends correct event', () {
        PostHogService.trackGoalAchieved(
          goalType: 'protein_intake',
          achievedValue: 150,
          unit: 'g',
          properties: {
            'days_to_achieve': 30,
            'average_daily_intake': 145,
          },
        );
      });

      test('trackAppOpen sends correct event', () {
        PostHogService.trackAppOpen(
          source: 'push_notification',
          properties: {
            'notification_type': 'reminder',
            'last_used_days_ago': 1,
          },
        );
      });

      test('trackError sends correct event', () {
        PostHogService.trackError(
          errorType: 'network_error',
          errorMessage: 'Failed to sync data',
          screen: 'food_diary',
          properties: {
            'retry_count': 3,
            'last_sync_time': DateTime.now().toIso8601String(),
          },
        );
      });
    });

    group('Subscription Events', () {
      test('trackSubscriptionStarted sends correct event', () {
        PostHogService.trackSubscriptionStarted(
          planId: 'premium_monthly',
          planName: 'Premium Monthly',
          price: 9.99,
          currency: 'USD',
          interval: 'monthly',
          additionalProperties: {
            'promotion_code': 'WELCOME50',
            'is_trial': true,
          },
        );
      });

      test('trackSubscriptionCancelled sends correct event', () {
        PostHogService.trackSubscriptionCancelled(
          planId: 'premium_monthly',
          planName: 'Premium Monthly',
          reason: 'Too expensive',
          additionalProperties: {
            'days_until_expiry': 30,
            'refund_requested': false,
          },
        );
      });

      test('trackSubscriptionRenewed sends correct event', () {
        PostHogService.trackSubscriptionRenewed(
          planId: 'premium_monthly',
          planName: 'Premium Monthly',
          price: 9.99,
          currency: 'USD',
          additionalProperties: {
            'renewal_date': DateTime.now().toIso8601String(),
            'months_subscribed': 6,
          },
        );
      });

      test('trackSubscriptionPaused sends correct event', () {
        PostHogService.trackSubscriptionPaused(
          planId: 'premium_monthly',
          planName: 'Premium Monthly',
          reason: 'Vacation',
          resumeDate: DateTime.now().add(const Duration(days: 30)),
          additionalProperties: {
            'pause_duration_days': 30,
            'auto_resume': true,
          },
        );
      });

      test('trackSubscriptionResumed sends correct event', () {
        PostHogService.trackSubscriptionResumed(
          planId: 'premium_monthly',
          planName: 'Premium Monthly',
          additionalProperties: {
            'pause_duration_days': 30,
            'resumed_early': true,
          },
        );
      });

      test('trackSubscriptionChanged sends correct event', () {
        PostHogService.trackSubscriptionChanged(
          oldPlanId: 'premium_monthly',
          oldPlanName: 'Premium Monthly',
          newPlanId: 'premium_yearly',
          newPlanName: 'Premium Yearly',
          priceDifference: -20.00,
          currency: 'USD',
          additionalProperties: {
            'upgrade_reason': 'Better value',
            'annual_savings': 20.00,
          },
        );
      });

      test('trackPaymentFailed sends correct event', () {
        PostHogService.trackPaymentFailed(
          planId: 'premium_monthly',
          planName: 'Premium Monthly',
          errorCode: 'insufficient_funds',
          errorMessage:
              'The card has insufficient funds to complete the purchase',
          additionalProperties: {
            'attempt_count': 1,
            'will_retry': true,
            'retry_date':
                DateTime.now().add(const Duration(days: 3)).toIso8601String(),
          },
        );
      });
    });
  });
}
