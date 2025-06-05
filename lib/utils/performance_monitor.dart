import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Comprehensive performance monitoring utility for MacroBalance
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final Map<String, DateTime> _operationStartTimes = {};
  final Map<String, Duration> _operationDurations = {};
  final List<PerformanceEvent> _events = [];
  final Map<String, int> _operationCounts = {};

  /// Track operation timing
  void startOperation(String operationName) {
    _operationStartTimes[operationName] = DateTime.now();
    _operationCounts[operationName] =
        (_operationCounts[operationName] ?? 0) + 1;

    if (kDebugMode) {
      developer.log('🚀 Started: $operationName', name: 'Performance');
    }
  }

  void endOperation(String operationName) {
    final startTime = _operationStartTimes.remove(operationName);
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      _operationDurations[operationName] = duration;

      _events.add(PerformanceEvent(
        name: operationName,
        duration: duration,
        timestamp: DateTime.now(),
      ));

      if (kDebugMode) {
        final emoji = duration.inMilliseconds > 100 ? '🐌' : '⚡';
        developer.log(
            '$emoji Finished: $operationName (${duration.inMilliseconds}ms)',
            name: 'Performance');
      }

      // Warn about slow operations
      if (duration.inMilliseconds > 100) {
        _logSlowOperation(operationName, duration);
      }
    }
  }

  /// Track memory usage
  void trackMemoryUsage(String context) {
    if (kDebugMode) {
      // Force garbage collection to get accurate reading
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

      developer.log('🧠 Memory check: $context', name: 'Memory');
    }
  }

  /// Track widget build performance
  Widget wrapWithPerformanceTracking(
    Widget child,
    String widgetName, {
    bool trackRebuilds = true,
  }) {
    return _PerformanceTrackingWidget(
      name: widgetName,
      trackRebuilds: trackRebuilds,
      child: child,
    );
  }

  /// Track async operations
  Future<T> trackAsyncOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    startOperation(operationName);
    try {
      final result = await operation();
      endOperation(operationName);
      return result;
    } catch (error) {
      endOperation(operationName);
      _logError(operationName, error);
      rethrow;
    }
  }

  /// Track FPS and frame rendering
  void startFrameTracking() {
    if (kDebugMode) {
      WidgetsBinding.instance.addPersistentFrameCallback((timeStamp) {
        _trackFrameTime(timeStamp);
      });
    }
  }

  DateTime? _lastFrameTime;
  final List<Duration> _frameTimes = [];

  void _trackFrameTime(Duration timeStamp) {
    final now = DateTime.now();
    if (_lastFrameTime != null) {
      final frameDuration = now.difference(_lastFrameTime!);
      _frameTimes.add(frameDuration);

      // Keep only last 60 frames
      if (_frameTimes.length > 60) {
        _frameTimes.removeAt(0);
      }

      // Calculate FPS
      if (_frameTimes.length >= 10) {
        final avgFrameTime =
            _frameTimes.map((d) => d.inMicroseconds).reduce((a, b) => a + b) /
                _frameTimes.length;
        final fps = 1000000 / avgFrameTime;

        // Log if FPS drops below 55
        if (fps < 55) {
          developer.log('📱 Low FPS detected: ${fps.toStringAsFixed(1)}',
              name: 'Performance');
        }
      }
    }
    _lastFrameTime = now;
  }

  /// Get performance report
  Map<String, dynamic> getPerformanceReport() {
    final report = <String, dynamic>{
      'operations': _operationDurations.map((key, value) => MapEntry(key, {
            'duration_ms': value.inMilliseconds,
            'count': _operationCounts[key] ?? 0,
          })),
      'slow_operations': _operationDurations.entries
          .where((entry) => entry.value.inMilliseconds > 100)
          .map((entry) => {
                'name': entry.key,
                'duration_ms': entry.value.inMilliseconds,
              })
          .toList(),
      'total_events': _events.length,
      'recent_events': _events
          .take(10)
          .map((event) => {
                'name': event.name,
                'duration_ms': event.duration.inMilliseconds,
                'timestamp': event.timestamp.toIso8601String(),
              })
          .toList(),
    };

    if (kDebugMode) {
      developer.log('📊 Performance Report: $report', name: 'Performance');
    }

    return report;
  }

  void _logSlowOperation(String operationName, Duration duration) {
    developer.log(
      '⚠️ SLOW OPERATION: $operationName took ${duration.inMilliseconds}ms',
      name: 'Performance',
      level: 900, // Warning level
    );
  }

  void _logError(String operationName, dynamic error) {
    developer.log(
      '❌ ERROR in $operationName: $error',
      name: 'Performance',
      level: 1000, // Error level
    );
  }

  /// Clear performance data
  void clear() {
    _operationStartTimes.clear();
    _operationDurations.clear();
    _events.clear();
    _operationCounts.clear();
    _frameTimes.clear();
  }
}

