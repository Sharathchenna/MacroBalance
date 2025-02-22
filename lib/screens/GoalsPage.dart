// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildAppBar(),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.builder(
                  itemCount: 6,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _controller,
                        curve: Interval(
                          index * 0.1,
                          1.0,
                          curve: Curves.easeOutQuart,
                        ),
                      )),
                      child: FadeTransition(
                        opacity: _controller,
                        child: _buildGoalCard(getGoalData(index)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () {},
          color: Colors.white70,
        ),
        const Text(
          'Goals',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: Colors.white,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 24),
          onPressed: () {},
          color: Colors.white70,
        ),
      ],
    );
  }

  Widget _buildGoalCard(GoalData data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      data.icon,
                      color: data.color.withValues(alpha: 0.9),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      data.title,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.value,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.95),
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (data.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            data.subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (data.showSetGoal)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: data.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Set Goal',
                          style: TextStyle(
                            color: data.color,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                if (data.showProgress) ...[
                  const SizedBox(height: 16),
                  _buildProgressIndicator(data),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(GoalData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(
              height: 3,
              width: constraints.maxWidth,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: data.progress),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutQuart,
              builder: (context, value, _) {
                return Container(
                  height: 3,
                  width: constraints.maxWidth * value,
                  decoration: BoxDecoration(
                    color: data.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class GoalData {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;
  final bool showSetGoal;
  final bool showProgress;
  final double progress;

  GoalData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
    this.showSetGoal = false,
    this.showProgress = false,
    this.progress = 0.0,
  });
}

GoalData getGoalData(int index) {
  switch (index) {
    case 0:
      return GoalData(
        title: 'Weight',
        value: '69 kg',
        subtitle: 'Feb 11, 2025',
        color: Colors.cyan,
        icon: Icons.monitor_weight_outlined,
        showProgress: true,
        progress: 0.7,
      );
    case 1:
      return GoalData(
        title: 'Calories',
        value: '2,237 cal',
        subtitle: 'remaining',
        color: Colors.green,
        icon: Icons.local_fire_department_outlined,
        showProgress: true,
        progress: 0.1,
      );
    // Add cases for other goals...
    default:
      return GoalData(
        title: 'Custom Goal',
        value: '0',
        subtitle: '',
        color: Colors.grey,
        icon: Icons.flag_outlined,
        showSetGoal: true,
      );
  }
}
