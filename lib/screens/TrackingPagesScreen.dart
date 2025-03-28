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

  Widget _buildPageIndicator(ThemeData theme, CustomColors customColors) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Page title indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < _titles.length; i++)
                GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: EdgeInsets.symmetric(
                      horizontal: i == _currentPage ? 16 : 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: i == _currentPage
                          ? customColors.accentPrimary
                          : customColors.dateNavigatorBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _titles[i],
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: i == _currentPage ? FontWeight.w600 : FontWeight.w500,
                        color: i == _currentPage
                            ? Colors.white
                            : customColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
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
