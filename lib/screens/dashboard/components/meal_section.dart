// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../searchPage.dart';
import '../../../models/foodEntry.dart';
import '../../../providers/dateProvider.dart';
import '../../../providers/foodEntryProvider.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/typography.dart';
import '../../../services/photo_analysis_service.dart';
import '../../../services/posthog_service.dart';
import '../../../utils/meal_time.dart';
import '../../../utils/number_format.dart';
import '../../foodDetail.dart';
import 'photo_job_card.dart';
import '../../../utils/quick_log.dart';

/// Widget that displays meal sections (Breakfast, Lunch, Snacks, Dinner).
/// Each meal can be expanded to show food entries and their nutritional info.
class MealSection extends StatefulWidget {
  const MealSection({super.key});

  @override
  State<MealSection> createState() => _MealSectionState();
}

class _MealSectionState extends State<MealSection> {
  // Only what the user toggled by hand, per day and meal. Anything not here
  // follows the default: open when it has food, a photo in progress, or is
  // the current meal of today.
  final Map<String, bool> _userExpanded = {};

  String _expandKey(DateTime date, String meal) =>
      '${date.year}-${date.month}-${date.day}-$meal';

  bool _isExpanded(DateTime date, String meal, bool hasContent) {
    final manual = _userExpanded[_expandKey(date, meal)];
    if (manual != null) return manual;
    if (hasContent) return true;
    return DateUtils.isSameDay(date, DateTime.now()) &&
        meal == MealTime.forTime(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Consumer<DateProvider>(
            builder: (context, dateProvider, _) => Column(
              children: [
                _buildMealCard('Breakfast',
                    key: ValueKey('Breakfast-${dateProvider.selectedDate}')),
                _buildMealCard('Lunch',
                    key: ValueKey('Lunch-${dateProvider.selectedDate}')),
                _buildMealCard('Snacks',
                    key: ValueKey('Snacks-${dateProvider.selectedDate}')),
                _buildMealCard('Dinner',
                    key: ValueKey('Dinner-${dateProvider.selectedDate}')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(String mealType, {Key? key}) {
    return Consumer3<FoodEntryProvider, DateProvider, PhotoAnalysisService>(
      key: key,
      builder: (context, foodEntryProvider, dateProvider, photoService, child) {
        final date = dateProvider.selectedDate;
        final entries = foodEntryProvider.getEntriesForMeal(date, mealType);
        final photoJobs = photoService.jobsFor(date, mealType);
        final expanded =
            _isExpanded(date, mealType, entries.isNotEmpty || photoJobs.isNotEmpty);

        double totalCalories = entries.fold(
            0.0,
            (sum, entry) =>
                sum + foodEntryProvider.calculateNutrientForEntry(entry, 'calories'));

        IconData getMealIcon() {
          switch (mealType) {
            case 'Breakfast':
              return Icons.breakfast_dining;
            case 'Lunch':
              return Icons.lunch_dining;
            case 'Dinner':
              return Icons.dinner_dining;
            case 'Snacks':
              return Icons.cookie;
            default:
              return Icons.restaurant;
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).extension<CustomColors>()?.cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.grey.shade300.withOpacity(0.4)
                    : Colors.black.withOpacity(0.2),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _userExpanded[_expandKey(date, mealType)] = !expanded);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.light
                              ? const Color(0xFFFFC107).withOpacity(0.1)
                              : const Color(0xFFFFC107).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          getMealIcon(),
                          color: const Color(0xFFFFC107),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mealType,
                              style: AppTypography.h3.copyWith(
                                color: Theme.of(context)
                                    .extension<CustomColors>()
                                    ?.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${entries.length} ${entries.length == 1 ? 'item' : 'items'}',
                              style: AppTypography.body2.copyWith(
                                color: Theme.of(context)
                                    .extension<CustomColors>()
                                    ?.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${totalCalories.toStringAsFixed(0)}',
                            style: AppTypography.body1.copyWith(
                              color: const Color(0xFFFFC107),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'kcal',
                            style: AppTypography.caption.copyWith(
                              color: Theme.of(context)
                                  .extension<CustomColors>()
                                  ?.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      _buildMealMenu(mealType, date, foodEntryProvider),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: Theme.of(context)
                              .extension<CustomColors>()
                              ?.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild:
                    _buildExpandedContent(entries, foodEntryProvider, mealType, photoJobs),
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMealMenu(String mealType, DateTime date, FoodEntryProvider provider) {
    final yesterday = date.subtract(const Duration(days: 1));
    final yesterdayEntries = provider.getEntriesForMeal(yesterday, mealType);
    return PopupMenuButton<String>(
      tooltip: '$mealType options',
      icon: Icon(
        Icons.more_horiz,
        color: Theme.of(context).extension<CustomColors>()?.textSecondary,
      ),
      onSelected: (value) {
        if (value == 'copy') _copyFromYesterday(mealType, date, provider);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'copy',
          enabled: yesterdayEntries.isNotEmpty,
          child: Text(yesterdayEntries.isEmpty
              ? 'Nothing logged for $mealType the day before'
              : 'Copy ${yesterdayEntries.length} ${yesterdayEntries.length == 1 ? 'item' : 'items'} from the day before'),
        ),
      ],
    );
  }

  Future<void> _copyFromYesterday(
      String mealType, DateTime date, FoodEntryProvider provider) async {
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    final copied = await provider.copyMeal(
      from: date.subtract(const Duration(days: 1)),
      to: date,
      meal: mealType,
    );
    if (copied.isEmpty) return;
    // The card may have been rebuilt or removed while the copy was saving.
    if (mounted) {
      setState(() => _userExpanded[_expandKey(date, mealType)] = true);
    }
    PostHogService.trackEvent('meal_copied', properties: {
      'meal_type': mealType,
      'item_count': copied.length,
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text('Copied ${copied.length} ${copied.length == 1 ? 'item' : 'items'} to $mealType'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            for (final entry in copied) {
              provider.removeEntry(entry.id);
            }
          },
        ),
      ),
    );
  }

  void _removeWithUndo(FoodEntry entry, FoodEntryProvider provider) {
    HapticFeedback.mediumImpact();
    provider.removeEntry(entry.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Removed ${entry.food.name}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => provider.addEntry(entry),
          ),
        ),
      );
  }

  void _openEntry(FoodEntry entry) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => FoodDetailPage(food: entry.food, existingEntry: entry),
      ),
    );
  }

  Widget _buildExpandedContent(List<FoodEntry> entries, FoodEntryProvider provider,
      String mealType, List<PhotoJob> photoJobs) {
    return Column(
      children: [
        ...photoJobs.map((job) => PhotoJobCard(key: ValueKey(job.id), job: job)),
        if (entries.isEmpty && photoJobs.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'No entries yet',
                style: AppTypography.body2.copyWith(
                  color: Theme.of(context).extension<CustomColors>()?.textSecondary,
                ),
              ),
            ),
          ),
        ...entries.map((entry) => _buildFoodEntryTile(entry, provider)),
        _buildAddFoodButton(mealType),
      ],
    );
  }

  Widget _buildAddFoodButton(String mealType) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextButton.icon(
        icon: Icon(Icons.add_circle_outline, size: 18, color: primary),
        label: Text(
          'Add Food to $mealType',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: primary,
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: primary.withOpacity(0.1),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(double.infinity, 40),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => FoodSearchPage(selectedMeal: mealType),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFoodEntryTile(FoodEntry entry, FoodEntryProvider provider) {
    final calories = provider.calculateNutrientForEntry(entry, 'calories');
    final protein = provider.calculateNutrientForEntry(entry, 'Protein');

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _removeWithUndo(entry, provider),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      child: InkWell(
        onTap: () => _openEntry(entry),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context)
                    .extension<CustomColors>()!
                    .dateNavigatorBackground,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.food.name,
                      style: AppTypography.body1.copyWith(
                        color: Theme.of(context).extension<CustomColors>()?.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      describeEntryAmount(entry),
                      style: AppTypography.caption.copyWith(
                        color: Theme.of(context).extension<CustomColors>()?.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${calories.toStringAsFixed(0)} kcal',
                    style: AppTypography.body2.copyWith(
                      color: Theme.of(context).extension<CustomColors>()?.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${protein.toStringAsFixed(1)}g protein',
                    style: AppTypography.caption.copyWith(
                      color: Theme.of(context).extension<CustomColors>()?.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
