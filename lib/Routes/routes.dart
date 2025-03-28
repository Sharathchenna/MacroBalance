import 'package:flutter/material.dart';
import 'package:macrotracker/screens/Dashboard.dart';
import 'package:macrotracker/screens/StepsTrackingScreen.dart';
import 'package:macrotracker/screens/WeightTrackingScreen.dart';
import 'package:macrotracker/screens/MacroTrackingScreen.dart';
import 'package:macrotracker/screens/accountdashboard.dart';
import 'package:macrotracker/screens/searchPage.dart';
import 'package:macrotracker/camera/camera.dart';
import 'route_constants.dart';

class Routes {
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String initial = '/';
  static const String authGate = '/auth';
  static const String dashboard = '/dashboard';
  static const String goals = '/goals';
  static const String search = '/search';
  static const String account = '/account';
  static const String weightTracking = '/weightTracking';
  static const String macroTracking = '/macroTracking';
}

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.dashboard:
        return MaterialPageRoute(builder: (_) => const Dashboard());
      case RouteNames.stepTracking:
        return MaterialPageRoute(builder: (_) => const StepTrackingScreen());
      case RouteNames.weightTracking:
        return MaterialPageRoute(builder: (_) => const WeightTrackingScreen());
      case RouteNames.macroTracking:
        return MaterialPageRoute(builder: (_) => const MacroTrackingScreen());
      case RouteNames.settings:
        return MaterialPageRoute(builder: (_) => const AccountDashboard());
      case RouteNames.search:
        return MaterialPageRoute(builder: (_) => const FoodSearchPage());
      case RouteNames.camera:
        return MaterialPageRoute(builder: (_) => const CameraScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}