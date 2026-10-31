import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:macrotracker/services/test_accounts.dart';

/// How a sign-in or sign-up attempt ended.
enum AuthOutcome {
  /// There is a session now.
  signedIn,

  /// The account was created but the email must be confirmed first.
  needsConfirmation,

  /// The user backed out of the Apple or Google sheet.
  cancelled,

  /// Something went wrong; see [AuthResult.message].
  failed,
}

class AuthResult {
  const AuthResult(this.outcome, [this.message]);

  final AuthOutcome outcome;

  /// The error text for [AuthOutcome.failed].
  final String? message;

  bool get signedIn => outcome == AuthOutcome.signedIn;
}

/// The sign-in and sign-up calls shared by the sign-up and login screens and
/// the onboarding Save screen. They return a result and never navigate or
/// show anything, so each screen decides what happens next.
class AuthActions {
  /// Web client ID registered with Google Cloud.
  static const _googleWebClientId =
      '253882759822-eaq84uc6t558i000fqroef3f47sf6e16.apps.googleusercontent.com';

  /// iOS client ID registered with Google Cloud.
  static const _googleIosClientId =
      '253882759822-7a6ka2f4k37v0ifhvpoe1fv6hfti4aar.apps.googleusercontent.com';

  /// Where Supabase sends the browser back after Apple sign-in on Android.
  /// Must be in the Supabase Auth redirect allowlist.
  static const oauthCallback = 'io.supabase.macrotracker://oauth-callback/';

  static SupabaseClient get _supabase => Supabase.instance.client;

  /// Words for the person, never a raw exception.
  static String _messageOf(Object error) {
    if (error is AuthException) return error.message;
    final text = error.toString();
    if (text.contains('already registered') || text.contains('409')) {
      return 'That email already has an account. Log in instead.';
    }
    if (text.contains('SocketException') || text.contains('Timeout')) {
      return 'We couldn’t reach the server. Check your connection and try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  static Future<AuthResult> signInWithGoogle() async {
    try {
      // Android finds its OAuth client from the package name and signing
      // certificate; only iOS takes a client ID.
      final googleSignIn = GoogleSignIn(
        clientId: Platform.isIOS ? _googleIosClientId : null,
        serverClientId: _googleWebClientId,
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return const AuthResult(AuthOutcome.cancelled);
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;
      if (accessToken == null) throw 'No Access Token found.';
      if (idToken == null) throw 'No ID Token found.';

      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      return const AuthResult(AuthOutcome.signedIn);
    } catch (error) {
      debugPrint('Google sign-in error: $error');
      return AuthResult(AuthOutcome.failed, _messageOf(error));
    }
  }

  static Future<AuthResult> signInWithApple() async {
    if (!Platform.isIOS) return _signInWithAppleInBrowser();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final token = credential.identityToken;
      if (token == null) throw 'No identity token received from Apple';
      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: token,
        accessToken: credential.authorizationCode,
      );
      return const AuthResult(AuthOutcome.signedIn);
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        return const AuthResult(AuthOutcome.cancelled);
      }
      debugPrint('Apple sign-in error: $error');
      return AuthResult(AuthOutcome.failed, _messageOf(error));
    } catch (error) {
      debugPrint('Apple sign-in error: $error');
      return AuthResult(AuthOutcome.failed, _messageOf(error));
    }
  }

  /// Apple sign-in outside iOS (for people who joined on iPhone): Supabase's
  /// web flow in the browser, which returns to [oauthCallback]. Supabase
  /// reads the session from that link; if the person comes back without one
  /// (closed the browser), it counts as cancelled.
  static Future<AuthResult> _signInWithAppleInBrowser() async {
    final signedIn = Completer<AuthResult>();
    final authSub = _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && !signedIn.isCompleted) {
        signedIn.complete(const AuthResult(AuthOutcome.signedIn));
      }
    });
    Timer? giveUp;
    final lifecycle = AppLifecycleListener(onResume: () {
      giveUp?.cancel();
      giveUp = Timer(const Duration(seconds: 4), () {
        if (!signedIn.isCompleted) {
          signedIn.complete(const AuthResult(AuthOutcome.cancelled));
        }
      });
    });
    try {
      final launched = await _supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: oauthCallback,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!launched) {
        return const AuthResult(AuthOutcome.failed, 'Couldn’t open the browser.');
      }
      return await signedIn.future;
    } catch (error) {
      debugPrint('Apple sign-in error: $error');
      return AuthResult(AuthOutcome.failed, _messageOf(error));
    } finally {
      giveUp?.cancel();
      lifecycle.dispose();
      await authSub.cancel();
    }
  }

  /// Email sign-up. Test accounts (@mbtest.ai, test builds only) are created
  /// already confirmed, so no email is sent, and are signed in straight away.
  static Future<AuthResult> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      email = email.trim();
      if (TestAccounts.isTestEmail(email)) {
        await TestAccounts.createConfirmedAccount(
            email: email, password: password, username: name);
        await _supabase.auth.signInWithPassword(email: email, password: password);
        return const AuthResult(AuthOutcome.signedIn);
      }
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'https://macrobalance.app/login-callback/',
        data: {'username': name},
      );
      if (response.user != null && response.session == null) {
        return const AuthResult(AuthOutcome.needsConfirmation);
      }
      if (response.user != null && response.session != null) {
        return const AuthResult(AuthOutcome.signedIn);
      }
      return const AuthResult(AuthOutcome.failed, 'Could not create the account');
    } catch (error) {
      return AuthResult(AuthOutcome.failed, _messageOf(error));
    }
  }

  static Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth
          .signInWithPassword(email: email.trim(), password: password);
      if (response.user != null) return const AuthResult(AuthOutcome.signedIn);
      return const AuthResult(AuthOutcome.failed, 'Could not log in');
    } catch (error) {
      return AuthResult(AuthOutcome.failed, _messageOf(error));
    }
  }
}
