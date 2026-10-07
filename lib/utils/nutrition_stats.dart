import 'dart:math' as math;

import 'weight_trend.dart';

/// What was logged on one day.
class DayIntake {
  const DayIntake({
    required this.cals,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final double cals;
  final double protein;
  final double carbs;
  final double fat;
}

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Intake over a run of days. Days with nothing logged are left out of every
/// average instead of counting as zero, and today isn't counted until it's
/// over (a half-logged day would drag everything down).
class NutritionSummary {
  NutritionSummary({
    required this.days,
    required this.byDay,
    required DateTime today,
  }) : _today = dayOf(today);

  /// Every day in the window, oldest first, ending today.
  final List<DateTime> days;

  /// Logged days only.
  final Map<DateTime, DayIntake> byDay;
  final DateTime _today;

  /// Builds the last [length] days ending on [today].
  factory NutritionSummary.lastDays(
    int length,
    Map<DateTime, DayIntake> intake, {
    required DateTime today,
  }) {
    final end = dayOf(today);
    final days = [
      for (var i = length - 1; i >= 0; i--)
        DateTime(end.year, end.month, end.day - i),
    ];
    return NutritionSummary(
      days: days,
      byDay: {
        for (final d in days)
          if (intake[d] != null && intake[d]!.cals > 0) d: intake[d]!,
      },
      today: today,
    );
  }

  /// Finished days that have something logged.
  List<DayIntake> get completeLogged => [
        for (final d in days)
          if (d.isBefore(_today) && byDay[d] != null) byDay[d]!,
      ];

  int get completeDays => days.where((d) => d.isBefore(_today)).length;
  int get loggedDays => completeLogged.length;

  double? _avg(double Function(DayIntake) of) {
    final logged = completeLogged;
    if (logged.isEmpty) return null;
    return logged.map(of).reduce((a, b) => a + b) / logged.length;
  }

  double? get avgCals => _avg((d) => d.cals);
  double? get avgProtein => _avg((d) => d.protein);
  double? get avgCarbs => _avg((d) => d.carbs);
  double? get avgFat => _avg((d) => d.fat);

  /// Finished days within [tolerance] of [goal] cals.
  int daysOnTarget(double goal, {double tolerance = 0.1}) {
    if (goal <= 0) return 0;
    return completeLogged
        .where((d) => (d.cals - goal).abs() <= goal * tolerance)
        .length;
  }

  /// Finished days with at least 90% of the [goal] grams of protein.
  int daysProteinHit(double goal) {
    if (goal <= 0) return 0;
    return completeLogged.where((d) => d.protein >= goal * 0.9).length;
  }
}

/// Maintenance cals worked out from what was eaten and what the scale did
/// over the same weeks.
class MaintenanceEstimate {
  const MaintenanceEstimate({
    required this.loggedDays,
    required this.weighInSpanDays,
    this.cals,
  });

  /// Rounded to 10 cals, or null until there's enough data.
  final double? cals;
  final int loggedDays;

  /// Days between the first and last weigh-in in the window.
  final int weighInSpanDays;

  static const int windowDays = 28;
  static const int minLoggedDays = 14;
  static const int minWeighInSpan = 14;

  bool get ready => cals != null;

  /// Weekly change in kg that eating [goalCals] a day would give.
  double? weeklyKgAt(double goalCals) =>
      cals == null ? null : (goalCals - cals!) * 7 / calsPerKg;

  /// Uses the [windowDays] finished days before [today]: average intake on
  /// logged days, minus the energy the weight change accounts for.
  static MaintenanceEstimate compute({
    required Map<DateTime, DayIntake> intake,
    required List<WeightEntry> weights,
    required DateTime today,
  }) {
    final end = dayOf(today); // exclusive
    final start = DateTime(end.year, end.month, end.day - windowDays);
    final logged = [
      for (var i = 0; i < windowDays; i++)
        intake[DateTime(start.year, start.month, start.day + i)],
    ].whereType<DayIntake>().where((d) => d.cals > 0).toList();
    final inWindow = weights
        .where((w) => !w.day.isBefore(start) && !w.day.isAfter(end))
        .toList();
    final span = inWindow.length < 2
        ? 0
        : inWindow.last.day.difference(inWindow.first.day).inDays;

    double? cals;
    if (logged.length >= minLoggedDays && span >= minWeighInSpan) {
      final avg = logged.map((d) => d.cals).reduce((a, b) => a + b) /
          logged.length;
      final weekly = weeklyRateKg(inWindow, minDays: minWeighInSpan);
      if (weekly != null) {
        final estimate = avg - weekly / 7 * calsPerKg;
        // Outside this the logs or weigh-ins are almost certainly incomplete.
        if (estimate >= 1000 && estimate <= 6000) {
          cals = (estimate / 10).round() * 10.0;
        }
      }
    }
    return MaintenanceEstimate(
      cals: cals,
      loggedDays: logged.length,
      weighInSpanDays: math.max(0, span),
    );
  }
}