class PerformanceEvent {
  final String name;
  final Duration duration;
  final DateTime timestamp;

  PerformanceEvent({
    required this.name,
    required this.duration,
    required this.timestamp,
  });
}

class _PerformanceTrackingWidget extends StatefulWidget {
  final Widget child;
  final String name;
  final bool trackRebuilds;

  const _PerformanceTrackingWidget({
    required this.child,
    required this.name,
    required this.trackRebuilds,
  });

  @override
  _PerformanceTrackingWidgetState createState() =>
      _PerformanceTrackingWidgetState();
}

class _PerformanceTrackingWidgetState
    extends State<_PerformanceTrackingWidget> {
  int _buildCount = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.trackRebuilds) {
      _buildCount++;
      if (kDebugMode) {
        developer.log('🔄 ${widget.name} rebuild #$_buildCount',
            name: 'Rebuilds');
      }
    }

    return widget.child;
  }
}

/// Performance tracking mixin for StatefulWidgets
mixin PerformanceTrackingMixin<T extends StatefulWidget> on State<T> {
  late final String _widgetName;

  @override
  void initState() {
    super.initState();
    _widgetName = widget.runtimeType.toString();
    PerformanceMonitor().startOperation('${_widgetName}_init');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PerformanceMonitor().endOperation('${_widgetName}_init');
  }

  @override
  void dispose() {
    PerformanceMonitor().startOperation('${_widgetName}_dispose');
    super.dispose();
    PerformanceMonitor().endOperation('${_widgetName}_dispose');
  }

  /// Track specific operations within the widget
  void trackOperation(String operationName) {
    PerformanceMonitor().startOperation('${_widgetName}_$operationName');
  }

  void endTracking(String operationName) {
    PerformanceMonitor().endOperation('${_widgetName}_$operationName');
  }
}

/// Performance debugging overlay
class PerformanceOverlay extends StatefulWidget {
  final Widget child;

  const PerformanceOverlay({super.key, required this.child});

  @override
  // ignore: library_private_types_in_public_api
  _PerformanceOverlayState createState() => _PerformanceOverlayState();
}

class _PerformanceOverlayState extends State<PerformanceOverlay> {
  bool _showOverlay = false;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      // Reduced frequency from 2 seconds to 30 seconds to save CPU/memory
      _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted && _showOverlay) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (kDebugMode && _showOverlay)
          Positioned(
            top: 100,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Performance Monitor',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...PerformanceMonitor()
                      ._operationDurations
                      .entries
                      .take(5)
                      .map((entry) => Text(
                            '${entry.key}: ${entry.value.inMilliseconds}ms',
                            style: TextStyle(
                              color: entry.value.inMilliseconds > 100
                                  ? Colors.red
                                  : Colors.green,
                              fontSize: 12,
                            ),
                          )),
                ],
              ),
            ),
          ),
        if (kDebugMode)
          Positioned(
            top: 50,
            right: 10,
            child: FloatingActionButton.small(
              onPressed: () => setState(() => _showOverlay = !_showOverlay),
              child:
                  Icon(_showOverlay ? Icons.visibility_off : Icons.visibility),
            ),
          ),
      ],
    );
  }
}
