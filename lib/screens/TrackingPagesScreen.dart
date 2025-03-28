import 'dart:ui'; // Added for ImageFilter
import 'package:flutter/cupertino.dart'; // Added for potential icons if needed
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrotracker/screens/StepsTrackingScreen.dart';
import '../theme/app_theme.dart';
import 'WeightTrackingScreen.dart';
import 'MacroTrackingScreen.dart';
import 'StepsTrackingScreen.dart';

class TrackingPagesScreen extends StatefulWidget {
  const TrackingPagesScreen({Key? key}) : super(key: key);

  @override
  State<TrackingPagesScreen> createState() => _TrackingPagesScreenState();
}

class _TrackingPagesScreenState extends State<TrackingPagesScreen>
    with AutomaticKeepAliveClientMixin {
  late PageController _pageController;
  int _currentPage = 0;
  final List<String> _titles = ['Steps', 'Weight', 'Macros'];
  bool _showSwipeHint = true;
  bool _isInitialLoad = true;

  @override
  bool get wantKeepAlive => true; // Keep the state alive

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage);
    
    // Show swipe hint after a short delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _isInitialLoad) {
        setState(() {
          _isInitialLoad = false;
          _showSwipeHint = true;
        });
        
        // Hide the hint after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showSwipeHint = false;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>()!;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          _titles[_currentPage],
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
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
          if (_currentPage == 1) // Weight screen unit toggle
            TextButton.icon(
              onPressed: () {
                // We'll need to implement this by lifting the state up
                // or using a state management solution
              },
              icon: Icon(
                Icons.scale,
                color: customColors.textPrimary,
                size: 20,
              ),
              label: Text(
                'kg',
                style: TextStyle(
                  color: customColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          // Navigation hint icon in app bar
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              Icons.swipe,
              size: 20,
              color: customColors.textSecondary.withOpacity(0.6),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
                _showSwipeHint = false; // Hide hint when user swipes
              });
            },
            children: [
              KeepAlivePage(child: StepTrackingScreen(hideAppBar: true)),
              KeepAlivePage(child: WeightTrackingScreen(hideAppBar: true)),
              KeepAlivePage(child: MacroTrackingScreen(hideAppBar: true)),
            ],
          ),
          
          // Subtle edge indicators for swipe navigation
          if (_currentPage < _titles.length - 1)
            _buildEdgeGradient(customColors, false),
          
          if (_currentPage > 0)
            _buildEdgeGradient(customColors, true),
            
          // Initial swipe hint - more elegant and minimal
          if (_showSwipeHint)
            _buildSwipeHint(customColors, size),
        ],
      ),
      bottomNavigationBar: _buildPageIndicator(theme, customColors),
    );
  }
  
  Widget _buildEdgeGradient(CustomColors customColors, bool isLeft) {
    return Positioned(
      top: 0,
      bottom: 0,
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      child: Container(
        width: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isLeft ? Alignment.centerRight : Alignment.centerLeft,
            end: isLeft ? Alignment.centerLeft : Alignment.centerRight,
            colors: [
              Colors.transparent,
              customColors.cardBackground.withOpacity(0.02),
              customColors.cardBackground.withOpacity(0.05),
            ],
          ),
        ),
        child: Center(
          child: Container(
            height: 50,
            width: 24,
            decoration: BoxDecoration(
              color: customColors.cardBackground.withOpacity(0.5),
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(isLeft ? 0 : 4),
                right: Radius.circular(isLeft ? 4 : 0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                isLeft ? Icons.chevron_left : Icons.chevron_right,
                size: 18,
                color: customColors.accentPrimary.withOpacity(0.7),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSwipeHint(CustomColors customColors, Size size) {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: customColors.cardBackground,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: customColors.accentPrimary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.swipe,
                          size: 18,
                          color: customColors.accentPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Swipe between tracking pages',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: customColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: customColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Replaces the old _buildPageIndicator
  Widget _buildPageIndicator(ThemeData theme, CustomColors customColors) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Define icons for each page
    final List<IconData> icons = [
      Icons.directions_walk, // Steps
      Icons.monitor_weight_outlined, // Weight
      Icons.pie_chart_outline_rounded, // Macros
    ];

    return Padding(
      // Add padding to mimic floating effect, adjust as needed
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 10, // Respect safe area + extra space
        left: screenWidth * 0.18, // Match dashboard horizontal padding
        right: screenWidth * 0.18,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.0), // Match dashboard radius
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0), // Frosted glass
          child: Container(
            height: 45, // Match dashboard height
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2), // Match dashboard padding
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.0),
              color: theme.brightness == Brightness.light
                  ? Colors.grey.shade50.withOpacity(0.4) // Match dashboard color
                  : Colors.black.withOpacity(0.4), // Match dashboard color
              border: Border.all( // Match dashboard border
                color: theme.brightness == Brightness.light
                    ? Colors.grey.withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
                width: 0.5,
              ),
              boxShadow: [ // Match dashboard shadow
                BoxShadow(
                  color: theme.brightness == Brightness.light
                      ? Colors.black.withOpacity(0.05)
                      : Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_titles.length, (index) {
                return _buildTrackingNavItem( // Use the new helper function
                  context: context,
                  icon: icons[index],
                  isActive: _currentPage == index,
                  onTap: () {
                    if (_currentPage != index) {
                      HapticFeedback.lightImpact();
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  // New helper function similar to _buildNavItemCompact from Dashboard
  Widget _buildTrackingNavItem({
    required BuildContext context,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(6), // Match dashboard padding
          decoration: BoxDecoration(
            // Use accent color with opacity for active state background
            color: isActive
                ? const Color(0xFFFFC107).withOpacity(0.2) // Match dashboard active bg
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            // Use the same accent color for the icon itself
            color: const Color(0xFFFFC107), // Match dashboard icon color
            size: 24, // Match dashboard icon size
          ),
        ),
      ),
    );
  }
}

class KeepAlivePage extends StatefulWidget {
  final Widget child;

  const KeepAlivePage({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
