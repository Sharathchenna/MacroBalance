import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/foodEntry.dart';
import '../../../providers/dateProvider.dart';
import '../../../providers/foodEntryProvider.dart';
import '../../../services/photo_analysis_service.dart';
import '../../../services/posthog_service.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/typography.dart';
import '../../../utils/food_clipboard.dart';
import '../../../utils/meal_time.dart';
import '../../../widgets/app_bottom_bar.dart';
import '../../../widgets/app_toast.dart';
import 'photo_job_card.dart';

const _accent = Color(0xFFFFC107);

/// Floats above the bottom bar on the dashboard: the progress of a meal photo
/// whose card is scrolled out of view, and the paste bar while foods are
/// copied.
class DashboardDock extends StatelessWidget {
  final ScrollController scrollController;
  final GlobalKey viewportKey;
  final Map<String, GlobalKey> photoJobKeys;

  const DashboardDock({
    super.key,
    required this.scrollController,
    required this.viewportKey,
    required this.photoJobKeys,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PhotoJobPill(
          scrollController: scrollController,
          viewportKey: viewportKey,
          photoJobKeys: photoJobKeys,
        ),
        const PasteBar(),
      ],
    );
  }
}

/// "Analyzing your dinner…" while that meal's photo rows are off screen.
/// Tapping it scrolls to them (switching day if needed), or opens the review
/// once the foods are ready.
class PhotoJobPill extends StatefulWidget {
  final ScrollController scrollController;
  final GlobalKey viewportKey;
  final Map<String, GlobalKey> photoJobKeys;

  const PhotoJobPill({
    super.key,
    required this.scrollController,
    required this.viewportKey,
    required this.photoJobKeys,
  });

  @override
  State<PhotoJobPill> createState() => _PhotoJobPillState();
}

enum _Where { onScreen, above, below, otherDay }

class _PhotoJobPillState extends State<PhotoJobPill> {
  _Where _where = _Where.onScreen;
  PhotoJob? _job;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_locate);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_locate);
    super.dispose();
  }

  /// Where [_job]'s rows are relative to the visible part of the dashboard.
  void _locate() {
    if (!mounted) return;
    final where = _whereIs(_job);
    if (where != _where) setState(() => _where = where);
  }

  _Where _whereIs(PhotoJob? job) {
    if (job == null) return _Where.onScreen;
    final selected = Provider.of<DateProvider>(context, listen: false).selectedDate;
    if (!DateUtils.isSameDay(job.date, selected)) return _Where.otherDay;
    final rows = widget.photoJobKeys[job.meal]?.currentContext?.findRenderObject();
    final viewport = widget.viewportKey.currentContext?.findRenderObject();
    if (rows is! RenderBox || viewport is! RenderBox) return _Where.onScreen;
    if (!rows.attached || !viewport.attached) return _Where.onScreen;
    final top = rows.localToGlobal(Offset.zero).dy;
    final bottom = top + rows.size.height;
    final viewTop = viewport.localToGlobal(Offset.zero).dy;
    // The bottom bar covers the last stretch of the viewport.
    final viewBottom = viewTop +
        viewport.size.height -
        AppBottomBar.bottomGap(context) -
        AppBottomBar.height;
    if (bottom <= viewTop) return _Where.above;
    if (top >= viewBottom) return _Where.below;
    return _Where.onScreen;
  }

  void _onTap(PhotoJob job) {
    HapticFeedback.selectionClick();
    if (job.status == PhotoJobStatus.ready) {
      reviewPhotoJob(job);
      return;
    }
    final dates = Provider.of<DateProvider>(context, listen: false);
    if (!DateUtils.isSameDay(job.date, dates.selectedDate)) dates.setDate(job.date);
    // After the (possibly new) day has built its meal cards.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rows = widget.photoJobKeys[job.meal]?.currentContext;
      if (rows == null || !rows.mounted) return;
      Scrollable.ensureVisible(rows,
          alignment: 0.4,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<PhotoAnalysisService>(context);
    // Rebuild when the day changes, since that moves the rows.
    Provider.of<DateProvider>(context);
    final jobs = service.jobs;
    final analyzing = jobs.where((j) => j.status == PhotoJobStatus.analyzing).toList();
    _job = analyzing.isNotEmpty ? analyzing.first : (jobs.isEmpty ? null : jobs.last);
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate());

    final job = _job;
    final show = job != null && _where != _Where.onScreen;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(animation), child: child),
      ),
      child: show
          ? Padding(
              key: ValueKey('${job.id}-${job.status}'),
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildPill(job, analyzing.length),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildPill(PhotoJob job, int analyzingCount) {
    final colors = Theme.of(context).extension<CustomColors>();
    final meal = job.meal.toLowerCase();
    final (Widget status, String title) = switch (job.status) {
      PhotoJobStatus.analyzing => (
          const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _accent)),
          analyzingCount > 1 ? 'Analyzing $analyzingCount photos…' : 'Analyzing your $meal…',
        ),
      PhotoJobStatus.ready => (
          const Icon(Icons.check_circle_rounded, size: 16, color: _accent),
          'Your $meal is ready · Review',
        ),
      PhotoJobStatus.failed => (
          Icon(Icons.error_outline_rounded, size: 16, color: Colors.red.shade400),
          "Couldn't analyze your $meal",
        ),
    };
    final arrow = switch (_where) {
      _Where.above => Icons.arrow_upward_rounded,
      _Where.otherDay => Icons.chevron_right_rounded,
      _ => Icons.arrow_downward_rounded,
    };
    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      child: Material(
        color: colors?.cardBackground,
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _onTap(job),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
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
                if (job.status != PhotoJobStatus.ready) ...[
                  const SizedBox(width: 6),
                  Icon(arrow, size: 16, color: colors?.textSecondary),
                ],
              ],
            ),
          ),
        ),
      ),
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
    FoodClipboard.instance.clear();
    final copies = await provider.copyEntries(entries, to: date, meal: meal);
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
          color: colors?.cardBackground,
          elevation: 6,
          shadowColor: Colors.black.withOpacity(0.25),
          borderRadius: BorderRadius.circular(20),
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
