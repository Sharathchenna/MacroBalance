import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [Locale('en'), Locale('es')];

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appTitle': 'MacroTracker',
      'welcomeAppName': 'MacroBalance',
      'welcomeTagline': 'Smart nutrition tracking made simple',
      'featureAiTitle': 'AI Food Recognition',
      'featureAiDesc': 'Just snap a photo to log your meals',
      'featureEffortlessTitle': 'Effortless Tracking',
      'featureEffortlessDesc': 'Monitor calories, macros, and nutrients',
      'featureHealthTitle': 'Health Integration',
      'featureHealthDesc': 'Sync with Apple Health & Google Fit',
      'signInButton': 'Sign In',
      'createAccountButton': 'Create Account',
      'loginWelcomeTitle': 'Welcome Back',
      'loginWelcomeSubtitle': 'Login to continue tracking your fitness journey',
      'emailLabel': 'Email',
      'emailHint': 'Enter your email',
      'passwordLabel': 'Password',
      'passwordHint': 'Enter your password',
      'forgotPassword': 'Forgot password?',
      'loginButton': 'Login',
      'orLabel': 'OR',
      'continueWithGoogle': 'Continue with Google',
      'continueWithApple': 'Continue with Apple',
      'noAccountPrompt': "Don't have an account? ",
      'signUpLink': 'Sign up',
      'snackPleaseEnterBoth': 'Please enter both email and password',
      'errorPrefix': 'Error: ',
      'googleSignInProblem': 'There was a problem signing in with Google',
      'appleSignInProblem': 'There was a problem signing in with Apple',
      'createAccountTitle': 'Create Account',
      'createAccountSubtitle': 'Start your fitness journey today',
      'nameLabel': 'Name',
      'nameHint': 'Enter your name',
      'confirmPasswordLabel': 'Confirm Password',
      'confirmPasswordHint': 'Confirm your password',
      'signUpButton': 'Sign Up',
      'alreadyHaveAccountPrompt': 'Already have an account? ',
      'loginLink': 'Login',
      'snackPleaseFillAllFields': 'Please fill in all fields',
      'snackPasswordsNoMatch': 'Passwords do not match',
      'snackPleaseEnterValidEmail': 'Please enter a valid email address',
      'signupSuccessCheckEmail': 'Signup successful! Please check your email to confirm your account.',
      'appleSignInErrorNoToken': 'No identity token received from Apple',
    },
    'es': {
      'appTitle': 'MacroTracker',
      'welcomeAppName': 'MacroBalance',
      'welcomeTagline': 'Seguimiento de nutrición inteligente y sencillo',
      'featureAiTitle': 'Reconocimiento de alimentos con IA',
      'featureAiDesc': 'Solo toma una foto para registrar tus comidas',
      'featureEffortlessTitle': 'Seguimiento sin esfuerzo',
      'featureEffortlessDesc': 'Supervisa calorías, macronutrientes y nutrientes',
      'featureHealthTitle': 'Integración con salud',
      'featureHealthDesc': 'Sincroniza con Apple Health y Google Fit',
      'signInButton': 'Iniciar sesión',
      'createAccountButton': 'Crear cuenta',
      'loginWelcomeTitle': 'Bienvenido de nuevo',
      'loginWelcomeSubtitle': 'Inicia sesión para continuar con tu progreso',
      'emailLabel': 'Correo electrónico',
      'emailHint': 'Introduce tu correo electrónico',
      'passwordLabel': 'Contraseña',
      'passwordHint': 'Introduce tu contraseña',
      'forgotPassword': '¿Olvidaste tu contraseña?',
      'loginButton': 'Iniciar sesión',
      'orLabel': 'O',
      'continueWithGoogle': 'Continuar con Google',
      'continueWithApple': 'Continuar con Apple',
      'noAccountPrompt': '¿No tienes una cuenta? ',
      'signUpLink': 'Regístrate',
      'snackPleaseEnterBoth': 'Por favor ingresa correo y contraseña',
      'errorPrefix': 'Error: ',
      'googleSignInProblem': 'Hubo un problema al iniciar sesión con Google',
      'appleSignInProblem': 'Hubo un problema al iniciar sesión con Apple',
      'createAccountTitle': 'Crear cuenta',
      'createAccountSubtitle': 'Comienza tu camino de fitness hoy',
      'nameLabel': 'Nombre',
      'nameHint': 'Introduce tu nombre',
      'confirmPasswordLabel': 'Confirmar contraseña',
      'confirmPasswordHint': 'Confirma tu contraseña',
      'signUpButton': 'Registrarse',
      'alreadyHaveAccountPrompt': '¿Ya tienes una cuenta? ',
      'loginLink': 'Iniciar sesión',
      'snackPleaseFillAllFields': 'Por favor completa todos los campos',
      'snackPasswordsNoMatch': 'Las contraseñas no coinciden',
      'snackPleaseEnterValidEmail': 'Por favor ingresa un correo válido',
      'signupSuccessCheckEmail': '¡Registro exitoso! Revisa tu correo para confirmar tu cuenta.',
      'appleSignInErrorNoToken': 'No se recibió el token de identidad de Apple',
    },
  };

  String _text(String key) {
    final lang = _localizedValues[locale.languageCode] ?? _localizedValues['en']!;
    return lang[key] ?? _localizedValues['en']![key] ?? key;
  }

  String get appTitle => _text('appTitle');
  String get welcomeAppName => _text('welcomeAppName');
  String get welcomeTagline => _text('welcomeTagline');
  String get featureAiTitle => _text('featureAiTitle');
  String get featureAiDesc => _text('featureAiDesc');
  String get featureEffortlessTitle => _text('featureEffortlessTitle');
  String get featureEffortlessDesc => _text('featureEffortlessDesc');
  String get featureHealthTitle => _text('featureHealthTitle');
  String get featureHealthDesc => _text('featureHealthDesc');
  String get signInButton => _text('signInButton');
  String get createAccountButton => _text('createAccountButton');
  String get loginWelcomeTitle => _text('loginWelcomeTitle');
  String get loginWelcomeSubtitle => _text('loginWelcomeSubtitle');
  String get emailLabel => _text('emailLabel');
  String get emailHint => _text('emailHint');
  String get passwordLabel => _text('passwordLabel');
  String get passwordHint => _text('passwordHint');
  String get forgotPassword => _text('forgotPassword');
  String get loginButton => _text('loginButton');
  String get orLabel => _text('orLabel');
  String get continueWithGoogle => _text('continueWithGoogle');
  String get continueWithApple => _text('continueWithApple');
  String get noAccountPrompt => _text('noAccountPrompt');
  String get signUpLink => _text('signUpLink');
  String get snackPleaseEnterBoth => _text('snackPleaseEnterBoth');
  String get errorPrefix => _text('errorPrefix');
  String get googleSignInProblem => _text('googleSignInProblem');
  String get appleSignInProblem => _text('appleSignInProblem');
  String get createAccountTitle => _text('createAccountTitle');
  String get createAccountSubtitle => _text('createAccountSubtitle');
  String get nameLabel => _text('nameLabel');
  String get nameHint => _text('nameHint');
  String get confirmPasswordLabel => _text('confirmPasswordLabel');
  String get confirmPasswordHint => _text('confirmPasswordHint');
  String get signUpButton => _text('signUpButton');
  String get alreadyHaveAccountPrompt => _text('alreadyHaveAccountPrompt');
  String get loginLink => _text('loginLink');
  String get snackPleaseFillAllFields => _text('snackPleaseFillAllFields');
  String get snackPasswordsNoMatch => _text('snackPasswordsNoMatch');
  String get snackPleaseEnterValidEmail => _text('snackPleaseEnterValidEmail');
  String get signupSuccessCheckEmail => _text('signupSuccessCheckEmail');
  String get appleSignInErrorNoToken => _text('appleSignInErrorNoToken');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'es'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}