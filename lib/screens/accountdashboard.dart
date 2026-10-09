// ignore_for_file: file_names

import 'package:macrotracker/widgets/app_bottom_bar.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart'; // Add this import
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/providers/day_status_provider.dart';
import 'package:macrotracker/providers/energy_provider.dart';
import 'package:macrotracker/screens/energy/energy_debug_screen.dart';
import 'package:macrotracker/services/test_accounts.dart';
import 'package:macrotracker/providers/subscription_provider.dart'; // Add import for SubscriptionProvider
import 'package:macrotracker/screens/editGoals.dart'; // Add this import
import 'package:macrotracker/screens/setting_screens/edit_profile.dart';
import 'package:macrotracker/screens/setting_screens/edit_profile_field_screen.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/finish_reminder_provider.dart';
import 'package:macrotracker/services/energy/finish_reminder.dart';
import 'package:macrotracker/providers/themeProvider.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/Health/Health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:macrotracker/providers/saved_food_provider.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:macrotracker/services/weight_sync_service.dart';
import 'package:macrotracker/screens/welcomescreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:macrotracker/screens/setting_screens/health_integration_screen.dart';
import 'package:macrotracker/screens/onboarding/onboarding_screen.dart';
import 'package:macrotracker/widgets/adaptive_choice.dart';
import 'dart:io' show Platform;
import 'package:macrotracker/services/notification_service.dart';
import 'package:macrotracker/screens/feedback_screen.dart'
    as fb_screen; // Added import for feedback with prefix
import 'package:macrotracker/screens/contact_support_screen.dart'; // Added import for contact support
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:url_launcher/url_launcher.dart';
import 'package:macrotracker/screens/delete_account_screen.dart'; // Add this import for the confirmation screen
import 'package:macrotracker/services/superwall_placements.dart'; // Import Superwall Placements
import 'package:macrotracker/services/posthog_service.dart'; // Import PostHogService
import 'package:macrotracker/services/superwall_service.dart'; // Import SuperwallService
import 'package:macrotracker/screens/app_shell.dart';

class AccountDashboard extends StatefulWidget {
  const AccountDashboard({super.key, this.showBackButton = true});

  /// False when shown as the Profile tab of the app shell.
  final bool showBackButton;

  @override
  State<AccountDashboard> createState() => _AccountDashboardState();
}

