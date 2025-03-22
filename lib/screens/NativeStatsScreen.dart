import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';

/// A utility class for displaying native iOS statistics screens
/// This is not a widget but a utility class with static methods
class NativeStatsScreen {
  // Method channel for communicating with native code
  static const MethodChannel _platform =
      MethodChannel('app.macrobalance.com/stats');

  // Static state management
  static bool _isScreenVisible = false;
  static Timer? _presentationDebounceTimer;
  static Timer? _lockTimer;
  static Completer<void>? _pendingOperation;

  /// Shows the native stats screen with specified section
  ///
  /// [context] - The BuildContext for showing error dialogs
  /// [initialSection] - Optional section to show initially ('weight', 'steps', 'calories', 'macros')
  /// Returns a Future that completes when the presentation is finished
  static Future<void> show(BuildContext context,
      {String? initialSection}) async {
    // If a presentation is already in progress, don't allow another
    if (_pendingOperation != null &&
        !(_pendingOperation?.isCompleted ?? true)) {
      debugPrint('Stats screen presentation already in progress');
      return _pendingOperation?.future ?? Future.value();
    }

    // If the screen is visible or we're in the lockout period, ignore
    if (_isScreenVisible || _lockTimer?.isActive == true) {
      debugPrint('Stats screen is already visible or in cooldown period');
      return Future.value();
    }

    // Cancel any existing timer to prevent race conditions
    _presentationDebounceTimer?.cancel();

    // Create new completer for this operation
    _pendingOperation = Completer<void>();

    // Mark the screen as visible immediately to prevent double-taps
    _isScreenVisible = true;

    // Add a small debounce to ensure any previous dismissals have completed
    _presentationDebounceTimer =
        Timer(const Duration(milliseconds: 300), () async {
      try {
        // Invoke the native method
        await _platform.invokeMethod('showStats', {
          'initialSection': initialSection ?? 'weight',
        });

        // Set a timer to automatically reset the state after 1 second
        // This handles cases where the native code might not call back
        Timer(const Duration(seconds: 1), () {
          // When the timer completes, add a 500ms lockout period
          _lockTimer = Timer(const Duration(milliseconds: 500), () {
            _lockTimer = null;
          });

          _isScreenVisible = false;
          if (_pendingOperation != null &&
              !(_pendingOperation?.isCompleted ?? true)) {
            _pendingOperation?.complete();
          }
        });
      } on PlatformException catch (e) {
        // Reset state on error
        _isScreenVisible = false;

        if (_pendingOperation != null &&
            !(_pendingOperation?.isCompleted ?? true)) {
          _pendingOperation?.completeError(e);
        }

        debugPrint('Error showing native stats: ${e.message}');

        // Only show dialog if context is still mounted
        if (context.mounted) {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Error'),
              content: Text('Could not show stats: ${e.message}'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('OK'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        // Handle any other errors
        _isScreenVisible = false;

        if (_pendingOperation != null &&
            !(_pendingOperation?.isCompleted ?? true)) {
          _pendingOperation?.completeError(e);
        }

        debugPrint('Unexpected error showing stats screen: $e');
      }
    });

    return _pendingOperation?.future ?? Future.value();
  }

  /// Resets the presentation state - can be called when app resumes
  /// to ensure the state is fresh
  static void resetState() {
    _presentationDebounceTimer?.cancel();
    _lockTimer?.cancel();
    _isScreenVisible = false;
    _lockTimer = null;
    if (_pendingOperation != null &&
        !(_pendingOperation?.isCompleted ?? true)) {
      _pendingOperation?.complete();
    }
    _pendingOperation = null;
  }
}
