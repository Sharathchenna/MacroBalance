import 'package:flutter/material.dart';
import 'package:macrotracker/screens/RevenueCat/custom_paywall_screen.dart';
import 'package:macrotracker/services/subscription_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionSettingsScreen extends StatefulWidget {
  const SubscriptionSettingsScreen({Key? key}) : super(key: key);

  @override
  _SubscriptionSettingsScreenState createState() =>
      _SubscriptionSettingsScreenState();
}

class _SubscriptionSettingsScreenState
    extends State<SubscriptionSettingsScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isLoading = true;
  CustomerInfo? _customerInfo;

  @override
  void initState() {
    super.initState();
    _fetchSubscriptionInfo();
  }

  Future<void> _fetchSubscriptionInfo() async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _subscriptionService.refreshPurchaserInfo();
      _customerInfo = _subscriptionService.customerInfo;
    } catch (e) {
      debugPrint('Error fetching subscription info: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restorePurchases() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final success = await _subscriptionService.restorePurchases();

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchases restored successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No purchases found to restore'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restoring purchases'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Refresh data
        _fetchSubscriptionInfo();
      }
    }
  }

  void _showUpgradePrompt() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return CustomPaywallScreen(
          onDismiss: () => Navigator.of(context).pop(),
          allowDismissal: true,
        );
      },
    ).then((_) {
      // Refresh data when returning from paywall
      _fetchSubscriptionInfo();
    });
  }

  Future<void> _manageBilling() async {
    try {
      final isApple = Theme.of(context).platform == TargetPlatform.iOS ||
          Theme.of(context).platform == TargetPlatform.macOS;

      final Uri url = Uri.parse(isApple
          ? 'https://apps.apple.com/account/subscriptions'
          : 'https://play.google.com/store/account/subscriptions');

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch subscription management URL';
      }
    } catch (e) {
      debugPrint('Error opening subscription settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening subscription settings'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final isPremium = _subscriptionService.hasPremiumAccess();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: customColors?.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchSubscriptionInfo,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Current plan
                      _buildStatusCard(context, isPremium, customColors),

                      const SizedBox(height: 24),

                      // Actions
                      Text(
                        'Subscription Management',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: customColors?.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Restore purchases
                      Card(
                        elevation: 2,
                        color: customColors?.cardBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Icon(Icons.restore,
                              color: customColors?.textPrimary),
                          title: Text(
                            'Restore Purchases',
                            style: TextStyle(color: customColors?.textPrimary),
                          ),
                          subtitle: Text(
                            'Restore previously purchased subscriptions',
                            style:
                                TextStyle(color: customColors?.textSecondary),
                          ),
                          onTap: _restorePurchases,
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: customColors?.textSecondary,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Manage billing
                      Card(
                        elevation: 2,
                        color: customColors?.cardBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Icon(Icons.payment,
                              color: customColors?.textPrimary),
                          title: Text(
                            'Manage Billing',
                            style: TextStyle(color: customColors?.textPrimary),
                          ),
                          subtitle: Text(
                            'View and change your subscription',
                            style:
                                TextStyle(color: customColors?.textSecondary),
                          ),
                          onTap: _manageBilling,
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: customColors?.textSecondary,
                          ),
                        ),
                      ),

                      if (!isPremium) ...[
                        const SizedBox(height: 12),

                        // Upgrade now
                        Card(
                          elevation: 2,
                          color: customColors?.accentPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading:
                                const Icon(Icons.star, color: Colors.white),
                            title: const Text(
                              'Upgrade to Premium',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: const Text(
                              'Unlock all premium features',
                              style: TextStyle(color: Colors.white70),
                            ),
                            onTap: _showUpgradePrompt,
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Premium features
                      Text(
                        'Premium Features',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: customColors?.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Feature list
                      _buildFeatureItem(
                          context, 'Unlimited Food Tracking', isPremium),
                      _buildFeatureItem(
                          context, 'Advanced Analytics', isPremium),
                      _buildFeatureItem(
                          context, 'AI-Powered Recommendations', isPremium),
                      _buildFeatureItem(
                          context, 'Ad-Free Experience', isPremium),
                      _buildFeatureItem(context, 'Priority Support', isPremium),

                      const SizedBox(height: 24),

                      // Terms and policies
                      Text(
                        'Legal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: customColors?.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/terms');
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 16,
                                color: customColors?.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Terms of Service',
                                style: TextStyle(
                                  color: customColors?.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/privacy');
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.privacy_tip_outlined,
                                size: 16,
                                color: customColors?.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Privacy Policy',
                                style: TextStyle(
                                  color: customColors?.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStatusCard(
      BuildContext context, bool isPremium, CustomColors? customColors) {
    final expiryString = _getExpiryString();

    return Card(
      elevation: 4,
      color: isPremium
          ? customColors?.accentPrimary
          : customColors?.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPremium ? Icons.verified : Icons.star_border,
                  color: isPremium ? Colors.white : customColors?.textPrimary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Current Plan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isPremium ? Colors.white : customColors?.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              isPremium ? 'Premium' : 'Free',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isPremium ? Colors.white : customColors?.textPrimary,
              ),
            ),
            if (expiryString != null && isPremium) ...[
              const SizedBox(height: 4),
              Text(
                expiryString,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isPremium
                        ? 'You have access to all premium features'
                        : 'Upgrade to access premium features',
                    style: TextStyle(
                      color: isPremium
                          ? Colors.white70
                          : customColors?.textSecondary,
                    ),
                  ),
                ),
                if (!isPremium)
                  ElevatedButton(
                    onPressed: _showUpgradePrompt,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: customColors?.accentPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Upgrade'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
      BuildContext context, String feature, bool isPremium) {
    final customColors = Theme.of(context).extension<CustomColors>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            isPremium ? Icons.check_circle : Icons.check_circle_outline,
            color: isPremium
                ? customColors?.accentPrimary
                : customColors?.textSecondary?.withOpacity(0.5),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              feature,
              style: TextStyle(
                color: isPremium
                    ? customColors?.textPrimary
                    : customColors?.textSecondary,
                fontWeight: isPremium ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _getExpiryString() {
    if (_customerInfo == null || !_subscriptionService.hasPremiumAccess()) {
      return null;
    }

    try {
      // Find any active entitlement
      final activeEntitlements = _customerInfo!.entitlements.active;
      if (activeEntitlements.isEmpty) {
        return null;
      }

      // Get expiration date of first active entitlement
      final firstEntitlement = activeEntitlements.values.first;
      final expirationDate = firstEntitlement.expirationDate;

      if (expirationDate == null) {
        return 'Lifetime access';
      }

      final expiry = DateTime.parse(expirationDate);
      final now = DateTime.now();
      final difference = expiry.difference(now);

      if (difference.inDays > 30) {
        return 'Renews on ${_formatDate(expiry)}';
      } else if (difference.inDays > 0) {
        return 'Renews in ${difference.inDays} days';
      } else if (difference.inHours > 0) {
        return 'Renews in ${difference.inHours} hours';
      } else {
        return 'Renewing soon';
      }
    } catch (e) {
      debugPrint('Error getting expiry date: $e');
      return null;
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
