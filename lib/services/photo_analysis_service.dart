import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../AI/gemini.dart';
import '../models/ai_food_item.dart';
import 'notification_service.dart';
import 'posthog_service.dart';

/// Turns a meal photo into detected foods. Throws [PhotoAnalysisException].
typedef PhotoAnalyzer = Future<List<AIFoodItem>> Function(Uint8List photo);

enum PhotoJobStatus { analyzing, ready, failed }

/// One meal photo being analysed for a given meal and day.
class PhotoJob {
  final String id;
  final String meal;
  final DateTime date;
  final Uint8List photo;
  PhotoJobStatus status = PhotoJobStatus.analyzing;
  List<AIFoodItem> foods = const [];
  PhotoAnalysisException? error;

  PhotoJob({
    required this.id,
    required this.meal,
    required this.date,
    required this.photo,
  });
}

/// Runs meal-photo analysis in the background so the camera can close straight
/// back to the dashboard. The dashboard shows each job as a card in its meal;
/// when a job finishes the user gets a banner (or a notification if the app is
/// in the background) and reviews the foods before anything is logged.
class PhotoAnalysisService extends ChangeNotifier with WidgetsBindingObserver {
  /// [analyzer] defaults to the Gemini analysis; tests pass their own.
  PhotoAnalysisService({this.onReady, PhotoAnalyzer? analyzer})
      : _analyze = analyzer ?? _analyzeWithGemini {
    WidgetsBinding.instance.addObserver(this);
  }

  final PhotoAnalyzer _analyze;

  static Future<List<AIFoodItem>> _analyzeWithGemini(Uint8List photo) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${const Uuid().v4()}.jpg');
    await file.writeAsBytes(photo);
    try {
      return await analyzeMealPhoto(file.path);
    } finally {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  /// Called when a job finishes while the app is in the foreground.
  final void Function(PhotoJob job)? onReady;

  final List<PhotoJob> _jobs = [];
  bool _inForeground = true;

  List<PhotoJob> get jobs => List.unmodifiable(_jobs);

  List<PhotoJob> jobsFor(DateTime date, String meal) => _jobs
      .where((job) => job.meal == meal && DateUtils.isSameDay(job.date, date))
      .toList();

  void start(Uint8List photo, {required String meal, required DateTime date}) {
    final job = PhotoJob(
      id: const Uuid().v4(),
      meal: meal,
      date: DateTime(date.year, date.month, date.day),
      photo: photo,
    );
    _jobs.add(job);
    notifyListeners();
    PostHogService.trackEvent('photo_analysis_started', properties: {'meal_type': meal});
    _run(job);
  }

  void retry(PhotoJob job) {
    job
      ..status = PhotoJobStatus.analyzing
      ..error = null;
    notifyListeners();
    _run(job);
  }

  /// Removes the job, for example once the user has opened its results.
  void dismiss(PhotoJob job) {
    _jobs.remove(job);
    notifyListeners();
  }

  Future<void> _run(PhotoJob job) async {
    final stopwatch = Stopwatch()..start();
    try {
      job.foods = await _analyze(job.photo);
      job.status = PhotoJobStatus.ready;
      PostHogService.trackEvent('photo_analysis_ready', properties: {
        'food_count': job.foods.length,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
    } on PhotoAnalysisException catch (e) {
      job
        ..status = PhotoJobStatus.failed
        ..error = e;
      PostHogService.trackEvent('photo_analysis_failed', properties: {
        'reason': e.kind.name,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
    } catch (e) {
      job
        ..status = PhotoJobStatus.failed
        ..error = PhotoAnalysisException(PhotoAnalysisFailure.server, e.toString());
    }
    if (!_jobs.contains(job)) return; // dismissed while running
    notifyListeners();
    _announce(job);
  }

  void _announce(PhotoJob job) {
    if (_inForeground) {
      onReady?.call(job);
      return;
    }
    final ok = job.status == PhotoJobStatus.ready;
    NotificationService().showNotification(
      id: job.id.hashCode & 0x7fffffff,
      title: ok ? 'Your ${job.meal.toLowerCase()} is ready' : "Couldn't analyze your photo",
      body: ok
          ? 'Review ${job.foods.length == 1 ? job.foods.first.name : '${job.foods.length} foods'} before logging.'
          : job.error?.message ?? 'Open the app to try again.',
      payload: 'photo_analysis',
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inForeground = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
