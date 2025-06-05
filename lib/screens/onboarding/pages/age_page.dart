import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/widgets/onboarding/tooltip_icon.dart';

class AgePage extends StatefulWidget {
  final int currentAge;
  final ValueChanged<int> onAgeChanged;

  const AgePage({
    super.key,
    required this.currentAge,
    required this.onAgeChanged,
  });

  @override
  State<AgePage> createState() => _AgePageState();
}

class _AgePageState extends State<AgePage> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    // Initialize with the current age
    _selectedDate =
        DateTime.now().subtract(Duration(days: widget.currentAge * 365));
  }

  int calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(flex: 1),
            _buildHeader(theme, customColors),
            const SizedBox(height: 50),
            _buildAgeDisplay(theme, customColors),
            const SizedBox(height: 24),
            _buildDatePicker(theme, customColors),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, CustomColors? customColors) {
    return Column(
      children: [
        Text(
          'When were you born?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: customColors?.textPrimary ??
                theme.textTheme.headlineSmall?.color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black12
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: customColors?.textSecondary ?? theme.hintColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Used to calculate your metabolic rate',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: customColors?.textSecondary ??
                      theme.textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(width: 4),
              const TooltipIcon(
                message:
                    'Your age affects your basal metabolic rate calculation',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAgeDisplay(ThemeData theme, CustomColors? customColors) {
    final Color primaryColor =
        customColors?.textPrimary ?? theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
      decoration: BoxDecoration(
        color: primaryColor.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: primaryColor.withAlpha((0.2 * 255).round()),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.currentAge}',
            style: TextStyle(
              color: primaryColor,
              fontSize: 25,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'years',
            style: TextStyle(
              color: (customColors?.textPrimary ??
                      theme.textTheme.bodyLarge?.color)
                  ?.withAlpha((0.8 * 255).round()),
              fontSize: 20,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(ThemeData theme, CustomColors? customColors) {
    return Container(
      height: 220, // Reduced height of the picker
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.black12
            : Colors.white,
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? [
                BoxShadow(
                  color: Colors.grey.withAlpha((0.2 * 255).round()),
                  spreadRadius: 1,
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: CupertinoTheme(
        data: CupertinoThemeData(
          textTheme: CupertinoTextThemeData(
            dateTimePickerTextStyle: TextStyle(
              color:
                  customColors?.textPrimary ?? theme.textTheme.bodyLarge?.color,
              fontSize: 18, // Slightly smaller font size
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        child: CupertinoDatePicker(
          itemExtent: 36.0, // Slightly reduced item height
          mode: CupertinoDatePickerMode.date,
          initialDateTime: _selectedDate,
          minimumDate: DateTime.now()
              .subtract(const Duration(days: 29200)), // 80 years ago
          maximumDate: DateTime.now()
              .subtract(const Duration(days: 6570)), // 18 years ago
          backgroundColor: Colors.transparent,
          onDateTimeChanged: (DateTime newDate) {
            _selectedDate = newDate;
            final age = calculateAge(newDate);
            if (age >= 18 && age <= 80) {
              HapticFeedback.selectionClick();
              widget.onAgeChanged(age);
            }
          },
        ),
      ),
    );
  }
}
