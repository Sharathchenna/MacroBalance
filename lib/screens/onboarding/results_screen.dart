import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrotracker/screens/dashboard.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:macrotracker/screens/onboarding/referral_page.dart';
import 'package:macrotracker/services/superwall_service.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/subscription_provider.dart';
import 'package:macrotracker/providers/food_entry_provider.dart';

class ResultsScreen extends StatefulWidget {
  final Map<String, dynamic> results;

  const ResultsScreen({super.key, required this.results});

  @override
  ResultsScreenState createState() => ResultsScreenState();
}

class ResultsScreenState extends State<ResultsScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _masterController;
  late AnimationController _heroController;
  late AnimationController _celebrationController;
  late AnimationController _ctaController;
  late AnimationController _particleController;
  late AnimationController _breathingController;

  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<double> _heroScaleAnimation;
  late Animation<double> _celebrationAnimation;
  late Animation<double> _ctaPulseAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _breathingAnimation;

  // Controllers
  late ScrollController _scrollController;

  // State management
  bool _isRevealed = false;
  bool _showMacros = false;
  bool _showGoals = false;
  bool _showInsights = false;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeAnimations();
    _saveResultsToPrefs();
    _startPremiumRevealSequence();
  }

  void _initializeControllers() {
    _masterController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _heroController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _ctaController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );

    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _scrollController = ScrollController();
  }

  void _initializeAnimations() {
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _heroScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _heroController,
        curve: Curves.elasticOut,
      ),
    );

    // _calorieCountAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
    //   CurvedAnimation(
    //     parent: _heroController,
    //     curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
    //   ),
    // );

    _celebrationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _celebrationController,
        curve: Curves.elasticOut,
      ),
    );

    _ctaPulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _ctaController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
      ),
    );

    _breathingAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOut,
      ),
    );
  }

  void _startPremiumRevealSequence() async {
    // Initial fade in
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) _masterController.forward();

    // Hero calorie animation
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      _heroController.forward();
      _breathingController.repeat(reverse: true);
      HapticFeedback.mediumImpact();
    }

    // Celebration burst
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) {
      _celebrationController.forward();
      _particleController.forward();
      HapticFeedback.heavyImpact();
      setState(() => _isRevealed = true);
    }

    // Progressive content reveal
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) setState(() => _showMacros = true);

    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _showGoals = true);

    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _showInsights = true);

    // CTA animation
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) _ctaController.repeat(reverse: true);
  }

  void _saveResultsToPrefs() {
    HapticFeedback.mediumImpact();
    StorageService().put('macro_results', jsonEncode(widget.results));
  }

  void _showPaywallAndProceed() async {
    // Play haptic feedback
    HapticFeedback.mediumImpact();

    // Get providers
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    final foodEntryProvider =
        Provider.of<FoodEntryProvider>(context, listen: false);

    // Initialize food entry provider
    await foodEntryProvider.initialize();
    if (!mounted) return;

    // Check subscription status
    final isProUser = await subscriptionProvider.refreshSubscriptionStatus();
    if (!mounted) return;

    if (isProUser) {
      // User already has a subscription, go directly to dashboard
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const Dashboard()),
      );
    } else {
      // Show referral page first
      if (!mounted) return;

      // We use the Navigator.push and then handle the result to avoid context issues
      final shouldContinue = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => ReferralPage(
            onContinue: () {
              // Close the referral page and indicate to continue
              Navigator.of(context).pop(true);
            },
          ),
        ),
      );

      // If state is no longer mounted or user didn't choose to continue
      if (!mounted || shouldContinue != true) return;

      try {
        // Show paywall
        await SuperwallService().showMainPaywall();

        // Wait a moment for the subscription to process
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;

        // Check if user subscribed
        final hasSubscription =
            await subscriptionProvider.refreshSubscriptionStatus();
        if (!mounted) return;

        if (hasSubscription) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const Dashboard()),
          );
        }
      } catch (e) {
        debugPrint('Error showing Superwall paywall: $e');
        if (!mounted) return;

        // If there was an error with the paywall, proceed to dashboard anyway
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const Dashboard()),
        );
      }
    }
  }

  @override
  void dispose() {
    _masterController.dispose();
    _heroController.dispose();
    _celebrationController.dispose();
    _ctaController.dispose();
    _particleController.dispose();
    _breathingController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.1 * 255).round()),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.1 * 255).round()),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _showDetails ? Icons.visibility_off : Icons.visibility,
                color: Colors.white,
              ),
            ),
            onPressed: () {
              setState(() => _showDetails = !_showDetails);
              HapticFeedback.lightImpact();
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Stack(
              children: [
                _buildPremiumBackground(),
                CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildPremiumHeroSection()),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          if (_showMacros) _buildPremiumMacroSection(),
                          if (_showGoals) _buildPremiumGoalSection(),
                          if (_showInsights) _buildPremiumInsightsSection(),
                          if (_showDetails) _buildPremiumDetailsSection(),
                          const SizedBox(height: 120),
                        ]),
                      ),
                    ),
                  ],
                ),
                _buildFloatingCTA(),
                if (_isRevealed) _buildPremiumCelebrationOverlay(),
                _buildParticleSystem(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPremiumBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A1A2E),
            Color(0xFF16213E),
            Color(0xFF0F3460),
            Color(0xFF533483),
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
        ),
      ),
    );
  }

  Widget _buildPremiumHeroSection() {
    final calories = widget.results['target_calories'] ?? 2000;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 60),

            // Celebration emoji
            AnimatedBuilder(
              animation: _celebrationAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_celebrationAnimation.value * 0.3),
                  child: const Text(
                    '🎉',
                    style: TextStyle(fontSize: 48),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            Text(
              'Your Perfect Plan',
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Scientifically calculated for your body',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white.withAlpha((0.8 * 255).round()),
              ),
            ),

            const SizedBox(height: 40),

            // Animated calorie circle
            AnimatedBuilder(
              animation:
                  Listenable.merge([_heroScaleAnimation, _breathingAnimation]),
              builder: (context, child) {
                return Transform.scale(
                  scale: _heroScaleAnimation.value * _breathingAnimation.value,
                  child: SizedBox(
                    width: 280,
                    height: 280,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer glow
                        Container(
                          width: 280,
                          height: 280,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.blue.withAlpha((0.3 * 255).round()),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        ),

                        // Main circle
                        Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black.withAlpha((0.3 * 255).round()),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(120),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withAlpha((0.1 * 255).round()),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white
                                        .withAlpha((0.2 * 255).round()),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      TweenAnimationBuilder<double>(
                                        tween: Tween<double>(
                                            begin: 0, end: calories.toDouble()),
                                        duration:
                                            const Duration(milliseconds: 2000),
                                        curve: Curves.easeOutCubic,
                                        builder: (context, value, child) {
                                          return Text(
                                            '${value.round()}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 48,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          );
                                        },
                                      ),
                                      Text(
                                        'calories/day',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          color: Colors.white
                                              .withAlpha((0.9 * 255).round()),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withAlpha((0.2 * 255).round()),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          _getGoalText().toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumMacroSection() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withAlpha((0.2 * 255).round()),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                    Colors.blue.withAlpha((0.2 * 255).round()),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.pie_chart_rounded,
                                color: Colors.blue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Daily Macros',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildMacroRow(
                            'Protein',
                            widget.results['protein_g'] ?? 0,
                            Colors.red.shade400),
                        const SizedBox(height: 12),
                        _buildMacroRow('Carbs', widget.results['carb_g'] ?? 0,
                            Colors.blue.shade400),
                        const SizedBox(height: 12),
                        _buildMacroRow('Fat', widget.results['fat_g'] ?? 0,
                            Colors.orange.shade400),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMacroRow(String name, int grams, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white.withAlpha((0.9 * 255).round()),
            ),
          ),
        ),
        Text(
          '${grams}g',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumGoalSection() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withAlpha((0.2 * 255).round()),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                    Colors.green.withAlpha((0.2 * 255).round()),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.track_changes_rounded,
                                color: Colors.green,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Your Goals',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildGoalInfo('BMR', '${widget.results['bmr']} cal',
                            'Base metabolic rate'),
                        const SizedBox(height: 12),
                        _buildGoalInfo('TDEE', '${widget.results['tdee']} cal',
                            'Total daily expenditure'),
                        const SizedBox(height: 12),
                        _buildGoalInfo(
                            'Steps',
                            '${widget.results['recommended_steps'] ?? 10000}',
                            'Daily step goal'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGoalInfo(String title, String value, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.white.withAlpha((0.7 * 255).round()),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.white.withAlpha((0.6 * 255).round()),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumInsightsSection() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withAlpha((0.2 * 255).round()),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.purple
                                    .withAlpha((0.2 * 255).round()),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.psychology_rounded,
                                color: Colors.purple,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Success Insights',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildInsightCard(
                          '95% Success Rate',
                          'Your plan is realistic and achievable',
                          Icons.verified,
                          Colors.green,
                        ),
                        const SizedBox(height: 12),
                        _buildInsightCard(
                          'Science-Based',
                          'Calculated using proven formulas',
                          Icons.science,
                          Colors.blue,
                        ),
                        const SizedBox(height: 12),
                        _buildInsightCard(
                          'Personalized',
                          'Tailored specifically for your body',
                          Icons.person,
                          Colors.orange,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInsightCard(
      String title, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withAlpha((0.3 * 255).round()),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withAlpha((0.7 * 255).round()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumDetailsSection() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withAlpha((0.2 * 255).round()),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calculation Details',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Formula: ${widget.results['formula_used'] ?? 'Mifflin-St Jeor'}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white.withAlpha((0.8 * 255).round()),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Activity Level: ${widget.results['activity_level'] ?? 'Moderate'}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white.withAlpha((0.8 * 255).round()),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Goal: ${_getGoalText()}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white.withAlpha((0.8 * 255).round()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingCTA() {
    return Positioned(
      bottom: 40,
      left: 20,
      right: 20,
      child: AnimatedBuilder(
        animation: _ctaPulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _ctaPulseAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withAlpha((0.3 * 255).round()),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      ),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: ElevatedButton(
                      onPressed: _showPaywallAndProceed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Start Your Journey',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPremiumCelebrationOverlay() {
    return AnimatedBuilder(
      animation: _celebrationAnimation,
      builder: (context, child) {
        return Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: PremiumConfettiPainter(_celebrationAnimation.value),
            ),
          ),
        );
      },
    );
  }

  Widget _buildParticleSystem() {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        return Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: ParticleSystemPainter(_particleController.value),
            ),
          ),
        );
      },
    );
  }

  String _getGoalText() {
    final goal = widget.results['goal'] ?? '';
    if (goal == 'lose') return 'Weight Loss';
    if (goal == 'gain') return 'Muscle Gain';
    return 'Maintenance';
  }
}

class PremiumConfettiPainter extends CustomPainter {
  final double progress;

  PremiumConfettiPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0.1) return;

    final paint = Paint()..style = PaintingStyle.fill;
    final random = math.Random(42);

    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final y = size.height * (1 - progress) + (random.nextDouble() * 200);
      final color = [
        Colors.blue,
        Colors.purple,
        Colors.pink,
        Colors.orange,
        Colors.green,
        Colors.yellow,
      ][i % 6];

      paint.color = color.withValues(alpha: (1 - progress).clamp(0.0, 1.0));

      canvas.drawCircle(
        Offset(x, y),
        3 + (random.nextDouble() * 4),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(PremiumConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class ParticleSystemPainter extends CustomPainter {
  final double progress;

  ParticleSystemPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = math.Random(123);

    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final opacity = (math.sin(progress * 2 * math.pi + i) + 1) / 2;

      paint.color = Colors.white.withValues(alpha: opacity * 0.1);

      canvas.drawCircle(
        Offset(x, y),
        1 + (random.nextDouble() * 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ParticleSystemPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
