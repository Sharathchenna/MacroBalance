import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/camera_service.dart';
import '../services/posthog_service.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/quick_add_sheet.dart';
import 'TrackingPagesScreen.dart';
import 'accountdashboard.dart';
import 'dashboard_screen.dart';

export '../widgets/app_bottom_bar.dart' show AppTab;

/// The signed-in app: Home, Progress and Profile behind one bottom bar.
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

class AppShellState extends State<AppShell> {
  late AppTab _tab = widget.initialTab;
  late final Set<AppTab> _opened = {widget.initialTab};

  AppTab get currentTab => _tab;

  void select(AppTab tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _opened.add(tab);
    });
    PostHogService.trackScreen('tab_${tab.name}');
  }

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

  Future<void> _openCamera() async {
    try {
      // Results come back to the Home tab's camera listener.
      await CameraService().showNativeCamera();
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t open the camera: ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).size.height * 0.04;
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _tab.index,
            children: [for (final tab in AppTab.values) _buildTab(tab)],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottom,
            child: Center(
              child: AppBottomBar(
                current: _tab,
                onSelect: select,
                // Logging food belongs on Home; the other tabs stay uncluttered.
                onAdd: _tab == AppTab.home
                    ? () => showQuickAddSheet(context, onScan: _openCamera)
                    : null,
                onAddLongPress: _tab == AppTab.home ? _openCamera : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
