import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:macrotracker/screens/StepsTrackingScreen.dart';
import '../theme/app_theme.dart';
import 'WeightTrackingScreen.dart';
import 'MacroTrackingScreen.dart';
import 'WorkoutTrackingScreen.dart';
import '../services/posthog_service.dart';

/// Progress: weight, calories, steps and workouts, switched with tabs at the
/// top (or by swiping).
class TrackingPagesScreen extends StatefulWidget {
  const TrackingPagesScreen({super.key, this.embedded = false, this.initialPage = 0});

  /// Shown as a tab of the app shell: no back button.
  final bool embedded;
  final int initialPage;

  @override
  State<TrackingPagesScreen> createState() => _TrackingPagesScreenState();
}

class _TrackingPagesScreenState extends State<TrackingPagesScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = ['Weight', 'Calories', 'Steps', 'Workouts'];

  late final TabController _tabController = TabController(
    length: _tabs.length,
    vsync: this,
    initialIndex: widget.initialPage.clamp(0, _tabs.length - 1),
  );

  @override
  void initState() {
    super.initState();
    PostHogService.trackScreen('tracking_pages_screen');
    // Rebuild for the Weight-only unit toggle in the app bar.
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) setState(() {});
    });
  }

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
          if (_tabController.index == 0)
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
        children: const [
          KeepAlivePage(child: WeightTrackingScreen(hideAppBar: true)),
          KeepAlivePage(child: MacroTrackingScreen(hideAppBar: true)),
          KeepAlivePage(child: StepTrackingScreen(hideAppBar: true)),
          KeepAlivePage(child: WorkoutTrackingScreen(hideAppBar: true)),
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
