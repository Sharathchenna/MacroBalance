import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/dateProvider.dart';
import '../providers/energy_provider.dart';
import '../services/finish_day_link.dart';
import '../services/camera_service.dart';
import '../services/posthog_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/app_bottom_bar.dart';
import '../widgets/home_tour.dart';
import '../widgets/log_food_menu.dart';
import 'TrackingPagesScreen.dart';
import 'accountdashboard.dart';
import 'askAI.dart';
import 'dashboard_screen.dart';
import 'energy/checkin_sheet.dart';
import 'searchPage.dart';

export '../widgets/app_bottom_bar.dart' show AppTab;

/// The signed-in app: Home, Progress and Profile behind one bottom bar, with
/// the log-food button beside it on every tab.
///
/// Tabs live in an IndexedStack so each keeps its scroll position and state.
/// A tab is only built the first time it's opened, so Progress (which asks
/// for Health access) doesn't start work at launch. Screens pushed on top
/// (food detail, search, ...) cover the bar as before.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialTab = AppTab.home});

  final AppTab initialTab;

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  late AppTab _tab = widget.initialTab;
  late final Set<AppTab> _opened = {widget.initialTab};

  late final AnimationController _menu = AnimationController(
    vsync: this,
    // Unhurried in, brisk out; curves are applied by the menu and the +.
    duration: const Duration(milliseconds: 520),
    reverseDuration: const Duration(milliseconds: 260),
  )..addStatusListener((_) => setState(() {}));

  AppTab get currentTab => _tab;
  bool get menuOpen => _menu.status != AnimationStatus.dismissed;

  // First-run tour. Keys are per shell so two shells never share one.
  final Map<TourTarget, GlobalKey> _tourKeys = {
    for (final t in TourTarget.values)
      t: GlobalKey(debugLabel: 'tour_${t.name}'),
  };
  bool _touring = false;
  bool get touring => _touring;

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  // The weekly check-in sheet shows on its own once a check-in has run.
  EnergyProvider? _energy;
  bool _showingCheckin = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final energy = Provider.of<EnergyProvider>(context);
    if (!identical(energy, _energy)) {
      _energy?.removeListener(_maybeShowCheckin);
      _energy = energy..addListener(_maybeShowCheckin);
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowCheckin());
    }
  }

  /// Shows this week's check-in sheet while it hasn't been dismissed, once
  /// nothing else (the tour, the log menu, a pushed screen) is in the way.
  void _maybeShowCheckin() {
    final checkin = _energy?.checkinToShow;
    if (checkin == null || _showingCheckin || !mounted) return;
    if (_touring || menuOpen || HomeTour.shouldShow(_userId)) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    _showingCheckin = true;
    showCheckinSheet(context, checkin)
        .whenComplete(() => _showingCheckin = false);
  }

  /// The finish-day reminder was tapped: Home, on today, scrolled to the
  /// Finish day row.
  void _openFinishDay() {
    if (!mounted || !FinishDayLink.take()) return;
    if (ModalRoute.of(context)?.isCurrent == false) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
    select(AppTab.home);
    final dates = Provider.of<DateProvider>(context, listen: false);
    dates.setDate(dates.today);
    // Home may have just been built, so wait for it to lay out.
    void scroll(int tries) {
      final target = FinishDayLink.rowKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target,
            alignment: 0.5, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      } else if (tries > 0 && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => scroll(tries - 1));
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => scroll(10));
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void initState() {
    super.initState();
    FinishDayLink.requests.addListener(_openFinishDay);
    // Opened from a tap on the reminder while the app was closed.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFinishDay());
    // Whenever a signed-in account reaches Home without having seen the tour
    // (after onboarding, subscribing, starting a trial, or on a new device),
    // show it once the screen has settled.
    if (widget.initialTab == AppTab.home && HomeTour.shouldShow(_userId)) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted &&
            _tab == AppTab.home &&
            !menuOpen &&
            HomeTour.shouldShow(_userId)) {
          startTour();
        }
      });
    }
  }

  /// Shows the tour from the start, on Home. Also used by Profile's
  /// "Show app tour".
  void startTour() {
    _closeMenu();
    select(AppTab.home);
    // Let Home lay out (it may have just been built) before measuring.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _touring = true);
      PostHogService.trackEvent('home_tour_started');
    });
    // Already on Home, nothing else asks for a frame, so request one or the
    // callback above would wait until the next touch.
    WidgetsBinding.instance.scheduleFrame();
  }

  void _endTour(bool completed) {
    setState(() => _touring = false);
    HomeTour.markSeen(_userId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowCheckin());
    PostHogService.trackEvent(
        completed ? 'home_tour_completed' : 'home_tour_skipped');
  }

  @override
  void dispose() {
    FinishDayLink.requests.removeListener(_openFinishDay);
    _energy?.removeListener(_maybeShowCheckin);
    _menu.dispose();
    super.dispose();
  }

  void select(AppTab tab) {
    _closeMenu();
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _opened.add(tab);
    });
    PostHogService.trackScreen('tab_${tab.name}');
  }

  void _toggleMenu() {
    if (_menu.isForwardOrCompleted) {
      _menu.reverse();
    } else {
      PostHogService.trackEvent('log_food_menu_opened',
          properties: {'tab': _tab.name});
      _menu.forward();
    }
  }

  void _closeMenu() {
    if (_menu.isForwardOrCompleted) _menu.reverse();
  }

  /// Starts closing the menu and runs [action] in the same frame, so the
  /// next screen slides in while the menu fades out underneath it. Taps that
  /// land while the menu is already closing are ignored (no double pushes).
  void _thenClose(VoidCallback action) {
    if (_menu.status == AnimationStatus.reverse) return;
    _menu.reverse();
    action();
  }

  Future<void> _openCamera() async {
    // Results arrive on Home (photo progress card, barcode results), so go
    // there first; this also builds Home if it hasn't been opened yet.
    select(AppTab.home);
    try {
      await CameraService().showNativeCamera();
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t open the camera: ${e.message}')),
      );
    }
  }

  void _push(Widget Function() screen) =>
      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => screen()));

  Widget _buildTab(AppTab tab) {
    if (!_opened.contains(tab)) return const SizedBox.shrink();
    switch (tab) {
      case AppTab.home:
        return const Dashboard();
      case AppTab.progress:
        return const TrackingPagesScreen(embedded: true);
      case AppTab.profile:
        return const AccountDashboard(showBackButton: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final barBottom = MediaQuery.of(context).size.height * 0.04;
    return PopScope(
      // Back (Android, or a swipe gesture) closes the menu first.
      canPop: !menuOpen && !_touring,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_touring) {
          _endTour(false);
        } else {
          _closeMenu();
        }
      },
      child: TourTargets(
        keys: _tourKeys,
        child: Scaffold(
          // The bar stays put under the keyboard instead of riding up behind
          // dialogs; each tab's own Scaffold makes room for the keyboard.
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              IndexedStack(
                index: _tab.index,
                children: [for (final tab in AppTab.values) _buildTab(tab)],
              ),
              if (menuOpen)
                Positioned.fill(
                  child: LogFoodMenu(
                    animation: _menu,
                    bottomOffset: barBottom + AppBottomBar.height,
                    onClose: _closeMenu,
                    onScan: () => _thenClose(_openCamera),
                    onSaved: () => _thenClose(
                        () => Navigator.of(context).pushNamed('/savedFoods')),
                    onSearch: () =>
                        _thenClose(() => _push(() => const FoodSearchPage())),
                    onDescribe: () =>
                        _thenClose(() => _push(() => const Askai())),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: barBottom,
                child: Center(
                  child: AppBottomBar(
                    current: _tab,
                    onSelect: select,
                    onAdd: _toggleMenu,
                    onAddLongPress: _openCamera,
                    menuAnimation: _menu,
                  ),
                ),
              ),
              if (_touring)
                Positioned.fill(
                  child: HomeTourOverlay(
                    keys: _tourKeys,
                    bottomInset: barBottom + AppBottomBar.height,
                    onFinish: _endTour,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
