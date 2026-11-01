import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/foodEntry.dart';
import '../../../providers/dateProvider.dart';
import '../../../providers/foodEntryProvider.dart';
import '../../../AI/gemini.dart' show PhotoAnalysisFailure;
import '../../../services/photo_analysis_service.dart';
import '../../../services/posthog_service.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/typography.dart';
import '../../../utils/food_clipboard.dart';
import '../../../utils/meal_time.dart';
import '../../../widgets/app_toast.dart';
import 'photo_job_card.dart';

const _accent = Color(0xFFFFC107);

/// A step lighter than the meal cards, so the dock reads as floating above
/// them rather than blending in.
Color? _floatingSurface(BuildContext context) {
  final card = Theme.of(context).extension<CustomColors>()?.cardBackground;
  if (card == null || Theme.of(context).brightness == Brightness.light) return card;
  return Color.lerp(card, Colors.white, 0.08);
}

/// Floats above the bottom bar on the dashboard: the meal photo being
/// analysed (or ready, or failed), and the paste bar while foods are copied.
class DashboardDock extends StatelessWidget {
  const DashboardDock({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PhotoJobPill(),
        CopyDropZone(),
        PasteBar(),
      ],
    );
  }
}

/// The one place a meal photo shows: "Analyzing your dinner…" while it's
/// analysed, then "ready" until tapped to review, or "couldn't" with a retry.
/// When there are several, the one still analysing comes first.
class PhotoJobPill extends StatelessWidget {
  const PhotoJobPill({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<PhotoAnalysisService>(context);
    final jobs = service.jobs;
    final analyzing = jobs.where((j) => j.status == PhotoJobStatus.analyzing).toList();
    final job = analyzing.isNotEmpty ? analyzing.first : (jobs.isEmpty ? null : jobs.last);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(animation), child: child),
      ),
      child: job == null
          ? const SizedBox.shrink()
          : Padding(
              key: ValueKey('${job.id}-${job.status}'),
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildPill(context, service, job, analyzing.length),
            ),
    );
  }

  Widget _buildPill(
      BuildContext context, PhotoAnalysisService service, PhotoJob job, int analyzingCount) {
    final colors = Theme.of(context).extension<CustomColors>();
    final meal = job.meal.toLowerCase();
    final noFood = job.error?.kind == PhotoAnalysisFailure.noFood;
    final (Widget status, String title, VoidCallback? onTap) = switch (job.status) {
      PhotoJobStatus.analyzing => (
          const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _accent)),
          analyzingCount > 1 ? 'Analyzing $analyzingCount photos…' : 'Analyzing your $meal…',
          null,
        ),
      PhotoJobStatus.ready => (
          const Icon(Icons.check_circle_rounded, size: 16, color: _accent),
          'Your $meal is ready · Review',
          () => reviewPhotoJob(job),
        ),
      PhotoJobStatus.failed => (
          Icon(Icons.error_outline_rounded, size: 16, color: Colors.red.shade400),
          noFood ? 'No food found · Retake' : "Couldn't analyze your $meal · Retry",
          () {
            // A retake starts a new photo; this one has nothing more to give.
            if (noFood) {
              service.dismiss(job);
              retakePhoto();
            } else {
              service.retry(job);
            }
          },
        ),
    };
    return Semantics(
      button: onTap != null,
      label: title,
      child: Material(
        color: _floatingSurface(context),
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: _accent.withOpacity(0.45)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap();
                },
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                6, 6, job.status == PhotoJobStatus.failed ? 0 : 12, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipOval(
                  child: Image.memory(job.photo,
                      width: 30,
                      height: 30,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(width: 30, height: 30)),
                ),
                const SizedBox(width: 10),
                status,
                const SizedBox(width: 8),
                Flexible(
                  child: ExcludeSemantics(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body2.copyWith(
                        color: colors?.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (job.status == PhotoJobStatus.failed)
                  IconButton(
                    tooltip: 'Dismiss',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close_rounded, size: 16, color: colors?.textSecondary),
                    onPressed: () => service.dismiss(job),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown only while a food is being dragged: drop it here to copy it instead
/// of moving it, then paste it from the paste bar into any meal or day.
class CopyDropZone extends StatelessWidget {
  const CopyDropZone({super.key});

  void _copy(BuildContext context, FoodEntry entry) {
    HapticFeedback.mediumImpact();
    FoodClipboard.instance.copyAndAnnounce([entry],
        what: entry.food.name, source: 'drag', context: context);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FoodEntry?>(
      valueListenable: FoodDrag.active,
      builder: (context, dragging, _) {
        if (dragging == null) return const SizedBox.shrink();
        final colors = Theme.of(context).extension<CustomColors>();
        return DragTarget<FoodEntry>(
          onAcceptWithDetails: (details) => _copy(context, details.data),
          builder: (context, candidates, _) {
            final over = candidates.isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: over ? _accent.withOpacity(0.22) : _floatingSurface(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accent, width: over ? 2 : 1),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.copy_rounded, color: _accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          over ? 'Let go to copy' : 'Drop here to copy',
                          style: AppTypography.body2.copyWith(
                            color: colors?.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Or drop on a meal to move it there',
                          style: AppTypography.caption
                              .copyWith(color: colors?.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// "Paste Coffee" with a button per meal, pasting into that meal on the day
/// shown on the dashboard (the same day or any other).
class PasteBar extends StatelessWidget {
  const PasteBar({super.key});

  Future<void> _paste(BuildContext context, List<FoodEntry> entries, String meal) async {
    HapticFeedback.mediumImpact();
    final provider = Provider.of<FoodEntryProvider>(context, listen: false);
    final date = Provider.of<DateProvider>(context, listen: false).selectedDate;
    final summary = FoodClipboard.instance.summary;
    // Cleared first so a second tap can't paste twice; put back if it fails.
    FoodClipboard.instance.clear();
    final List<FoodEntry> copies;
    try {
      copies = await provider.copyEntries(entries, to: date, meal: meal);
    } catch (_) {
      FoodClipboard.instance.copy(entries);
      rethrow;
    }
    MealTime.remember(meal);
    PostHogService.trackEvent('food_pasted', properties: {
      'meal_type': meal,
      'item_count': copies.length,
      'same_day': entries.every((e) => DateUtils.isSameDay(e.date, date)),
    });
    AppToast.show(
      'Pasted $summary into $meal',
      context: context.mounted ? context : null,
      actionLabel: 'Undo',
      onAction: () {
        for (final entry in copies) {
          provider.removeEntry(entry.id);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final clipboard = FoodClipboard.instance;
    return ValueListenableBuilder<List<FoodEntry>>(
      valueListenable: clipboard,
      builder: (context, entries, _) {
        if (entries.isEmpty) return const SizedBox.shrink();
        final colors = Theme.of(context).extension<CustomColors>();
        final dates = Provider.of<DateProvider>(context);
        final day = dates.isOnToday
            ? 'today'
            : 'on ${DateFormat.MMMEd().format(dates.selectedDate)}';
        return Material(
          color: _floatingSurface(context),
          elevation: 6,
          shadowColor: Colors.black.withOpacity(0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _accent.withOpacity(0.45)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 4, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.content_paste_rounded, size: 18, color: _accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Paste ${clipboard.summary}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body2.copyWith(
                              color: colors?.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Tap the meal to add it to, $day',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption
                                .copyWith(color: colors?.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cancel paste',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close_rounded, size: 18, color: colors?.textSecondary),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        clipboard.clear();
                      },
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Row(
                    children: [
                      for (final meal in MealTime.meals) ...[
                        if (meal != MealTime.meals.first) const SizedBox(width: 6),
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: () => _paste(context, entries, meal),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              minimumSize: const Size(0, 36),
                              backgroundColor: _accent.withOpacity(0.15),
                              foregroundColor: colors?.textPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: FittedBox(
                              child: Text(meal,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
