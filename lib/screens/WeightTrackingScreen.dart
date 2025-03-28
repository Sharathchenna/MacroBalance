import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

// Weight data point model
class WeightPoint {
  final DateTime date;
  final double weight;

  WeightPoint({required this.date, required this.weight});
}

// Touch interaction model
class TouchData {
  final Offset position;
  final WeightPoint point;

  TouchData({required this.position, required this.point});
}

class WeightTrackingScreen extends StatefulWidget {
  final bool hideAppBar;

  const WeightTrackingScreen({
    Key? key,
    this.hideAppBar = false,
  }) : super(key: key);

  @override
  State<WeightTrackingScreen> createState() => _WeightTrackingScreenState();
}

class _WeightTrackingScreenState extends State<WeightTrackingScreen> {
  bool _isLoading = false;
  double _currentWeight = 70.0; // Default weight in kg
  double _targetWeight = 65.0; // Default target weight in kg
  String _selectedTimeFrame = 'Month';
  List<Map<String, dynamic>> _weightData = [];
  bool _isMetric = true; // Toggle between kg and lbs

  @override
  void initState() {
    super.initState();
    _loadWeightData();
  }

  Future<void> _loadWeightData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load weights from SharedPreferences first
      final prefs = await SharedPreferences.getInstance();
      
      // Try to get the current weight from macro_results
      final String? macroResultsJson = prefs.getString('macro_results');
      if (macroResultsJson != null) {
        final macroResults = json.decode(macroResultsJson);
        if (macroResults['weight_kg'] != null) {
          _currentWeight = macroResults['weight_kg'].toDouble();
        }
      }
      
      // Try to get the goal weight
      _targetWeight = prefs.getDouble('goal_weight_kg') ?? _currentWeight;

