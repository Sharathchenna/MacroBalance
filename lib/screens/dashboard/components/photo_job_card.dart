import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../AI/gemini.dart' show PhotoAnalysisFailure;
import '../../../camera/results_page.dart';
import '../../../main.dart' show navigatorKey;
import '../../../services/camera_service.dart';
import '../../../services/photo_analysis_service.dart';
import '../../../widgets/app_toast.dart';

/// Opens the detected foods for review; nothing is logged until the user adds them.
void reviewPhotoJob(PhotoJob job) {
  final navigator = navigatorKey.currentState;
  final context = navigatorKey.currentContext;
  if (navigator == null || context == null) return;
  final service = Provider.of<PhotoAnalysisService>(context, listen: false)..dismiss(job);
  navigator.push(CupertinoPageRoute(
    builder: (_) => ResultsPage(
        foods: job.foods,
        meal: job.meal,
        date: job.date,
        photo: job.photo,
        note: job.note,
        reviser: service.reviser),
  ));
}

/// Opens the camera for a new photo of the meal.
void retakePhoto() {
  CameraService().showNativeCamera().catchError((_) {});
}

PhotoAnalysisService? _service() {
  final context = navigatorKey.currentContext;
  return context == null ? null : Provider.of<PhotoAnalysisService>(context, listen: false);
}

void _retry(PhotoJob job) => _service()?.retry(job);

void _retakeFor(PhotoJob job) {
  _service()?.dismiss(job);
  retakePhoto();
}

/// Drops in from the top when a background analysis finishes while the app is
/// open, then leaves on its own; the dashboard's pill keeps the job for later.
void showPhotoJobBanner(PhotoJob job) {
  final ok = job.status == PhotoJobStatus.ready;
  final noFood = job.error?.kind == PhotoAnalysisFailure.noFood;
  HapticFeedback.lightImpact();
  AppToast.showNotice(
    leading: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(job.photo,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox(width: 40, height: 40)),
    ),
    title: ok
        ? 'Your ${job.meal.toLowerCase()} is ready'
        : job.error?.message ?? "Couldn't analyze your photo",
    subtitle: ok
        ? (job.foods.length == 1
            ? '${job.foods.first.name} · tap to review'
            : '${job.foods.length} foods · tap to review')
        : (noFood ? 'Try a clearer photo of the plate' : 'Your photo is kept, so you can retry'),
    actionLabel: ok ? 'Review' : (noFood ? 'Retake' : 'Retry'),
    onTap: ok ? () => reviewPhotoJob(job) : (noFood ? () => _retakeFor(job) : () => _retry(job)),
  );
}
