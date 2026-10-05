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
                      const SizedBox(width: 8),
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
                    _buildExpandedContent(
                    entries, foodEntryProvider, mealType, photoJobs, date),
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

  /// "Same as yesterday?" card shown in an empty meal.
  Widget _buildRepeatYesterday(String mealType, DateTime date,
      List<FoodEntry> yesterday, FoodEntryProvider provider) {
    final colors = Theme.of(context).extension<CustomColors>();
    final isLight = Theme.of(context).brightness == Brightness.light;
    final kcal = yesterday.fold<double>(
        0, (sum, e) => sum + provider.calculateNutrientForEntry(e, 'calories'));
    // Group repeats: "Toast ×3" rather than "Toast, Toast and 1 more".
    final counts = <String, int>{};
    for (final e in yesterday) {
      counts[e.food.name] = (counts[e.food.name] ?? 0) + 1;
    }
    final names = [
      for (final c in counts.entries) c.value > 1 ? '${c.key} ×${c.value}' : c.key
    ];
    final summary = names.length <= 2
        ? names.join(' and ')
        : '${names.take(2).join(', ')} and ${names.length - 2} more';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Semantics(
        button: true,
        label: 'Repeat yesterday\'s $mealType: $summary, ${kcal.round()} kcal',
        excludeSemantics: true,
        child: Material(
          color: isLight ? Colors.black.withOpacity(0.03) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _copyFromYesterday(mealType, date, provider),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, size: 20, color: colors?.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Same as yesterday?',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors?.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$summary · ${kcal.round()} kcal',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: colors?.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Repeat',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
      String mealType, List<PhotoJob> photoJobs, DateTime date) {
    final empty = entries.isEmpty && photoJobs.isEmpty;
    final yesterday = empty
        ? provider.getEntriesForMeal(date.subtract(const Duration(days: 1)), mealType)
        : const <FoodEntry>[];
    return Column(
      children: [
        ...photoJobs.map((job) => PhotoJobCard(key: ValueKey(job.id), job: job)),
        // An empty meal that had food the day before offers to repeat it.
        if (empty && yesterday.isNotEmpty)
          _buildRepeatYesterday(mealType, date, yesterday, provider)
        else if (empty)
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
