// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'BeerApp';

  @override
  String get navMap => 'Mapa';

  @override
  String get navDiscover => 'Descubrir';

  @override
  String get navScan => 'Escanear';

  @override
  String get navCollection => 'Colección';

  @override
  String get navProfile => 'Perfil';

  @override
  String get comingSoonBadge => 'Próximamente';

  @override
  String get mapScreenDescription =>
      'Explora las cervezas a tu alrededor en un mapa mundial interactivo.';

  @override
  String get discoverScreenDescription =>
      'Encuentra nuevas cervecerías, estilos y cervezas que vale la pena probar.';

  @override
  String get scanScreenDescription =>
      'Escanea la etiqueta de una cerveza para añadirla a tu colección en segundos.';

  @override
  String get collectionScreenDescription =>
      'Lleva el registro de cada cerveza que has probado y valorado.';

  @override
  String get profileScreenDescription =>
      'Gestiona tu perfil, logros y preferencias.';

  @override
  String get logoutAction => 'Cerrar sesión';

  @override
  String profileScreenGreeting(String name) {
    return 'Sesión iniciada como $name.';
  }

  @override
  String get welcomeSubtitle =>
      'Descubre, colecciona y recuerda cada cerveza que pruebes.';

  @override
  String get welcomeAgeStatement =>
      'Confirmo que tengo la edad legal para consumir alcohol en mi jurisdicción.';

  @override
  String get welcomeCreateAccount => 'Crear una cuenta';

  @override
  String get welcomeSignIn => 'Ya tengo una cuenta';

  @override
  String get continueWithGoogle => 'Continuar con Google';

  @override
  String get signInTitle => 'Iniciar sesión';

  @override
  String get signInSubmit => 'Iniciar sesión';

  @override
  String get signInForgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get signInNoAccount => '¿No tienes una cuenta? Regístrate';

  @override
  String get signUpTitle => 'Crea tu cuenta';

  @override
  String get signUpSubmit => 'Crear cuenta';

  @override
  String get signUpHaveAccount => '¿Ya tienes una cuenta? Inicia sesión';

  @override
  String get checkEmailTitle => 'Revisa tu correo';

  @override
  String get checkEmailMessage =>
      'Te enviamos un enlace de confirmación. Tócalo para terminar de crear tu cuenta.';

  @override
  String get checkEmailBackToSignIn => 'Volver a iniciar sesión';

  @override
  String get forgotPasswordTitle => 'Restablece tu contraseña';

  @override
  String get forgotPasswordDescription =>
      'Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.';

  @override
  String get forgotPasswordSubmit => 'Enviar enlace';

  @override
  String get forgotPasswordConfirmation =>
      'Si existe una cuenta con ese correo, te hemos enviado un enlace para restablecer la contraseña.';

  @override
  String get forgotPasswordBackToSignIn => 'Volver a iniciar sesión';

  @override
  String get resetPasswordTitle => 'Elige una nueva contraseña';

  @override
  String get resetPasswordSubmit => 'Actualizar contraseña';

  @override
  String get passwordSameAsCurrentError =>
      'La nueva contraseña debe ser diferente de la contraseña actual.';

  @override
  String get profileUnavailableError =>
      'No pudimos cargar tu perfil. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get completeProfileTitle => 'Elige un nombre de usuario';

  @override
  String get completeProfileDescription =>
      'Elige un nombre de usuario para terminar de configurar tu cuenta de BeerApp.';

  @override
  String get completeProfileSubmit => 'Guardar nombre de usuario';

  @override
  String get emailHint => 'Correo electrónico';

  @override
  String get passwordHint => 'Contraseña';

  @override
  String get usernameHint => 'Nombre de usuario';

  @override
  String get emailInvalidError => 'Ingresa un correo electrónico válido.';

  @override
  String get passwordRequiredError => 'Ingresa tu contraseña.';

  @override
  String get passwordTooShortError =>
      'La contraseña debe tener al menos 8 caracteres.';

  @override
  String get usernameInvalidError =>
      'El nombre de usuario debe tener 3-20 caracteres: minúsculas, números y guiones bajos únicamente.';

  @override
  String get usernameTakenError => 'Ese nombre de usuario ya está en uso.';

  @override
  String get authInvalidCredentialsError => 'Correo o contraseña inválidos.';

  @override
  String get authGenericError => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get googleSignInUnavailableError =>
      'El inicio de sesión con Google todavía no está disponible.';

  @override
  String get loadingStateMessage => 'Cargando…';

  @override
  String get emptyStateDefaultMessage => 'Todavía no hay nada aquí.';

  @override
  String get errorStateDefaultMessage => 'Algo salió mal.';

  @override
  String get errorStateRetryLabel => 'Reintentar';
}
