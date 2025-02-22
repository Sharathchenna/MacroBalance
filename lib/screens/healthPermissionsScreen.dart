import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:macrotracker/theme/app_theme.dart';

class HealthPermissionsScreen extends StatefulWidget {
  const HealthPermissionsScreen({super.key});

  @override
  State<HealthPermissionsScreen> createState() =>
      _HealthPermissionsScreenState();
}

class _HealthPermissionsScreenState extends State<HealthPermissionsScreen> {
  final Map<HealthDataType, bool> _permissions = {
    HealthDataType.WEIGHT: false,
    HealthDataType.STEPS: false,
    HealthDataType.ACTIVE_ENERGY_BURNED: false,
    HealthDataType.BASAL_ENERGY_BURNED: false,
  };

  final Map<HealthDataType, String> _permissionTitles = {
    HealthDataType.WEIGHT: 'Weight',
    HealthDataType.STEPS: 'Steps',
    HealthDataType.ACTIVE_ENERGY_BURNED: 'Active Energy',
    HealthDataType.BASAL_ENERGY_BURNED: 'Basal Energy',
  };

  final Map<HealthDataType, String> _permissionDescriptions = {
    HealthDataType.WEIGHT: 'Track your weight changes',
    HealthDataType.STEPS: 'Monitor your daily steps',
    HealthDataType.ACTIVE_ENERGY_BURNED: 'Track calories burned from exercise',
    HealthDataType.BASAL_ENERGY_BURNED: 'Track calories burned at rest',
  };

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final health = Health();

    try {
      for (var type in _permissions.keys) {
        bool? authorized = await health.hasPermissions([type]);
        setState(() {
          _permissions[type] = authorized ?? false;
        });
      }
    } catch (e) {
      print('Error checking health permissions: $e');
    }
  }

  Future<void> _requestPermission(HealthDataType type) async {
    final health = Health();

    try {
      bool authorized = await health.requestAuthorization([type]);
      setState(() {
        _permissions[type] = authorized;
      });
    } catch (e) {
      print('Error requesting health permission: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:
              Icon(CupertinoIcons.back, color: Theme.of(context).primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Health Permissions',
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: _permissions.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final type = _permissions.keys.elementAt(index);
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).extension<CustomColors>()?.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.surface),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _permissionTitles[type] ?? type.toString(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _permissionDescriptions[type] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoSwitch(
                    value: _permissions[type] ?? false,
                    onChanged: (value) => _requestPermission(type),
                    activeColor: Theme.of(context).colorScheme.secondary,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
