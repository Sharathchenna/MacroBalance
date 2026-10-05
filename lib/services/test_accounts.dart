import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'posthog_service.dart';
import 'storage_service.dart';

/// Test accounts: emails ending in @mbtest.ai skip email confirmation and can
/// "buy" the subscription for free.
///
/// Only active in debug builds, or builds made with
/// `--dart-define=TEST_ACCOUNTS=true` (for TestFlight). A normal App Store
/// build ignores the domain completely, so it can't be used to get premium
/// for free in production.
class TestAccounts {
  static const String domain = '@mbtest.ai';
  static const bool _buildFlag = bool.fromEnvironment('TEST_ACCOUNTS');

  static bool get enabledInThisBuild => kDebugMode || _buildFlag;

  static bool isTestEmail(String? email) =>
      enabledInThisBuild &&
      email != null &&
      email.trim().toLowerCase().endsWith(domain);

  /// The signed-in user is a test account in a build that allows them.
  static bool get isActive =>
      isTestEmail(Supabase.instance.client.auth.currentUser?.email);

  static String _grantKey(String userId) => 'test_subscription_$userId';

  /// The test account "bought" the subscription on this device.
  static bool get hasSubscription {
    final user = Supabase.instance.client.auth.currentUser;
    return hasSubscriptionFor(email: user?.email, userId: user?.id);
  }

  /// [hasSubscription] for a given account, so it can be checked without a
  /// signed-in session.
  static bool hasSubscriptionFor({String? email, String? userId}) =>
      isTestEmail(email) &&
      userId != null &&
      StorageService().get(_grantKey(userId)) == true;

  static Future<void> grantSubscription() {
    final user = Supabase.instance.client.auth.currentUser;
    return grantSubscriptionFor(email: user?.email, userId: user?.id);
  }

  /// Grants the free test subscription to a test account; does nothing for
  /// any other account or when signed out.
  static Future<void> grantSubscriptionFor({String? email, String? userId}) async {
    if (!isTestEmail(email) || userId == null) return;
    await StorageService().put(_grantKey(userId), true);
    PostHogService.trackEvent('test_subscription_granted');
  }

  /// Creates an already-confirmed @mbtest.ai account through the
  /// create-test-account edge function, so no confirmation email is sent.
  static Future<void> createConfirmedAccount({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await Supabase.instance.client.functions.invoke(
      'create-test-account',
      body: {'email': email.trim(), 'password': password, 'username': username},
    );
    if (response.status != 200) {
      final data = response.data;
      throw Exception(data is Map ? data['error'] ?? 'Could not create test account' : data);
    }
  }

  /// Stands in for the Superwall paywall for test accounts. Returns true when
  /// the user taps Buy (the subscription is granted), false if they cancel.
  static Future<bool> showTestPaywall(BuildContext context) async {
    final bought = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('MacroBalance Pro',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Test account: tapping Buy activates the subscription on this device '
                'without charging anything. Real users see the normal paywall.',
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Buy (test, free)'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
    if (bought == true) {
      await grantSubscription();
      return true;
    }
    return false;
  }
}
