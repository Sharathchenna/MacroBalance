/// PREMIUM IMPLEMENTATION GUIDE
///
/// This file contains examples of how to implement the new premium design system
/// throughout your MacroBalance app. Use these patterns to upgrade existing screens.

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_macro_ring.dart';
import '../widgets/premium_input.dart';

/// EXAMPLE 1: Enhanced Calorie Tracker Card
/// BEFORE: Basic container with hardcoded styling
/// AFTER: Premium card with sophisticated animations and shadows
class PremiumCalorieTrackerExample extends StatefulWidget {
  final int caloriesConsumed;
  final int caloriesGoal;
  final int caloriesBurned;

  const PremiumCalorieTrackerExample({
    super.key,
    required this.caloriesConsumed,
    required this.caloriesGoal,
    required this.caloriesBurned,
  });

  @override
  State<PremiumCalorieTrackerExample> createState() =>
      _PremiumCalorieTrackerExampleState();
}

class _PremiumCalorieTrackerExampleState
    extends State<PremiumCalorieTrackerExample>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: PremiumAnimations.slow,
      vsync: this,
    );

    final progress = widget.caloriesGoal > 0
        ? (widget.caloriesConsumed / widget.caloriesGoal).clamp(0.0, 1.0)
        : 0.0;

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: progress,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: PremiumAnimations.smooth,
    ));

    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caloriesRemaining =
        (widget.caloriesGoal + widget.caloriesBurned) - widget.caloriesConsumed;

    return Container(
      margin: const EdgeInsets.all(16),
      child: PremiumCard.elevated(
        child: Column(
          children: [
            // Premium header with gradient text
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  PremiumColors.slate900,
                  PremiumColors.slate700,
                ],
              ).createShader(bounds),
              child: Text(
                'Today\'s Progress',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Enhanced calorie circle with premium styling
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white,
                    PremiumColors.slate50,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: PremiumColors.emerald500.withOpacity(0.1),
                    blurRadius: 40,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Animated progress ring
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return SizedBox(
                        width: 140,
                        height: 140,
                        child: CircularProgressIndicator(
                          value: _progressAnimation.value,
                          strokeWidth: 12,
                          strokeCap: StrokeCap.round,
                          backgroundColor: PremiumColors.slate200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _progressAnimation.value > 1.0
                                ? PremiumColors.red500
                                : PremiumColors.emerald500,
                          ),
                        ),
                      );
                    },
                  ),

                  // Center content
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        caloriesRemaining.toString(),
                        style: theme.textTheme.displayLarge?.copyWith(
                          color: PremiumColors.slate900,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'calories left',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: PremiumColors.slate500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Premium info cards
            Row(
              children: [
                Expanded(
                  child: _PremiumInfoCard(
                    title: 'Goal',
                    value: widget.caloriesGoal,
                    color: PremiumColors.emerald500,
                    icon: Icons.flag_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PremiumInfoCard(
                    title: 'Food',
                    value: widget.caloriesConsumed,
                    color: PremiumColors.amber500,
                    icon: Icons.restaurant_menu_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PremiumInfoCard(
                    title: 'Burned',
                    value: widget.caloriesBurned,
                    color: PremiumColors.blue500,
                    icon: Icons.local_fire_department_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumInfoCard extends StatelessWidget {
  final String title;
  final int value;
  final Color color;
  final IconData icon;

  const _PremiumInfoCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// EXAMPLE 2: Enhanced Meal Card with Premium Styling
class PremiumMealCardExample extends StatefulWidget {
  final String mealType;
  final List<String> foods;
  final int totalCalories;

  const PremiumMealCardExample({
    super.key,
    required this.mealType,
    required this.foods,
    required this.totalCalories,
  });

  @override
  State<PremiumMealCardExample> createState() => _PremiumMealCardExampleState();
}

class _PremiumMealCardExampleState extends State<PremiumMealCardExample> {
  bool _isExpanded = false;

  IconData _getMealIcon() {
    switch (widget.mealType.toLowerCase()) {
      case 'breakfast':
        return Icons.breakfast_dining_rounded;
      case 'lunch':
        return Icons.lunch_dining_rounded;
      case 'dinner':
        return Icons.dinner_dining_rounded;
      case 'snacks':
        return Icons.cookie_rounded;
      default:
        return Icons.restaurant_rounded;
    }
  }

  Color _getMealColor() {
    switch (widget.mealType.toLowerCase()) {
      case 'breakfast':
        return PremiumColors.amber500;
      case 'lunch':
        return PremiumColors.emerald500;
      case 'dinner':
        return PremiumColors.blue500;
      case 'snacks':
        return PremiumColors.slate600;
      default:
        return PremiumColors.slate500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: PremiumCard(
        padding: EdgeInsets.zero,
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getMealColor().withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getMealIcon(),
                      color: _getMealColor(),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.mealType,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: customColors?.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${widget.foods.length} item${widget.foods.length != 1 ? 's' : ''}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: customColors?.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${widget.totalCalories} kcal',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: customColors?.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0,
                        duration: PremiumAnimations.medium,
                        child: Icon(
                          Icons.expand_more_rounded,
                          color: customColors?.textSecondary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Expandable content
            AnimatedContainer(
              duration: PremiumAnimations.medium,
              curve: PremiumAnimations.smooth,
              height: _isExpanded ? null : 0,
              child: _isExpanded
                  ? Column(
                      children: [
                        Divider(
                          height: 1,
                          color: PremiumColors.slate200,
                        ),

                        // Food items
                        for (int i = 0; i < widget.foods.length; i++) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _getMealColor(),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    widget.foods[i],
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: customColors?.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (i < widget.foods.length - 1)
                            Divider(
                              height: 1,
                              color: PremiumColors.slate100,
                              indent: 36,
                            ),
                        ],

                        // Add food button
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: PremiumButton.outlined(
                            text: 'Add Food to ${widget.mealType}',
                            icon: Icons.add_rounded,
                            onPressed: () {
                              // Add food logic
                            },
                            size: PremiumButtonSize.small,
                            expanded: true,
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// EXAMPLE 3: Premium Macro Ring Layout
class PremiumMacroSectionExample extends StatelessWidget {
  final int carbs;
  final int carbsGoal;
  final int protein;
  final int proteinGoal;
  final int fat;
  final int fatGoal;
  final int steps;
  final int stepsGoal;

  const PremiumMacroSectionExample({
    super.key,
    required this.carbs,
    required this.carbsGoal,
    required this.protein,
    required this.proteinGoal,
    required this.fat,
    required this.fatGoal,
    required this.steps,
    required this.stepsGoal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: PremiumSectionCard(
        title: 'Macronutrients',
        icon: Icons.pie_chart_rounded,
        subtitle: 'Track your daily macro goals',
        child: Column(
          children: [
            // Macro rings
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                MacroProgressRing(
                  macro: 'Carbs',
                  current: carbs,
                  target: carbsGoal,
                  animated: true,
                ),
                MacroProgressRing(
                  macro: 'Protein',
                  current: protein,
                  target: proteinGoal,
                  animated: true,
                ),
                MacroProgressRing(
                  macro: 'Fat',
                  current: fat,
                  target: fatGoal,
                  animated: true,
                ),
                MacroProgressRing(
                  macro: 'Steps',
                  current: steps,
                  target: stepsGoal,
                  animated: true,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: PremiumButton.secondary(
                    text: 'Adjust Goals',
                    icon: Icons.settings_rounded,
                    onPressed: () {
                      // Navigate to goal settings
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PremiumButton.primary(
                    text: 'View Details',
                    icon: Icons.analytics_rounded,
                    onPressed: () {
                      // Navigate to detailed view
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// EXAMPLE 4: Premium Settings Screen Layout
class PremiumSettingsExample extends StatelessWidget {
  const PremiumSettingsExample({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: theme.textTheme.headlineMedium,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile section
            PremiumSectionCard(
              title: 'Profile',
              icon: Icons.person_rounded,
              child: Column(
                children: [
                  _SettingsItem(
                    title: 'Personal Information',
                    subtitle: 'Update your profile details',
                    icon: Icons.edit_rounded,
                    onTap: () {},
                  ),
                  _SettingsItem(
                    title: 'Goals & Preferences',
                    subtitle: 'Customize your fitness goals',
                    icon: Icons.center_focus_strong_rounded,
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // App preferences
            PremiumSectionCard(
              title: 'App Preferences',
              icon: Icons.tune_rounded,
              child: Column(
                children: [
                  _SettingsItem(
                    title: 'Notifications',
                    subtitle: 'Manage app notifications',
                    icon: Icons.notifications_rounded,
                    trailing: Switch(
                      value: true,
                      onChanged: (value) {},
                    ),
                  ),
                  _SettingsItem(
                    title: 'Theme',
                    subtitle: 'Light or dark mode',
                    icon: Icons.palette_rounded,
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Dangerous actions
            PremiumSectionCard(
              title: 'Account',
              icon: Icons.security_rounded,
              child: Column(
                children: [
                  _SettingsItem(
                    title: 'Privacy Policy',
                    subtitle: 'Review our privacy policy',
                    icon: Icons.privacy_tip_rounded,
                    onTap: () {},
                  ),
                  _SettingsItem(
                    title: 'Delete Account',
                    subtitle: 'Permanently delete your account',
                    icon: Icons.delete_forever_rounded,
                    onTap: () {},
                    isDestructive: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isDestructive;

  const _SettingsItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDestructive
                      ? PremiumColors.red500.withOpacity(0.1)
                      : PremiumColors.slate100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isDestructive
                      ? PremiumColors.red500
                      : PremiumColors.slate600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: isDestructive
                            ? PremiumColors.red500
                            : customColors?.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: customColors?.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: customColors?.textSecondary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// IMPLEMENTATION BEST PRACTICES:
/// 
/// 1. **Color Usage:**
///    - Use PremiumColors for all color references
///    - Prefer semantic colors (emerald for success, red for errors)
///    - Always consider dark mode support
/// 
/// 2. **Typography:**
///    - Use theme.textTheme styles instead of hardcoded fonts
///    - Apply consistent letter spacing and font weights
///    - Use proper text color hierarchy
/// 
/// 3. **Spacing:**
///    - Use consistent padding (8, 12, 16, 20, 24)
///    - Apply proper margins between sections
///    - Follow 8pt grid system
/// 
/// 4. **Cards:**
///    - Use PremiumCard for all container elements
///    - Choose appropriate factory methods (subtle, elevated, glass)
///    - Apply consistent border radius (12-16px)
/// 
/// 5. **Buttons:**
///    - Use PremiumButton for all interactive elements
///    - Choose appropriate styles (primary, secondary, outlined)
///    - Include proper loading and disabled states
/// 
/// 6. **Animations:**
///    - Use PremiumAnimations constants for timing
///    - Apply smooth curves for natural feel
///    - Stagger animations for lists
/// 
/// 7. **Accessibility:**
///    - Ensure proper contrast ratios
///    - Add semantic labels
///    - Support dynamic text scaling 