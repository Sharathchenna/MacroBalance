import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrotracker/screens/welcomescreen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/providers/themeProvider.dart';
import 'package:macrotracker/providers/subscription_provider.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({Key? key}) : super(key: key);

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _passwordVisible = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not found');
      }

      // 1. Delete user data from all tables
      await _deleteUserData(currentUser.id);

      // 2. For email/password users, verify password before proceeding
      final bool isOAuthUser =
          currentUser.appMetadata.containsKey('provider') &&
              currentUser.appMetadata['provider'] != 'email';

      if (!isOAuthUser && _passwordController.text.isNotEmpty) {
        // Email/password user - verify password
        final String? email = currentUser.email;
        try {
          final AuthResponse response = await _supabase.auth.signInWithPassword(
            email: email!,
            password: _passwordController.text,
          );

          if (response.user == null) {
            throw Exception('Incorrect password');
          }
        } catch (e) {
          throw Exception('Password verification failed: ${e.toString()}');
        }
      }

      // 3. Call the Edge Function to delete the user account with proper authorization
      try {
        // Get the user's session for the Authorization header
        final Session? session = _supabase.auth.currentSession;
        if (session == null) {
          throw Exception('User session not found');
        }

        // Debug logging
        debugPrint(
            'Attempting to call Edge Function with user ID: ${currentUser.id}');
        debugPrint('Access token available: ${session.accessToken.isNotEmpty}');

        final response = await _supabase.functions.invoke(
          'delete-user',
          body: {'user_id': currentUser.id},
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
          },
        );

        // Debug logging for response
        debugPrint('Edge Function response status: ${response.status}');
        debugPrint('Edge Function response data: ${response.data}');

        if (response.status != 200) {
          final error = response.data is Map
              ? response.data['error'] ?? 'Unknown error occurred'
              : 'Unknown error occurred';
          throw Exception('Server error: $error');
        }

        // Check if it's a partial success (data deleted but account remains)
        bool isPartialSuccess = false;
        bool isAccountDeactivated = false;
        String statusMessage = '';

        if (response.data is Map) {
          if (response.data['partial'] == true) {
            isPartialSuccess = true;
            statusMessage = response.data['message'] ??
                'Your account data has been deleted, but your account may still exist.';
            debugPrint('Partial success details: ${response.data['details']}');
          } else if (response.data['account_deactivated'] == true) {
            isAccountDeactivated = true;
            statusMessage = response.data['message'] ??
                'Your account has been deactivated and your data deleted.';
            debugPrint('Account deactivated');
          } else if (response.data['account_deleted'] == true) {
            statusMessage = response.data['message'] ??
                'Your account has been completely deleted.';
            debugPrint('Account fully deleted');
          } else {
            statusMessage = 'Your account data has been deleted.';
          }
        } else {
          statusMessage = 'Your account data has been deleted.';
        }

        // 4. Clear local data
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        final foodEntryProvider =
            Provider.of<FoodEntryProvider>(context, listen: false);
        await foodEntryProvider.clearEntries();

        // Sign out regardless of outcome
        await _supabase.auth.signOut();

        // 5. Navigate to welcome screen
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(statusMessage),
              backgroundColor: isPartialSuccess
                  ? Colors.orange
                  : isAccountDeactivated
                      ? Colors.blue
                      : Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );

          Navigator.of(context).pushAndRemoveUntil(
            CupertinoPageRoute(builder: (context) => const Welcomescreen()),
            (route) => false,
          );
        }
      } catch (e) {
        debugPrint('Error calling delete-user function: ${e.toString()}');
        throw Exception('Could not delete account. Please contact support.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteUserData(String userId) async {
    try {
      // Delete user data from all tables in order
      final tables = [
        'user_food_entries',
        'user_notification_preferences',
        'user_notification_tokens',
        'user_preferences',
        'user_settings',
        'user_macros',
        'feedback'
      ];

      // Delete data from each table where user_id or id matches
      for (String table in tables) {
        try {
          await _supabase.from(table).delete().eq('user_id', userId);
        } catch (_) {
          // Try with 'id' if 'user_id' fails
          try {
            await _supabase.from(table).delete().eq('id', userId);
          } catch (e) {
            // Log but continue with other tables
            debugPrint('Skipping table $table: ${e.toString()}');
          }
        }
      }
    } catch (e) {
      debugPrint('Error deleting user data: ${e.toString()}');
      rethrow; // Rethrow to handle in the calling function
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Delete Account?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'This action is permanent and cannot be undone. Your account will be permanently deleted, along with all your data, food entries, and preferences.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showSubscriptionWarningDialog();
              },
              child: Text(
                'Yes, Delete My Account',
                style: GoogleFonts.poppins(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSubscriptionWarningDialog() {
    // Check if user has an active subscription
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    final hasActiveSubscription = subscriptionProvider.isProUser;

    if (!hasActiveSubscription) {
      // If no subscription, proceed directly to account deletion
      _deleteAccount();
      return;
    }

    // If they have a subscription, show warning dialog
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Active Subscription Found',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You have an active subscription. Deleting your account does NOT automatically cancel your subscription.',
                style: GoogleFonts.poppins(),
              ),
              const SizedBox(height: 16),
              Text(
                'To avoid being charged, you must cancel your subscription in the App Store settings first.',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openSubscriptionSettings();
              },
              child: Text(
                'Manage Subscription',
                style: GoogleFonts.poppins(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAccount();
              },
              child: Text(
                'Delete Anyway',
                style: GoogleFonts.poppins(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openSubscriptionSettings() async {
    if (Platform.isIOS) {
      // This URL opens the App Store subscriptions management page
      const url = 'itms-apps://apps.apple.com/account/subscriptions';
      try {
        if (await canLaunch(url)) {
          await launch(url);
        } else {
          // Fallback to settings app if subscription URL can't be opened
          await launch('App-Prefs:root=STORE');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open subscription settings: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else if (mounted) {
      // Show message for non-iOS platforms
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Subscription management is only available on iOS devices'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDarkMode = themeProvider.isDarkMode;
        final colorScheme = Theme.of(context).colorScheme;
        final customColors = Theme.of(context).extension<CustomColors>();

        // Check if user is OAuth user
        final currentUser = _supabase.auth.currentUser;
        final isOAuthUser = currentUser != null &&
            currentUser.appMetadata.containsKey('provider') &&
            currentUser.appMetadata['provider'] != 'email';

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            systemOverlayStyle: isDarkMode
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.back,
                    color: colorScheme.primary, size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Delete Account',
              style: GoogleFonts.poppins(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            centerTitle: false,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.exclamationmark_triangle_fill,
                            color: Colors.red,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Warning',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'You are about to delete your account. This action:',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildWarningPoint(
                        '• Cannot be undone or reversed',
                        colorScheme,
                      ),
                      _buildWarningPoint(
                        '• Will delete all your personal data',
                        colorScheme,
                      ),
                      _buildWarningPoint(
                        '• Will delete all your food entries and logs',
                        colorScheme,
                      ),
                      _buildWarningPoint(
                        '• Will delete all your macro goals and settings',
                        colorScheme,
                      ),
                      _buildWarningPoint(
                        '• Will sign you out of the application',
                        colorScheme,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Confirm Account Deletion',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Only show password field for email/password users
                      if (!isOAuthUser)
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_passwordVisible,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Enter your password to confirm',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _passwordVisible = !_passwordVisible;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              // Check if user is OAuth user first
                              final currentUser = _supabase.auth.currentUser;
                              final isOAuthUser = currentUser != null &&
                                  currentUser.appMetadata
                                      .containsKey('provider') &&
                                  currentUser.appMetadata['provider'] !=
                                      'email';

                              // Skip validation for OAuth users
                              if (isOAuthUser) {
                                return null;
                              }
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                      // Show message for OAuth users
                      if (isOAuthUser)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'You signed in with ${currentUser?.appMetadata['provider'] ?? 'a third-party provider'}. No password is required to delete your account.',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              _isLoading ? null : _showConfirmationDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Delete My Account',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'This action will permanently delete your account and all associated data. If you want to use the app again later, you will need to create a new account.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWarningPoint(String text, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 15,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}
