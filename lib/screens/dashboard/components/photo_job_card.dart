import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../AI/gemini.dart' show PhotoAnalysisFailure;
import '../../../camera/results_page.dart';
import '../../../main.dart' show navigatorKey, scaffoldMessengerKey;
import '../../../services/camera_service.dart';
import '../../../services/photo_analysis_service.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/typography.dart';

/// Opens the detected foods for review; nothing is logged until the user adds them.
void reviewPhotoJob(PhotoJob job) {
  final navigator = navigatorKey.currentState;
  final context = navigatorKey.currentContext;
  if (navigator == null || context == null) return;
  Provider.of<PhotoAnalysisService>(context, listen: false).dismiss(job);
  navigator.push(CupertinoPageRoute(
    builder: (_) => ResultsPage(foods: job.foods, meal: job.meal, date: job.date),
  ));
}

void _retake() {
  CameraService().showNativeCamera().catchError((_) {});
}

/// Banner shown when a background analysis finishes while the app is open.
void showPhotoJobBanner(PhotoJob job) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;
  final ok = job.status == PhotoJobStatus.ready;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(ok
          ? 'Your ${job.meal.toLowerCase()} is ready'
          : job.error?.message ?? "Couldn't analyze your photo"),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: ok ? 'Review' : 'Retake',
        onPressed: () => ok ? reviewPhotoJob(job) : _retake(),
      ),
    ),
  );
}

/// Placeholder row inside a meal card while its photo is analysed, and the
/// entry point to review or retry once it's done.
class PhotoJobCard extends StatelessWidget {
  final PhotoJob job;

  const PhotoJobCard({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final service = Provider.of<PhotoAnalysisService>(context, listen: false);
    const accent = Color(0xFFFFC107);

    late final Widget leading;
    late final String title;
    late final String subtitle;
    List<Widget> actions = [];

    switch (job.status) {
      case PhotoJobStatus.analyzing:
        leading = const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: accent),
        );
        title = 'Analyzing your meal…';
        subtitle = 'You can keep using the app';
        break;
      case PhotoJobStatus.ready:
        leading = const Icon(Icons.check_circle_rounded, color: accent);
        title = 'Your meal is ready';
        subtitle = job.foods.length == 1
            ? job.foods.first.name
            : '${job.foods.length} foods found · review before logging';
        actions = [
          TextButton(onPressed: () => reviewPhotoJob(job), child: const Text('Review')),
        ];
        break;
      case PhotoJobStatus.failed:
        final noFood = job.error?.kind == PhotoAnalysisFailure.noFood;
        leading = Icon(Icons.error_outline_rounded, color: Colors.red.shade400);
        title = job.error?.message ?? "Couldn't analyze your photo";
        subtitle = noFood ? 'Try a clearer photo of the plate' : 'Your photo is kept, so you can retry';
        actions = [
          TextButton(
            onPressed: () => noFood ? _retake() : service.retry(job),
            child: Text(noFood ? 'Retake' : 'Retry'),
          ),
          IconButton(
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => service.dismiss(job),
          ),
        ];
        break;
    }

    return InkWell(
      onTap: job.status == PhotoJobStatus.ready ? () => reviewPhotoJob(job) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.08),
          border: Border(
            top: BorderSide(
              color: customColors?.dateNavigatorBackground ?? Colors.grey,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(job.photo, width: 40, height: 40, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(width: 40, height: 40)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    leading,
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        style: AppTypography.body2.copyWith(
                          color: customColors?.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(color: customColors?.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}
