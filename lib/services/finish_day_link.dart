import 'package:flutter/widgets.dart';

/// Taps on the finish-day reminder land here. The app shell opens Home on
/// today and scrolls to the Finish day row.
///
/// A tap can arrive before any screen exists (the app was closed), so the
/// request stays [pending] until something [take]s it.
class FinishDayLink {
  FinishDayLink._();

  /// The payload of the local reminder and the `finish_day` push data flag.
  static const String payload = 'finish_day';

  static final ValueNotifier<int> requests = ValueNotifier(0);
  static bool pending = false;

  /// The Finish day row on Home, to scroll to.
  static final GlobalKey rowKey = GlobalKey(debugLabel: 'finish_day_row');

  static void request() {
    pending = true;
    requests.value++;
  }

  /// Whether a request was waiting; it won't be again.
  static bool take() {
    final was = pending;
    pending = false;
    return was;
  }
}
