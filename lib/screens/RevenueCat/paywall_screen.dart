import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:macrotracker/theme/app_theme.dart'; // Import theme

class PaywallScreen extends StatefulWidget {
  final VoidCallback onDismiss;
  final bool allowDismissal;

  const PaywallScreen({
    Key? key,
    required this.onDismiss,
    this.allowDismissal = true,
  }) : super(key: key);

  @override
  _PaywallScreenState createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> with WidgetsBindingObserver {
  Offering? _offering;
  bool _isLoading = true;
  bool _isPaywallMounted = false;
  bool _shouldShowPaywall = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchOffering();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes
    if (state == AppLifecycleState.resumed) {
      // App has come to the foreground
      if (!_shouldShowPaywall && _isPaywallMounted) {
        // If paywall was previously shown but shouldn't be now, force refresh
        _fetchOffering();
      }
    }
  }

  Future<void> _fetchOffering() async {
    try {
      setState(() {
        _isLoading = true;
        _shouldShowPaywall = false;
        _isPaywallMounted = false;
      });
      
      final offerings = await Purchases.getOfferings();
      print("RevenueCat offerings: ${offerings.all}");

      if (!mounted) return;

      if (offerings.current != null) {
        print("Current offering: ${offerings.current!.identifier}");
        print(
            "Available packages: ${offerings.current!.availablePackages.length}");

        setState(() {
          _offering = offerings.current;
          _isLoading = false;
          _shouldShowPaywall = true;
        });
      } else {
        print("No current offering available");
        setState(() {
          _offering = null;
          _isLoading = false;
          _shouldShowPaywall = false;
        });
      }
    } catch (e) {
      print("Error fetching offerings: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _shouldShowPaywall = false;
        });
      }
    }
  }

  // Helper to check if user has Pro access, regardless of entitlement naming
  bool _hasProAccess(CustomerInfo customerInfo) {
    // Check for different possible entitlement identifiers
    final entitlements = customerInfo.entitlements.active.keys;
    print("Checking entitlements: $entitlements");
    
    // Check for any entitlement containing 'pro' in a case-insensitive way
    return entitlements.any((key) => 
      key.toLowerCase() == 'pro' || 
      key == 'Pro' || 
      key.toLowerCase().contains('pro')
    );
  }
  
  // Handle successful purchase
  void _handlePurchaseSuccess(CustomerInfo customerInfo) {
    print("Purchase success detected - dismissing paywall safely");
    
    // Set flag to not show paywall anymore
    setState(() {
      _shouldShowPaywall = false;
      _isPaywallMounted = false;
    });
    
    // Delay the dismissal slightly to ensure view is properly cleaned up
    Future.delayed(Duration(milliseconds: 300), () {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.allowDismissal ? IconButton(
          icon: Icon(Icons.close, color: customColors?.textPrimary),
          onPressed: widget.onDismiss,
        ) : null,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _offering != null && _shouldShowPaywall
              ? Builder(
                  builder: (context) {
                    // Mark that we're about to mount the paywall
                    _isPaywallMounted = true;
                    
                    return PaywallView(
                      offering: _offering,
                      onRestoreCompleted: (CustomerInfo customerInfo) {
                        // Check if user has access to pro features
                        if (_hasProAccess(customerInfo)) {
                          print("Restore completed with pro access");
                          _handlePurchaseSuccess(customerInfo);
                        }
                      },
                      onPurchaseCompleted: (CustomerInfo customerInfo, StoreTransaction transaction) {
                        // This callback is triggered when a purchase is completed successfully
                        print("Purchase completed: ${transaction.productIdentifier}");
                        print("Active entitlements: ${customerInfo.entitlements.active.keys}");
                        
                        if (_hasProAccess(customerInfo)) {
                          print("Pro entitlement active after purchase");
                          _handlePurchaseSuccess(customerInfo);
                        } else {
                          print("WARNING: Purchase completed but no Pro entitlement detected!");
                          // Dismiss anyway since the purchase was confirmed
                          _handlePurchaseSuccess(customerInfo);
                        }
                      },
                      onDismiss: widget.allowDismissal ? () {
                        // Mark paywall as unmounted first
                        setState(() {
                          _isPaywallMounted = false;
                        });
                        
                        // Then dismiss
                        widget.onDismiss();
                      } : null,
                      displayCloseButton: widget.allowDismissal,
                    );
                  }
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
                        onPressed: _fetchOffering,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text("Try Again"),
                      ),
                      SizedBox(height: 16),
                      if (widget.allowDismissal)
                        TextButton(
                          onPressed: widget.onDismiss,
                          child: Text(
                            "Continue Without Premium",
                            style: TextStyle(
                              color: customColors?.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
