import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:macrotracker/Routes/route_constants.dart'; // Added import

class CustomPaywallScreen extends StatefulWidget {
  final VoidCallback
      onDismiss; // Called on successful purchase/restore or explicit dismissal action
  final VoidCallback?
      onBackPressedOverride; // Optional override for the back button press
  final bool allowDismissal;

  const CustomPaywallScreen({
    Key? key,
    required this.onDismiss,
    this.onBackPressedOverride, // Add to constructor
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
  // bool _isTrialMode = true; // No longer needed, rely on introductoryPrice
  bool _isReturningUser = false; // Flag to identify returning users
  bool _showDismissButton = false; // Initially hide dismiss button
  bool _showScrollIndicator = true; // Control scroll indicator visibility

  // UI Controllers
  final PageController _pageController = PageController();
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();
  Timer? _carouselTimer;
  Timer? _dismissButtonTimer;
  int _currentPage = 0;

  // Features for carousel with enhanced descriptions
  final List<Map<String, dynamic>> _features = [
    {
      'title': 'Unlimited Nutrition Tracking',
      'description':
          'Track unlimited meals and foods with detailed macronutrient breakdowns, calorie counts, and personalized nutrition insights',
      'icon': Icons.analytics_outlined,
      'animation': 'assets/animations/nutrition.json',
      'highlight': 'Unlimited',
    },
    {
      'title': 'AI-Powered',
      'description':
          'Our advanced AI accurately identifies foods, estimates portions, and provides detailed nutritional analysis from photos or text descriptions',
      'icon': Icons.auto_awesome_mosaic_outlined,
      'animation': 'assets/animations/AI_powered.json',
      'highlight': 'AI-Powered',
    },
    {
      'title': 'Easy Meal Logging',
      'description':
          'Save time with our intuitive interface, quick entry templates, meal history, and smart suggestions based on your eating habits',
      'icon': Icons.psychology_outlined,
      'animation': 'assets/animations/meal_logging.json',
      'highlight': 'Easy',
    },
    {
      'title': 'Premium Experience',
      'description':
          'Enjoy an ad-free interface, priority customer support, and exclusive premium features including detailed nutrition reports and trends',
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

    // Add scroll controller listener to show/hide indicator
    _scrollController.addListener(_handleScroll);

    // Set system UI overlay style for better immersion
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    // Check if user has previously used the app
    _checkIfReturningUser();

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

  void _handleScroll() {
    // Show indicator only when scroll position is at the top
    final isAtTop = _scrollController.offset <= 20;
    if (isAtTop != _showScrollIndicator) {
      setState(() {
        _showScrollIndicator = isAtTop;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
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
          Package? defaultPackage;
          if (offerings.current!.availablePackages.isNotEmpty) {
            defaultPackage = offerings.current!.availablePackages.first;
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
        // Log the error but don't show to user - UI will display an error state
        debugPrint('Failed to fetch offerings: ${e.toString()}');
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
        // Navigate to Dashboard and clear the stack
        Navigator.pushNamedAndRemoveUntil(
            context,
            RouteNames.dashboard,
            (Route<dynamic> route) =>
                false); // Corrected class name and route name
      } else {
        _showError(
            'Purchase completed but your subscription could not be activated. Please contact support.');
      }
    } catch (e) {
      if (e is PurchasesErrorCode) {
        // Handle specific RevenueCat error codes with user-friendly messages
        if (e == PurchasesErrorCode.purchaseCancelledError) {
          // Don't show error for user cancellation
          return;
        } else if (e == PurchasesErrorCode.networkError) {
          _showError(
              'Network connection error. Please check your internet connection and try again.');
        } else if (e == PurchasesErrorCode.storeProblemError) {
          _showError(
              'There was a problem with the App Store. Please try again later.');
        } else if (e == PurchasesErrorCode.purchaseNotAllowedError) {
          _showError(
              'Purchase not allowed. Please check your device settings or parental controls.');
        } else if (e == PurchasesErrorCode.purchaseInvalidError) {
          _showError(
              'The purchase was invalid. Please try again or contact support.');
        } else if (e == PurchasesErrorCode.productAlreadyPurchasedError) {
          _showError(
              'You already own this subscription. Please restore your purchases.');
        } else {
          _showError(
              'There was an error processing your purchase. Please try again later.');
        }
      } else {
        // Generic error message for unexpected errors
        _showError('An unexpected error occurred. Please try again later.');
        // Log the actual error for debugging
        debugPrint('Purchase error: ${e.toString()}');
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
        // Navigate to Dashboard and clear the stack
        Navigator.pushNamedAndRemoveUntil(
            context,
            RouteNames.dashboard,
            (Route<dynamic> route) =>
                false); // Corrected class name and route name
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No previous purchases found'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // User-friendly message for restore errors
      if (e is PurchasesErrorCode && e == PurchasesErrorCode.networkError) {
        _showError(
            'Network connection error. Please check your internet connection and try again.');
      } else {
        _showError('Could not restore purchases. Please try again later.');
        // Log the actual error for debugging
        debugPrint('Restore error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  Future<void> _launchPrivacyPolicy() async {
    final Uri privacyPolicyUrl = Uri.parse('https://macrobalance.app/privacy');
    try {
      if (!await launchUrl(privacyPolicyUrl,
          mode: LaunchMode.externalApplication)) {
        _showError(
            'Could not open the privacy policy. Please try again later.');
      }
    } catch (e) {
      _showError('Could not open the privacy policy. Please try again later.');
      debugPrint('Error launching URL: $e');
    }
  }

  Future<void> _launchTermsOfService() async {
    final Uri tosUrl = Uri.parse('https://macrobalance.app/terms');
    try {
      if (!await launchUrl(tosUrl, mode: LaunchMode.externalApplication)) {
        _showError(
            'Could not open the terms of service. Please try again later.');
      }
    } catch (e) {
      _showError(
          'Could not open the terms of service. Please try again later.');
      debugPrint('Error launching URL: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(
              // Added const
              color: Colors.white,
            )),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
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

  // Check if the user is returning based on RevenueCat data
  Future<void> _checkIfReturningUser() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();

      // Check for any past purchases (subscriptions or one-time)
      final bool hasPreviousPurchases =
          customerInfo.nonSubscriptionTransactions.isNotEmpty;

      // Check for any previous subscription history (active or expired)
      final bool hasEntitlementHistory = customerInfo.entitlements.all.values
          .any((entitlement) => entitlement.originalPurchaseDate != null);

      // Check if they had any past subscription periods (more comprehensive)
      final bool hasSubscriptionHistory =
          customerInfo.allPurchaseDates.isNotEmpty;

      setState(() {
        // If they meet any of the criteria, consider them a returning user
        _isReturningUser = hasPreviousPurchases ||
            hasEntitlementHistory ||
            hasSubscriptionHistory;

        if (_isReturningUser) {
          debugPrint(
              'User identified as returning customer - trial eligibility depends on introductoryPrice');
        } else {
          debugPrint(
              'User identified as new customer - trial eligible if introductoryPrice exists');
        }
      });
    } catch (e) {
      // If we can't determine, default to new user (safer for offering trials)
      debugPrint('Error identifying user type: $e - defaulting to new user');
      if (mounted) {
        setState(() {
          _isReturningUser = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final size = MediaQuery.of(context).size;
    final isDark = true; // Force dark theme regardless of system preference

    // Define premium paywall-specific colors (dark mode only)
    final premiumGradientStart = const Color(0xFF14162D);
    final premiumGradientEnd = const Color(0xFF0F111E);
    final premiumAccent = const Color(0xFF64D2FF);
    final premiumAccentSecondary = const Color(0xFF9B81FF);
    final premiumTextColor = Colors.white;
    final goldAccent = const Color(0xFFE6C06A);
    final highlightColor = const Color(0xFF2A3052);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        height: size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              premiumGradientStart,
              premiumGradientEnd,
            ],
          ),
        ),
        child: _isLoading
            ? _buildLoadingState(customColors)
            : _offering == null
                ? _buildErrorState(customColors)
                : _buildPaywallContent(
                    customColors,
                    size,
                    isDark,
                    PremiumColors(
                      accent: premiumAccent,
                      accentSecondary: premiumAccentSecondary,
                      textColor: premiumTextColor,
                      gold: goldAccent,
                      highlight: highlightColor,
                    )),
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

  Widget _buildPaywallContent(CustomColors? customColors, Size size,
      bool isDark, PremiumColors colors) {
    final textColor = colors.textColor;
    final accentColor = colors.accent;

    // Determine if the selected package has a trial available for this user
    final bool isTrialAvailable =
        _selectedPackage?.storeProduct.introductoryPrice != null &&
            !_isReturningUser;

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
                  secondaryColor: colors.accentSecondary,
                  goldColor: colors.gold,
                ),
              );
            },
          ),
        ),

        // Main Content
        SafeArea(
          child: Column(
            children: [
              // Back button in top left
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: textColor.withOpacity(0.8),
                      size: 20,
                    ),
                    onPressed: widget.allowDismissal
                        ? (widget.onBackPressedOverride ?? widget.onDismiss)
                        : null,
                  ),
                ),
              ),

              // Main scrollable content
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification notification) {
                    return true;
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    itemCount: 1,
                    itemBuilder: (context, index) {
                      return RepaintBoundary(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 5),

                            // Hero section
                            RepaintBoundary(
                              child: TweenAnimationBuilder<double>(
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
                                    ShaderMask(
                                      shaderCallback: (bounds) =>
                                          LinearGradient(
                                        colors: [
                                          colors.accent,
                                          colors.accentSecondary,
                                          colors.gold,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ).createShader(bounds),
                                      child: const Text(
                                        'Track Smarter, Eat Better, Live Healthier',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Feature carousel
                            RepaintBoundary(
                              child: SizedBox(
                                height: 200,
                                child: PageView.builder(
                                  controller: _pageController,
                                  itemCount: _features.length,
                                  itemBuilder: (context, index) {
                                    return _buildFeatureCard(
                                      _features[index],
                                      customColors,
                                      textColor,
                                      premiumColors: colors,
                                    );
                                  },
                                ),
                              ),
                            ),

                            // Subscription options
                            if (_offering != null &&
                                _offering!.availablePackages.isNotEmpty)
                              RepaintBoundary(
                                child: Column(
                                  children: _buildSubscriptionCards(
                                    textColor,
                                    accentColor,
                                    goldAccent: colors.gold,
                                    highlightColor: colors.highlight,
                                  ),
                                ),
                              ),

                            const SizedBox(height: 10),

                            // Subscribe button
                            RepaintBoundary(
                              child: TweenAnimationBuilder<double>(
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
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 8),
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
                                        Color.lerp(accentColor, Colors.blue,
                                                0.4) ??
                                            accentColor,
                                      ],
                                    ),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _isPurchasing ||
                                            _selectedPackage == null
                                        ? null
                                        : () {
                                            HapticFeedback.mediumImpact();
                                            _purchasePackage(_selectedPackage!);
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      disabledBackgroundColor:
                                          Colors.transparent,
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
                                        : Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                // Show "Start Free Trial" only if trial is available
                                                isTrialAvailable
                                                    ? "Start Free Trial"
                                                    : "Subscribe Now",
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              // Show "Then..." text only if trial is available and not lifetime
                                              if (isTrialAvailable &&
                                                  _selectedPackage
                                                          ?.packageType !=
                                                      PackageType.lifetime)
                                                Text(
                                                  "Then ${_selectedPackage?.storeProduct.priceString}/${_selectedPackage?.packageType == PackageType.annual ? 'year' : 'month'}",
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ),

                            // Restore/Redeem buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Center(
                                    child: TextButton(
                                      onPressed: _isPurchasing
                                          ? null
                                          : () {
                                              HapticFeedback.mediumImpact();
                                              _restorePurchases();
                                            },
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            textColor.withOpacity(0.6),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                      ),
                                      child: const Row(
                                        // Added const
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.restore, size: 14),
                                          SizedBox(width: 6),
                                          Text(
                                            "Restore",
                                            style: TextStyle(fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  height: 16,
                                  width: 1,
                                  color: textColor.withOpacity(0.2),
                                ),
                                Expanded(
                                  child: Center(
                                    child: TextButton(
                                      onPressed: _isPurchasing
                                          ? null
                                          : () async {
                                              if (_isPurchasing)
                                                return; // Prevent double taps
                                              HapticFeedback.mediumImpact();
                                              setState(() {
                                                _isPurchasing = true;
                                              });
                                              try {
                                                await Purchases
                                                    .presentCodeRedemptionSheet();

                                                // After the sheet is dismissed, check if redemption was successful
                                                final customerInfo =
                                                    await Purchases
                                                        .getCustomerInfo();
                                                // Use the entitlement ID defined in SubscriptionService
                                                const String
                                                    premiumEntitlementId =
                                                    'pro';
                                                if (customerInfo
                                                    .entitlements.active
                                                    .containsKey(
                                                        premiumEntitlementId)) {
                                                  // Redemption successful, navigate to dashboard
                                                  Navigator
                                                      .pushNamedAndRemoveUntil(
                                                          context,
                                                          RouteNames.dashboard,
                                                          (Route<dynamic>
                                                                  route) =>
                                                              false);
                                                } else {
                                                  // Optional: Show a message if redemption didn't grant access
                                                  debugPrint(
                                                      "Redemption sheet closed, but no active premium entitlement found.");
                                                }
                                              } catch (e) {
                                                debugPrint(
                                                    "Error presenting code redemption sheet or checking info: $e");
                                                _showError(
                                                    "Could not open the redeem code screen. Please try again later.");
                                              } finally {
                                                if (mounted) {
                                                  setState(() {
                                                    _isPurchasing = false;
                                                  });
                                                }
                                              }
                                            },
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            textColor.withOpacity(0.6),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                      ),
                                      child: const Row(
                                        // Added const
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.card_giftcard, size: 14),
                                          SizedBox(width: 6),
                                          Text(
                                            "Redeem",
                                            style: TextStyle(fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Terms/Privacy links
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    _launchTermsOfService();
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                    minimumSize: const Size(50, 30),
                                    foregroundColor: textColor.withOpacity(0.6),
                                  ),
                                  child: const Text(
                                    "Terms",
                                    style: TextStyle(
                                      fontSize: 12,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                Text(
                                  "•",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textColor.withOpacity(0.4),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    _launchPrivacyPolicy();
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                    minimumSize: const Size(50, 30),
                                    foregroundColor: textColor.withOpacity(0.6),
                                  ),
                                  child: const Text(
                                    "Privacy Policy",
                                    style: TextStyle(
                                      fontSize: 12,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        // Purchase processing overlay
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

  List<Widget> _buildSubscriptionCards(
    Color textColor,
    Color accentColor, {
    required Color goldAccent,
    required Color highlightColor,
  }) {
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

    // Sort packages: annual first, then monthly, then others
    List<Package> sortedPackages = List.from(_offering!.availablePackages);
    sortedPackages.sort((a, b) {
      if (a.packageType == PackageType.annual) return -1;
      if (b.packageType == PackageType.annual) return 1;
      if (a.packageType == PackageType.monthly) return -1;
      if (b.packageType == PackageType.monthly) return 1;
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

      String title;
      String? description;
      String billingInfo;
      String? perMonthPrice;
      bool isBestValue = isAnnual && savingsText != null;
      // Determine if a trial is available for this specific package and user
      final bool isTrialAvailableForPackage =
          package.storeProduct.introductoryPrice != null && !_isReturningUser;

      switch (package.packageType) {
        case PackageType.monthly:
          title = "Monthly";
          description = isTrialAvailableForPackage
              ? "Free Trial Available" // Static text if trial exists
              : "Auto-renewing plan";
          billingInfo = "Billed monthly";
          break;
        case PackageType.annual:
          title = "Annual";
          description = isTrialAvailableForPackage
              ? "Free Trial Available" // Static text if trial exists
              : "Auto-renewing plan";
          billingInfo = "Billed yearly";
          if (package.storeProduct.price > 0) {
            double monthlyEquivalent = package.storeProduct.price / 12;
            perMonthPrice =
                "${package.storeProduct.currencyCode} ${monthlyEquivalent.toStringAsFixed(2)}/mo";
          }
          break;
        case PackageType.lifetime:
          title = "Lifetime";
          description = "One-time payment";
          billingInfo = "No recurring charges";
          break;
        default:
          title = package.packageType.name;
          description = "Premium subscription";
          billingInfo = "";
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
              HapticFeedback.selectionClick();
              setState(() {
                _selectedPackage = package;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? highlightColor
                    : const Color(0xFF1A1E33).withOpacity(0.7),
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
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  if (perMonthPrice != null) ...[
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        perMonthPrice,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.normal,
                                          color: textColor.withOpacity(0.7),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (description != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Show trial badge only if intro price exists AND user is not returning
                                    if (isTrialAvailableForPackage &&
                                        (package.packageType ==
                                                PackageType.monthly ||
                                            package.packageType ==
                                                PackageType.annual))
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color:
                                                accentColor.withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            // Static text for trial badge
                                            "FREE TRIAL",
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: accentColor,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      Flexible(
                                        child: Text(
                                          description, // Show regular description if no trial
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: textColor.withOpacity(0.6),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Price and billing info column
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              price, // Total Billed Amount
                              style: TextStyle(
                                fontSize: 20, // Larger font size
                                fontWeight: FontWeight.bold, // Bolder
                                color: textColor,
                              ),
                            ),
                            Text(
                              billingInfo, // e.g., "Billed yearly"
                              style: TextStyle(
                                fontSize: 12, // Slightly larger for clarity
                                color: textColor.withOpacity(
                                    0.7), // Consistent secondary color
                              ),
                            ),
                          ],
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
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [accentColor, goldAccent.withOpacity(0.8)],
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: goldAccent.withOpacity(0.3),
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
                                fontSize: 10,
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

  Widget _buildFeatureCard(
    Map<String, dynamic> feature,
    CustomColors? customColors,
    Color textColor, {
    required PremiumColors premiumColors,
  }) {
    final accentColor = premiumColors.accent;
    final hasAnimation = feature['animation'] != null;
    final highlight = feature['highlight'] ?? '';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 65, // Even smaller
          height: 65, // Even smaller
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
                  size: 28, // Slightly smaller
                ),
        ),
        const SizedBox(height: 12), // Reduced
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              if (highlight.isNotEmpty)
                TextSpan(
                  text: highlight,
                  style: TextStyle(
                    fontSize: 16, // Smaller
                    fontWeight: FontWeight.bold,
                    color: premiumColors.gold,
                  ),
                ),
              TextSpan(
                text: feature['title'].replaceAll(highlight, ''),
                style: TextStyle(
                  fontSize: 16, // Smaller
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4), // Reduced
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20), // Reduced padding
          child: Text(
            feature['description'],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11, // Even smaller
              color: textColor.withOpacity(0.7),
              height: 1.2, // Reduced line height
            ),
          ),
        ),
      ],
    );
  }

  String _calculateTrialEndDate() {
    final DateTime now = DateTime.now();
    final DateTime trialEndDate = now.add(const Duration(days: 14));
    return "${trialEndDate.month}/${trialEndDate.day}/${trialEndDate.year}";
  }
}

// Premium colors class to hold all the special paywall colors
class PremiumColors {
  final Color accent;
  final Color accentSecondary;
  final Color textColor;
  final Color gold;
  final Color highlight;

  PremiumColors({
    required this.accent,
    required this.accentSecondary,
    required this.textColor,
    required this.gold,
    required this.highlight,
  });
}

class NutritionBackgroundPainter extends CustomPainter {
  final bool isDark;
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;
  final Color goldColor;

  NutritionBackgroundPainter({
    required this.isDark,
    required this.progress,
    required this.primaryColor,
    this.secondaryColor = Colors.blue,
    this.goldColor = Colors.amber,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Create a more sophisticated gradient background
    final gradientRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        primaryColor.withOpacity(0.03),
        secondaryColor.withOpacity(0.04),
        goldColor.withOpacity(0.02),
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
      ..color = primaryColor.withOpacity(0.03)
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
    // final spacing = size.width * 0.15; // spacing not used

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
      ..color = primaryColor.withOpacity(0.02)
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
