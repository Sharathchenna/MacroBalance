// ignore_for_file: file_names

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrotracker/screens/healthPermissionsScreen.dart';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/themeProvider.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:health/health.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // State variables for notification settings
  bool _dailyReminder = true;
  bool _weeklyReport = true;
  bool _goalAchieved = true;
  bool _healthConnected = false;

  // Create a reusable text style for section titles
  TextStyle _getSectionTitleStyle(BuildContext context) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).primaryColor,
    );
  }

  // Create a reusable text style for item titles
  TextStyle _getItemTitleStyle(BuildContext context) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: Theme.of(context).primaryColor,
    );
  }

  Future<void> _requestHealthPermissions() async {
    final health = Health();

    try {
      bool authorized = await health.requestAuthorization([
        HealthDataType.WEIGHT,
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.BASAL_ENERGY_BURNED,
      ]);

      setState(() {
        _healthConnected = authorized;
      });
    } catch (e) {
      print('Error requesting health permissions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(CupertinoIcons.back,
                  color: Theme.of(context).primaryColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Settings',
              style: GoogleFonts.roboto(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Notifications',
                    style: _getSectionTitleStyle(context),
                  ),
                ),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .extension<CustomColors>()
                        ?.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.surface),
                  ),
                  child: Column(
                    children: [
                      // Daily Reminder Toggle
                      _buildNotificationTile(
                        title: 'Daily Reminder',
                        subtitle: 'Remind me to log my weight',
                        value: _dailyReminder,
                        onChanged: (value) {
                          setState(() => _dailyReminder = value);
                        },
                      ),
                      Divider(
                          height: 1,
                          color: Theme.of(context)
                              .extension<CustomColors>()
                              ?.dateNavigatorBackground),
                      // Weekly Report Toggle
                      _buildNotificationTile(
                        title: 'Weekly Report',
                        subtitle: 'Send me my weekly progress',
                        value: _weeklyReport,
                        onChanged: (value) {
                          setState(() => _weeklyReport = value);
                        },
                      ),
                      Divider(
                          height: 1,
                          color: Theme.of(context)
                              .extension<CustomColors>()
                              ?.dateNavigatorBackground),
                      // Goal Achieved Toggle
                      _buildNotificationTile(
                        title: 'Goal Achieved',
                        subtitle: 'Notify me when I reach my goal',
                        value: _goalAchieved,
                        onChanged: (value) {
                          setState(() => _goalAchieved = value);
                        },
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Health',
                    style: _getSectionTitleStyle(context),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .extension<CustomColors>()
                        ?.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.surface),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => const HealthPermissionsScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.heart_fill,
                            size: 22,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Health App',
                                  style: _getItemTitleStyle(context),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Manage health permissions',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            CupertinoIcons.chevron_right,
                            size: 16,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Appearance',
                    style: _getSectionTitleStyle(context),
                  ),
                ),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .extension<CustomColors>()
                        ?.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.surface),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dark Mode',
                                style: _getItemTitleStyle(context),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Switch between light and dark theme',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Row(
                              children: [
                                const SizedBox(width: 8),
                                CupertinoSwitch(
                                  value: themeProvider.isDarkMode,
                                  onChanged: (value) {
                                    themeProvider.toggleTheme();
                                  },
                                  activeTrackColor:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Billing',
                    style: _getSectionTitleStyle(context),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .extension<CustomColors>()
                        ?.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.surface),
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () {
                          // TODO: Navigate to subscription management
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Subscription Plan',
                                      style: _getItemTitleStyle(context),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Free Plan', // Replace with actual plan name
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                CupertinoIcons.chevron_right,
                                size: 16,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(
                          height: 1,
                          color: Theme.of(context)
                              .extension<CustomColors>()
                              ?.dateNavigatorBackground),
                      InkWell(
                        onTap: () {
                          // TODO: Navigate to payment methods
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Payment Method',
                                      style: _getItemTitleStyle(context),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Add payment method', // Replace with actual payment method
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                CupertinoIcons.chevron_right,
                                size: 16,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(
                          height: 1,
                          color: Theme.of(context)
                              .extension<CustomColors>()
                              ?.dateNavigatorBackground),
                      InkWell(
                        onTap: () {
                          // TODO: Navigate to billing history
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Billing History',
                                      style: _getItemTitleStyle(context),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'View past invoices',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                CupertinoIcons.chevron_right,
                                size: 16,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Support',
                    style: _getSectionTitleStyle(context),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .extension<CustomColors>()
                        ?.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.surface),
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () {
                          // TODO: Navigate to feedback form
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 12.0),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.chat_bubble_text,
                                size: 22,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Send Feedback',
                                      style: _getItemTitleStyle(context),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Help us improve the app',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                CupertinoIcons.chevron_right,
                                size: 16,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(
                          height: 1,
                          color: Theme.of(context)
                              .extension<CustomColors>()
                              ?.dateNavigatorBackground),
                      InkWell(
                        onTap: () {
                          // TODO: Implement share functionality
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 12.0),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.person_add,
                                size: 22,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Invite Friends',
                                      style: _getItemTitleStyle(context),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Share the app with friends',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                CupertinoIcons.chevron_right,
                                size: 16,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _getItemTitleStyle(context),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: Theme.of(context).colorScheme.secondary,
          ),
        ],
      ),
    );
  }
}
