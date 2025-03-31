import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'dart:math' as math;
import 'dart:async';

class CustomPaywallScreen extends StatefulWidget {
  final VoidCallback onDismiss;
  final bool allowDismissal;

  const CustomPaywallScreen({
    Key? key,
    required this.onDismiss,
    this.allowDismissal = true,
  }) : super(key: key);

  @override
  State<CustomPaywallScreen> createState() => _CustomPaywallScreenState();
}

class _CustomPaywallScreenState extends State<CustomPaywallScreen>
    with SingleTickerProviderStateMixin {
  Offering? _offering;
  Package? _selectedPackage;
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isTrialMode = true; // Default to trial mode
  bool _showDismissButton = false; // Initially hide dismiss button

  // UI Controllers
  final PageController _pageController = PageController();
  late AnimationController _animationController;
  Timer? _carouselTimer;
  Timer? _dismissButtonTimer;
  int _currentPage = 0;

  // Features for carousel with enhanced descriptions
  final List<Map<String, dynamic>> _features = [
    {
      'title': 'Unlimited Nutrition Tracking',
      'description':
          'Track every meal with unlimited entries and detailed macro breakdowns',
      'icon': Icons.analytics_outlined,
      'animation': 'assets/animations/food_tracking.json',
      'highlight': 'Unlimited',
    },
    {
      'title': 'AI-Powered Insights',
      'description':
          'Get personalized nutrition analysis and recommendations powered by advanced AI',
      'icon': Icons.lightbulb_outline,
      'animation': 'assets/animations/insights.json',
      'highlight': 'AI-Powered',
    },
    {
      'title': 'Smart Meal Planning',
      'description':
          'Let AI create custom meal plans tailored to your goals and preferences',
      'icon': Icons.psychology_outlined,
      'animation': 'assets/animations/meal_planning.json',
      'highlight': 'Smart',
    },
    {
      'title': 'Premium Experience',
      'description':
          'Enjoy an ad-free experience with exclusive features and priority support',
      'icon': Icons.star_outline,
      'animation': 'assets/animations/premium_badge.json',
      'highlight': 'Premium',
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: false);

    _pageController.addListener(() {
      int nextPage = _pageController.page!.round();
      if (_currentPage != nextPage) {
        setState(() {
          _currentPage = nextPage;
        });
        _resetCarouselTimer();
      }
    });

    // Set system UI overlay style for better immersion
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _fetchOfferings();
    _startCarouselTimer();

    // Delay showing dismiss button
    _dismissButtonTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showDismissButton = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _carouselTimer?.cancel();
    _dismissButtonTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOfferings() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final offerings = await Purchases.getOfferings();

      if (mounted) {
        if (offerings.current != null) {
          // Find default package (prefer monthly)
          Package? defaultPackage;
          if (offerings.current!.availablePackages.isNotEmpty) {
            defaultPackage = offerings.current!.availablePackages.first;

            // Try to find monthly package for default selection
            final monthlyPackage = offerings.current!.availablePackages
                .where((p) => p.packageType == PackageType.monthly)
                .firstOrNull;

            if (monthlyPackage != null) {
              defaultPackage = monthlyPackage;
            }
          }

          setState(() {
            _offering = offerings.current;
            _selectedPackage = defaultPackage;
            _isLoading = false;
          });
        } else {
          setState(() {
            _offering = null;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _purchasePackage(Package package) async {
    if (_isPurchasing) return;

    setState(() {
      _isPurchasing = true;
    });

    try {
      final customerInfo = await Purchases.purchasePackage(package);

      if (customerInfo.entitlements.active.isNotEmpty) {
        widget.onDismiss();
      } else {
        _showError('Purchase completed but subscription not activated');
      }
    } catch (e) {
      if (e is PurchasesErrorCode) {
        // Don't show error for user cancellation
        if (e != PurchasesErrorCode.purchaseCancelledError) {
          _showError(e.toString());
        }
      } else {
        _showError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  Future<void> _restorePurchases() async {
    if (_isPurchasing) return;

    setState(() {
      _isPurchasing = true;
    });

    try {
      final customerInfo = await Purchases.restorePurchases();

      if (customerInfo.entitlements.active.isNotEmpty) {
        widget.onDismiss();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No previous purchases found'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $message'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
      ),
    );
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % _features.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _resetCarouselTimer() {
    _carouselTimer?.cancel();
    _startCarouselTimer();
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        height: size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isDark ? const Color(0xFF121212) : Colors.white,
              isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F7F3),
            ],
          ),
        ),
        child: _isLoading
            ? _buildLoadingState(customColors)
            : _offering == null
                ? _buildErrorState(customColors)
                : _buildPaywallContent(customColors, size, isDark),
      ),
    );
  }

  Widget _buildLoadingState(CustomColors? customColors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: customColors?.accentPrimary,
            strokeWidth: 2,
          ),
          const SizedBox(height: 24),
          Text(
            'Loading',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: customColors?.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(CustomColors? customColors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: customColors?.textSecondary,
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to load premium features',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: customColors?.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchOfferings,
              style: ElevatedButton.styleFrom(
                backgroundColor: customColors?.accentPrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size(180, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Try Again'),
            ),
            if (widget.allowDismissal)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: TextButton(
                  onPressed: widget.onDismiss,
                  child: Text(
                    'Continue with free version',
                    style: TextStyle(
                      color: customColors?.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaywallContent(
      CustomColors? customColors, Size size, bool isDark) {
    final textColor =
        customColors?.textPrimary ?? (isDark ? Colors.white : Colors.black);
    final accentColor = customColors?.accentPrimary ?? Colors.green;

    return Stack(
      children: [
        // Enhanced background pattern with nutrition elements
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return CustomPaint(
                painter: NutritionBackgroundPainter(
                  isDark: isDark,
                  progress: _animationController.value,
                  primaryColor: accentColor,
                ),
              );
            },
          ),
        ),

        // Main Content
        SafeArea(
          child: Column(
            children: [
              // Close button if dismissal is allowed
              if (widget.allowDismissal && _showDismissButton)
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: IconButton(
                      icon: Icon(Icons.close,
                          color: textColor.withOpacity(0.6), size: 24),
                      onPressed: () => _showExitDialog(textColor, accentColor),
                    ),
                  ),
                ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 32),

                        // Enhanced hero section with premium branding
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.9, end: 1.0),
                          duration: const Duration(seconds: 1),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: child,
                            );
                          },
                          child: Column(
                            children: [
                              // Premium badge with animation
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: accentColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.workspace_premium,
                                        color: accentColor, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'PREMIUM',
                                      style: TextStyle(
                                        color: accentColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Main title with gradient
                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [
                                    accentColor,
                                    Color.lerp(accentColor, Colors.blue, 0.4) ??
                                        accentColor
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(bounds),
                                child: Text(
                                  'Unlock Your Full\nNutrition Potential',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Subtitle
                              Text(
                                'Join thousands of users who have transformed their nutrition journey',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: textColor.withOpacity(0.7),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Enhanced feature carousel
                        SizedBox(
                          height: 280,
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: _features.length,
                            itemBuilder: (context, index) {
                              return _buildFeatureCard(
                                  _features[index], customColors, textColor);
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Enhanced page indicator
                        Center(
                          child: SmoothPageIndicator(
                            controller: _pageController,
                            count: _features.length,
                            effect: ExpandingDotsEffect(
                              activeDotColor: accentColor,
                              dotColor: accentColor.withOpacity(0.2),
                              dotHeight: 6,
                              dotWidth: 6,
                              expansionFactor: 3,
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Subscription options with enhanced visuals
                        if (_offering != null &&
                            _offering!.availablePackages.isNotEmpty)
                          Column(
                            children:
                                _buildSubscriptionCards(textColor, accentColor),
                          ),

                        const SizedBox(height: 24),

                        // Enhanced price comparison with social proof
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: accentColor.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _isTrialMode
                                    ? "Start with a 7-day free trial"
                                    : "Join thousands of satisfied users",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Less than a coffee per week for better nutrition insights",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textColor.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Enhanced subscribe button with animation and gradient
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.95, end: 1.0),
                          duration: const Duration(milliseconds: 2000),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: child,
                            );
                          },
                          child: Container(
                            height: 60,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  accentColor,
                                  Color.lerp(accentColor, Colors.blue, 0.4) ??
                                      accentColor,
                                ],
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: _isPurchasing ||
                                      _selectedPackage == null
                                  ? null
                                  : () => _purchasePackage(_selectedPackage!),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                disabledBackgroundColor: Colors.transparent,
                                disabledForegroundColor:
                                    Colors.white.withOpacity(0.5),
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isPurchasing
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _isTrialMode
                                              ? "Start 7-Day Free Trial"
                                              : "Subscribe Now",
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Enhanced restore purchases button
                        Center(
                          child: TextButton(
                            onPressed: _isPurchasing ? null : _restorePurchases,
                            style: TextButton.styleFrom(
                              foregroundColor: textColor.withOpacity(0.6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.restore, size: 16),
                                const SizedBox(width: 8),
                                const Text(
                                  "Restore Purchases",
                                  style: TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Enhanced terms text
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: textColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "Subscription automatically renews unless canceled at least 24 hours before the end of the current period. You can manage your subscription in your App Store account settings.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: textColor.withOpacity(0.4),
                              height: 1.4,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Enhanced purchase processing overlay
        if (_isPurchasing)
          Positioned.fill(
            child: Container(
              color: isDark
                  ? Colors.black.withOpacity(0.7)
                  : Colors.white.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(
                              color: customColors?.accentPrimary,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "Processing your premium upgrade...",
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "This will only take a moment",
                            style: TextStyle(
                              color: textColor.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
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

  List<Widget> _buildSubscriptionCards(Color textColor, Color accentColor) {
    List<Widget> cards = [];

    if (_offering?.availablePackages == null ||
        _offering!.availablePackages.isEmpty) {
      return cards;
    }

    // Find annual plan for best value calculation
    Package? annualPackage = _offering!.availablePackages
        .where((p) => p.packageType == PackageType.annual)
        .firstOrNull;

    // Find monthly plan for comparison
    Package? monthlyPackage = _offering!.availablePackages
        .where((p) => p.packageType == PackageType.monthly)
        .firstOrNull;

    // Calculate savings percentage if both packages exist
    String? savingsText;
    if (annualPackage != null && monthlyPackage != null) {
      double annualPricePerMonth = annualPackage.storeProduct.price / 12;
      double monthlyPrice = monthlyPackage.storeProduct.price;

      if (monthlyPrice > 0) {
        int savingsPercentage =
            ((1 - (annualPricePerMonth / monthlyPrice)) * 100).round();
        savingsText = "$savingsPercentage%";
      }
    }

    // Sort packages: monthly first, then annual, then others
    List<Package> sortedPackages = List.from(_offering!.availablePackages);
    sortedPackages.sort((a, b) {
      if (a.packageType == PackageType.monthly) return -1;
      if (b.packageType == PackageType.monthly) return 1;
      if (a.packageType == PackageType.annual) return -1;
      if (b.packageType == PackageType.annual) return 1;
      return 0;
    });

    // Build card for each package
    for (var package in sortedPackages) {
      final isSelected = package.identifier == _selectedPackage?.identifier;
      final price = package.storeProduct.priceString;
      final isAnnual = package.packageType == PackageType.annual;
      final isMonthly = package.packageType == PackageType.monthly;
      final isLifetime = package.packageType == PackageType.lifetime;

      // Skip packages we don't want to show
      if (!isMonthly && !isAnnual && !isLifetime) continue;

      String title, description;
      String? perMonthPrice;
      bool isBestValue = isAnnual && savingsText != null;

      switch (package.packageType) {
        case PackageType.monthly:
          title = "Monthly";
          description = "Full access, billed monthly";
          break;
        case PackageType.annual:
          title = "Annual";
          description = "Best value annual plan";
          // Calculate per-month price
          if (package.storeProduct.price > 0) {
            double monthlyEquivalent = package.storeProduct.price / 12;
            perMonthPrice =
                "${package.storeProduct.currencyCode} ${monthlyEquivalent.toStringAsFixed(2)}/mo";
          }
          break;
        case PackageType.lifetime:
          title = "Lifetime";
          description = "One-time payment, forever access";
          break;
        default:
          title = package.packageType.name;
          description = "Premium subscription";
      }

      cards.add(
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.95, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: isSelected ? value : 1.0,
              child: child,
            );
          },
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedPackage = package;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withOpacity(0.1)
                    : Theme.of(context).brightness == Brightness.dark
                        ? Colors.black.withOpacity(0.3)
                        : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? accentColor : textColor.withOpacity(0.1),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: accentColor.withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  // Main content
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 18),
                    child: Row(
                      children: [
                        // Selection indicator
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? accentColor
                                  : textColor.withOpacity(0.3),
                              width: 2,
                            ),
                            color:
                                isSelected ? accentColor : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),

                        // Subscription details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                  if (perMonthPrice != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      perMonthPrice,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: accentColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                description,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textColor.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Price
                        Text(
                          price,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Best value badge
                  if (isBestValue)
                    Positioned(
                      top: 0,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.workspace_premium,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "SAVE $savingsText",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return cards;
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature,
      CustomColors? customColors, Color textColor) {
    final accentColor = customColors?.accentPrimary ?? Colors.green;
    final hasAnimation = feature['animation'] != null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.05),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: hasAnimation
              ? Lottie.asset(
                  feature['animation'],
                  fit: BoxFit.cover,
                )
              : Icon(
                  feature['icon'],
                  color: accentColor,
                  size: 32,
                ),
        ),
        const SizedBox(height: 20),
        Text(
          feature['title'],
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            feature['description'],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: textColor.withOpacity(0.7),
            ),
          ),
        ),
      ],
    );
  }

  void _showExitDialog(Color textColor, Color accentColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Before you go...",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Would you like to try our app with premium features at a special discount?",
              style: TextStyle(color: textColor.withOpacity(0.8)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.check_circle, color: accentColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Unlimited food tracking",
                    style: TextStyle(color: textColor.withOpacity(0.7)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, color: accentColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Personalized meal plans",
                    style: TextStyle(color: textColor.withOpacity(0.7)),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: widget.onDismiss,
            child: Text(
              "No thanks",
              style: TextStyle(color: textColor.withOpacity(0.6)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              // Apply special discount logic here if needed
            },
            child: const Text("Get Discount"),
          ),
        ],
      ),
    );
  }
}

class NutritionBackgroundPainter extends CustomPainter {
  final bool isDark;
  final double progress;
  final Color primaryColor;

  NutritionBackgroundPainter({
    required this.isDark,
    required this.progress,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Create a more sophisticated gradient background
    final gradientRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        isDark
            ? primaryColor.withOpacity(0.03)
            : primaryColor.withOpacity(0.02),
        isDark
            ? primaryColor.withOpacity(0.05)
            : primaryColor.withOpacity(0.03),
        isDark
            ? primaryColor.withOpacity(0.03)
            : primaryColor.withOpacity(0.02),
      ],
    );

    canvas.drawRect(
      gradientRect,
      Paint()..shader = gradient.createShader(gradientRect),
    );

    // Draw premium patterns
    _drawPremiumPatterns(canvas, size);
  }

  void _drawPremiumPatterns(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor.withOpacity(isDark ? 0.03 : 0.02)
      ..style = PaintingStyle.fill;

    // Draw floating hexagons
    _drawFloatingHexagons(canvas, size, paint);

    // Draw subtle nutrition icons
    _drawNutritionIcons(canvas, size, paint);

    // Draw connecting lines
    _drawConnectingLines(canvas, size, paint);
  }

  void _drawFloatingHexagons(Canvas canvas, Size size, Paint paint) {
    final hexSize = size.width * 0.08;
    final spacing = size.width * 0.15;

    for (int i = 0; i < 3; i++) {
      final offset = (i * 0.3 + progress) % 1.0;
      final x = size.width * (0.2 + offset * 0.6);
      final y = size.height * (0.1 + offset * 0.8);

      _drawHexagon(canvas, Offset(x, y), hexSize, paint);
    }
  }

  void _drawHexagon(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * math.pi / 3) + (progress * math.pi * 0.5);
      final x = center.dx + size * math.cos(angle);
      final y = center.dy + size * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawNutritionIcons(Canvas canvas, Size size, Paint paint) {
    // Draw apple
    final appleCenter = Offset(
      size.width * (0.2 + 0.1 * math.sin(progress * math.pi)),
      size.height * (0.15 + 0.05 * math.cos(progress * math.pi * 0.5)),
    );
    _drawApple(canvas, appleCenter, size.width * 0.08, paint);

    // Draw plate
    final plateCenter = Offset(
      size.width * (0.8 - 0.05 * math.sin(progress * math.pi * 0.7)),
      size.height * (0.3 + 0.08 * math.cos(progress * math.pi * 0.3)),
    );
    _drawPlate(canvas, plateCenter, size.width * 0.15, paint);

    // Draw water drop
    final dropCenter = Offset(
      size.width * (0.3 + 0.08 * math.cos(progress * math.pi * 1.2)),
      size.height * (0.6 + 0.1 * math.sin(progress * math.pi * 0.9)),
    );
    _drawWaterDrop(canvas, dropCenter, size.width * 0.1, paint);
  }

  void _drawApple(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    // Draw apple body
    path.addOval(Rect.fromCircle(center: center, radius: size));
    // Draw leaf
    final leafPath = Path();
    leafPath.moveTo(center.dx, center.dy - size);
    leafPath.quadraticBezierTo(
      center.dx + size * 0.5,
      center.dy - size * 1.2,
      center.dx,
      center.dy - size * 1.5,
    );
    leafPath.quadraticBezierTo(
      center.dx - size * 0.5,
      center.dy - size * 1.2,
      center.dx,
      center.dy - size,
    );
    canvas.drawPath(path, paint);
    canvas.drawPath(leafPath, paint);
  }

  void _drawPlate(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    // Draw plate rim
    path.addOval(Rect.fromCircle(center: center, radius: size));
    // Draw plate center
    path.addOval(Rect.fromCircle(center: center, radius: size * 0.8));
    canvas.drawPath(path, paint);
  }

  void _drawWaterDrop(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    path.moveTo(center.dx, center.dy - size);
    path.quadraticBezierTo(
      center.dx + size,
      center.dy,
      center.dx,
      center.dy + size,
    );
    path.quadraticBezierTo(
      center.dx - size,
      center.dy,
      center.dx,
      center.dy - size,
    );
    canvas.drawPath(path, paint);
  }

  void _drawConnectingLines(Canvas canvas, Size size, Paint paint) {
    final linePaint = Paint()
      ..color = primaryColor.withOpacity(isDark ? 0.02 : 0.01)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw curved connecting lines between elements
    for (int i = 0; i < 3; i++) {
      final offset = (i * 0.3 + progress) % 1.0;
      final startX = size.width * (0.2 + offset * 0.6);
      final startY = size.height * (0.1 + offset * 0.8);
      final endX = size.width * (0.8 - offset * 0.6);
      final endY = size.height * (0.9 - offset * 0.8);

      final path = Path();
      path.moveTo(startX, startY);
      path.quadraticBezierTo(
        (startX + endX) / 2,
        (startY + endY) / 2 + math.sin(progress * math.pi * 2) * 50,
        endX,
        endY,
      );
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant NutritionBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
