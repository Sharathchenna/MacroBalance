import '../screens/TrackingPagesScreen.dart';

class AppRoutes {
  static const String tracking = '/tracking';

  static final routes = {
    tracking: (context) => const TrackingPagesScreen(),
  };
}