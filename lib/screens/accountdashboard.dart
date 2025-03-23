// ignore_for_file: file_names

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrotracker/main.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart'; // Add this import
import 'package:macrotracker/screens/NativeStatsScreen.dart'; // Add this import
import 'package:macrotracker/screens/editGoals.dart'; // Add this import
import 'package:macrotracker/screens/setting_screens/edit_profile.dart';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/themeProvider.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/Health/Health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:macrotracker/screens/welcomescreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:macrotracker/screens/setting_screens/health_integration_screen.dart';
import 'package:macrotracker/screens/onboarding/onboarding_screen.dart';
import 'dart:io' show Platform;

class AccountDashboard extends StatefulWidget {
  const AccountDashboard({super.key});

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
  String _selectedUnit = 'Metric'; // 'Metric' or 'Imperial'
  Map<String, dynamic> userData = {
    'name': 'John Doe',
    'email': 'john.doe@example.com',
  };
  final Map<String, bool> _notificationSettings = {
    'mealReminders': true,
    // 'hydrationTracking': true,
    'weeklyReports': true,
    // 'achievementAlerts': true,
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _checkHealthConnection();
    _loadUserData(); // Add this line

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
    setState(() {
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

  Future<void> _handleLogout() async {
    try {
      // Clear user data from SharedPreferences first
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('macro_results');
      // Clear food entries
      final foodEntryProvider =
          Provider.of<FoodEntryProvider>(context, listen: false);
      await foodEntryProvider.clearEntries();
      // Other user-related data can be removed here as well

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
            leading: IconButton(
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
              'Settings',
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
            padding:
                const EdgeInsets.only(top: 8), // Add some padding at the top
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
                    onTap: () {
                      HapticFeedback.lightImpact();
                      // Use the static show method instead of trying to navigate to it as a widget
                      NativeStatsScreen.show(context, initialSection: 'macros');
                    },
                    colorScheme: colorScheme,
                    customColors: customColors,
                  ),
                  // _buildListTile(
                  //   icon: CupertinoIcons.arrow_up_arrow_down,
                  //   iconColor: Colors.orange,
                  //   title: 'Unit System',
                  //   subtitle: 'Current: $_selectedUnit',
                  //   trailing: const Icon(Icons.chevron_right),
                  //   onTap: () {
                  //     HapticFeedback.lightImpact();
                  //     _showUnitPicker();
                  //   },
                  //   colorScheme: colorScheme,
                  //   customColors: customColors,
                  // ),
                ],
              ),

              // Appearance section
              _buildSection(
                title: 'Appearance',
                icon: CupertinoIcons.paintbrush_fill,
                colorScheme: colorScheme,
                customColors: customColors,
                children: [
                  _buildSwitchTile(
                    icon: isDarkMode
                        ? CupertinoIcons.moon_fill
                        : CupertinoIcons.sun_max_fill,
                    iconColor: isDarkMode ? Colors.indigo : Colors.amber,
                    title: 'Dark Mode',
                    subtitle: isDarkMode
                        ? 'Switch to light theme'
                        : 'Switch to dark theme',
                    value: isDarkMode,
                    onChanged: (value) {
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
                    },
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
                children: _notificationSettings.entries.map((entry) {
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
                    },
                    colorScheme: colorScheme,
                    customColors: customColors,
                  );
                }).toList(),
              ),

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
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () {/* Open privacy policy */},
                    colorScheme: colorScheme,
                    customColors: customColors,
                  ),
                  // Add the reset onboarding button here
                  _buildListTile(
                    icon: CupertinoIcons.refresh,
                    iconColor: Colors.purple,
                    title: 'Reset Onboarding',
                    subtitle: 'Recalculate your macros and goals',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _confirmResetOnboarding,
                    colorScheme: colorScheme,
                    customColors: customColors,
                  ),
                ],
              ),

              // Support section
              _buildSection(
                title: 'Support',
                icon: CupertinoIcons.question_circle_fill,
                colorScheme: colorScheme,
                customColors: customColors,
                children: [
                  _buildListTile(
                    icon: CupertinoIcons.envelope_fill,
                    iconColor: Colors.teal,
                    title: 'Contact Support',
                    subtitle: 'Reach out to our team',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {/* Show contact options */},
                    colorScheme: colorScheme,
                    customColors: customColors,
                  ),
                ],
              ),

              // Logout button and spacing at the bottom
              const SizedBox(height: 24),
              _buildLogoutButton(colorScheme),
              const SizedBox(height: 32),
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
        trailing: CupertinoSwitch(
          value: value,
          activeTrackColor: colorScheme.primary,
          onChanged: onChanged,
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
      case 'weeklyReports':
        return CupertinoIcons.chart_bar_alt_fill;
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
      case 'weeklyReports':
        return Colors.green;
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
      case 'weeklyReports':
        return 'Weekly Reports';
      // case 'achievementAlerts':
      //   return 'Achievement Alerts';
      default:
        return key;
    }
  }

  void _showUnitPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Select Unit System'),
        message: const Text('Choose your preferred measurement system'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Metric (kg, cm)'),
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedUnit = 'Metric');
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Imperial (lb, in)'),
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedUnit = 'Imperial');
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

  void _confirmResetOnboarding() {
    HapticFeedback.lightImpact();

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Reset Onboarding?',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'This will reset all your macro calculations. You\'ll need to complete the onboarding process again. This action cannot be undone.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetOnboarding();
              },
              child: Text(
                'Reset',
                style: GoogleFonts.poppins(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetOnboarding() async {
    try {
      // Clear macro data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('macro_results');

      // Reset any other onboarding-related data
      // For example, you might want to reset weight history but keep the account
      // If using Supabase, you can update the user's record to clear specific fields

      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null) {
        try {
          // Reset macro values in the database but keep the user account
          await _supabase.from('user_macros').update({
            'calories_goal': null,
            'protein_goal': null,
            'carbs_goal': null,
            'fat_goal': null,
            'gender': null,
            'weight': null,
            'height': null,
            'age': null,
            'activity_level': null,
            'goal_type': null,
            'deficit_surplus': null,
            'protein_ratio': null,
            'fat_ratio': null,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', currentUser.id);
        } catch (e) {
          print('Error resetting Supabase data: $e');
        }
      }

      // Clear local provider data
      final foodEntryProvider =
          Provider.of<FoodEntryProvider>(context, listen: false);
      await foodEntryProvider.clearEntries();

      // Navigate to onboarding screen with replacement
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          (route) => false, // This removes all previous routes
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
