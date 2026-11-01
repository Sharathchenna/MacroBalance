import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/posthog_service.dart';

/// What a person sees when something fails: a short line, never the raw
/// exception. The full error goes to PostHog as "error_occurred" (and the
/// debug log), so it can be looked into there instead.
class UserError {
  UserError._();

  static const offline = "You're offline. Check your connection and try again.";
  static const generic = 'Something went wrong. Please try again.';

  /// Reports [error] from [where] (a screen or action, e.g. "delete_account")
  /// and returns the words to show. [fallback] replaces the generic line for
  /// failures that aren't about the connection, e.g. "Couldn't save your
  /// workout. Please try again."
  static String describe(Object error,
      {required String where, String? fallback, StackTrace? stack}) {
    report(error, where: where, stack: stack);
    return messageFor(error, fallback: fallback);
  }

  /// The words to show for [error], without reporting it.
  static String messageFor(Object error, {String? fallback}) {
    if (isOffline(error)) return offline;
    // Supabase auth explains itself in plain words ("Invalid login
    // credentials", "Email not confirmed"), so those are kept.
    if (error is AuthException && _readable(error.message)) return error.message;
    return fallback ?? generic;
  }

  /// Sends [error] to PostHog without showing anything.
  static void report(Object error, {required String where, StackTrace? stack}) {
    debugPrint('[$where] $error${stack == null ? '' : '\n$stack'}');
    try {
      PostHogService.trackError(
        errorType: isOffline(error) ? 'offline' : error.runtimeType.toString(),
        errorMessage: _clip('$error', 1000),
        screen: where,
        properties: {if (stack != null) 'stack': _clip('$stack', 2000)},
      );
    } catch (_) {
      // Reporting must never be what breaks the screen.
    }
  }

  static final _offlinePattern = RegExp(
    r'SocketException|Failed host lookup|ClientException|HandshakeException|'
    r'Connection (refused|reset|closed|failed|timed out)|Network is unreachable|'
    r'TimeoutException|No address associated with hostname',
    caseSensitive: false,
  );

  /// No connection, a dropped one, or a server that didn't answer in time.
  static bool isOffline(Object error) =>
      error is SocketException ||
      error is TimeoutException ||
      error is HandshakeException ||
      error is AuthRetryableFetchException ||
      _offlinePattern.hasMatch('$error');

  static bool _readable(String message) =>
      message.isNotEmpty &&
      message.length <= 120 &&
      !message.contains('Exception') &&
      !message.contains('://');

  static String _clip(String text, int max) =>
      text.length <= max ? text : '${text.substring(0, max)}…';
}
