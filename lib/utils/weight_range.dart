import 'package:intl/intl.dart';

/// Date ranges for the weight chart.
enum WeightRange {
  week('1W'),
  month('1M'),
  threeMonths('3M'),
  sixMonths('6M'),
  year('1Y'),
  all('All');

  const WeightRange(this.label);

  /// Short label shown in the range selector.
  final String label;

  /// First moment included, or null for all time.
  DateTime? start(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    switch (this) {
      case WeightRange.week:
        return today.subtract(const Duration(days: 6));
      case WeightRange.month:
        return DateTime(today.year, today.month - 1, today.day);
      case WeightRange.threeMonths:
        return DateTime(today.year, today.month - 3, today.day);
      case WeightRange.sixMonths:
        return DateTime(today.year, today.month - 6, today.day);
      case WeightRange.year:
        return DateTime(today.year - 1, today.month, today.day);
      case WeightRange.all:
        return null;
    }
  }

  bool includes(DateTime date, DateTime now) {
    final from = start(now);
    return from == null || !date.isBefore(from);
  }

  /// Items whose date falls in this range, oldest first.
  List<T> filter<T>(Iterable<T> items, DateTime Function(T) dateOf,
      {DateTime? now}) {
    final at = now ?? DateTime.now();
    return items.where((item) => includes(dateOf(item), at)).toList()
      ..sort((a, b) => dateOf(a).compareTo(dateOf(b)));
  }

  /// Axis label for a point: weekday for a week, day of month for a month,
  /// month and day up to a year, month and year beyond that.
  String axisLabel(DateTime date) {
    switch (this) {
      case WeightRange.week:
        return DateFormat.E().format(date);
      case WeightRange.month:
        return DateFormat.d().format(date);
      case WeightRange.threeMonths:
      case WeightRange.sixMonths:
      case WeightRange.year:
        return DateFormat.MMMd().format(date);
      case WeightRange.all:
        return DateFormat.yMMM().format(date);
    }
  }

  /// Phrase for summaries like "2.1 kg lost in the last month".
  String get description {
    switch (this) {
      case WeightRange.week:
        return 'this week';
      case WeightRange.month:
        return 'this month';
      case WeightRange.threeMonths:
        return 'in 3 months';
      case WeightRange.sixMonths:
        return 'in 6 months';
      case WeightRange.year:
        return 'this year';
      case WeightRange.all:
        return 'overall';
    }
  }
}
