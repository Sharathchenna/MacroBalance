// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/finish_day_link.dart';

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
import '../../../services/storage_service.dart';
import '../../../utils/food_clipboard.dart';
import '../../../utils/meal_routine.dart';
import '../../foodDetail.dart';
import 'finish_day_row.dart';
import 'photo_job_card.dart';
import '../../../utils/quick_log.dart';

import 'package:macrotracker/widgets/app_toast.dart';

/// Widget that displays meal sections (Breakfast, Lunch, Snacks, Dinner).
/// Each meal can be expanded to show food entries and their nutritional info.
class MealSection extends StatefulWidget {
  /// Keys for each meal's photo-analysis rows, so the dashboard can tell
  /// whether they're on screen and scroll to them.
  final Map<String, GlobalKey>? photoJobKeys;

  const MealSection({super.key, this.photoJobKeys});

  /// Storage key for whether [meal]'s card is open. Remembered on this
  /// device across days and app launches; meals start open.
  static String expandedKey(String meal) => 'meal_expanded_$meal';

  @override
  State<MealSection> createState() => _MealSectionState();
}

const _accent = Color(0xFFFFC107);

class _MealSectionState extends State<MealSection> {
  final _storage = StorageService();
  final _dismissals = RoutineDismissals();

  // The last open/closed the user chose for each meal, on every day. Empty
  // meals have nothing to open.
  bool _isExpanded(String meal) =>
      _storage.get(MealSection.expandedKey(meal)) as bool? ?? true;

