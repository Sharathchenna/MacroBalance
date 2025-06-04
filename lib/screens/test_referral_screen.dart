import 'package:flutter/material.dart';
import 'package:macrotracker/services/superwall_service.dart';
import 'package:macrotracker/widgets/referral_code_dialog.dart';
import 'package:macrotracker/screens/onboarding/referral_page.dart';

/// Test screen to demonstrate referral code functionality with Superwall
class TestReferralScreen extends StatelessWidget {
  const TestReferralScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Referral Codes'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Referral Code Testing',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Test the referral code functionality with Superwall integration. Try these test codes:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),

            // Test codes section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Valid Test Codes:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTestCodeRow('WELCOME50', '50% off'),
                    _buildTestCodeRow('FRIEND20', '20% off'),
                    _buildTestCodeRow('NEWUSER', '25% off'),
                    _buildTestCodeRow('SAVE30', '30% off'),
                    _buildTestCodeRow('TESTCODE', '50% off'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Action buttons
            ElevatedButton.icon(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (context) => ReferralCodeDialog(
                    onSuccess: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Referral code applied successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    onCancel: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Referral code dialog cancelled'),
                        ),
                      );
                    },
                  ),
                );
              },
              icon: const Icon(Icons.local_offer),
              label: const Text('Enter Referral Code'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ReferralPage(
                      onContinue: () {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Referral page completed!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.credit_card),
              label: const Text('Test New Referral Page'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
                backgroundColor: Colors.purple,
              ),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: () async {
                await SuperwallService().showReferralPaywall('TESTCODE');
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Referral paywall triggered!'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              icon: const Icon(Icons.science),
              label: const Text('Test Referral Paywall Directly'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
                backgroundColor: Colors.orange,
              ),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: () async {
                await SuperwallService().showMainPaywall();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Main paywall triggered!'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              icon: const Icon(Icons.payment),
              label: const Text('Test Main Paywall'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
                backgroundColor: Colors.blue,
              ),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: () async {
                final success = await SuperwallService().restorePurchases();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Restore successful - active subscription found!'
                        : 'No previous purchases found'),
                    backgroundColor: success ? Colors.green : Colors.orange,
                  ),
                );
              },
              icon: const Icon(Icons.restore),
              label: const Text('Test Restore Purchases'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
                backgroundColor: Colors.green,
              ),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: () {
                SuperwallService().handleCustomAction('restore');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Custom restore action triggered!'),
                    backgroundColor: Colors.teal,
                  ),
                );
              },
              icon: const Icon(Icons.touch_app),
              label: const Text('Test Custom Action: restore'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
                backgroundColor: Colors.teal,
              ),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: () async {
                final service = SuperwallService();
                if (service.isInitialized) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Superwall delegate is properly set up!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Superwall not initialized'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Check Delegate Status'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
                backgroundColor: Colors.purple,
              ),
            ),

            const Spacer(),

            // Status info
            Card(
              color: Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Superwall Status:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          SuperwallService().isInitialized
                              ? Icons.check_circle
                              : Icons.error,
                          color: SuperwallService().isInitialized
                              ? Colors.green
                              : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          SuperwallService().isInitialized
                              ? 'Initialized'
                              : 'Not Initialized',
                          style: TextStyle(
                            color: SuperwallService().isInitialized
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCodeRow(String code, String discount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            discount,
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
