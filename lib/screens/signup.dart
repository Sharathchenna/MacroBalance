// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:macrotracker/auth/auth_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:macrotracker/screens/loginscreen.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io';

class Signup extends StatefulWidget {
  const Signup({super.key});

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
      final response = await _supabase.auth.signUp(
          email: _emailController.text,
          password: _passwordController.text,
          data: {'username': _nameController.text});

      if (response.user != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthGate()),
          (route) => false,
        );
      }
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
          '362662407469-tq90edhg69p21s816herauenvckhbes6.apps.googleusercontent.com';

      /// iOS Client ID that you registered with Google Cloud.
      const iosClientId =
          '362662407469-vntsu0nvlv04mrk01bsusddqdtunq154.apps.googleusercontent.com';

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

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthGate()),
        (route) => false,
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google sign-in error: $error'),
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

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthGate()),
          (route) => false,
        );
      } else {
        throw 'No identity token received from Apple';
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Apple sign-in error: $error'),
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                  const SizedBox(height: 40),
                  Hero(
                    tag: 'app_logo',
                    child: Container(
                      height: 80,
                      width: 80,
                      alignment: Alignment.center,
                      child: Image.asset(
                        'assets/splash_screen/Fitpro.png',
                        height: 80,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, obj, stack) => Icon(
                          Icons.fitness_center,
                          size: 60,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  Text(
                    'Create Account',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start your fitness journey today',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.primaryColor.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Name field
                  _buildInputLabel('Name'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _nameController,
                    hintText: 'Enter your name',
                    prefixIcon: Icons.person_outline,
                  ),

                  const SizedBox(height: 20),

                  // Email field
                  _buildInputLabel('Email'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _emailController,
                    hintText: 'Enter your email',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                  ),

                  const SizedBox(height: 20),

                  // Password field
                  _buildInputLabel('Password'),
                  const SizedBox(height: 8),
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

                  const SizedBox(height: 20),

                  // Confirm Password field
                  _buildInputLabel('Confirm Password'),
                  const SizedBox(height: 8),
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

                  const SizedBox(height: 30),

                  // Sign Up Button
                  ElevatedButton(
                    onPressed: isLoading ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                        : const Text(
                            "Sign Up",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),

                  const SizedBox(height: 24),

                  // OR divider
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: theme.primaryColor.withOpacity(0.2),
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: theme.primaryColor.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: theme.primaryColor.withOpacity(0.2),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Google Sign In Button
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : _nativeGoogleSignIn,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: theme.primaryColor.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: SvgPicture.asset(
                      "assets/icons/Google.svg",
                      width: 20,
                      height: 20,
                    ),
                    label: Text(
                      'Continue with Google',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Apple Sign In Button - only show on iOS
                  if (Platform.isIOS) ...[
                    OutlinedButton.icon(
                      onPressed: isLoading ? null : _signInWithApple,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: theme.primaryColor.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        Icons.apple,
                        size: 22,
                        color: theme.primaryColor,
                      ),
                      label: Text(
                        'Continue with Apple',
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Login prompt
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(
                          color: theme.primaryColor.withOpacity(0.7),
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
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.w600,
          fontSize: 14,
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
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !(passwordVisibility ?? false),
      keyboardType: keyboardType,
      style: TextStyle(color: Theme.of(context).primaryColor),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Theme.of(context).primaryColor.withOpacity(0.5),
          fontSize: 14,
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                color: Theme.of(context).primaryColor.withOpacity(0.5),
              )
            : null,
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  (passwordVisibility ?? false)
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: Theme.of(context).primaryColor.withOpacity(0.5),
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
            color: Theme.of(context).primaryColor.withOpacity(0.1),
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
