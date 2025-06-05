// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:macrotracker/auth/auth_gate.dart';
import 'package:macrotracker/theme/typography.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:macrotracker/screens/loginscreen.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/screens/forgot_password_screen.dart';
import 'dart:io';

class Signup extends StatefulWidget {
  final bool fromOnboarding;
  final VoidCallback? onSignupSuccess;

  const Signup({
    super.key,
    this.fromOnboarding = false,
    this.onSignupSuccess,
  });

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _supabase = Supabase.instance.client;

  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;
  bool isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    // Unfocus the keyboard
    FocusScope.of(context).unfocus();

    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_confirmPasswordController.text.isNotEmpty &&
        _passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final email = _emailController.text.trim(); // Trim whitespace
      if (email.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid email address'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => isLoading = false); // Reset loading state
        return;
      }
      final response = await _supabase.auth.signUp(
          email: email, // Use trimmed email
          password: _passwordController.text,
          emailRedirectTo:
              'https://macrobalance.app/login-callback/', // Use Universal Link
          data: {'username': _nameController.text});

      if (response.user != null && response.session == null) {
        // User signed up but needs email confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Signup successful! Please check your email to confirm your account.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Navigate to login screen after showing the message
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else if (response.user != null && response.session != null) {
        // This case might happen if email confirmation is disabled or if the user somehow confirms immediately.
        debugPrint('=== SIGNUP SUCCESS: User and session created ===');
        debugPrint('User ID: ${response.user!.id}');
        debugPrint('fromOnboarding: ${widget.fromOnboarding}');
        debugPrint(
            'onSignupSuccess callback exists: ${widget.onSignupSuccess != null}');

        if (widget.fromOnboarding && widget.onSignupSuccess != null) {
          debugPrint('Calling onSignupSuccess callback');
          // Call the success callback - don't pop, let parent handle navigation
          widget.onSignupSuccess!();
        } else {
          debugPrint('Navigating to AuthGate normally');
          // Navigate to AuthGate as before.
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthGate()),
            (route) => false,
          );
        }
      }
      // If response.user is null, the catch block will handle the error.
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${error.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _nativeGoogleSignIn() async {
    setState(() {
      isLoading = true;
    });

    try {
      /// Web Client ID that you registered with Google Cloud.
      const webClientId =
          '701854121812-o16ceunerojb75emmvqgjfsv6k3il75q.apps.googleusercontent.com';

      /// iOS Client ID that you registered with Google Cloud.
      const iosClientId =
          '701854121812-omm2i6nk8e1s88ngtnfb4tt5i1t5c0tp.apps.googleusercontent.com';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: iosClientId,
        serverClientId: webClientId,
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // Sign in aborted.
        return;
      }
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null) {
        throw 'No Access Token found.';
      }
      if (idToken == null) {
        throw 'No ID Token found.';
      }

      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      debugPrint('=== GOOGLE SIGNIN SUCCESS ===');
      debugPrint('fromOnboarding: ${widget.fromOnboarding}');
      debugPrint(
          'onSignupSuccess callback exists: ${widget.onSignupSuccess != null}');

      if (widget.fromOnboarding && widget.onSignupSuccess != null) {
        debugPrint('Calling onSignupSuccess callback from Google signin');
        // Call the success callback - don't pop, let parent handle navigation
        widget.onSignupSuccess!();
      } else {
        debugPrint('Navigating to AuthGate from Google signin');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthGate()),
          (route) => false,
        );
      }
    } catch (error) {
      print('Google sign-in error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('There was a problem signing in with Google'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Request credential for the user
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Use the credential to sign in to Supabase
      if (credential.identityToken != null) {
        await _supabase.auth.signInWithIdToken(
          provider: OAuthProvider.apple,
          idToken: credential.identityToken!,
          accessToken: credential.authorizationCode,
        );

        debugPrint('=== APPLE SIGNIN SUCCESS ===');
        debugPrint('fromOnboarding: ${widget.fromOnboarding}');
        debugPrint(
            'onSignupSuccess callback exists: ${widget.onSignupSuccess != null}');

        if (widget.fromOnboarding && widget.onSignupSuccess != null) {
          debugPrint('Calling onSignupSuccess callback from Apple signin');
          // Call the success callback - don't pop, let parent handle navigation
          widget.onSignupSuccess!();
        } else {
          debugPrint('Navigating to AuthGate from Apple signin');
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthGate()),
            (route) => false,
          );
        }
      } else {
        throw 'No identity token received from Apple';
      }
    } catch (error) {
      print('Apple sign-in error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('There was a problem signing in with Apple'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = Theme.of(context).extension<CustomColors>();

    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping anywhere on the screen
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: widget.fromOnboarding
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_rounded,
                      color: customColors!.textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              )
            : null,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24), // Reduced from 40
                    Text(
                      'Create Account',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: customColors!.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4), // Reduced from 8
                    Text(
                      widget.fromOnboarding
                          ? 'Create an account to save your personalized plan'
                          : 'Start your fitness journey today',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: customColors!.textPrimary
                            .withAlpha(((0.7) * 255).round()),
                      ),
                    ),
                    const SizedBox(height: 24), // Reduced from 40

                    // Name field
                    _buildInputLabel('Name'),
                    const SizedBox(height: 4), // Reduced from 8
                    _buildTextField(
                      controller: _nameController,
                      hintText: 'Enter your name',
                      prefixIcon: Icons.person_outline,
                    ),

                    const SizedBox(height: 16), // Reduced from 20

                    // Email field
                    _buildInputLabel('Email'),
                    const SizedBox(height: 4), // Reduced from 8
                    _buildTextField(
                      controller: _emailController,
                      hintText: 'Enter your email',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email_outlined,
                    ),

                    const SizedBox(height: 16), // Reduced from 20

                    // Password field
                    _buildInputLabel('Password'),
                    const SizedBox(height: 4), // Reduced from 8
                    _buildTextField(
                      controller: _passwordController,
                      hintText: 'Create a password',
                      isPassword: true,
                      passwordVisibility: isPasswordVisible,
                      onPasswordVisibilityChanged: (value) {
                        setState(() {
                          isPasswordVisible = value;
                        });
                      },
                      prefixIcon: Icons.lock_outline,
                    ),

                    const SizedBox(height: 16), // Reduced from 20

                    // Confirm Password field
                    _buildInputLabel('Confirm Password'),
                    const SizedBox(height: 4), // Reduced from 8
                    _buildTextField(
                      controller: _confirmPasswordController,
                      hintText: 'Confirm your password',
                      isPassword: true,
                      passwordVisibility: isConfirmPasswordVisible,
                      onPasswordVisibilityChanged: (value) {
                        setState(() {
                          isConfirmPasswordVisible = value;
                        });
                      },
                      prefixIcon: Icons.lock_outline,
                    ),

                    // Forgot Password link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 8), // Reduced padding
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.w500,
                            fontSize: 13, // Slightly smaller font
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16), // Reduced from 30

                    // Sign Up Button
                    ElevatedButton(
                      onPressed: isLoading ? null : _signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: customColors!.textPrimary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14), // Reduced from 16
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.onPrimary,
                                ),
                              ),
                            )
                          : Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                    ),

                    const SizedBox(height: 16), // Reduced from 24

                    // OR divider with reduced height
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: customColors.textPrimary
                                .withAlpha(((0.2) * 255).round()),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12), // Reduced from 16
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: customColors.textPrimary
                                  .withAlpha(((0.6) * 255).round()),
                              fontWeight: FontWeight.w500,
                              fontSize: 13, // Slightly smaller font
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: customColors.textPrimary
                                .withAlpha(((0.2) * 255).round()),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16), // Reduced from 24

                    // Google Sign In Button
                    OutlinedButton.icon(
                      onPressed: isLoading ? null : _nativeGoogleSignIn,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: customColors.textPrimary
                                .withAlpha(((0.3) * 255).round())),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12), // Reduced from 14
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: SvgPicture.asset(
                        'assets/icons/Google.svg',
                        width: 20,
                        height: 20,
                      ),
                      label: Text(
                        'Continue with Google',
                        style: TextStyle(
                          color: customColors.textPrimary
                              .withAlpha(((0.8) * 255).round()),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    if (Platform.isIOS) ...[
                      const SizedBox(height: 12), // Reduced from 16

                      // Apple Sign In Button - only show on iOS
                      OutlinedButton.icon(
                        onPressed: isLoading ? null : _signInWithApple,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: customColors.textPrimary
                                  .withAlpha(((0.3) * 255).round())),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12), // Reduced from 14
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(
                          Icons.apple,
                          size: 22,
                          color: customColors.textPrimary,
                        ),
                        label: Text(
                          'Continue with Apple',
                          style: TextStyle(
                            color: customColors.textPrimary
                                .withAlpha(((0.8) * 255).round()),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16), // Reduced from 20

                    // Login prompt with slightly smaller text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(
                            color: customColors.textPrimary
                                .withAlpha(((0.7) * 255).round()),
                            fontSize: 13, // Slightly smaller font
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Login',
                            style: TextStyle(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13, // Slightly smaller font
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16), // Reduced from 40
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    final customColors = Theme.of(context).extension<CustomColors>();
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: AppTypography.inputLabel.copyWith(
          color: customColors!.textPrimary,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    IconData? prefixIcon,
    bool isPassword = false,
    bool? passwordVisibility,
    Function(bool)? onPasswordVisibilityChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final customColors = Theme.of(context).extension<CustomColors>();
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !(passwordVisibility ?? false),
      keyboardType: keyboardType,
      style: AppTypography.inputText.copyWith(
        color: customColors!.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTypography.inputHint.copyWith(
          color: customColors.textPrimary.withAlpha(((0.5) * 255).round()),
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                color:
                    customColors.textPrimary.withAlpha(((0.5) * 255).round()),
                size: 22,
              )
            : null,
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  (passwordVisibility ?? false)
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: Theme.of(context)
                      .primaryColor
                      .withAlpha(((0.5) * 255).round()),
                  size: 22,
                ),
                onPressed: () {
                  onPasswordVisibilityChanged
                      ?.call(!(passwordVisibility ?? false));
                },
              )
            : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            width: 1,
            color:
                Theme.of(context).primaryColor.withAlpha(((0.1) * 255).round()),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            width: 1.5,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ),
    );
  }
}
