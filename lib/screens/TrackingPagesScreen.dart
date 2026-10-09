import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:macrotracker/screens/StepsTrackingScreen.dart';
import '../theme/app_theme.dart';
import 'energy/energy_tab.dart';
import 'WeightTrackingScreen.dart';
import 'NutritionTrendsScreen.dart';
import 'WorkoutTrackingScreen.dart';
import '../services/posthog_service.dart';

/// Progress: weight, nutrition, steps, workouts and energy, switched with
/// tabs at the top (or by swiping). Weight opens first: it's where most
/// people look; Energy (the calories you burn) is last, for the curious.
class TrackingPagesScreen extends StatefulWidget {
  const TrackingPagesScreen(
      {super.key, this.embedded = false, this.initialPage = weightTab});

  // Tab indexes, for [initialPage].
  static const weightTab = 0;
  static const nutritionTab = 1;
  static const stepsTab = 2;
  static const workoutsTab = 3;
  static const energyTab = 4;

  /// Shown as a tab of the app shell: no back button.
  final bool embedded;
  final int initialPage;

  @override
  State<TrackingPagesScreen> createState() => _TrackingPagesScreenState();
}

class _TrackingPagesScreenState extends State<TrackingPagesScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = ['Weight', 'Nutrition', 'Steps', 'Workouts', 'Energy'];

  late final TabController _tabController = TabController(
    length: _tabs.length,
    vsync: this,
    initialIndex: widget.initialPage.clamp(0, _tabs.length - 1),
  );

  @override
  void initState() {
    super.initState();
    PostHogService.trackScreen('tracking_pages_screen');
    _shown = _tabController.index;
    if (_shown == TrackingPagesScreen.energyTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) EnergyTab.trackViewed(context);
      });
    }
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || !mounted) return;
      if (_tabController.index != _shown) {
        _shown = _tabController.index;
        if (_shown == TrackingPagesScreen.energyTab) {
          EnergyTab.trackViewed(context);
        }
      }
      // Rebuild for the Weight-only unit toggle in the app bar.
      setState(() {});
    });
  }

  /// The tab last settled on, so each visit to Energy is counted once.
  late int _shown;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>()!;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        centerTitle: false,
        title: Text(
          'Progress',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: customColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: theme.brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: customColors.textPrimary),
        actions: [
          if (_tabController.index == TrackingPagesScreen.weightTab)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Consumer<WeightUnitProvider>(
                builder: (context, unitProvider, _) => TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    unitProvider.toggleUnit();
                  },
                  icon: Icon(Icons.scale, color: customColors.textPrimary, size: 20),
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
        ],
        bottom: TabBar(
          controller: _tabController,
          // Sized to their labels from the left edge, so "Workouts" isn't
          // clipped on narrower phones or with larger text.
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          labelPadding: const EdgeInsets.symmetric(horizontal: 12),
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.label,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(width: 2.5, color: customColors.accentPrimary),
            borderRadius: BorderRadius.circular(2),
          ),
          labelColor: customColors.textPrimary,
          unselectedLabelColor: customColors.textSecondary,
          labelStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          onTap: (_) => HapticFeedback.selectionClick(),
          tabs: [for (final t in _tabs) Tab(text: t, height: 40)],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        // In the order of [_tabs] and the index constants.
        children: [
          const KeepAlivePage(child: WeightTrackingScreen(hideAppBar: true)),
          const KeepAlivePage(child: NutritionTrendsScreen(hideAppBar: true)),
          const KeepAlivePage(child: StepTrackingScreen(hideAppBar: true)),
          const KeepAlivePage(child: WorkoutTrackingScreen(hideAppBar: true)),
          KeepAlivePage(
            child: EnergyTab(
              onLogWeight: () =>
                  _tabController.animateTo(TrackingPagesScreen.weightTab),
            ),
          ),
        ],
      ),
    );
  }
}

/// Keeps a tab's state while another tab is showing.
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