      // If user is authenticated, try to get the latest values from Supabase
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        final response = await Supabase.instance.client
            .from('user_macros')
            .select('weight, goal_weight_kg')
            .eq('id', currentUser.id)
            .order('updated_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (response != null) {
          if (response['weight'] != null) {
            _currentWeight = response['weight'].toDouble();
          }
          if (response['goal_weight_kg'] != null) {
            _targetWeight = response['goal_weight_kg'].toDouble();
          }
        }
      }

      // Generate sample weight data around the current weight
      _weightData = List.generate(30, (index) {
        final date = DateTime.now().subtract(Duration(days: 29 - index));
        // Generate more realistic weight fluctuations (±0.5 kg)
        final randomFluctuation = (math.Random().nextDouble() - 0.5);
        return {
          'date': date,
          'weight': _currentWeight + randomFluctuation,
        };
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading weight data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  double _getProgressPercentage() {
    if (_currentWeight == _targetWeight) return 1.0;
    final totalChange = (_currentWeight - _targetWeight).abs();
    final remainingChange = (_currentWeight - _targetWeight).abs();
    return 1 - (remainingChange / totalChange);
  }

  String _formatWeight(double weight) {
    return _isMetric
        ? '${weight.toStringAsFixed(1)} kg'
        : '${(weight * 2.20462).toStringAsFixed(1)} lbs';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>()!;

    Widget body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWeightStatusCard(context, customColors),
                    const SizedBox(height: 24),
                    _buildTimeFrameSelector(customColors),
                    const SizedBox(height: 24),
                    _buildWeightChart(customColors),
                    const SizedBox(height: 24),
                    _buildWeightHistory(customColors),
                    const SizedBox(height: 24),
                    _buildWeightGoalCard(customColors),
                    const SizedBox(height: 50)
                  ],
                ),
              ),
            ),
          );

    if (!widget.hideAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Weight Tracking',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: customColors.textPrimary,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: theme.brightness == Brightness.light
              ? SystemUiOverlayStyle.dark
              : SystemUiOverlayStyle.light,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: customColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            // Unit toggle button
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _isMetric = !_isMetric;
                });
              },
              icon: Icon(
                Icons.scale,
                color: customColors.textPrimary,
                size: 20,
              ),
              label: Text(
                _isMetric ? 'kg' : 'lbs',
                style: TextStyle(
                  color: customColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        body: body,
      );
    }

    return body;
  }

  Widget _buildWeightStatusCard(
      BuildContext context, CustomColors customColors) {
    final progress = _getProgressPercentage();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            customColors.cardBackground,
            customColors.cardBackground.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Weight',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: customColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, MMMM d').format(DateTime.now()),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: customColors.textSecondary,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => _showAddWeightDialog(context, customColors),
                icon: Icon(
                  Icons.add_circle_outline,
                  color: customColors.accentPrimary,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.grey.shade100
                            : customColors.cardBackground,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: progress,
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.light
                                ? Colors.grey.shade200
                                : customColors.dateNavigatorBackground,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 1.0
                              ? Colors.green
                              : customColors.accentPrimary,
                        ),
                        strokeWidth: 12,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: customColors.cardBackground,
                        shape: BoxShape.circle,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatWeight(_currentWeight),
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: customColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProgressItem(
                      context,
                      'Target',
                      _formatWeight(_targetWeight),
                      Icons.flag_rounded,
                      customColors,
                    ),
                    const SizedBox(height: 20),
                    _buildProgressItem(
                      context,
                      'To Go',
                      _formatWeight((_currentWeight - _targetWeight).abs()),
                      Icons.trending_down,
                      customColors,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    CustomColors customColors,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: customColors.accentPrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: customColors.accentPrimary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: customColors.textSecondary,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: customColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeFrameSelector(CustomColors customColors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: customColors.dateNavigatorBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['Week', 'Month', 'Year'].map((timeFrame) {
          final isSelected = _selectedTimeFrame == timeFrame;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextButton(
              onPressed: () {
                setState(() {
                  _selectedTimeFrame = timeFrame;
                });
              },
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(
                  isSelected ? customColors.cardBackground : Colors.transparent,
                ),
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                padding: MaterialStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
              ),
              child: Text(
                timeFrame,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? customColors.accentPrimary
                      : customColors.textPrimary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeightChart(CustomColors customColors) {
    // Extract weight data as points for chart
    final weightPoints = _weightData.map((data) {
      return WeightPoint(
        date: data['date'] as DateTime,
        weight: data['weight'] as double,
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: customColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weight Trend',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: customColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 240,
            child: CustomWeightChart(
              weightPoints: weightPoints,
              isMetric: _isMetric,
              customColors: customColors,
              targetWeight: _targetWeight,
              timeFrame: _selectedTimeFrame,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightHistory(CustomColors customColors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: customColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weight History',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: customColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: math.min(5, _weightData.length),
            itemBuilder: (context, index) {
              final data = _weightData[_weightData.length - 1 - index];
              final weight = data['weight'] as double;
              final date = data['date'] as DateTime;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: customColors.dateNavigatorBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('d').format(date),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: customColors.textPrimary,
                            ),
                          ),
                          Text(
                            DateFormat('MMM').format(date),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: customColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE').format(date),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: customColors.textPrimary,
                            ),
                          ),
                          Text(
                            _formatWeight(weight),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: customColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeightGoalCard(CustomColors customColors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: customColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weight Goal',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: customColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target Weight:',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: customColors.textPrimary,
                ),
              ),
              Text(
                _formatWeight(_targetWeight),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: customColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _showEditGoalDialog(context, customColors),
            style: ElevatedButton.styleFrom(
              backgroundColor: customColors.accentPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Edit Goal'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveWeightChanges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save to SharedPreferences
      await prefs.setDouble('current_weight', _currentWeight);
      await prefs.setDouble('goal_weight_kg', _targetWeight);

      // Update macro_results with new current weight
      final String? macroResultsJson = prefs.getString('macro_results');
      if (macroResultsJson != null) {
        final macroResults = json.decode(macroResultsJson);
        macroResults['weight_kg'] = _currentWeight;
        await prefs.setString('macro_results', json.encode(macroResults));
      }

      // If user is authenticated, sync to Supabase
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        await Supabase.instance.client.from('user_macros').upsert({
          'id': currentUser.id,
          'weight': _currentWeight,
          'goal_weight_kg': _targetWeight,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('Error saving weight changes: $e');
    }
  }

  Future<void> _showAddWeightDialog(
      BuildContext context, CustomColors customColors) async {
    double newWeight = _currentWeight;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Weight',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: customColors.textPrimary,
          ),
        ),
        content: TextField(
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'Enter your weight',
            suffix: Text(_isMetric ? 'kg' : 'lbs'),
          ),
          onChanged: (value) {
            if (value.isNotEmpty) {
              try {
                newWeight = double.parse(value);
                if (!_isMetric) {
                  newWeight = newWeight / 2.20462; // Convert to kg
                }
              } catch (e) {
                // Handle invalid input
              }
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: customColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                _currentWeight = newWeight;
                // Add the new weight entry to the data
                _weightData.add({
                  'date': DateTime.now(),
                  'weight': newWeight,
                });
                // Sort the data by date
                _weightData.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
                // Keep only the last 30 entries
                if (_weightData.length > 30) {
                  _weightData = _weightData.sublist(_weightData.length - 30);
                }
              });
              // Save the changes
              await _saveWeightChanges();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: customColors.accentPrimary,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditGoalDialog(
      BuildContext context, CustomColors customColors) async {
    double newTarget = _targetWeight;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit Weight Goal',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: customColors.textPrimary,
          ),
        ),
        content: TextField(
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'Enter target weight',
            suffix: Text(_isMetric ? 'kg' : 'lbs'),
          ),
          onChanged: (value) {
            if (value.isNotEmpty) {
              try {
                newTarget = double.parse(value);
                if (!_isMetric) {
                  newTarget = newTarget / 2.20462; // Convert to kg
                }
              } catch (e) {
                // Handle invalid input
              }
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: customColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                _targetWeight = newTarget;
              });
              // Save the changes
              await _saveWeightChanges();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: customColors.accentPrimary,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class CustomWeightChart extends StatefulWidget {
  final List<WeightPoint> weightPoints;
  final bool isMetric;
  final CustomColors customColors;
  final double targetWeight;
  final String timeFrame;

  const CustomWeightChart({
    Key? key,
    required this.weightPoints,
    required this.isMetric,
    required this.customColors,
    required this.targetWeight,
    required this.timeFrame,
  }) : super(key: key);

  @override
  State<CustomWeightChart> createState() => _CustomWeightChartState();
}

class _CustomWeightChartState extends State<CustomWeightChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  TouchData? _touchData;
  final List<Offset> _animatedPoints = [];

  double _zoomLevel = 1.0; // Default zoom level
  double _zoomFactor = 1.0; // Current zoom factor
  Offset? _lastFocalPoint;
  late double _panOffset = 0.0; // Horizontal panning offset
  final double _maxPanOffset = 100.0; // Maximum pan offset

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CustomWeightChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weightPoints != widget.weightPoints ||
        oldWidget.timeFrame != widget.timeFrame) {
      _animationController.reset();
      _animationController.forward();
      // Reset zoom and pan when data or timeframe changes
      _zoomLevel = 1.0;
      _panOffset = 0.0;
    }
  }

  List<WeightPoint> _getFilteredData() {
    final now = DateTime.now();
    List<WeightPoint> filteredPoints;

    switch (widget.timeFrame) {
      case 'Week':
        final weekAgo = now.subtract(const Duration(days: 7));
        filteredPoints = widget.weightPoints
            .where((point) =>
                point.date.isAfter(weekAgo) ||
                point.date.isAtSameMomentAs(weekAgo))
            .toList();
        break;
      case 'Month':
        final monthAgo = DateTime(now.year, now.month - 1, now.day);
        filteredPoints = widget.weightPoints
            .where((point) =>
                point.date.isAfter(monthAgo) ||
                point.date.isAtSameMomentAs(monthAgo))
            .toList();
        break;
      case 'Year':
        final yearAgo = DateTime(now.year - 1, now.month, now.day);
        filteredPoints = widget.weightPoints
            .where((point) =>
                point.date.isAfter(yearAgo) ||
                point.date.isAtSameMomentAs(yearAgo))
            .toList();
        break;
      default:
        filteredPoints = widget.weightPoints;
    }

    // Sort points by date just to be sure
    filteredPoints.sort((a, b) => a.date.compareTo(b.date));

    return filteredPoints;
  }

  String _formatWeight(double weight) {
    return widget.isMetric
        ? '${weight.toStringAsFixed(1)} kg'
        : '${(weight * 2.20462).toStringAsFixed(1)} lbs';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onScaleStart: (details) {
            _lastFocalPoint = details.focalPoint;
            _zoomFactor = 1.0;
            // Handle touch interaction at start
            _updateTouch(details.localFocalPoint);
          },
          onScaleUpdate: (details) {
            if (details.scale != 1.0) {
              setState(() {
                // Calculate new zoom level with limits
                final newZoom =
                    (_zoomLevel * details.scale / _zoomFactor).clamp(1.0, 3.5);
                _zoomFactor = details.scale;
                _zoomLevel = newZoom;

                // Clear touch data when zooming
                _touchData = null;
              });
            } else if (_lastFocalPoint != null) {
              // Handle panning
              final delta = details.focalPoint.dx - _lastFocalPoint!.dx;
              setState(() {
                // Update pan offset with limits based on zoom level
                final maxOffset = _maxPanOffset * (_zoomLevel - 1);
                _panOffset =
                    (_panOffset + delta / 5).clamp(-maxOffset, maxOffset);
                _lastFocalPoint = details.focalPoint;
              });
            }

            // Handle touch interaction during scale if scale is 1.0 (just moving)
            if (details.scale == 1.0) {
              _updateTouch(details.localFocalPoint);
            }
          },
          onScaleEnd: (details) {
            _lastFocalPoint = null;

            // Keep tooltip visible for a moment after touch ends
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                setState(() {
                  _touchData = null;
                });
              }
            });
          },
          onTapDown: (details) {
            _updateTouch(details.localPosition);
          },
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _WeightChartPainter(
                  weightPoints: _getFilteredData(),
                  customColors: widget.customColors,
                  targetWeight: widget.targetWeight,
                  animation: _animationController.value,
                  touchData: _touchData,
                  isMetric: widget.isMetric,
                  zoomLevel: _zoomLevel,
                  panOffset: _panOffset,
                ),
              );
            },
          ),
        ),
        // Zoom indicator
        Positioned(
          right: 10,
          bottom: 10,
          child: AnimatedOpacity(
            opacity: _zoomLevel > 1.0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: widget.customColors.cardBackground.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.zoom_in,
                    size: 14,
                    color: widget.customColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${(_zoomLevel).toStringAsFixed(1)}x',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: widget.customColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _zoomLevel = 1.0;
                        _panOffset = 0.0;
                      });
                    },
                    child: Icon(
                      Icons.refresh,
                      size: 14,
                      color: widget.customColors.accentPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _updateTouch(Offset position) {
    final size = context.size;
    if (size == null) return;

    final filteredData = _getFilteredData();
    if (filteredData.isEmpty) return;

    final chartWidth = size.width - 60; // Accounting for padding
    final chartHeight = size.height - 50; // Accounting for padding

    // Calculate min and max values
    final weights = filteredData.map((p) => p.weight).toList();
    final double minWeight = weights.reduce(math.min) - 1;
    final double maxWeight = weights.reduce(math.max) + 1;

    // Find closest point, accounting for zoom and pan
    double minDistance = double.infinity;
    WeightPoint? closestPoint;
    Offset? closestPos;

    // Calculate visible range based on zoom and pan
    final visiblePoints = _getVisiblePointsIndices(filteredData.length);

    for (int i = visiblePoints.start; i <= visiblePoints.end; i++) {
      final point = filteredData[i];
      final pointX =
          _getXPositionForIndex(i, filteredData.length, chartWidth, size);
      final pointY = size.height -
          40 -
          ((point.weight - minWeight) / (maxWeight - minWeight)) * chartHeight;

      final distance = (Offset(pointX, pointY) - position).distance;
      if (distance < minDistance && distance < 30) {
        minDistance = distance;
        closestPoint = point;
        closestPos = Offset(pointX, pointY);
      }
    }

    setState(() {
      if (closestPoint != null && closestPos != null) {
        _touchData = TouchData(
          position: closestPos,
          point: closestPoint,
        );
      } else {
        _touchData = null;
      }
    });
  }

  // Calculate which points are visible based on zoom and pan
  _VisibleRange _getVisiblePointsIndices(int totalPoints) {
    if (totalPoints <= 1) return _VisibleRange(0, 0);

    // Calculate visible range based on zoom level and pan offset
    final visiblePortion = 1.0 / _zoomLevel;
    final center = 0.5 + (_panOffset / (_maxPanOffset * 2));

    // Calculate start and end indices
    int start = ((center - visiblePortion / 2) * (totalPoints - 1)).floor();
    int end = ((center + visiblePortion / 2) * (totalPoints - 1)).ceil();

    // Ensure indices are within bounds
    start = math.max(0, start);
    end = math.min(totalPoints - 1, end);

    return _VisibleRange(start, end);
  }

  // Calculate x position for point at index, accounting for zoom and pan
  double _getXPositionForIndex(
      int index, int totalPoints, double chartWidth, Size size) {
    final visibleRange = _getVisiblePointsIndices(totalPoints);
    final visibleCount = visibleRange.end - visibleRange.start;

    if (visibleCount <= 0) return 30 + (index / (totalPoints - 1)) * chartWidth;

    // Map index to position within visible range
    final relativeIndex = index - visibleRange.start;
    return 30 + (relativeIndex / visibleCount) * chartWidth;
  }
}

