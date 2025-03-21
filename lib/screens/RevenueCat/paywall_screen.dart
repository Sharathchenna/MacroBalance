import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:macrotracker/theme/app_theme.dart'; // Import theme

class PaywallScreen extends StatefulWidget {
  final VoidCallback onDismiss;

  const PaywallScreen({
    Key? key,
    required this.onDismiss,
  }) : super(key: key);

  @override
  _PaywallScreenState createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Offering? _offering;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOffering();
  }

  Future<void> _fetchOffering() async {
    try {
      final offerings = await Purchases.getOfferings();
      print("RevenueCat offerings: ${offerings.all}");

      if (offerings.current != null) {
        print("Current offering: ${offerings.current!.identifier}");
        print(
            "Available packages: ${offerings.current!.availablePackages.length}");

        setState(() {
          _offering = offerings.current;
          _isLoading = false;
        });
      } else {
        print("No current offering available");
        setState(() {
          _isLoading = false;
          // Set offering to null but handle in the UI
        });
      }
    } catch (e) {
      print("Error fetching offerings: $e");
      setState(() {
        _isLoading = false;
        // Instead of immediately dismissing, show error UI
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: customColors?.textPrimary),
          onPressed: widget.onDismiss,
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _offering != null
              ? PaywallView(
                  offering: _offering,
                  onRestoreCompleted: (CustomerInfo customerInfo) {
                    // Check if user has access to pro features
                    if (customerInfo.entitlements.active.containsKey("pro")) {
                      widget.onDismiss();
                    }
                  },
                  onDismiss: widget.onDismiss,
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Upgrade to Premium",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: customColors?.textPrimary,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Something went wrong. Please try again later.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: customColors?.textSecondary,
                        ),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: widget.onDismiss,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: customColors?.textPrimary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text("Continue"),
                      ),
                    ],
                  ),
                ),
    );
  }
}
