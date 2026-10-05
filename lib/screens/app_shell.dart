import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/camera_service.dart';
import '../services/posthog_service.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/log_food_menu.dart';
import 'TrackingPagesScreen.dart';
import 'accountdashboard.dart';
import 'askAI.dart';
import 'dashboard_screen.dart';
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

class AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  late AppTab _tab = widget.initialTab;
  late final Set<AppTab> _opened = {widget.initialTab};

  late final AnimationController _menu = AnimationController(
    vsync: this,
    // Unhurried in, brisk out; curves are applied by the menu and the +.
    duration: const Duration(milliseconds: 460),
    reverseDuration: const Duration(milliseconds: 260),
  )..addStatusListener((_) => setState(() {}));

  AppTab get currentTab => _tab;
  bool get menuOpen => _menu.status != AnimationStatus.dismissed;

  @override
  void dispose() {
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
      PostHogService.trackEvent('log_food_menu_opened', properties: {'tab': _tab.name});
      _menu.forward();
    }
  }

  void _closeMenu() {
    if (_menu.isForwardOrCompleted) _menu.reverse();
  }

  /// Closes the menu, then runs [action] once it has animated away.
  Future<void> _thenClose(VoidCallback action) async {
    await _menu.reverse();
    if (mounted) action();
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
      canPop: !menuOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeMenu();
      },
      child: Scaffold(
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
                  onSearch: () => _thenClose(() => _push(() => const FoodSearchPage())),
                  onDescribe: () => _thenClose(() => _push(() => const Askai())),
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
          ],
        ),
      ),
    );
  }
}