// Class to track visible range of points
class _VisibleRange {
  final int start;
  final int end;

  _VisibleRange(this.start, this.end);
}

class _WeightChartPainter extends CustomPainter {
  final List<WeightPoint> weightPoints;
  final CustomColors customColors;
  final double targetWeight;
  final double animation;
  final TouchData? touchData;
  final bool isMetric;
  final double zoomLevel;
  final double panOffset;

  _WeightChartPainter({
    required this.weightPoints,
    required this.customColors,
    required this.targetWeight,
    required this.animation,
    this.touchData,
    required this.isMetric,
    this.zoomLevel = 1.0,
    this.panOffset = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (weightPoints.isEmpty) return;

    final chartWidth = size.width - 60; // Left and right padding
    final chartHeight = size.height - 50; // Top and bottom padding

    // Calculate min and max values with padding
    final weights = weightPoints.map((p) => p.weight).toList();
    final double minWeight = weights.reduce(math.min) - 1;
    final double maxWeight = weights.reduce(math.max) + 1;

    // Paint for the grid lines
    final gridPaint = Paint()
      ..color = customColors.textSecondary.withOpacity(0.1)
      ..strokeWidth = 1;

    // Paint for the axis labels
    final labelStyle = TextStyle(
      color: customColors.textSecondary,
      fontSize: 10,
    );
    final labelPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Draw horizontal grid lines
    final stepCount = 5;
    for (int i = 0; i <= stepCount; i++) {
      final y = size.height - 40 - (i / stepCount) * chartHeight;

      // Draw grid line
      canvas.drawLine(
        Offset(30, y),
        Offset(size.width - 30, y),
        gridPaint,
      );

      // Draw weight label
      final weight = minWeight + (i / stepCount) * (maxWeight - minWeight);
      final weightText = isMetric
          ? '${weight.toStringAsFixed(1)}'
          : '${(weight * 2.20462).toStringAsFixed(1)}';

      labelPainter
        ..text = TextSpan(text: weightText, style: labelStyle)
        ..layout();

      labelPainter.paint(
        canvas,
        Offset(10, y - labelPainter.height / 2),
      );
    }

    // Draw unit label
    labelPainter
      ..text = TextSpan(
          text: isMetric ? 'kg' : 'lbs',
          style: labelStyle.copyWith(fontWeight: FontWeight.bold))
      ..layout();

    labelPainter.paint(
      canvas,
      Offset(10, 10),
    );

    // Calculate visible range of points based on zoom level
    final visibleRange = _getVisiblePointsIndices(weightPoints.length);

    // Calculate date interval based on zoom and visible points
    int dateInterval =
        _calculateDateInterval(visibleRange.end - visibleRange.start + 1);

    // Draw vertical grid lines and date labels for visible points
    for (int i = visibleRange.start; i <= visibleRange.end; i++) {
      // Only show labels at intervals
      if ((i - visibleRange.start) % dateInterval != 0 && i != visibleRange.end)
        continue;

      final x = _getXPositionForIndex(i, chartWidth);

      // Draw grid line
      canvas.drawLine(
        Offset(x, 10),
        Offset(x, size.height - 40),
        gridPaint,
      );

      // Draw date label
      final date = weightPoints[i].date;
      final dateText = _formatDateForInterval(date, dateInterval);

      labelPainter
        ..text = TextSpan(text: dateText, style: labelStyle)
        ..layout();

      labelPainter.paint(
        canvas,
        Offset(x - labelPainter.width / 2, size.height - 25),
      );
    }

    // Draw target weight line with improved visibility
    final targetY = size.height -
        40 -
        ((targetWeight - minWeight) / (maxWeight - minWeight)) * chartHeight;

    final targetPaint = Paint()
      ..color = Colors.green.shade600
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw solid line instead of dashed for better visibility
    canvas.drawLine(
      Offset(30, targetY),
      Offset(size.width - 30, targetY),
      targetPaint,
    );

    // Draw target indicator
    labelPainter
      ..text = TextSpan(
          text: 'Target Goal',
          style: labelStyle.copyWith(
            color: Colors.green.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ))
      ..layout();

    // Draw target label with better visibility
    final targetLabelBackground = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width - labelPainter.width - 18, targetY - 12,
          labelPainter.width + 16, 24),
      const Radius.circular(12),
    );

