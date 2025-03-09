// ignore_for_file: file_names

import 'package:flutter/material.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(context),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
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
                    childCount: 6,
                  ),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        elevation: 2,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withOpacity(0.8),
              ],
            ),
          ),
          child: const Icon(Icons.add, size: 28),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: Row(
          children: [
            Text(
              'My Goals',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 20),
        onPressed: () => Navigator.of(context).pop(),
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildGoalCard(GoalData data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  data.color.withOpacity(0.15),
                  data.color.withOpacity(0.05),
                ],
              ),
              border: Border.all(
                color: data.color.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: data.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        data.icon,
                        color: data.color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.title,
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (data.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            data.subtitle,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.5),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      data.value,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (data.showSetGoal)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              data.color,
                              data.color.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: data.color.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Set Goal',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                if (data.showProgress) ...[
                  const SizedBox(height: 20),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(data.progress * 100).toInt()}% Complete',
              style: TextStyle(
                color: Theme.of(context).primaryColor.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Target: ${data.target ?? "Not set"}',
              style: TextStyle(
                color: Theme.of(context).primaryColor.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              height: 6,
              width: constraints.maxWidth,
              decoration: BoxDecoration(
                color: data.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: data.progress),
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return Container(
                        width: constraints.maxWidth * value,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              data.color,
                              data.color.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: data.color.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ],
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
  final String? target;

  GoalData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
    this.showSetGoal = false,
    this.showProgress = false,
    this.progress = 0.0,
    this.target,
  });
}

GoalData getGoalData(int index) {
  final themeColors = [
    const Color(0xFF64B5F6), // blue
    const Color(0xFF81C784), // green
    const Color(0xFFFFB74D), // orange
    const Color(0xFFE57373), // red
    const Color(0xFF9575CD), // purple
    const Color(0xFF4DB6AC), // teal
  ];

  switch (index) {
    case 0:
      return GoalData(
        title: 'Weight Goal',
        value: '69 kg',
        subtitle: 'Target by Feb 11, 2025',
        color: themeColors[0],
        icon: Icons.monitor_weight_outlined,
        showProgress: true,
        progress: 0.7,
        target: '65 kg',
      );
    case 1:
      return GoalData(
        title: 'Daily Calories',
        value: '2,237',
        subtitle: 'calories remaining today',
        color: themeColors[1],
        icon: Icons.local_fire_department_outlined,
        showProgress: true,
        progress: 0.3,
        target: '2,500 cal',
      );
    case 2:
      return GoalData(
        title: 'Protein Intake',
        value: '82g',
        subtitle: 'of daily target',
        color: themeColors[2],
        icon: Icons.fitness_center_outlined,
        showProgress: true,
        progress: 0.6,
        target: '120g',
      );
    case 3:
      return GoalData(
        title: 'Water Intake',
        value: '1.8L',
        subtitle: 'of daily target',
        color: themeColors[3],
        icon: Icons.water_drop_outlined,
        showProgress: true,
        progress: 0.45,
        target: '3.0L',
      );
    case 4:
      return GoalData(
        title: 'Steps',
        value: '6,789',
        subtitle: 'steps today',
        color: themeColors[4],
        icon: Icons.directions_walk_outlined,
        showProgress: true,
        progress: 0.55,
        target: '10,000',
      );
    default:
      return GoalData(
        title: 'New Goal',
        value: 'Tap to set',
        subtitle: 'Create custom goal',
        color: themeColors[5],
        icon: Icons.add_chart,
        showSetGoal: true,
      );
  }
}
