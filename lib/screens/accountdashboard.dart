// ignore_for_file: file_names

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/themeProvider.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/Health/Health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:macrotracker/screens/welcomescreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  Map<String, bool> _notificationSettings = {
    'mealReminders': true,
    'hydrationTracking': true,
    'weeklyReports': true,
    'achievementAlerts': true,
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _checkHealthConnection();
  }

  Future<void> _checkHealthConnection() async {
    final isAvailable = await _healthService.isHealthDataAvailable();
    setState(() {
      _healthConnected = isAvailable;
    });
  }

  Future<void> _handleLogout() async {
    try {
      // Clear user data from SharedPreferences first
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('macro_results');
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

        return Scaffold(
          backgroundColor:
              customColors?.cardBackground ?? colorScheme.background,
          appBar: _buildAppBar(colorScheme, isDarkMode),
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildProfileHeader(colorScheme, customColors),
              const SizedBox(height: 16),
              _buildSectionTitle('Quick Actions', colorScheme),
              _buildQuickActionsRow(colorScheme, customColors),
              _buildSection(
                title: 'Account',
                icon: CupertinoIcons.person_fill,
                colorScheme: colorScheme,
                customColors: customColors,
                children: [
                  _buildListTile(
                    icon: CupertinoIcons.profile_circled,
                    iconColor: colorScheme.primary,
                    title: 'Edit Profile',
                    subtitle: 'Update your personal information',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {/* Navigate to profile editor */},
                    colorScheme: colorScheme,
                    customColors: customColors,
                  ),
                  if (_healthConnected)
                    _buildListTile(
                      icon: CupertinoIcons.heart_fill,
                      iconColor: Colors.red,
                      title: 'Health App',
                      subtitle: 'Connected',
                      trailing: Icon(Icons.check_circle, color: Colors.green),
                      onTap: () {/* Health app settings */},
                      colorScheme: colorScheme,
                      customColors: customColors,
                    )
                  else
                    _buildListTile(
                      icon: CupertinoIcons.heart,
                      iconColor: Colors.red,
                      title: 'Health App',
                      subtitle: 'Connect to sync health data',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {/* Connect health app */},
                      colorScheme: colorScheme,
                      customColors: customColors,
                    ),
                ],
              ),
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
                    onTap: () {/* Navigate to macro goals */},
                    colorScheme: colorScheme,
                    customColors: customColors,
                  ),
                  _buildSwitchTile(
                    icon: CupertinoIcons.wand_stars,
                    iconColor: Colors.purple,
                    title: 'AI Meal Suggestions',
                    subtitle: 'Get personalized recommendations',
                    value: true,
                    onChanged: (value) {/* Toggle AI suggestions */},
                    colorScheme: colorScheme,
                    customColors: customColors,
                  ),
                  _buildListTile(
                    icon: CupertinoIcons.arrow_up_arrow_down,
                    iconColor: Colors.orange,
                    title: 'Unit System',
                    subtitle: 'Current: $_selectedUnit',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showUnitPicker,
                    colorScheme: colorScheme,
                    customColors: customColors,
                  ),
                ],
              ),
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
                    onChanged: (value) => themeProvider.toggleTheme(),
                    colorScheme: colorScheme,
                    customColors: customColors,
                  ),
                ],
              ),
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
                      setState(() {
                        _notificationSettings[entry.key] = value;
                      });
                    },
                    colorScheme: colorScheme,
                    customColors: customColors,
                  );
                }).toList(),
              ),
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
                ],
              ),
              _buildSection(
                title: 'Support',
                icon: CupertinoIcons.question_circle_fill,
                colorScheme: colorScheme,
                customColors: customColors,
                children: [
                  _buildListTile(
                    icon: CupertinoIcons.question_diamond_fill,
                    iconColor: colorScheme.primary,
                    title: 'Help Center',
                    subtitle: 'Get answers to common questions',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {/* Navigate to help center */},
                    colorScheme: colorScheme,
                    customColors: customColors,
                  ),
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
            color: colorScheme.primary.withOpacity(0.1),
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
          color: colorScheme.onBackground,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
      ),
      centerTitle: false,
    );
  }

  Widget _buildProfileHeader(
      ColorScheme colorScheme, CustomColors? customColors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.primary.withOpacity(0.8),
            colorScheme.primary.withOpacity(0.6),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor:
                      colorScheme.primaryContainer.withOpacity(0.6),
                  child: Text(
                    userData['name'].toString().substring(0, 1).toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userData['name'],
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(CupertinoIcons.mail,
                            color: Colors.white.withOpacity(0.9), size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            userData['email'],
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {/* Edit profile */},
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.pencil,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow(
      ColorScheme colorScheme, CustomColors? customColors) {
    final actions = [
      {
        'icon': CupertinoIcons.person_fill,
        'color': Colors.blue,
        'label': 'Profile',
        'onTap': () {/* Navigate to profile */},
      },
      {
        'icon': CupertinoIcons.chart_bar_alt_fill,
        'color': Colors.orange,
        'label': 'Goals',
        'onTap': () {/* Navigate to goals */},
      },
      {
        'icon': CupertinoIcons.bell_fill,
        'color': Colors.red,
        'label': 'Alerts',
        'onTap': () {/* Show notifications */},
      },
      {
        'icon': CupertinoIcons.heart_fill,
        'color': Colors.pink,
        'label': 'Health',
        'onTap': () {/* Health settings */},
      },
      {
        'icon': CupertinoIcons.star_fill,
        'color': Colors.amber,
        'label': 'Premium',
        'onTap': () {/* Show premium options */},
      },
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: action['onTap'] as VoidCallback,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color:
                          customColors?.cardBackground ?? colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.onSurface.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      action['icon'] as IconData,
                      color: action['color'] as Color,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  action['label'] as String,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
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
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: colorScheme.primary,
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
                  color: colorScheme.shadow.withOpacity(0.04),
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
            color: iconColor.withOpacity(0.1),
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
            color: colorScheme.onSurface.withOpacity(0.6),
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
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
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
            color: colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        value: value,
        activeColor: colorScheme.primary,
        inactiveThumbColor: colorScheme.onSurface.withOpacity(0.4),
        onChanged: onChanged,
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
      case 'hydrationTracking':
        return CupertinoIcons.drop_fill;
      case 'weeklyReports':
        return CupertinoIcons.chart_bar_alt_fill;
      case 'achievementAlerts':
        return CupertinoIcons.star_fill;
      default:
        return CupertinoIcons.bell_fill;
    }
  }

  Color _getNotificationColor(String key) {
    switch (key) {
      case 'mealReminders':
        return Colors.orange;
      case 'hydrationTracking':
        return Colors.blue;
      case 'weeklyReports':
        return Colors.green;
      case 'achievementAlerts':
        return Colors.amber;
      default:
        return Colors.purple;
    }
  }

  String _getNotificationTitle(String key) {
    switch (key) {
      case 'mealReminders':
        return 'Meal Reminders';
      case 'hydrationTracking':
        return 'Hydration Tracking';
      case 'weeklyReports':
        return 'Weekly Reports';
      case 'achievementAlerts':
        return 'Achievement Alerts';
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
              setState(() => _selectedUnit = 'Metric');
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Imperial (lb, in)'),
            onPressed: () {
              setState(() => _selectedUnit = 'Imperial');
              Navigator.pop(context);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
