import 'package:flutter/cupertino.dart'; // Added for icons
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Added for fonts
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:macrotracker/theme/app_theme.dart'; // Added for custom colors

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill email if user is logged in
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.email != null) {
      _emailController.text = user.email!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    // Dismiss keyboard first
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final email = _emailController.text;
      final message = _messageController.text;

      try {
        // Call the Supabase Edge Function
        final response = await Supabase.instance.client.functions.invoke(
          'contact-support', // Name of your Edge Function
          body: {
            'email': email,
            'message': message,
          },
        );

        if (response.status != 200) {
          // Handle function error
          final errorData = response.data;
          throw Exception(
              'Failed to send message: ${errorData?['error'] ?? 'Unknown error'}');
        }

        // Success
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Support message sent successfully!',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating, // Make it floating
            ),
          );
          // Optionally clear fields or navigate back
          _messageController.clear();
          // Consider navigating back after a delay
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted && Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
          });
        }
      } catch (e) {
        // Handle network or other errors
        debugPrint('Error sending support message: $e'); // Log the detailed error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'There was a problem sending the message.', // Generic error message
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating, // Make it floating
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final customColors = theme.extension<CustomColors>(); // Get custom colors
    final isDarkMode = theme.brightness == Brightness.dark;

    // Define input decoration theme based on current theme
    final inputDecorationTheme = InputDecoration(
      filled: true,
      fillColor: customColors?.cardBackground ?? colorScheme.surface,
      hintStyle:
          GoogleFonts.poppins(color: colorScheme.onSurface.withOpacity(0.5)),
      labelStyle:
          GoogleFonts.poppins(color: colorScheme.onSurface.withOpacity(0.7)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide.none, // No border by default
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(
          color: colorScheme.onSurface.withOpacity(0.1), // Subtle border
          width: 1.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(
          color: colorScheme.primary, // Primary color border when focused
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(
          color: colorScheme.error, // Error color border
          width: 1.0,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(
          color: colorScheme.error, // Error color border when focused
          width: 1.5,
        ),
      ),
      prefixIconColor: colorScheme.onSurface.withOpacity(0.6),
      contentPadding:
          const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Contact Support',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          // Consistent back button
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child:
                Icon(CupertinoIcons.back, color: colorScheme.primary, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside of text fields
          FocusScope.of(context).unfocus();
        },
        behavior: HitTestBehavior
            .opaque, // Ensures the GestureDetector covers the screen
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Text(
                  'Get in Touch with us!',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                // Text(
                //   'Have questions or feedback? Send us a message!',
                //   style: GoogleFonts.poppins(
                //     fontSize: 14,
                //     color: colorScheme.onSurface.withOpacity(0.7),
                //   ),
                // ),
                const SizedBox(height: 24.0),
                TextFormField(
                  controller: _emailController,
                  style: GoogleFonts.poppins(color: colorScheme.onSurface),
                  decoration: inputDecorationTheme.copyWith(
                    labelText: 'Your Email',
                    hintText: 'Enter your email address',
                    prefixIcon: const Icon(CupertinoIcons.mail),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _messageController,
                  style: GoogleFonts.poppins(color: colorScheme.onSurface),
                  decoration: inputDecorationTheme.copyWith(
                    labelText: 'Message',
                    hintText: 'Describe your issue or question...',
                    prefixIcon: Padding(
                      // Align icon better for multiline
                      padding:
                          const EdgeInsets.only(bottom: 80), // Adjust as needed
                      child: Icon(CupertinoIcons.bubble_left),
                    ),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your message';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32.0),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendEmail,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18.0),
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12.0), // Consistent radius
                    ),
                    elevation: 2, // Subtle elevation
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Send Message',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
