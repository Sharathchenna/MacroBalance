import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:macrotracker/screens/onboarding/pages/age_page.dart';
import 'package:macrotracker/screens/onboarding/pages/gender_page.dart';
import 'package:macrotracker/screens/onboarding/pages/height_page.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:provider/provider.dart';

/// The profile facts the account screen can edit.
enum ProfileField { sex, height, age }

/// Edits one of sex, height or age. Saving recomputes the targets with the
/// user's current settings, after an old -> new confirm.
class EditProfileFieldScreen extends StatefulWidget {
  const EditProfileFieldScreen({super.key, required this.field});

  final ProfileField field;

  @override
  State<EditProfileFieldScreen> createState() => _EditProfileFieldScreenState();
}

class _EditProfileFieldScreenState extends State<EditProfileFieldScreen> {
  late String _sex;
  late double _heightCm;
  late int _age;
  late bool _isMetric;

  @override
  void initState() {
    super.initState();
    final goals = context.read<GoalsProvider>();
    _sex = goals.sex ?? MacroCalculatorService.MALE;
    _heightCm = goals.heightCm ?? 170;
    _age = (goals.age ?? 30).clamp(kMinimumAge, 80);
    _isMetric = context.read<WeightUnitProvider>().isMetric;
  }

  String get _title => switch (widget.field) {
        ProfileField.sex => 'Sex',
        ProfileField.height => 'Height',
        ProfileField.age => 'Age',
      };

  Widget _picker() => switch (widget.field) {
        ProfileField.sex => GenderPage(
            currentGender: _sex,
            onGenderSelected: (sex) => setState(() => _sex = sex),
          ),
        ProfileField.height => HeightPage(
            currentHeightCm: _heightCm,
            isMetric: _isMetric,
            onHeightChanged: (cm) => setState(() => _heightCm = cm),
            onUnitChanged: (metric) => setState(() => _isMetric = metric),
          ),
        ProfileField.age => AgePage(
            currentAge: _age,
            onAgeChanged: (age) => setState(() => _age = age),
          ),
      };

  Future<void> _save() async {
    HapticFeedback.selectionClick();
    final goals = context.read<GoalsProvider>();
    final sex = widget.field == ProfileField.sex ? _sex : null;
    final height = widget.field == ProfileField.height ? _heightCm : null;
    final age = widget.field == ProfileField.age ? _age : null;

    // Nothing was changed: leave the targets alone (they may have been
    // edited by hand since they were last worked out).
    if ((sex == null || sex == goals.sex) &&
        (height == null || height == goals.heightCm) &&
        (age == null || age == goals.age)) {
      Navigator.of(context).pop(false);
      return;
    }

    final change = goals.previewProfile(sex: sex, heightCm: height, age: age);
    if (change != null && !change.isUnchanged) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _TargetsChangeDialog(change: change),
      );
      if (confirmed != true) return;
    }
    await goals.saveProfile(sex: sex, heightCm: height, age: age);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _picker()),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Your targets will change": each of the four targets, old -> new.
class _TargetsChangeDialog extends StatelessWidget {
  const _TargetsChangeDialog({required this.change});

  final ProfileChange change;

  static final _grouped = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>();
    final before = change.before;
    final after = change.after;

    Widget row(String label, double old, double next, String unit) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: customColors?.textSecondary)),
              ),
              Text(
                '${_grouped.format(old.round())} → ${_grouped.format(next.round())} $unit',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );

    return AlertDialog(
      title: const Text('Update your targets?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This changes what your daily targets are worked out from.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: customColors?.textSecondary)),
          const SizedBox(height: 12),
          row('Calories', before.calories, after.calories, 'cals'),
          row('Protein', before.protein, after.protein, 'g'),
          row('Carbs', before.carbs, after.carbs, 'g'),
          row('Fat', before.fat, after.fat, 'g'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Update'),
        ),
      ],
    );
  }
}
