import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('de'),
    Locale('it'),
    Locale('pt'),
  ];

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
    'fr': {
      'appTitle': 'MacroTracker',
      'welcomeAppName': 'MacroBalance',
      'welcomeTagline': 'Le suivi nutritionnel intelligent et simple',
      'featureAiTitle': 'Reconnaissance alimentaire par IA',
      'featureAiDesc': 'Prenez simplement une photo pour enregistrer vos repas',
      'featureEffortlessTitle': 'Suivi sans effort',
      'featureEffortlessDesc': 'Suivez calories, macros et nutriments',
      'featureHealthTitle': 'Intégration santé',
      'featureHealthDesc': 'Synchronisation avec Apple Health et Google Fit',
      'signInButton': 'Se connecter',
      'createAccountButton': 'Créer un compte',
      'loginWelcomeTitle': 'Bon retour',
      'loginWelcomeSubtitle': 'Connectez-vous pour continuer à suivre votre progression',
      'emailLabel': 'E-mail',
      'emailHint': 'Entrez votre e-mail',
      'passwordLabel': 'Mot de passe',
      'passwordHint': 'Entrez votre mot de passe',
      'forgotPassword': 'Mot de passe oublié ?',
      'loginButton': 'Se connecter',
      'orLabel': 'OU',
      'continueWithGoogle': 'Continuer avec Google',
      'continueWithApple': 'Continuer avec Apple',
      'noAccountPrompt': 'Pas de compte ? ',
      'signUpLink': 'Inscription',
      'snackPleaseEnterBoth': "Veuillez saisir l'e-mail et le mot de passe",
      'errorPrefix': 'Erreur : ',
      'googleSignInProblem': 'Un problème est survenu avec la connexion Google',
      'appleSignInProblem': 'Un problème est survenu avec la connexion Apple',
      'createAccountTitle': 'Créer un compte',
      'createAccountSubtitle': "Commencez votre parcours de remise en forme aujourd'hui",
      'nameLabel': 'Nom',
      'nameHint': 'Entrez votre nom',
      'confirmPasswordLabel': 'Confirmez le mot de passe',
      'confirmPasswordHint': 'Confirmez votre mot de passe',
      'signUpButton': "S'inscrire",
      'alreadyHaveAccountPrompt': 'Vous avez déjà un compte ? ',
      'loginLink': 'Se connecter',
      'snackPleaseFillAllFields': 'Veuillez remplir tous les champs',
      'snackPasswordsNoMatch': 'Les mots de passe ne correspondent pas',
      'snackPleaseEnterValidEmail': 'Veuillez entrer une adresse e-mail valide',
      'signupSuccessCheckEmail': 'Inscription réussie ! Veuillez vérifier votre e-mail pour confirmer votre compte.',
      'appleSignInErrorNoToken': "Aucun jeton d'identité reçu d'Apple",
    },
    'de': {
      'appTitle': 'MacroTracker',
      'welcomeAppName': 'MacroBalance',
      'welcomeTagline': 'Intelligentes, einfaches Ernährungs-Tracking',
      'featureAiTitle': 'KI-Lebensmittelerkennung',
      'featureAiDesc': 'Einfach ein Foto machen, um Mahlzeiten zu protokollieren',
      'featureEffortlessTitle': 'Müheloses Tracking',
      'featureEffortlessDesc': 'Kalorien, Makros und Nährstoffe überwachen',
      'featureHealthTitle': 'Gesundheitsintegration',
      'featureHealthDesc': 'Mit Apple Health und Google Fit synchronisieren',
      'signInButton': 'Anmelden',
      'createAccountButton': 'Konto erstellen',
      'loginWelcomeTitle': 'Willkommen zurück',
      'loginWelcomeSubtitle': 'Melden Sie sich an, um Ihren Fortschritt weiter zu verfolgen',
      'emailLabel': 'E-Mail',
      'emailHint': 'Geben Sie Ihre E-Mail ein',
      'passwordLabel': 'Passwort',
      'passwordHint': 'Geben Sie Ihr Passwort ein',
      'forgotPassword': 'Passwort vergessen?',
      'loginButton': 'Anmelden',
      'orLabel': 'ODER',
      'continueWithGoogle': 'Mit Google fortfahren',
      'continueWithApple': 'Mit Apple fortfahren',
      'noAccountPrompt': 'Noch kein Konto? ',
      'signUpLink': 'Registrieren',
      'snackPleaseEnterBoth': 'Bitte E-Mail und Passwort eingeben',
      'errorPrefix': 'Fehler: ',
      'googleSignInProblem': 'Problem bei der Anmeldung mit Google',
      'appleSignInProblem': 'Problem bei der Anmeldung mit Apple',
      'createAccountTitle': 'Konto erstellen',
      'createAccountSubtitle': 'Beginnen Sie noch heute Ihre Fitnessreise',
      'nameLabel': 'Name',
      'nameHint': 'Geben Sie Ihren Namen ein',
      'confirmPasswordLabel': 'Passwort bestätigen',
      'confirmPasswordHint': 'Bestätigen Sie Ihr Passwort',
      'signUpButton': 'Registrieren',
      'alreadyHaveAccountPrompt': 'Bereits ein Konto? ',
      'loginLink': 'Anmelden',
      'snackPleaseFillAllFields': 'Bitte alle Felder ausfüllen',
      'snackPasswordsNoMatch': 'Passwörter stimmen nicht überein',
      'snackPleaseEnterValidEmail': 'Bitte eine gültige E-Mail-Adresse eingeben',
      'signupSuccessCheckEmail': 'Registrierung erfolgreich! Bitte überprüfen Sie Ihre E-Mail, um Ihr Konto zu bestätigen.',
      'appleSignInErrorNoToken': 'Kein Identitätstoken von Apple erhalten',
    },
    'it': {
      'appTitle': 'MacroTracker',
      'welcomeAppName': 'MacroBalance',
      'welcomeTagline': 'Monitoraggio nutrizionale intelligente e semplice',
      'featureAiTitle': 'Riconoscimento alimenti con IA',
      'featureAiDesc': 'Scatta una foto per registrare i pasti',
      'featureEffortlessTitle': 'Monitoraggio senza sforzo',
      'featureEffortlessDesc': 'Monitora calorie, macro e nutrienti',
      'featureHealthTitle': 'Integrazione salute',
      'featureHealthDesc': 'Sincronizza con Apple Health e Google Fit',
      'signInButton': 'Accedi',
      'createAccountButton': 'Crea account',
      'loginWelcomeTitle': 'Bentornato',
      'loginWelcomeSubtitle': 'Accedi per continuare a seguire i tuoi progressi',
      'emailLabel': 'Email',
      'emailHint': 'Inserisci la tua email',
      'passwordLabel': 'Password',
      'passwordHint': 'Inserisci la tua password',
      'forgotPassword': 'Password dimenticata?',
      'loginButton': 'Accedi',
      'orLabel': 'OPPURE',
      'continueWithGoogle': 'Continua con Google',
      'continueWithApple': 'Continua con Apple',
      'noAccountPrompt': 'Non hai un account? ',
      'signUpLink': 'Registrati',
      'snackPleaseEnterBoth': 'Inserisci email e password',
      'errorPrefix': 'Errore: ',
      'googleSignInProblem': "Si è verificato un problema con l'accesso Google",
      'appleSignInProblem': "Si è verificato un problema con l'accesso Apple",
      'createAccountTitle': 'Crea account',
      'createAccountSubtitle': 'Inizia oggi il tuo percorso fitness',
      'nameLabel': 'Nome',
      'nameHint': 'Inserisci il tuo nome',
      'confirmPasswordLabel': 'Conferma password',
      'confirmPasswordHint': 'Conferma la tua password',
      'signUpButton': 'Registrati',
      'alreadyHaveAccountPrompt': 'Hai già un account? ',
      'loginLink': 'Accedi',
      'snackPleaseFillAllFields': 'Compila tutti i campi',
      'snackPasswordsNoMatch': 'Le password non corrispondono',
      'snackPleaseEnterValidEmail': "Inserisci un'email valida",
      'signupSuccessCheckEmail': "Registrazione riuscita! Controlla l'email per confermare l'account.",
      'appleSignInErrorNoToken': 'Nessun token di identità ricevuto da Apple',
    },
    'pt': {
      'appTitle': 'MacroTracker',
      'welcomeAppName': 'MacroBalance',
      'welcomeTagline': 'Rastreamento nutricional inteligente e simples',
      'featureAiTitle': 'Reconhecimento de alimentos por IA',
      'featureAiDesc': 'Basta tirar uma foto para registrar suas refeições',
      'featureEffortlessTitle': 'Acompanhamento sem esforço',
      'featureEffortlessDesc': 'Monitore calorias, macros e nutrientes',
      'featureHealthTitle': 'Integração com saúde',
      'featureHealthDesc': 'Sincronize com Apple Health e Google Fit',
      'signInButton': 'Entrar',
      'createAccountButton': 'Criar conta',
      'loginWelcomeTitle': 'Bem-vindo de volta',
      'loginWelcomeSubtitle': 'Entre para continuar acompanhando seu progresso',
      'emailLabel': 'E-mail',
      'emailHint': 'Digite seu e-mail',
      'passwordLabel': 'Senha',
      'passwordHint': 'Digite sua senha',
      'forgotPassword': 'Esqueceu a senha?',
      'loginButton': 'Entrar',
      'orLabel': 'OU',
      'continueWithGoogle': 'Continuar com Google',
      'continueWithApple': 'Continuar com Apple',
      'noAccountPrompt': 'Não tem uma conta? ',
      'signUpLink': 'Cadastre-se',
      'snackPleaseEnterBoth': 'Informe e-mail e senha',
      'errorPrefix': 'Erro: ',
      'googleSignInProblem': 'Ocorreu um problema ao entrar com o Google',
      'appleSignInProblem': 'Ocorreu um problema ao entrar com a Apple',
      'createAccountTitle': 'Criar conta',
      'createAccountSubtitle': 'Comece hoje sua jornada fitness',
      'nameLabel': 'Nome',
      'nameHint': 'Digite seu nome',
      'confirmPasswordLabel': 'Confirmar senha',
      'confirmPasswordHint': 'Confirme sua senha',
      'signUpButton': 'Cadastrar',
      'alreadyHaveAccountPrompt': 'Já tem uma conta? ',
      'loginLink': 'Entrar',
      'snackPleaseFillAllFields': 'Preencha todos os campos',
      'snackPasswordsNoMatch': 'As senhas não coincidem',
      'snackPleaseEnterValidEmail': 'Digite um e-mail válido',
      'signupSuccessCheckEmail': 'Cadastro realizado! Verifique seu e-mail para confirmar a conta.',
      'appleSignInErrorNoToken': 'Nenhum token de identidade recebido da Apple',
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
  bool isSupported(Locale locale) => ['en', 'es', 'fr', 'de', 'it', 'pt'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}