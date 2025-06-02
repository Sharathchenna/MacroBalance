import 'dart:ui'; // Added for ImageFilter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:macrotracker/screens/steps_tracking_screen.dart';
import '../theme/app_theme.dart';
import 'weight_tracking_screen.dart';
import 'macro_tracking_screen.dart';

class TrackingPagesScreen extends StatefulWidget {
  const TrackingPagesScreen({super.key});

  @override
  State<TrackingPagesScreen> createState() => _TrackingPagesScreenState();
}

class _TrackingPagesScreenState extends State<TrackingPagesScreen>
    with AutomaticKeepAliveClientMixin {
  late PageController _pageController;
  int _currentPage = 0;
  final List<String> _titles = ['Weight', 'Calories', 'Steps'];

  @override
  bool get wantKeepAlive => true; // Keep the state alive

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage);
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
          if (_currentPage == 0) // Weight screen unit toggle
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Consumer<WeightUnitProvider>(
                builder: (context, unitProvider, _) => TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    unitProvider.toggleUnit();
                  },
                  icon: Icon(
                    Icons.scale,
                    color: customColors.textPrimary,
                    size: 20,
                  ),
                  label: Text(
                    unitProvider.unitLabel,
                    style: TextStyle(
                      color: customColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          // Navigation hint icon in app bar
          // Padding(
          //   padding: const EdgeInsets.only(right: 16),
          //   child: Icon(
          //     Icons.swipe,
          //     size: 20,
          //     color: customColors.textSecondary.withAlpha((0.6 * 255).round()),
          //   ),
          // ),
        ],
      ),
      // Removed bottomNavigationBar, using Stack for floating effect
      body: Stack(
        // Parent Stack for PageView and Floating Nav
        children: [
          // Main Content Area (PageView) with bottom padding
          // Add padding ONLY to the PageView container to prevent overlap with floating bar
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: const [
              KeepAlivePage(child: WeightTrackingScreen(hideAppBar: true)),
              KeepAlivePage(child: MacroTrackingScreen(hideAppBar: true)),
              KeepAlivePage(child: StepTrackingScreen(hideAppBar: true)),
            ],
          ),

          // Subtle edge indicators for swipe navigation (keep these)
          // if (_currentPage < _titles.length - 1)
          //   _buildEdgeGradient(customColors, false),

          // if (_currentPage > 0) _buildEdgeGradient(customColors, true),

          // Initial swipe hint - more elegant and minimal (keep this)
          // if (_showSwipeHint) _buildSwipeHint(customColors, size),

          // Positioned Floating Navigation Bar
          Positioned(
            // Use similar positioning as Dashboard
            bottom: size.height * 0.04, // Adjust as needed
            left: size.width * 0.18, // Adjust as needed
            right: size.width * 0.18, // Adjust as needed
            child: _buildPageIndicator(
                theme, customColors), // This now builds the floating bar
          ),
        ],
      ),
    );
  }

  // --- Helper Methods (Defined ONCE) ---

  // This function builds the floating bar content
  Widget _buildPageIndicator(ThemeData theme, CustomColors customColors) {
    final List<IconData> icons = [
      Icons.monitor_weight_outlined, // Weight
      Icons.pie_chart_outline_rounded, // Macros
      Icons.directions_walk, // Steps
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(14.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          height: 45,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.0),
            color: theme.brightness == Brightness.light
                ? Colors.grey.shade50.withAlpha((0.4 * 255).round())
                : Colors.black.withAlpha((0.4 * 255).round()),
            border: Border.all(
              color: theme.brightness == Brightness.light
                  ? Colors.grey.withAlpha((0.2 * 255).round())
                  : Colors.white.withAlpha((0.1 * 255).round()),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.brightness == Brightness.light
                    ? Colors.black.withAlpha((0.05 * 255).round())
                    : Colors.black.withAlpha((0.2 * 255).round()),
                blurRadius: 10,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_titles.length, (index) {
              return _buildTrackingNavItem(
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
    );
  }

  // Helper function for individual nav items
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
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFFFC107).withAlpha((0.2 * 255).round())
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: const Color(0xFFFFC107),
            size: 24,
          ),
        ),
      ),
    );
  }
}

// --- KeepAlivePage Class (Defined ONCE) ---
class KeepAlivePage extends StatefulWidget {
  final Widget child;

  const KeepAlivePage({
    super.key,
    required this.child,
  });

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