class _AccountDashboardState extends State<AccountDashboard>
    with SingleTickerProviderStateMixin {
  final HealthService _healthService = HealthService();
  late AnimationController _animationController;
  final _supabase = Supabase.instance.client;

  // State variables
  bool _healthConnected = false;
  Map<String, dynamic> userData = {
    'name': 'John Doe',
    'email': 'john.doe@example.com',
  };
  final Map<String, bool> _notificationSettings = {
    'mealReminders': true,
    // 'weeklyReports': true, // Commented out weekly reports
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Track screen view
    PostHogService.trackScreen('account_dashboard');
    
    _checkHealthConnection();
    _loadUserData(); // Add this line
    _loadNotificationPreferences(); // Add this line

    // Force iOS status bar to use black icons (for light mode)
    if (Platform.isIOS) {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarBrightness:
            Brightness.light, // Light background = dark content
        statusBarIconBrightness: Brightness.dark, // Force dark icons
        statusBarColor: Colors.transparent, // Transparent status bar
      ));
    }
  }

  // Make sure the status bar stays correct during hot reload and when returning to this screen
  void updateStatusBarForIOS(bool isDarkMode) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
      statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
      statusBarColor: Colors.transparent,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    if (Platform.isIOS) {
      updateStatusBarForIOS(isDarkMode);
    }
  }

  Future<void> _checkHealthConnection() async {
    final isAvailable = await _healthService.isHealthDataAvailable();
    if (mounted) setState(() {
      _healthConnected = isAvailable;
    });
  }

  Future<void> _loadUserData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        // Get data from user metadata first
        final userMetadata = user.userMetadata;

        if (mounted) {
          setState(() {
            userData = {
              'name': userMetadata?['full_name'] ??
                  userMetadata?['name'] ??
                  user.email?.split('@')[0] ??
                  'User',
              'email': user.email ?? 'No email',
              'avatar_url':
                  userMetadata?['avatar_url'] ?? userMetadata?['picture'],
            };
          });
        }

        // Try to get profile data from profiles table if it exists
        try {
          final response = await _supabase
              .from('profiles')
              .select()
              .eq('id', user.id)
              .single();

          if (mounted) {
            setState(() {
              userData.update(
                  'name', (value) => response['full_name'] ?? value);
              userData.update(
                  'avatar_url', (value) => response['avatar_url'] ?? value);
            });
          }
        } catch (e) {
          // Silently handle missing profiles table or no profile data
          // We already have data from user metadata
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading user data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadNotificationPreferences() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final response = await _supabase
            .from('user_notification_preferences')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();

        if (response != null) {
          if (mounted) setState(() {
            _notificationSettings['mealReminders'] =
                response['meal_reminders'] ?? true;
            // _notificationSettings['weeklyReports'] =
            //     response['weekly_reports'] ?? true; // Commented out weekly reports
          });
        } else {
          // Create default preferences if none exist
          await NotificationService().updateNotificationPreferences(
            _notificationSettings['mealReminders'] ?? true,
            // _notificationSettings['weeklyReports'] ?? true, // Commented out weekly reports
            false, // Pass default false for weekly reports now
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading notification preferences: $e');
    }
  }

  /// Logging out clears this phone's copy, so say so when it isn't backed up.
  Future<bool?> _confirmLogoutWithoutBackup() {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Some data isn't backed up"),
        content: const Text(
            "We couldn't reach the server, so recent food or weight entries on this phone "
            "may not be saved to your account. If you log out now they'll be deleted from this phone. "
            "Connect to the internet and try again to keep them."),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay Logged In'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out Anyway'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      // Add haptic feedback
      HapticFeedback.mediumImpact();

      // Push any queued changes before this device forgets them.
      final foodEntryProvider =
          Provider.of<FoodEntryProvider>(context, listen: false);
      final goals = Provider.of<GoalsProvider>(context, listen: false);
      final dayStatus = Provider.of<DayStatusProvider>(context, listen: false);
      final energy = Provider.of<EnergyProvider>(context, listen: false);
      final finishReminder = Provider.of<FinishReminderProvider>(context, listen: false);
      final savedFoodProvider =
          Provider.of<SavedFoodProvider>(context, listen: false);
      var backedUp = true;
      try {
        final results = await Future.wait<Object?>([
          foodEntryProvider.syncWithCloud().then((_) => true),
          WeightSyncService().syncLocalHistory(),
        ]).timeout(const Duration(seconds: 8));
        // syncLocalHistory returns null when the cloud couldn't be reached.
        backedUp = results[1] != null;
      } catch (_) {
        backedUp = false;
      }
      if (!backedUp) {
        final logOutAnyway = await _confirmLogoutWithoutBackup();
        if (logOutAnyway != true) return;
      }
      // Clear goals, entries, weight history, saved foods and sync state so the
      // next account on this device starts from its own data.
      await foodEntryProvider.clearUserData();
      await goals.clearUserData();
      await dayStatus.clearUserData();
      await energy.clearUserData();
      await finishReminder.clearUserData();
      await savedFoodProvider.clearUserData();

      // Then sign out from Supabase
      await _supabase.auth.signOut();

      if (mounted) {
        Navigator.of(context).pushReplacement(
            CupertinoPageRoute(builder: (context) => const Welcomescreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error signing out. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: TextStyle(
              color: Colors.white,
            )),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Future<void> _launchPrivacyPolicy() async {
    final Uri privacyPolicyUrl = Uri.parse('https://macrobalance.app/privacy');
    try {
      if (!await launchUrl(privacyPolicyUrl,
          mode: LaunchMode.externalApplication)) {
        _showError(
            'Could not open the privacy policy. Please try again later.');
      }
    } catch (e) {
      _showError('Could not open the privacy policy. Please try again later.');
      debugPrint('Error launching URL: $e');
    }
  }

  Future<void> _launchTermsOfService() async {
    final Uri tosUrl = Uri.parse('https://macrobalance.app/terms');
    try {
      if (!await launchUrl(tosUrl, mode: LaunchMode.externalApplication)) {
        _showError(
            'Could not open the terms of service. Please try again later.');
      }
    } catch (e) {
      _showError(
          'Could not open the terms of service. Please try again later.');
      debugPrint('Error launching URL: $e');
    }
  }

  Future<void> _saveNotificationPreferences() async {
    await NotificationService().updateNotificationPreferences(
      _notificationSettings['mealReminders'] ?? false,
      // _notificationSettings['weeklyReports'] ?? false, // Commented out weekly reports
      false, // Pass false for weekly reports now
    );
    // The finish-day prompt joins the meal reminder only while that's on.
    if (!mounted) return;
    context.read<FinishReminderProvider?>()?.refresh();
  }

  // --- Removed Notification Test Functions ---

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDarkMode = themeProvider.isDarkMode;
        final colorScheme = Theme.of(context).colorScheme;
        final customColors = Theme.of(context).extension<CustomColors>();

        // Apply the appropriate status bar style based on the theme
        if (Platform.isIOS) {
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarBrightness:
                isDarkMode ? Brightness.dark : Brightness.light,
            statusBarIconBrightness:
                isDarkMode ? Brightness.light : Brightness.dark,
            statusBarColor: Colors.transparent,
          ));
        }

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          // Use a regular AppBar instead of extendBodyBehindAppBar to fix layout issues
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            systemOverlayStyle: isDarkMode
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            automaticallyImplyLeading: false,
            leading: !widget.showBackButton
                ? null
                : IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(CupertinoIcons.back,
                          color: colorScheme.primary, size: 18),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
            title: Text(
              widget.showBackButton ? 'Settings' : 'Profile',
              style: GoogleFonts.poppins(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            centerTitle: false,
          ),
          // Use a regular ListView instead of a Stack to avoid layout issues
          body: ListView(
            // Bottom room so the last row scrolls clear of the bottom bar.
            padding: EdgeInsets.only(top: 8, bottom: widget.showBackButton ? 24 : AppBottomBar.scrollClearance),
            children: [
              // Profile header
              _buildProfileHeader(colorScheme, customColors),
              // const SizedBox(height: 16),

              // Account section
              _buildSection(
                title: 'Account',
                icon: CupertinoIcons.person_fill,
                colorScheme: colorScheme,
                customColors: customColors,
                children: [
                  _buildListTile(
                    icon: CupertinoIcons.profile_circled,
                    iconColor: customColors!.accentPrimary,
                    title: 'Edit Profile',
                    subtitle: 'Update your personal information',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      final result = await Navigator.push<Map<String, dynamic>>(
                        context,
                        CupertinoPageRoute(
                          builder: (context) =>
                              EditProfileScreen(userData: userData),
                        ),
                      );
                      if (result != null && mounted) {
                        setState(() {
                          userData = result;
                        });
                      }
                    },
                    colorScheme: colorScheme,
                    customColors: customColors,
                  ),
                  _buildHealthAppTile(colorScheme, customColors),
                ],
              ),

              // Sex, height and age: what the energy maths starts from
              Consumer2<GoalsProvider, WeightUnitProvider>(
                builder: (context, goals, units, _) => _buildSection(
                  title: 'Body',
                  icon: CupertinoIcons.person_crop_circle_fill,
                  colorScheme: colorScheme,
                  customColors: customColors,
                  children: [
                    for (final (field, icon, title, value) in [
                      (
                        ProfileField.sex,
                        CupertinoIcons.person_2_fill,
                        'Sex',
                        switch (goals.sex) {
                          MacroCalculatorService.MALE => 'Male',
                          MacroCalculatorService.FEMALE => 'Female',
                          _ => 'Not set',
                        }
                      ),
                      (
                        ProfileField.height,
                        CupertinoIcons.arrow_up_down,
                        'Height',
                        _heightText(goals.heightCm, units.isMetric)
                      ),
                      (
                        ProfileField.age,
                        CupertinoIcons.calendar,
                        'Age',
                        goals.age == null ? 'Not set' : '${goals.age} years'
                      ),
                    ])
                      _buildListTile(
                        icon: icon,
                        iconColor: colorScheme.primary,
                        title: title,
                        subtitle: value,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) =>
                                  EditProfileFieldScreen(field: field),
                            ),
                          );
                        },
                        colorScheme: colorScheme,
                        customColors: customColors,
                      ),
                  ],
                ),
              ),

              // Nutrition & Goals section
              _buildSection(
                title: 'Nutrition & Goals',
                icon: CupertinoIcons.chart_pie_fill,
                colorScheme: colorScheme,
                customColors: customColors,
                children: [
                  _buildListTile(
                    icon: CupertinoIcons.chart_bar_alt_fill,
                    iconColor: colorScheme.primary,
                    title: 'Macro Goals',
                    subtitle: 'Set your daily macro targets',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      // Make onTap async
                      HapticFeedback.lightImpact();
                      // Await the result from EditGoalsScreen
                      final result = await Navigator.push<bool>(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => const EditGoalsScreen(),
                        ),
                      );

                      // If goals were saved (result is true), refresh provider data
                      if (result == true && context.mounted) {
                        // Reload goals from storage so every screen shows the saved ones.
                        await Provider.of<GoalsProvider>(context, listen: false)
                            .load();
                        debugPrint("Goals reloaded after EditGoalsScreen.");
                      }
                    },
                    colorScheme: colorScheme,
                    customColors: customColors,
                  ),
                  _buildListTile(
                    icon: CupertinoIcons.refresh,
                    iconColor: Colors.purple,
                    title: 'Recalculate Goals',
                    subtitle: 'Answer the body and goal questions again',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => const OnboardingScreen(recalculateOnly: true),
                        ),
                      );
                    },
                    colorScheme: colorScheme,
                    customColors: customColors,
                  ),
                  // Adaptive goals and the day check-ins fall on
                  Consumer<GoalsProvider>(
                    builder: (context, goals, _) => Column(
                      children: [
                        _buildSwitchTile(
                          icon: CupertinoIcons.arrow_2_circlepath,
                          iconColor: Colors.green,
                          title: 'Adaptive Goals',
                          subtitle: goals.adaptiveGoals
                              ? 'Targets update weekly as we learn'
                              : 'Targets stay as calculated',
                          value: goals.adaptiveGoals,
                          onChanged: (on) => changeAdaptiveGoals(context, to: on),
                          colorScheme: colorScheme,
                          customColors: customColors,
                        ),
                        if (goals.adaptiveGoals)
                          _buildListTile(
                            icon: CupertinoIcons.calendar_today,
                            iconColor: Colors.blue,
                            title: 'Check-in Day',
                            subtitle: weekdayName(goals.checkinWeekday),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _showCheckinDayPicker(goals);
                            },
                            colorScheme: colorScheme,
                            customColors: customColors,
                          ),
                      ],
                    ),
                  ),
                  Consumer<WeightUnitProvider>(
                    builder: (context, units, _) => _buildListTile(
                      icon: CupertinoIcons.arrow_up_arrow_down,
                      iconColor: Colors.orange,
                      title: 'Units',
                      subtitle: units.isMetric
                          ? 'Metric (kg, g, cm)'
                          : 'Imperial (lb, oz, ft)',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showUnitPicker();
                      },
                      colorScheme: colorScheme,
                      customColors: customColors,
                    ),
                  ),
                ],
              ),

              // Data & Sync section
              _buildSyncSection(colorScheme, customColors),

              // Appearance section
              _buildSection(
                title: 'Appearance',
                icon: CupertinoIcons.paintbrush_fill,
                colorScheme: colorScheme,
                customColors: customColors,
                children: [
                  _buildSwitchTile(
                    icon: CupertinoIcons.device_phone_portrait,
                    iconColor: Colors.teal,
                    title: 'Use System Theme',
                    subtitle: 'Follow your device theme settings',
                    value: themeProvider.useSystemTheme,
                    onChanged: (value) {
                      themeProvider.setUseSystemTheme(value);
                      HapticFeedback.lightImpact();

                      // Update status bar when system theme setting changes
                      if (Platform.isIOS) {
                        Future.delayed(const Duration(milliseconds: 100), () {
                          updateStatusBarForIOS(themeProvider.isDarkMode);
                        });
                      }
                    },
                    colorScheme: colorScheme,
                    customColors: customColors,
                  ),
                  _buildSwitchTile(
                    icon: isDarkMode
                        ? CupertinoIcons.moon_fill
                        : CupertinoIcons.sun_max_fill,
                    iconColor: isDarkMode ? Colors.indigo : Colors.amber,
                    title: 'Dark Mode',
                    subtitle: themeProvider.useSystemTheme
                        ? 'Controlled by system settings'
                        : (isDarkMode
                            ? 'Switch to light theme'
                            : 'Switch to dark theme'),
                    value: isDarkMode,
                    onChanged: (value) {
                      if (!themeProvider.useSystemTheme) {
                        themeProvider.toggleTheme();
                        HapticFeedback.lightImpact();

                        // Update status bar when theme changes
                        if (Platform.isIOS) {
                          // Use a small delay to let theme change apply first
                          Future.delayed(const Duration(milliseconds: 100), () {
                            SystemChrome.setSystemUIOverlayStyle(
                                SystemUiOverlayStyle(
                              statusBarBrightness:
                                  value ? Brightness.dark : Brightness.light,
                              statusBarIconBrightness:
                                  value ? Brightness.light : Brightness.dark,
                              statusBarColor: Colors.transparent,
                            ));
                          });
                        }
                      }
                    },
                    enabled: !themeProvider.useSystemTheme,
                    colorScheme: colorScheme,
                    customColors: customColors,
                  ),
                ],
              ),

              // Notifications section
              _buildSection(
                title: 'Notifications',
                icon: CupertinoIcons.bell_fill,
                colorScheme: colorScheme,
                customColors: customColors,
                children: _notificationSettings.entries
                    .where((entry) =>
                        entry.key !=
                        'weeklyReports') // Filter out weekly reports
                    .map((entry) {
                  return _buildSwitchTile(
                    icon: _getNotificationIcon(entry.key),
                    iconColor: _getNotificationColor(entry.key),
                    title: _getNotificationTitle(entry.key),
                    subtitle: 'Tap to toggle',
                    value: entry.value,
                    onChanged: (value) {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _notificationSettings[entry.key] = value;
                      });
                      _saveNotificationPreferences();
                      // After the meal reminder toggle
                      if (_notificationSettings['mealReminders'] == true) {
                        _buildListTile(
                          icon: CupertinoIcons.clock,
                          iconColor: Colors.orange,
                          title: 'Reminder Time',
                          subtitle: 'Set when to receive meal reminders',
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _showMealReminderTimePicker();
                          },
                          colorScheme: colorScheme,
                          customColors: customColors,
                        );
                      }
                    },
                    colorScheme: colorScheme,
                    customColors: customColors,
                  );
                }).toList()
                  ..addAll(_finishReminderTiles(colorScheme, customColors)),
              ),

              // --- Removed Testing Section ---

              // Privacy & Security section
              _buildSection(
                title: 'Privacy & Security',
                icon: CupertinoIcons.lock_fill,
                colorScheme: colorScheme,
                customColors: customColors,
                children: [
                  _buildListTile(
                    icon: CupertinoIcons.doc_text,
                    iconColor: Colors.grey,
                    title: 'Privacy Policy',
                    subtitle: 'Read our privacy policy',
                    trailing: const Icon(Icons.chevron_right), // Changed icon
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _launchPrivacyPolicy();
                    },
                    colorScheme: colorScheme,
                    customColors: customColors,
                  ),
                  _buildListTile(
                    // Added Terms & Conditions
                    icon: CupertinoIcons.doc_text_fill,
                    iconColor: Colors.blueGrey,
                    title: 'Terms & Conditions',
                    subtitle: 'Read our terms of service',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _launchTermsOfService();
                    },
                    colorScheme: colorScheme,
                    customColors: customColors,
                  ),
                  // Remove reset onboarding button from here
                  _buildListTile(
                    icon: CupertinoIcons.delete,
                    iconColor: Colors.red,
                    title: 'Delete Account',
                    subtitle: 'Permanently delete your account and data',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _confirmDeleteAccount,
                    colorScheme: colorScheme,
                    customColors: customColors,
                  ),
                ],
              ),

              // Add new Data Management section
              // Support section
              _buildSection(
                title: 'Support',
                icon: CupertinoIcons.question_circle_fill,
                colorScheme: colorScheme,
                customColors: customColors,
                children: [
                  // Only inside the app shell, where Home is a tab.
                  if (context.findAncestorStateOfType<AppShellState>() != null)
                    _buildListTile(
                      icon: CupertinoIcons.sparkles,
                      iconColor: const Color(0xFFFFC107),
                      title: 'Show app tour',
                      subtitle: 'A quick look at the basics',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.findAncestorStateOfType<AppShellState>()?.startTour();
                      },
                      colorScheme: colorScheme,
                      customColors: customColors,
                    ),
                  _buildListTile(
                    icon: CupertinoIcons.envelope_fill,
                    iconColor: Colors.teal,
                    title: 'Contact Support',
                    subtitle: 'Reach out to our team',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => const ContactSupportScreen(),
                        ),
                      );
                    },
                    colorScheme: colorScheme,
                    customColors: customColors,
                  ),
                  _buildListTile(
                    icon: CupertinoIcons.star_fill,
                    iconColor: Colors.amber,
                    title: 'Give Feedback or Report a Bug',
                    subtitle: 'Help us improve the app',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      // Navigate to FeedbackScreen
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => const fb_screen
                              .FeedbackScreen(), // Use prefix here
                        ),
                      );
                    },
                    colorScheme: colorScheme,
                    customColors: customColors,
                  ),
                  // Only show test notifications button in debug mode
                  if (kDebugMode)
                    _buildListTile(
                      icon: CupertinoIcons.bell_fill,
                      iconColor: Colors.red,
                      title: 'Test Notifications',
                      subtitle: 'Send a test push notification',
                      trailing: ElevatedButton(
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          // Show options dialog
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text(
                                  'Test Notifications',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                content: Text(
                                  'Choose which type of notification to test:',
                                  style: GoogleFonts.poppins(),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      Navigator.of(context).pop();
                                      // Show toast/snackbar
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Sending local notification...'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );

                                      try {
                                        await NotificationService()
                                            .scheduleTestLocalNotification();

                                        if (mounted) {
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Local notification sent!'),
                                              backgroundColor: Colors.green,
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Error: ${e.toString()}'),
                                              backgroundColor: Colors.red,
                                              duration: Duration(seconds: 3),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: Text(
                                      'Local Notification',
                                      style: GoogleFonts.poppins(
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      Navigator.of(context).pop();
                                      // Show toast/snackbar
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Sending FCM/APN notification...'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );

                                      try {
                                        await NotificationService()
                                            .testFirebaseCloudMessaging();

                                        if (mounted) {
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'FCM/APN notification sent! Check device notifications.'),
                                              backgroundColor: Colors.green,
                                              duration: Duration(seconds: 3),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Error: ${e.toString()}'),
                                              backgroundColor: Colors.red,
                                              duration: Duration(seconds: 3),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: Text(
                                      'Firebase/APN',
                                      style: GoogleFonts.poppins(
                                        color: colorScheme.secondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text('Test'),
                      ),
                      onTap: () {
                        // Button handles the action
                      },
                      colorScheme: colorScheme,
                      customColors: customColors,
                    ),
                  // Add a button in debug mode for copying the FCM token
                  if (kDebugMode)
                    _buildListTile(
                      icon: CupertinoIcons.doc_on_clipboard_fill,
                      iconColor: Colors.blue,
                      title: 'Copy FCM Token',
                      subtitle: 'Copy the device FCM token to clipboard',
                      trailing: ElevatedButton(
                        child: const Text('Copy'),
                        onPressed: () async {
                                      final messenger = ScaffoldMessenger.of(context);
                          try {
                            final fcmToken =
                                await NotificationService1().getFcmToken();
                            if (fcmToken != null) {
                              await Clipboard.setData(
                                  ClipboardData(text: fcmToken));
                              messenger.showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('FCM token copied to clipboard!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Failed to retrieve FCM token.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                      onTap: () {}, // No additional action on tap
                      colorScheme: colorScheme,
                      customColors: customColors,
                    ),
                ],
              ),

              // Subscription section
              _buildSection(
                title: 'Subscription',
                icon: CupertinoIcons.creditcard_fill,
                colorScheme: colorScheme,
                customColors: customColors,
                children: [
                  Consumer<SubscriptionProvider>(
                    builder: (context, subscriptionProvider, _) {
                      return _buildListTile(
                        icon: CupertinoIcons.creditcard_fill,
                        iconColor: Colors.blue,
                        title: 'Manage Subscription',
                        subtitle: subscriptionProvider.isProUser
                            ? 'Manage your Pro subscription'
                            : 'Subscribe to Pro features',
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          _openAppleSubscriptionSettings();
                        },
                        colorScheme: colorScheme,
                        customColors: customColors,
                      );
                    },
                  ),
                ],
              ),

              // Developer tools: debug builds and test accounts only.
              if (kDebugMode || TestAccounts.isActive)
                _buildSection(
                  title: 'Developer',
                  icon: CupertinoIcons.hammer_fill,
                  colorScheme: colorScheme,
                  customColors: customColors,
                  children: [
                    _buildListTile(
                      icon: CupertinoIcons.flame_fill,
                      iconColor: Colors.orange,
                      title: 'Energy estimates',
                      subtitle: 'Expenditure estimator, shadow mode',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => const EnergyDebugScreen(),
                          ),
                        );
                      },
                      colorScheme: colorScheme,
                      customColors: customColors,
                    ),
                  ],
                ),

              // Logout button and spacing at the bottom
              const SizedBox(height: 24),
              _buildLogoutButton(colorScheme),
              const SizedBox(height: 32),

              // Only show in debug mode
              if (kDebugMode)
                _buildSection(
                  title: 'Subscription Debug',
                  icon: CupertinoIcons.hammer_fill,
                  colorScheme: colorScheme,
                  customColors: customColors,
                  children: [
                    Consumer<SubscriptionProvider>(
                      builder: (context, subscriptionProvider, _) {
                        return _buildListTile(
                          icon: subscriptionProvider.isProUser
                              ? CupertinoIcons.star_fill
                              : CupertinoIcons.star_slash,
                          iconColor: subscriptionProvider.isProUser
                              ? Colors.amber
                              : Colors.grey,
                          title: 'Subscription Status',
                          subtitle: subscriptionProvider.isProUser
                              ? 'Pro Subscription Active'
                              : 'No Subscription',
                          trailing: ElevatedButton(
                            onPressed: () async {
                                      final messenger = ScaffoldMessenger.of(context);
                              HapticFeedback.mediumImpact();
                              // Toggle the subscription status (for testing only)
                              final prefs =
                                  await SharedPreferences.getInstance();
                              final isCurrentlyPro =
                                  subscriptionProvider.isProUser;
                              await prefs.setBool(
                                  'is_pro_user', !isCurrentlyPro);
                              await subscriptionProvider
                                  .refreshSubscriptionStatus();

                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(!isCurrentlyPro
                                      ? 'Pro access enabled (DEBUG)'
                                      : 'Pro access disabled (DEBUG)'),
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.fixed,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: subscriptionProvider.isProUser
                                  ? Colors.red.shade200
                                  : Colors.green.shade200,
                              padding: EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: Text(
                              subscriptionProvider.isProUser
                                  ? 'Disable Pro'
                                  : 'Enable Pro',
                              style: TextStyle(
                                color: subscriptionProvider.isProUser
                                    ? Colors.red.shade800
                                    : Colors.green.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          onTap: () {
                            // Do nothing on tap - the button handles it
                          },
                          colorScheme: colorScheme,
                          customColors: customColors,
                        );
                      },
                    ),
                    // Add Show Paywall Button for Debug
                    _buildListTile(
                      icon: CupertinoIcons.money_dollar_circle_fill,
                      iconColor: Colors.purple,
                      title: 'Show Paywall (Debug)',
                      subtitle: 'Navigate to the paywall screen',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        SuperwallPlacements.showDebugPaywall(context);
                      },
                      colorScheme: colorScheme,
                      customColors: customColors,
                    ),
                    // Add Test Superwall Integration Button
                    _buildListTile(
                      icon: CupertinoIcons.lab_flask_solid,
                      iconColor: Colors.orange,
                      title: 'Test Superwall Integration',
                      subtitle: 'Verify Superwall is working correctly',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        SuperwallPlacements.showTestPaywall(context);
                      },
                      colorScheme: colorScheme,
                      customColors: customColors,
                    ),
                    // Add Test Redeem Action Button
                    _buildListTile(
                      icon: CupertinoIcons.gift_fill,
                      iconColor: Colors.green,
                      title: 'Test Redeem Action',
                      subtitle: 'Test the native iOS redemption sheet',
                      trailing: ElevatedButton(
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          
                          // Show loading indicator
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Testing redeem action...'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                          
                          try {
                            // Test the redeem action
                            SuperwallService().testRedeemAction();
                            
                            // Show success message
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Redeem test triggered! Check for redemption sheet.'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          } catch (e) {
                            // Show error message
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Test failed: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text('Test'),
                      ),
                      onTap: () {
                        // Button handles the action
                      },
                      colorScheme: colorScheme,
                      customColors: customColors,
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme colorScheme, bool isDarkMode) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child:
              Icon(CupertinoIcons.back, color: colorScheme.primary, size: 18),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Settings',
        style: GoogleFonts.poppins(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
      ),
      centerTitle: false,
    );
  }

  Widget _buildProfileHeader(
      ColorScheme colorScheme, CustomColors? customColors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.secondary,
              colorScheme.primary.withValues(alpha: 0.8),
              colorScheme.secondary.withValues(alpha: 0.6),
            ],
          ),
          borderRadius: const BorderRadius.all(Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.white.withValues(alpha: 0.8),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text(
                          userData['name']
                              .toString()
                              .substring(0, 1)
                              .toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              userData['name'],
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              onPressed: () async {
                                HapticFeedback.lightImpact();
                                final result =
                                    await Navigator.push<Map<String, dynamic>>(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) =>
                                        EditProfileScreen(userData: userData),
                                  ),
                                );
                                if (result != null && mounted) {
                                  setState(() {
                                    userData = result;
                                  });
                                }
                              },
                              icon: const Icon(CupertinoIcons.pencil,
                                  color: Colors.white, size: 18),
                              constraints: const BoxConstraints.tightFor(
                                width: 30,
                                height: 30,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.mail,
                                color: Colors.white.withValues(alpha: 0.9),
                                size: 14),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                userData['email'],
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colorScheme.secondary,
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required ColorScheme colorScheme,
    required CustomColors? customColors,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: customColors!.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onBackground,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: customColors?.cardBackground ?? colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncSection(ColorScheme colorScheme, CustomColors? customColors) {
    return Consumer<FoodEntryProvider>(
      builder: (context, foodEntryProvider, child) {
        final lastSync = foodEntryProvider.lastSyncDate;
        final needsSync = foodEntryProvider.needsSync;
        final syncStatus = foodEntryProvider.syncStatusMessage;
        final syncSubtitle = foodEntryProvider.syncSubtitle;
        
        IconData syncIcon;
        Color syncIconColor;
        
        if (lastSync == null) {
          syncIcon = CupertinoIcons.cloud_upload;
          syncIconColor = Colors.orange;
        } else if (needsSync) {
          syncIcon = CupertinoIcons.cloud_upload;
          syncIconColor = Colors.orange;
        } else {
          syncIcon = CupertinoIcons.cloud_fill;
          syncIconColor = Colors.green;
        }
        
        return _buildSection(
          title: 'Data & Sync',
          icon: CupertinoIcons.cloud,
          colorScheme: colorScheme,
          customColors: customColors,
          children: [
            _buildListTile(
              icon: syncIcon,
              iconColor: syncIconColor,
              title: syncStatus,
              subtitle: syncSubtitle,
              trailing: needsSync || lastSync == null
                  ? const Icon(Icons.chevron_right)
                  : Icon(Icons.check_circle, color: Colors.green),
              onTap: () async {
                if (needsSync || lastSync == null) {
                  HapticFeedback.lightImpact();
                  // Grab these before awaiting; the screen may be gone after.
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    // Show loading indicator with appropriate message
                    final isFirstTime = foodEntryProvider.isFirstTimeSync;
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => AlertDialog(
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(isFirstTime 
                                ? 'Backing up your food entries...'
                                : 'Syncing food entries...'),
                          ],
                        ),
                      ),
                    );
                    
                    await foodEntryProvider.forceFoodEntrySync();
                    
                    navigator.pop(); // Close loading dialog
                    
                    // Show success message
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(isFirstTime 
                            ? 'Food entries backed up successfully!'
                            : 'Food entries synced successfully!'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } catch (e) {
                    navigator.pop(); // Close loading dialog
                    
                    // Show error message
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Sync failed: ${e.toString()}'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              colorScheme: colorScheme,
              customColors: customColors,
            ),
          ],
        );
      },
    );
  }

  /// "180 cm" or "5′11″"; "Not set" when unknown.
  static String _heightText(double? cm, bool isMetric) {
    if (cm == null) return 'Not set';
    if (isMetric) return '${cm.round()} cm';
    final inches = (cm / 2.54).round();
    return '${inches ~/ 12}\u2032${inches % 12}\u2033';
  }

  Widget _buildListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    required CustomColors? customColors,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ColorScheme colorScheme,
    required CustomColors? customColors,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 15,
            color: enabled
                ? colorScheme.onSurface
                : colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: enabled
                ? colorScheme.onSurface.withValues(alpha: 0.6)
                : colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
        trailing: CupertinoSwitch(
          value: value,
          activeTrackColor: colorScheme.primary,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  Widget _buildLogoutButton(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ElevatedButton.icon(
        onPressed: _handleLogout,
        icon: const Icon(CupertinoIcons.square_arrow_right, size: 20),
        label: Text(
          'Logout',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: colorScheme.error,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String key) {
    switch (key) {
      case 'mealReminders':
        return CupertinoIcons.clock_fill;
      // case 'hydrationTracking':
      //   return CupertinoIcons.drop_fill;
      // case 'weeklyReports': // Commented out
      //   return CupertinoIcons.chart_bar_alt_fill;
      // case 'achievementAlerts':
      //   return CupertinoIcons.star_fill;
      default:
        return CupertinoIcons.bell_fill;
    }
  }

  Color _getNotificationColor(String key) {
    switch (key) {
      case 'mealReminders':
        return Colors.orange;
      // case 'hydrationTracking':
      //   return Colors.blue;
      // case 'weeklyReports': // Commented out
      //   return Colors.green;
      // case 'achievementAlerts':
      //   return Colors.amber;
      default:
        return Colors.purple;
    }
  }

  String _getNotificationTitle(String key) {
    switch (key) {
      case 'mealReminders':
        return 'Meal Reminders';
      // case 'hydrationTracking':
      //   return 'Hydration Tracking';
      // case 'weeklyReports': // Commented out
      //   return 'Weekly Reports';
      // case 'achievementAlerts':
      //   return 'Achievement Alerts';
      default:
        return key;
    }
  }

  /// The weekday weekly check-ins fall on.
  void _showCheckinDayPicker(GoalsProvider goals) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Check-in Day'),
        message: const Text(
            'Your targets update once a week, on this day. Pick a day you usually log.'),
        actions: [
          for (var day = DateTime.monday; day <= DateTime.sunday; day++)
            CupertinoActionSheetAction(
              isDefaultAction: day == goals.checkinWeekday,
              child: Text(weekdayName(day)),
              onPressed: () {
                HapticFeedback.lightImpact();
                goals.checkinWeekday = day;
                Navigator.pop(context);
              },
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
            child: const Text('Cancel'),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            }),
      ),
    );
  }

  void _showUnitPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Select Unit System'),
        message: const Text('Used for body weight, food amounts and height. Defaults to your region.'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Metric (kg, g, cm)'),
            onPressed: () {
              HapticFeedback.lightImpact();
              Provider.of<WeightUnitProvider>(context, listen: false).setMetric(true);
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Imperial (lb, oz, ft)'),
            onPressed: () {
              HapticFeedback.lightImpact();
              Provider.of<WeightUnitProvider>(context, listen: false).setMetric(false);
              Navigator.pop(context);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
            child: const Text('Cancel'),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            }),
      ),
    );
  }

  Widget _buildHealthAppTile(
      ColorScheme colorScheme, CustomColors? customColors) {
    if (_healthConnected) {
      return _buildListTile(
        icon: CupertinoIcons.heart_fill,
        iconColor: Colors.red,
        title: 'Health App',
        subtitle: 'Connected',
        trailing: Icon(Icons.check_circle, color: Colors.green),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => const HealthIntegrationScreen(),
            ),
          );
        },
        colorScheme: colorScheme,
        customColors: customColors,
      );
    } else {
      return _buildListTile(
        icon: CupertinoIcons.heart,
        iconColor: Colors.red,
        title: 'Health App',
        subtitle: 'Connect to sync health data',
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => const HealthIntegrationScreen(),
            ),
          );
        },
        colorScheme: colorScheme,
        customColors: customColors,
      );
    }
  }

  /// Settings → Notifications → "Finish-day reminder": off until turned on
  /// here or from the prompts that offer it; a time once it's on.
  List<Widget> _finishReminderTiles(ColorScheme colorScheme, CustomColors? customColors) {
    final reminder = context.watch<FinishReminderProvider?>();
    if (reminder == null) return const [];
    final merged = reminder.mode == FinishReminderMode.mergedIntoMeal;
    return [
      _buildSwitchTile(
        icon: CupertinoIcons.checkmark_circle_fill,
        iconColor: Colors.teal,
        title: 'Finish-day reminder',
        subtitle: merged
            ? 'Added to your meal reminder'
            : 'An evening nudge to finish your day',
        value: reminder.enabled,
        onChanged: (value) async {
          HapticFeedback.lightImpact();
          if (!value) {
            await reminder.disable();
            return;
          }
          final ok = await reminder.enable(FinishReminderSource.settings);
          if (!ok && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Allow notifications for this app in your phone\'s Settings first.'),
            ));
          }
        },
        colorScheme: colorScheme,
        customColors: customColors,
      ),
      if (reminder.enabled && !merged)
        _buildListTile(
          icon: CupertinoIcons.clock,
          iconColor: Colors.teal,
          title: 'Finish-day reminder time',
          subtitle: formatReminderTime(reminder.minutes),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            HapticFeedback.lightImpact();
            _showFinishReminderTimePicker(reminder);
          },
          colorScheme: colorScheme,
          customColors: customColors,
        ),
    ];
  }

  void _showFinishReminderTimePicker(FinishReminderProvider reminder) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.3,
          padding: const EdgeInsets.only(top: 6.0),
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: CupertinoButton(
                    child: const Text('Done'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime:
                        DateTime(2022, 1, 1, reminder.minutes ~/ 60, reminder.minutes % 60),
                    onDateTimeChanged: (t) => reminder.setMinutes(t.hour * 60 + t.minute),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMealReminderTimePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.3,
          padding: const EdgeInsets.only(top: 6.0),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    CupertinoButton(
                      child: const Text('Done'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Time is saved when picker value changes
                      },
                    ),
                  ],
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime:
                        DateTime(2022, 1, 1, 19, 0), // 7:00 PM default
                    onDateTimeChanged: (DateTime newTime) {
                      final formattedTime =
                          '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}:00';
                      NotificationService().updateNotificationPreferences(
                        _notificationSettings['mealReminders'] ?? false,
                        // _notificationSettings['weeklyReports'] ?? false, // Commented out weekly reports
                        false, // Pass false for weekly reports
                        mealReminderTime: formattedTime,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAppleSubscriptionSettings() async {
    // For iOS, open the App Store subscriptions page
    if (Platform.isIOS) {
      // This URL opens the App Store subscriptions management page
      const url = 'itms-apps://apps.apple.com/account/subscriptions';
      try {
        if (await canLaunch(url)) {
          await launch(url);
        } else {
          // Fallback to settings app if subscription URL can't be opened
          await launch('App-Prefs:root=STORE');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open subscription settings'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else if (mounted) {
      // Show message for non-iOS platforms
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Subscription management is only available on iOS devices'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Add this function to handle account deletion
  Future<void> _confirmDeleteAccount() async {
    HapticFeedback.mediumImpact();

    // Navigate to a dedicated screen for account deletion confirmation
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => const DeleteAccountScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

class NotificationService1 {
  Future<String?> getFcmToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      return token;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }
}