  void _setExpanded(String meal, bool expanded) {
    setState(() {});
    _storage.put(MealSection.expandedKey(meal), expanded);
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
                _buildMealCard(
                  'Breakfast',
                  key: ValueKey('Breakfast-${dateProvider.selectedDate}'),
                ),
                _buildMealCard(
                  'Lunch',
                  key: ValueKey('Lunch-${dateProvider.selectedDate}'),
                ),
                _buildMealCard(
                  'Snacks',
                  key: ValueKey('Snacks-${dateProvider.selectedDate}'),
                ),
                _buildMealCard(
                  'Dinner',
                  key: ValueKey('Dinner-${dateProvider.selectedDate}'),
                ),
                FinishDayRow(key: FinishDayLink.rowKey),
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
        final empty = entries.isEmpty;
        final expanded = !empty && _isExpanded(mealType);

        double totalCalories = entries.fold(
          0.0,
          (sum, entry) =>
              sum +
              foodEntryProvider.calculateNutrientForEntry(entry, 'calories'),
        );

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

        final colors = Theme.of(context).extension<CustomColors>();
        // A meal of today offers "the usual": what the user keeps having in
        // it that isn't logged yet.
        final now = DateTime.now();
        final usual = !_dismissals.isHidden(mealType, now)
            ? MealRoutine.suggest(
                meal: mealType,
                viewedDate: date,
                today: now,
                entriesFor: (day) =>
                    foodEntryProvider.getEntriesForMeal(day, mealType),
              )
            : null;

        // Drop a food dragged from another meal here to move it.
        return DragTarget<FoodEntry>(
          onWillAcceptWithDetails: (details) => details.data.meal != mealType,
          onAcceptWithDetails: (details) =>
              _moveEntry(details.data, mealType, foodEntryProvider),
          builder: (context, candidates, _) => AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .extension<CustomColors>()
                  ?.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: candidates.isNotEmpty ? _accent : Colors.transparent,
                width: 2,
              ),
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
            // Taps ripple on the card itself, inside its rounded clip, rather
            // than as a square on the page behind it.
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  Semantics(
                    button: true,
                    label: empty
                        ? '$mealType, nothing logged yet. Add food'
                        : null,
                    excludeSemantics: empty,
                    // No ripple: the haptic and the expanding list are the feedback.
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (empty) {
                          _openSearch(mealType);
                          return;
                        }
                        HapticFeedback.selectionClick();
                        _setExpanded(mealType, !expanded);
                      },
                      onLongPress: empty
                          ? null
                          : () => _showCopySheet(entries, mealType),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.light
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
                                    empty
                                        ? 'Nothing logged yet'
                                        : '${entries.length} ${entries.length == 1 ? 'item' : 'items'}',
                                    style: AppTypography.body2.copyWith(
                                      color: colors?.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (empty)
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colors?.textSecondary.withOpacity(
                                    0.12,
                                  ),
                                ),
                                child: Icon(
                                  Icons.add_rounded,
                                  size: 20,
                                  color: colors?.textSecondary,
                                ),
                              )
                            else ...[
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
                                    'cals',
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
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Photo analysis shows whether or not the meal is open, so a
                  // closed meal never hides that something is happening.
                  if (photoJobs.isNotEmpty)
                    KeyedSubtree(
                      key: widget.photoJobKeys?[mealType],
                      child: Column(
                        children: [
                          for (final job in photoJobs)
                            PhotoJobCard(key: ValueKey(job.id), job: job),
                        ],
                      ),
                    ),
                  if (usual != null) _buildUsualMeal(usual, foodEntryProvider),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: _buildExpandedContent(
                      entries,
                      foodEntryProvider,
                    ),
                    crossFadeState: expanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _moveEntry(
    FoodEntry entry,
    String toMeal,
    FoodEntryProvider provider,
  ) async {
    HapticFeedback.mediumImpact();
    final moved = FoodEntry(
      id: entry.id,
      food: entry.food,
      meal: toMeal,
      quantity: entry.quantity,
      unit: entry.unit,
      date: entry.date,
      servingDescription: entry.servingDescription,
    );
    await provider.updateEntry(moved);
    PostHogService.trackEvent(
      'food_moved',
      properties: {'from_meal': entry.meal, 'to_meal': toMeal},
    );
    AppToast.show(
      'Moved ${entry.food.name} to $toMeal',
      context: mounted ? context : null,
      icon: Icons.swap_vert_rounded,
      actionLabel: 'Undo',
      onAction: () => provider.updateEntry(entry),
    );
  }

  /// "Your usual breakfast" card shown in a meal of today, offering what's
  /// usually in it and not logged yet.
  Widget _buildUsualMeal(RoutineSuggestion usual, FoodEntryProvider provider) {
    final colors = Theme.of(context).extension<CustomColors>();
    final isLight = Theme.of(context).brightness == Brightness.light;
    final mealType = usual.meal;
    final usualName = 'your usual ${mealType.toLowerCase()}';
    final title = 'Your usual ${mealType.toLowerCase()}';
    final kcal = usual.entries.fold<double>(
      0,
      (sum, e) => sum + provider.calculateNutrientForEntry(e, 'calories'),
    );
    // Group repeats: "Toast ×3" rather than "Toast, Toast and 1 more".
    final counts = <String, int>{};
    for (final e in usual.entries) {
      counts[e.food.name] = (counts[e.food.name] ?? 0) + 1;
    }
    final names = [
      for (final c in counts.entries)
        c.value > 1 ? '${c.key} ×${c.value}' : c.key,
    ];
    final summary = names.length <= 2
        ? names.join(' and ')
        : '${names.take(2).join(', ')} and ${names.length - 2} more';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Material(
        color: isLight
            ? Colors.black.withOpacity(0.03)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              label: 'Add $usualName: $summary, ${kcal.round()} cals',
              excludeSemantics: true,
              child: InkWell(
                onTap: () => _addUsual(usual, provider),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 20,
                        color: colors?.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors?.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$summary · ${kcal.round()} cals',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: colors?.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Add',
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
            // Lined up under the text, out of the way of the main action.
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 0, 0, 4),
              child: Semantics(
                button: true,
                label: 'Not today, hide $usualName',
                excludeSemantics: true,
                child: TextButton(
                  onPressed: () => _dismissUsual(mealType),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: colors?.textSecondary,
                  ),
                  child: Text(
                    'Not today',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors?.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addUsual(
    RoutineSuggestion usual,
    FoodEntryProvider provider,
  ) async {
    HapticFeedback.mediumImpact();
    final mealType = usual.meal;
    final today = DateTime.now();
    final copied = await provider.copyEntries(
      usual.entries,
      to: today,
      meal: mealType,
    );
    if (copied.isEmpty) return;
    await _dismissals.used(mealType);
    PostHogService.trackEvent(
      'usual_meal_added',
      properties: {
        'meal_type': mealType,
        'item_count': copied.length,
        'matching_days': usual.matchingDays,
      },
    );
    AppToast.show(
      'Added your usual ${mealType.toLowerCase()}',
      context: mounted ? context : null,
      actionLabel: 'Undo',
      onAction: () {
        for (final entry in copied) {
          provider.removeEntry(entry.id);
        }
      },
    );
  }

  Future<void> _dismissUsual(String mealType) async {
    HapticFeedback.selectionClick();
    await _dismissals.dismiss(mealType, DateTime.now());
    PostHogService.trackEvent(
      'usual_meal_dismissed',
      properties: {'meal_type': mealType},
    );
    if (mounted) setState(() {});
  }

  void _removeWithUndo(FoodEntry entry, FoodEntryProvider provider) {
    HapticFeedback.mediumImpact();
    provider.removeEntry(entry.id);
    AppToast.show(
      'Removed ${entry.food.name}',
      context: context,
      icon: Icons.delete_outline_rounded,
      actionLabel: 'Undo',
      onAction: () => provider.addEntry(entry),
    );
  }

  void _openEntry(FoodEntry entry) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) =>
            FoodDetailPage(food: entry.food, existingEntry: entry),
      ),
    );
  }

  Widget _buildExpandedContent(
    List<FoodEntry> entries,
    FoodEntryProvider provider,
  ) {
    return Column(
      children: entries
          .map((entry) => _buildFoodEntryTile(entry, provider))
          .toList(),
    );
  }

  /// Long press on a food or a meal header: copy it, to paste into another
  /// meal or day from the dashboard's paste bar.
  void _showCopySheet(
    List<FoodEntry> mealEntries,
    String mealType, {
    FoodEntry? entry,
  }) {
    HapticFeedback.mediumImpact();
    final colors = Theme.of(context).extension<CustomColors>();
    void copy(List<FoodEntry> entries, String what) {
      Navigator.pop(context);
      FoodClipboard.instance.copy(entries);
      PostHogService.trackEvent(
        'food_copied',
        properties: {'meal_type': mealType, 'item_count': entries.length},
      );
      AppToast.show(
        'Copied $what · pick a meal to paste into',
        context: context,
        icon: Icons.copy_rounded,
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: colors?.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (entry != null)
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: Text('Copy ${entry.food.name}'),
                  subtitle: Text(describeEntryAmount(entry)),
                  onTap: () => copy([entry], entry.food.name),
                ),
              if (entry == null || mealEntries.length > 1)
                ListTile(
                  leading: const Icon(Icons.copy_all_rounded),
                  title: Text('Copy all of $mealType'),
                  subtitle: Text(
                    '${mealEntries.length} ${mealEntries.length == 1 ? 'item' : 'items'}',
                  ),
                  onTap: () => copy(mealEntries, mealType.toLowerCase()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSearch(String mealType) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => FoodSearchPage(selectedMeal: mealType),
      ),
    );
  }

  /// Long press and drag a food onto another meal to move it there; long
  /// press and let go to copy it instead.
  Widget _buildFoodEntryTile(FoodEntry entry, FoodEntryProvider provider) {
    final calories = provider.calculateNutrientForEntry(entry, 'calories');
    var dragged = 0.0;

    return LongPressDraggable<FoodEntry>(
      data: entry,
      hapticFeedbackOnStart: true,
      onDragStarted: () => dragged = 0,
      onDragUpdate: (details) => dragged += details.delta.distance,
      onDragEnd: (details) {
        if (details.wasAccepted || dragged > 12 || !mounted) return;
        _showCopySheet(
          provider.getEntriesForMeal(entry.date, entry.meal),
          entry.meal,
          entry: entry,
        );
      },
      feedback: _buildDragFeedback(entry, calories),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _buildEntryRow(entry, provider, calories),
      ),
      child: _buildEntryRow(entry, provider, calories),
    );
  }

  Widget _buildDragFeedback(FoodEntry entry, double calories) {
    final colors = Theme.of(context).extension<CustomColors>();
    return Material(
      color: colors?.cardBackground,
      elevation: 8,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _accent, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.drag_indicator_rounded, size: 18, color: _accent),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                entry.food.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body2.copyWith(
                  color: colors?.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${calories.toStringAsFixed(0)} cals',
              style: AppTypography.caption.copyWith(
                color: colors?.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryRow(
    FoodEntry entry,
    FoodEntryProvider provider,
    double calories,
  ) {
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
                        color: Theme.of(context)
                            .extension<CustomColors>()
                            ?.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      describeEntryAmount(entry),
                      style: AppTypography.caption.copyWith(
                        color: Theme.of(context)
                            .extension<CustomColors>()
                            ?.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${calories.toStringAsFixed(0)} cals',
                style: AppTypography.body2.copyWith(
                  color: Theme.of(context)
                      .extension<CustomColors>()
                      ?.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
