import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

class NativeStatsScreen extends StatefulWidget {
  final String? initialSection;

  const NativeStatsScreen({Key? key, this.initialSection}) : super(key: key);

  @override
  State<NativeStatsScreen> createState() => _NativeStatsScreenState();
}

class _NativeStatsScreenState extends State<NativeStatsScreen> {
  static const platform = MethodChannel('app.macrobalance.com/stats');
  bool _isLoading = true;
  String? _error;
  bool _hasShownStats = false;

  @override
  void initState() {
    super.initState();
    _initializeStats();
  }

  Future<void> _initializeStats() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Initialize stats services first
      await platform.invokeMethod('initialize');

      if (!mounted) return;

      // After successful initialization, show the stats screen
      await platform.invokeMethod(
          'showStats', {'initialSection': widget.initialSection ?? 'weight'});

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasShownStats = true;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message ?? 'Failed to initialize stats';
        _isLoading = false;
      });
      debugPrint('Stats screen error: ${e.message}');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Unexpected error occurred';
        _isLoading = false;
      });
      debugPrint('Stats screen unexpected error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Statistics'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _initializeStats,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // If we've successfully shown the stats screen, return an empty container
    // since the native view will be displayed on top
    return _hasShownStats ? Container() : const SizedBox.shrink();
  }
}
