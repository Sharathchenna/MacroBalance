import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/test_accounts.dart';

void main() {
  // flutter test runs as a debug build, where test accounts are enabled.
  test('only @mbtest.ai addresses are test accounts', () {
    expect(TestAccounts.isTestEmail('qa1@mbtest.ai'), isTrue);
    expect(TestAccounts.isTestEmail('  QA1@MBTest.AI '), isTrue);
    expect(TestAccounts.isTestEmail('qa1@mbtest.ai.example.com'), isFalse);
    expect(TestAccounts.isTestEmail('someone@gmail.com'), isFalse);
    expect(TestAccounts.isTestEmail(null), isFalse);
  });
}