    // Draw a colored background for the target label
    canvas.drawRRect(
      targetLabelBackground,
      Paint()..color = Colors.green.shade50.withOpacity(0.8),
    );

    // Draw border
    canvas.drawRRect(
        targetLabelBackground,
        Paint()
          ..color = Colors.green.shade600
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    labelPainter.paint(
      canvas,
      Offset(size.width - labelPainter.width - 10,
          targetY - labelPainter.height / 2),
    );

    // Calculate points for weight line with zoom consideration
    final points = <Offset>[];
    final animatedPoints = <Offset>[];

    for (int i = visibleRange.start; i <= visibleRange.end; i++) {
      final point = weightPoints[i];
      final x = _getXPositionForIndex(i, chartWidth);
      final y = size.height -
          40 -
          ((point.weight - minWeight) / (maxWeight - minWeight)) * chartHeight;

      points.add(Offset(x, y));

      // Apply animation only to points that should be visible
      if (animation >= 1.0 ||
          i <=
              visibleRange.start +
                  (visibleRange.end - visibleRange.start) * animation) {
        animatedPoints.add(Offset(x, y));
      }
    }

    // Draw line connecting points
    if (animatedPoints.length > 1) {
      final linePaint = Paint()
        ..color = customColors.accentPrimary
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(animatedPoints.first.dx, animatedPoints.first.dy);

      for (int i = 1; i < animatedPoints.length; i++) {
        path.lineTo(animatedPoints[i].dx, animatedPoints[i].dy);
      }

      canvas.drawPath(path, linePaint);
    }

    // Draw fill under the line
    if (animatedPoints.length > 1) {
      final fillPath = Path();
      fillPath.moveTo(animatedPoints.first.dx, size.height - 40);
      fillPath.lineTo(animatedPoints.first.dx, animatedPoints.first.dy);

      for (int i = 1; i < animatedPoints.length; i++) {
        fillPath.lineTo(animatedPoints[i].dx, animatedPoints[i].dy);
      }

      fillPath.lineTo(animatedPoints.last.dx, size.height - 40);
      fillPath.close();

      canvas.drawPath(
          fillPath,
          Paint()
            ..color = customColors.accentPrimary.withOpacity(0.1)
            ..style = PaintingStyle.fill);
    }

    // Draw data points
    final pointPaint = Paint()
      ..color = customColors.cardBackground
      ..style = PaintingStyle.fill;

    final pointBorderPaint = Paint()
      ..color = customColors.accentPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < animatedPoints.length; i++) {
      final point = animatedPoints[i];
      final originalIndex = i + visibleRange.start;

      // Determine if this is a point that should be highlighted
      bool isHighlighted = false;
      if (i == 0 ||
          i == animatedPoints.length - 1 ||
          originalIndex == 0 ||
          originalIndex == weightPoints.length - 1) {
        isHighlighted = true;
      }

      // Draw all points with subtle appearance
      canvas.drawCircle(point, 4, pointPaint);
      canvas.drawCircle(point, 4, pointBorderPaint);

      // Draw emphasized points
      if (isHighlighted) {
        canvas.drawCircle(point, 6, pointPaint);
        canvas.drawCircle(point, 6, pointBorderPaint);
      }
    }

