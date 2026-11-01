import 'dart:async';

import 'package:macrotracker/Health/Health.dart';

/// Tests describe the iOS app, which has Apple Health, unless a test turns
/// health off to check the Android layout.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  HealthService.debugIsSupported = true;
  await testMain();
}
