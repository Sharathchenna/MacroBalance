import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/foodEntry.dart';
import '../providers/foodEntryProvider.dart';
import '../services/posthog_service.dart';
import '../theme/app_theme.dart';
import '../theme/typography.dart';
import '../utils/meal_time.dart';
import '../utils/quick_log.dart';
import '../widgets/quick_log_tile.dart';
import 'foodDetail.dart';

/// Every food the user has logged before, newest first and grouped by the
/// day it was last had, each one tap away from being logged again.
/// Reached from the history button on the search page.
class PreviouslyLoggedScreen extends StatefulWidget {
  /// Meal the + adds to; defaults to the one for this time of day.
  final String? selectedMeal;

  const PreviouslyLoggedScreen({super.key, this.selectedMeal});

  /// How many distinct foods to list.
  static const int limit = 200;

  @override
  State<PreviouslyLoggedScreen> createState() => _PreviouslyLoggedScreenState();
}

class _PreviouslyLoggedScreenState extends State<PreviouslyLoggedScreen> {
  final _filter = TextEditingController();

  @override
  void initState() {
    super.initState();
    PostHogService.trackScreen('previously_logged');
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  String _dayLabel(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    final day = DateUtils.dateOnly(date.toLocal());
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return day.year == today.year
        ? DateFormat.MMMEd().format(day)
        : DateFormat.yMMMd().format(day);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>();
    final meal = widget.selectedMeal ?? MealTime.suggested();
    final query = _filter.text.trim().toLowerCase();
    final foods = Provider.of<FoodEntryProvider>(context)
        .recentFoods(limit: PreviouslyLoggedScreen.limit)
        .where((e) => query.isEmpty || e.food.name.toLowerCase().contains(query))
        .toList();

    // Foods come newest first, so each day's group is contiguous.
    final rows = <Widget>[];
    String? day;
    for (final entry in foods) {
      final label = _dayLabel(entry.date);
      if (label != day) {
        day = label;
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: colors?.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ));
      }
      rows.add(foodHistoryTile(context, entry, meal));
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            tooltip: 'Back',
            icon: Icon(Icons.arrow_back_ios_rounded, size: 16, color: colors?.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Previously logged',
            style: AppTypography.h3.copyWith(
              color: colors?.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: false,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: TextField(
                controller: _filter,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Filter your foods',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: foods.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          query.isEmpty
                              ? 'Foods you log will show up here.'
                              : 'Nothing you\'ve logged matches "${_filter.text.trim()}".',
                          textAlign: TextAlign.center,
                          style: AppTypography.body2.copyWith(color: colors?.textSecondary),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Tap + to add to $meal',
                            style: AppTypography.caption.copyWith(color: colors?.textSecondary),
                          ),
                        ),
                        ...rows,
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A food the user logged before: + logs it again with the same amount into
/// [meal]; tapping the row opens its details. Used on the search page and in
/// Previously logged.
Widget foodHistoryTile(BuildContext context, FoodEntry template, String meal) =>
    QuickLogTile(
      title: template.food.name,
      subtitle: describeEntryAmount(template),
      trailingLabel: '${FoodEntryProvider.nutrientForEntry(template, 'calories').round()} cals',
      addTooltip: 'Add to $meal',
      onAdd: () => quickLogAgain(context, template, meal: meal),
      onOpen: () => Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) => FoodDetailPage(food: template.food, selectedMeal: meal),
        ),
      ),
    );