    // Draw tooltip for touched point
    if (touchData != null) {
      final point = touchData!.point;
      final position = touchData!.position;

      // Format weight and date for tooltip
      final weightText = isMetric
          ? '${point.weight.toStringAsFixed(1)} kg'
          : '${(point.weight * 2.20462).toStringAsFixed(1)} lbs';
      final dateText = DateFormat('MMM dd, yyyy').format(point.date);

      // Prepare tooltip text
      labelPainter
        ..text = TextSpan(
          children: [
            TextSpan(
              text: weightText,
              style: TextStyle(
                color: customColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(
              text: '\n$dateText',
              style: TextStyle(
                color: customColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        )
        ..layout(maxWidth: 120);

      // Draw tooltip background
      final tooltipWidth = math.max(labelPainter.width + 16, 80.0);
      final tooltipHeight = labelPainter.height + 12;

      // Calculate tooltip position
      double tooltipX = position.dx - tooltipWidth / 2;
      final tooltipY = position.dy - tooltipHeight - 12;

      // Ensure tooltip stays within bounds
      tooltipX =
          math.max(10, math.min(size.width - tooltipWidth - 10, tooltipX));

      final tooltipRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tooltipX, tooltipY, tooltipWidth, tooltipHeight),
        const Radius.circular(8),
      );

      final tooltipTrianglePath = Path()
        ..moveTo(position.dx, position.dy - 6)
        ..lineTo(position.dx - 8, tooltipY)
        ..lineTo(position.dx + 8, tooltipY)
        ..close();

      canvas.drawRRect(
        tooltipRect,
        Paint()..color = customColors.cardBackground,
      );

      canvas.drawShadow(Path()..addRRect(tooltipRect),
          Colors.black.withOpacity(0.2), 4, true);

      canvas.drawPath(
        tooltipTrianglePath,
        Paint()..color = customColors.cardBackground,
      );

      labelPainter.paint(
        canvas,
        Offset(tooltipX + 8, tooltipY + 6),
      );

      // Emphasize the selected point
      canvas.drawCircle(
        position,
        8,
        pointPaint,
      );

      canvas.drawCircle(
        position,
        8,
        Paint()
          ..color = customColors.accentPrimary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    // Draw zoom instructions if not zoomed
    if (zoomLevel <= 1.05 && animation >= 1.0) {
      labelPainter
        ..text = TextSpan(
          text: 'Pinch to zoom',
          style: TextStyle(
            color: customColors.textSecondary.withOpacity(0.6),
            fontSize: 10,
            fontStyle: FontStyle.italic,
          ),
        )
        ..layout();

      labelPainter.paint(
        canvas,
        Offset(size.width - labelPainter.width - 10, size.height - 15),
      );
    }
  }

  // Calculate which points are visible based on zoom and pan
  _VisibleRange _getVisiblePointsIndices(int totalPoints) {
    if (totalPoints <= 1) return _VisibleRange(0, 0);

    // Calculate visible range based on zoom level and pan offset
    final visiblePortion = 1.0 / zoomLevel;
    final center = 0.5 + (panOffset / 100);

    // Calculate start and end indices
    int start = ((center - visiblePortion / 2) * (totalPoints - 1)).floor();
    int end = ((center + visiblePortion / 2) * (totalPoints - 1)).ceil();

    // Ensure indices are within bounds
    start = math.max(0, start);
    end = math.min(totalPoints - 1, end);

    return _VisibleRange(start, end);
  }

  // Calculate x position for point at index, accounting for zoom and pan
  double _getXPositionForIndex(int index, double chartWidth) {
    final visibleRange = _getVisiblePointsIndices(weightPoints.length);
    final visibleCount = visibleRange.end - visibleRange.start;

    if (visibleCount <= 0)
      return 30 + (index / (weightPoints.length - 1)) * chartWidth;

    // Map index to position within visible range
    final relativeIndex = index - visibleRange.start;
    return 30 + (relativeIndex / visibleCount) * chartWidth;
  }

  // Calculate appropriate date interval based on number of visible points
  int _calculateDateInterval(int visiblePoints) {
    if (visiblePoints <= 7) return 1;
    if (visiblePoints <= 14) return 2;
    if (visiblePoints <= 30) return 5;
    if (visiblePoints <= 60) return 10;
    if (visiblePoints <= 180) return 30;
    return math.max(1, (visiblePoints / 10).round());
  }

  // Format date based on interval size
  String _formatDateForInterval(DateTime date, int interval) {
    if (interval <= 2) {
      return DateFormat('MM/dd').format(date);
    } else if (interval <= 10) {
      return DateFormat('MM/dd').format(date);
    } else if (interval <= 30) {
      return DateFormat('MM/dd').format(date);
    } else {
      return DateFormat('MM/yy').format(date);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) {
    return oldDelegate.weightPoints != weightPoints ||
        oldDelegate.animation != animation ||
        oldDelegate.touchData != touchData ||
        oldDelegate.isMetric != isMetric ||
        oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.panOffset != panOffset;
  }
}
