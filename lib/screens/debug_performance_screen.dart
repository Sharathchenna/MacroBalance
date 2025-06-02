import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../utils/performance_monitor.dart';
import '../services/storage_service.dart';
import '../providers/food_entry_provider.dart';
import 'package:provider/provider.dart';

class DebugPerformanceScreen extends StatefulWidget {
  const DebugPerformanceScreen({super.key});

  @override
  State<DebugPerformanceScreen> createState() => _DebugPerformanceScreenState();
}

class _DebugPerformanceScreenState extends State<DebugPerformanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _refreshTimer;
  Map<String, dynamic> _performanceData = {};
  // Map<String, dynamic> _memoryData = {}; // Unused field
  Map<String, dynamic> _storageStats = {};
  bool _isRealTimeMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _refreshData();

    // Start frame tracking
    PerformanceMonitor().startFrameTracking();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refreshData() {
    if (!mounted) return;

    setState(() {
      _performanceData = PerformanceMonitor().getPerformanceReport();
      _storageStats = StorageService().getStorageStats();
      // _memoryData = _getMemoryInfo(); // Unused variable
    });
  }

  void _toggleRealTimeMode() {
    setState(() {
      _isRealTimeMode = !_isRealTimeMode;
    });

    if (_isRealTimeMode) {
      _refreshTimer =
          Timer.periodic(const Duration(seconds: 1), (_) => _refreshData());
    } else {
      _refreshTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔧 Performance Debug'),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isRealTimeMode ? Icons.pause : Icons.play_arrow),
            onPressed: _toggleRealTimeMode,
            tooltip: 'Toggle Real-time Monitoring',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              PerformanceMonitor().clear();
              _refreshData();
            },
            tooltip: 'Clear Performance Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: '⚡ Performance'),
            Tab(text: '🧠 Memory'),
            Tab(text: '💾 Storage'),
            Tab(text: '📊 Providers'),
            Tab(text: '🔧 Actions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPerformanceTab(),
          _buildMemoryTab(),
          _buildStorageTab(),
          _buildProvidersTab(),
          _buildActionsTab(),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: '📈 Operation Performance',
            child: Column(
              children: [
                if (_performanceData['operations'] != null)
                  ..._performanceData['operations']
                      .entries
                      .map<Widget>((entry) {
                    final data = entry.value as Map<String, dynamic>;
                    final duration = data['duration_ms'] as int;
                    final count = data['count'] as int;
                    final isSlowOperation = duration > 100;

                    return Card(
                      color:
                          isSlowOperation ? Colors.red[50] : Colors.green[50],
                      child: ListTile(
                        leading: Icon(
                          isSlowOperation ? Icons.warning : Icons.check_circle,
                          color: isSlowOperation ? Colors.red : Colors.green,
                        ),
                        title: Text(
                          entry.key,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSlowOperation
                                ? Colors.red[800]
                                : Colors.green[800],
                          ),
                        ),
                        subtitle: Text('Count: $count times'),
                        trailing: Text(
                          '${duration}ms',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSlowOperation ? Colors.red : Colors.green,
                          ),
                        ),
                      ),
                    );
                  }).toList()
                else
                  const Text('No performance data available'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: '🐌 Slow Operations',
            child: Column(
              children: [
                if (_performanceData['slow_operations'] != null &&
                    _performanceData['slow_operations'].isNotEmpty)
                  ..._performanceData['slow_operations']
                      .map<Widget>((operation) {
                    return Card(
                      color: Colors.orange[50],
                      child: ListTile(
                        leading: const Icon(Icons.speed, color: Colors.orange),
                        title: Text(
                          operation['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
                          ),
                        ),
                        trailing: Text(
                          '${operation['duration_ms']}ms',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    );
                  }).toList()
                else
                  const Card(
                    color: Colors.green,
                    child: ListTile(
                      leading: Icon(Icons.thumb_up, color: Colors.white),
                      title: Text(
                        'No slow operations detected! 🎉',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: '🧠 Memory Information',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'For detailed memory analysis:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('1. Open Flutter DevTools'),
                const Text('2. Go to Memory tab'),
                const Text('3. Take memory snapshots'),
                const Text('4. Analyze heap usage'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    // Trigger garbage collection for testing
                    PerformanceMonitor().trackMemoryUsage('Manual GC trigger');
                  },
                  icon: const Icon(Icons.cleaning_services),
                  label: const Text('Trigger Memory Check'),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💡 Memory Optimization Tips:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text('• Use const constructors where possible'),
                      Text('• Dispose controllers and listeners'),
                      Text('• Implement proper widget keys'),
                      Text('• Use ListView.builder for large lists'),
                      Text('• Cache images with size limits'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: '💾 Storage Statistics',
            child: Column(
              children: _storageStats.entries.map<Widget>((entry) {
                return ListTile(
                  leading: const Icon(Icons.storage, color: Colors.blue),
                  title: Text(entry.key.replaceAll('_', ' ').toUpperCase()),
                  trailing: Text(
                    entry.value.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: '🗂️ Storage Actions',
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await StorageService().flushAllPendingWrites();
                    _refreshData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('All pending writes flushed')),
                      );
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Flush Pending Writes'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    await StorageService().compact();
                    _refreshData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Storage compacted')),
                      );
                    }
                  },
                  icon: const Icon(Icons.compress),
                  label: const Text('Compact Storage'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvidersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: '🔄 Provider Status',
            child: Consumer<FoodEntryProvider>(
              builder: (context, provider, child) {
                return Column(
                  children: [
                    _buildProviderStatusCard(
                      'FoodEntryProvider',
                      {
                        'Initialized': provider.isInitialized,
                        'Loading': provider.isLoading,
                        'Entry Count': provider.entries.length,
                        'Calories Goal': provider.caloriesGoal,
                        'Protein Goal': provider.proteinGoal,
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        PerformanceMonitor()
                            .startOperation('force_sync_diagnose');
                        await provider.forceSyncAndDiagnose();
                        PerformanceMonitor()
                            .endOperation('force_sync_diagnose');
                        _refreshData();
                      },
                      icon: const Icon(Icons.sync),
                      label: const Text('Force Sync & Diagnose'),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: '🧪 Performance Tests',
            child: Column(
              children: [
                _buildActionButton(
                  'Test Heavy Operation',
                  Icons.hourglass_bottom,
                  () => _simulateHeavyOperation(),
                  Colors.orange,
                ),
                const SizedBox(height: 8),
                _buildActionButton(
                  'Test Memory Allocation',
                  Icons.memory,
                  () => _simulateMemoryTest(),
                  Colors.purple,
                ),
                const SizedBox(height: 8),
                _buildActionButton(
                  'Test Storage Operations',
                  Icons.storage,
                  () => _simulateStorageTest(),
                  Colors.blue,
                ),
                const SizedBox(height: 8),
                _buildActionButton(
                  'Open DevTools',
                  Icons.developer_mode,
                  () => _openDevTools(),
                  Colors.green,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🚀 DevTools Usage Guide:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('1. Run: flutter run --profile'),
                Text('2. Press "w" in terminal to open DevTools'),
                Text('3. Use Performance tab for frame analysis'),
                Text('4. Use Memory tab for heap analysis'),
                Text('5. Use CPU Profiler for method timing'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildProviderStatusCard(String name, Map<String, dynamic> data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...data.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key),
                      Text(
                        entry.value.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
    Color color,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Future<void> _simulateHeavyOperation() async {
    PerformanceMonitor().startOperation('heavy_simulation');

    // Simulate heavy computation
    for (int i = 0; i < 1000000; i++) {
      // Some computation
      math.sqrt(i.toDouble());
    }

    PerformanceMonitor().endOperation('heavy_simulation');
    _refreshData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Heavy operation completed')),
      );
    }
  }

  Future<void> _simulateMemoryTest() async {
    PerformanceMonitor().startOperation('memory_test');

    // Create some temporary objects
    final List<String> tempData = [];
    for (int i = 0; i < 10000; i++) {
      tempData.add('Test data item $i with some content');
    }

    PerformanceMonitor().trackMemoryUsage('After creating 10k items');

    // Clear the data
    tempData.clear();

    PerformanceMonitor().endOperation('memory_test');
    _refreshData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Memory test completed')),
      );
    }
  }

  Future<void> _simulateStorageTest() async {
    PerformanceMonitor().startOperation('storage_test');

    final storage = StorageService();

    // Write some test data
    for (int i = 0; i < 100; i++) {
      await storage.put('test_key_$i', 'Test value $i');
    }

    // Read the data back
    for (int i = 0; i < 100; i++) {
      storage.get('test_key_$i');
    }

    // Clean up
    for (int i = 0; i < 100; i++) {
      await storage.delete('test_key_$i');
    }

    PerformanceMonitor().endOperation('storage_test');
    _refreshData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage test completed')),
      );
    }
  }

  void _openDevTools() {
    // In a real app, this would open DevTools
    // For now, just show instructions
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open DevTools'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To open DevTools:'),
            Text('1. Make sure your app is running'),
            Text('2. Press "w" in the terminal'),
            Text('3. Or run: flutter pub global activate devtools'),
            Text('4. Then: flutter pub global run devtools'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
