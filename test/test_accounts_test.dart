import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/services/test_accounts.dart';

import 'helpers/test_app.dart';

void main() {
  setUp(() async {
    await setUpTestEnvironment();
    for (final id in ['user-1', 'user-2']) {
      await StorageService().delete('test_subscription_$id');
    }
  });

  // flutter test runs as a debug build, where test accounts are enabled.
  test('test accounts are enabled in debug builds', () {
    expect(TestAccounts.enabledInThisBuild, isTrue);
  });

  test('only @mbtest.ai addresses are test accounts', () {
    expect(TestAccounts.isTestEmail('qa1@mbtest.ai'), isTrue);
    expect(TestAccounts.isTestEmail('  QA1@MBTest.AI '), isTrue);
    expect(TestAccounts.isTestEmail('qa1@mbtest.ai.example.com'), isFalse);
    expect(TestAccounts.isTestEmail('qa1@notmbtest.ai.com'), isFalse);
    expect(TestAccounts.isTestEmail('someone@gmail.com'), isFalse);
    expect(TestAccounts.isTestEmail(''), isFalse);
    expect(TestAccounts.isTestEmail(null), isFalse);
  });

  test('signed out: never active, never subscribed, granting does nothing', () async {
    expect(TestAccounts.isActive, isFalse);
    expect(TestAccounts.hasSubscription, isFalse);
    await TestAccounts.grantSubscription();
    expect(TestAccounts.hasSubscription, isFalse);
  });

  test('a test account is subscribed only after buying', () async {
    const email = 'qa1@mbtest.ai';
    expect(TestAccounts.hasSubscriptionFor(email: email, userId: 'user-1'), isFalse);
    await TestAccounts.grantSubscriptionFor(email: email, userId: 'user-1');
    expect(TestAccounts.hasSubscriptionFor(email: email, userId: 'user-1'), isTrue);
  });

  test('the grant belongs to that account only', () async {
    await TestAccounts.grantSubscriptionFor(email: 'qa1@mbtest.ai', userId: 'user-1');
    expect(TestAccounts.hasSubscriptionFor(email: 'qa2@mbtest.ai', userId: 'user-2'),
        isFalse);
    expect(TestAccounts.hasSubscriptionFor(email: 'qa1@mbtest.ai', userId: null),
        isFalse);
  });

  test('a real account can never get the free subscription', () async {
    await TestAccounts.grantSubscriptionFor(email: 'someone@gmail.com', userId: 'user-1');
    expect(StorageService().get('test_subscription_user-1'), isNull);
    // Even if a grant were left on the device, a real email ignores it.
    await StorageService().put('test_subscription_user-1', true);
    expect(TestAccounts.hasSubscriptionFor(email: 'someone@gmail.com', userId: 'user-1'),
        isFalse);
  });
}
