import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrotracker/Health/Health.dart';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/themeProvider.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class HealthIntegrationScreen extends StatefulWidget {
  const HealthIntegrationScreen({super.key});

  @override
  State<HealthIntegrationScreen> createState() =>
      _HealthIntegrationScreenState();
}

class _HealthIntegrationScreenState extends State<HealthIntegrationScreen> {
  final HealthService _healthService = HealthService();
  bool _isHealthConnected = false;
  bool _isLoading = true;
  String _healthDataStatus = "Checking connection...";

  // Health data
  int _steps = 0;
  double _calories = 0;
  String _heightWeight = "No data";

  // Permission statuses
  final Map<String, bool> _permissions = {
    'Steps': false,
    'Calories': false,
    'Height & Weight': false,
  };

  @override
  void initState() {
    super.initState();
    _loadConnectionStatus(); // Load from SharedPreferences
  }

  Future<void> _loadConnectionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isHealthConnected = prefs.getBool('healthConnected') ?? false;
      _healthDataStatus = _isHealthConnected
          ? "Connected to Health App"
          : "Not connected to Health App";
    });
    if (_isHealthConnected) {
      _fetchHealthData();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveConnectionStatus(bool connected) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('healthConnected', connected);
  }

  Future<void> _connectHealthApp() async {
    setState(() {
      _isLoading = true;
      _healthDataStatus = "Requesting permissions...";
    });

    try {
      final granted = await _healthService.requestPermissions();
      setState(() {
        _isHealthConnected = granted;
        _healthDataStatus = granted
            ? "Successfully connected to Health App"
            : "Permission denied for Health App";
      });
      await _saveConnectionStatus(_isHealthConnected); // Save the status

      if (granted) {
        await _fetchHealthData();
        _showSuccessSnackbar("Successfully connected to Health App");
      } else {
        _showErrorSnackbar(
            "Failed to connect to Health App: Permission denied");
      }
    } catch (e) {
      setState(() {
        _healthDataStatus = "Error connecting to Health App";
      });
      _showErrorSnackbar("Failed to connect to Health App: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchHealthData() async {
    try {
      // Get steps
      final steps = await _healthService.getSteps();

      // Get calories
      final calories = await _healthService.getCalories();

      // Get height and weight
      final heightWeight = await _healthService.getHeightandWeight();

      setState(() {
        _steps = steps;
        _calories = calories;
        _heightWeight = heightWeight;

        // Update permissions based on successful data retrieval
        _permissions['Steps'] = steps > 0;
        _permissions['Calories'] = calories > 0;
        _permissions['Height & Weight'] = heightWeight != "Error" &&
            heightWeight != "Height or weight data not available";
      });
    } catch (e) {
      _showErrorSnackbar("Failed to fetch health data: $e");
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
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
          appBar: AppBar(
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
                child: Icon(CupertinoIcons.back,
                    color: colorScheme.primary, size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Health Integration',
              style: GoogleFonts.poppins(
                color: colorScheme.onBackground,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            centerTitle: false,
          ),
          body: _isLoading
              ? _buildLoadingIndicator(colorScheme)
              : _buildBody(colorScheme, customColors),
        );
      },
    );
  }

  Widget _buildLoadingIndicator(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            _healthDataStatus,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme, CustomColors? customColors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHealthStatusCard(colorScheme, customColors),
          const SizedBox(height: 24),
          if (_isHealthConnected)
            _buildHealthDataCards(colorScheme, customColors),
          const SizedBox(height: 24),
          _buildPermissionsSection(colorScheme, customColors),
          const SizedBox(height: 24),
          _buildActionButtons(colorScheme),
        ],
      ),
    );
  }

  Widget _buildHealthStatusCard(
      ColorScheme colorScheme, CustomColors? customColors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isHealthConnected
              ? [colorScheme.primary, colorScheme.primary.withBlue(255)]
              : [Colors.grey, Colors.blueGrey],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isHealthConnected
                  ? CupertinoIcons.heart_fill
                  : CupertinoIcons.heart_slash_fill,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isHealthConnected ? "Connected" : "Not Connected",
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isHealthConnected
                      ? "Your health data is being synced"
                      : "Connect to sync your health data",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthDataCards(
      ColorScheme colorScheme, CustomColors? customColors) {
    final healthMetrics = [
      {
        'icon': Icons.directions_walk,
        'color': Colors.blue,
        'title': 'Steps Today',
        'value': '$_steps',
        'subtitle': 'steps',
      },
      {
        'icon': CupertinoIcons.flame_fill,
        'color': Colors.orange,
        'title': 'Calories Burned',
        'value': '${_calories.toStringAsFixed(0)}',
        'subtitle': 'calories',
      },
      {
        'icon': CupertinoIcons.person_fill,
        'color': Colors.green,
        'title': 'Body Metrics',
        'value': _heightWeight,
        'subtitle': '',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            "Health Data",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.onBackground,
            ),
          ),
        ),
        ...healthMetrics.map((metric) => _buildMetricCard(
              colorScheme,
              customColors,
              metric['icon'] as IconData,
              metric['color'] as Color,
              metric['title'] as String,
              metric['value'] as String,
              metric['subtitle'] as String,
            )),
      ],
    );
  }

  Widget _buildMetricCard(
    ColorScheme colorScheme,
    CustomColors? customColors,
    IconData icon,
    Color color,
    String title,
    String value,
    String subtitle,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: customColors?.cardBackground ?? colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                if (title == 'Body Metrics')
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    softWrap: true,
                  )
                else
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          " $subtitle",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsSection(
      ColorScheme colorScheme, CustomColors? customColors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            "Health Permissions",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: customColors?.cardBackground ?? colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: _permissions.entries.map((entry) {
              return _buildPermissionTile(
                title: entry.key,
                granted: entry.value,
                colorScheme: colorScheme,
                customColors: customColors,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required bool granted,
    required ColorScheme colorScheme,
    required CustomColors? customColors,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: granted
              ? Colors.green.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          granted ? Icons.check_circle : Icons.cancel_outlined,
          color: granted ? Colors.green : Colors.grey,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        granted ? "Permission granted" : "Permission not granted",
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme) {
    return Column(
      children: [
        if (!_isHealthConnected)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _connectHealthApp,
              icon: const Icon(CupertinoIcons.link),
              label: Text(
                "Connect to Health App",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _fetchHealthData,
              icon: const Icon(CupertinoIcons.refresh),
              label: Text(
                "Refresh Health Data",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
