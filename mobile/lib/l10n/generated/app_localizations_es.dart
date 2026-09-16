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
  String get discoverScreenDescription =>
      'Encuentra nuevas cervecerías, estilos y cervezas que vale la pena probar.';

  @override
  String get scanScreenDescription =>
      'Escanea la etiqueta de una cerveza para añadirla a tu colección en segundos.';

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

  @override
  String get catalogErrorUnauthorized =>
      'Tu sesión ha caducado. Vuelve a iniciar sesión para continuar.';

  @override
  String get catalogErrorServiceUnavailable =>
      'El catálogo de cervezas no está disponible temporalmente. Inténtalo de nuevo en un momento.';

  @override
  String get catalogErrorNetwork =>
      'Revisa tu conexión a internet e inténtalo de nuevo.';

  @override
  String get catalogErrorNotFound => 'No se pudo encontrar esta cerveza.';

  @override
  String get catalogErrorGeneric =>
      'No pudimos cargar el catálogo de cervezas. Inténtalo de nuevo.';

  @override
  String get discoverSearchHint =>
      'Busca cervezas, cervecerías, estilos, países';

  @override
  String get discoverSearchClearAction => 'Borrar búsqueda';

  @override
  String get discoverFiltersAction => 'Filtros';

  @override
  String get discoverFiltersSheetTitle => 'Filtros';

  @override
  String get discoverFilterSectionStyle => 'Estilo';

  @override
  String get discoverFilterSectionCountry => 'País';

  @override
  String get discoverFilterSectionBrewery => 'Cervecería';

  @override
  String get discoverClearAllAction => 'Borrar todo';

  @override
  String get discoverShowResultsAction => 'Mostrar resultados';

  @override
  String get discoverNoResultsMessage =>
      'Ninguna cerveza coincide con tu búsqueda.';

  @override
  String get beerDetailBreweryLabel => 'Cervecería';

  @override
  String get beerDetailStyleLabel => 'Estilo';

  @override
  String get beerDetailAbvLabel => 'ABV';

  @override
  String get beerDetailIbuLabel => 'IBU';

  @override
  String get beerDetailDescriptionLabel => 'Descripción';

  @override
  String get beerDetailVerifiedBadge => 'Verificada';

  @override
  String get cancelAction => 'Cancelar';

  @override
  String get beerDetailLogAction => 'Registrar esta cerveza';

  @override
  String get beerLogSectionTitle => 'Tus registros';

  @override
  String get beerLogEmptyMessage => 'Todavía no has registrado esta cerveza.';

  @override
  String get beerLogLoadMoreAction => 'Cargar más';

  @override
  String get beerLogFormTitleCreate => 'Registrar esta cerveza';

  @override
  String get beerLogFormTitleEdit => 'Editar registro';

  @override
  String get beerLogRatingLabel => 'Valoración';

  @override
  String beerLogRatingStarSemanticLabel(int rating) {
    return 'Valorar $rating de 5';
  }

  @override
  String get beerLogAddDetailsAction => 'Añadir detalles';

  @override
  String get beerLogReviewHint => 'Reseña (opcional)';

  @override
  String get beerLogServingNoteHint => 'Nota de la cata (opcional)';

  @override
  String get beerLogPriceHint => 'Precio (opcional)';

  @override
  String get beerLogCurrencyHint => 'Moneda, p. ej. USD';

  @override
  String get beerLogVenueHint => 'Lugar (opcional)';

  @override
  String get beerLogServingVolumeLabel => 'Volumen de la ración (ml)';

  @override
  String get beerLogSaveAction => 'Guardar';

  @override
  String get beerLogDeleteAction => 'Eliminar';

  @override
  String get beerLogDeleteConfirmTitle => '¿Eliminar este registro?';

  @override
  String get beerLogDeleteConfirmMessage => 'Esta acción no se puede deshacer.';

  @override
  String get beerLogSavedConfirmation => 'Registro guardado.';

  @override
  String get beerLogDeletedConfirmation => 'Registro eliminado.';

  @override
  String get beerLogErrorUnauthorized =>
      'Tu sesión ha caducado. Vuelve a iniciar sesión para continuar.';

  @override
  String get beerLogErrorServiceUnavailable =>
      'Esto no está disponible en este momento. Inténtalo de nuevo en un momento.';

  @override
  String get beerLogErrorNetwork =>
      'Revisa tu conexión a internet e inténtalo de nuevo.';

  @override
  String get beerLogErrorNotFound => 'No se pudo encontrar este registro.';

  @override
  String get beerLogErrorInvalidRequest =>
      'Revisa la fecha y los campos de precio/moneda e inténtalo de nuevo.';

  @override
  String get beerLogErrorGeneric =>
      'No pudimos guardar tu registro. Inténtalo de nuevo.';

  @override
  String get beerDetailAddToFavoritesAction => 'Añadir a favoritas';

  @override
  String get beerDetailRemoveFromFavoritesAction => 'Quitar de favoritas';

  @override
  String get beerDetailAddToWishlistAction => 'Añadir a la lista de deseos';

  @override
  String get beerDetailRemoveFromWishlistAction =>
      'Quitar de la lista de deseos';

  @override
  String get collectionTabLogged => 'Registradas';

  @override
  String get collectionTabFavorites => 'Favoritas';

  @override
  String get collectionTabWishlist => 'Lista de deseos';

  @override
  String get collectionFiltersSheetTitle => 'Filtros';

  @override
  String get collectionSortRecent => 'Reciente';

  @override
  String get collectionSortRating => 'Valoración';

  @override
  String get collectionSortName => 'Nombre';

  @override
  String get collectionLoggedEmptyMessage =>
      'Todavía no has registrado ninguna cerveza.';

  @override
  String get collectionFavoritesEmptyMessage =>
      'Todavía no has marcado ninguna cerveza como favorita.';

  @override
  String get collectionWishlistEmptyMessage => 'Tu lista de deseos está vacía.';

  @override
  String get collectionErrorUnauthorized =>
      'Tu sesión ha caducado. Vuelve a iniciar sesión para continuar.';

  @override
  String get collectionErrorServiceUnavailable =>
      'Esto no está disponible en este momento. Inténtalo de nuevo en un momento.';

  @override
  String get collectionErrorNetwork =>
      'Revisa tu conexión a internet e inténtalo de nuevo.';

  @override
  String get collectionErrorNotFound => 'No se pudo encontrar esta cerveza.';

  @override
  String get collectionErrorGeneric =>
      'No pudimos cargar tu colección. Inténtalo de nuevo.';

  @override
  String get mapModeAll => 'Todas las cervezas';

  @override
  String get mapModeTried => 'Probadas';

  @override
  String get mapModeNotTried => 'No probadas';

  @override
  String get mapModeFavorites => 'Favoritas';

  @override
  String get mapModeWishlist => 'Lista de deseos';

  @override
  String get mapModeBreweries => 'Cervecerías';

  @override
  String get mapSearchHint => 'Busca un país o región';

  @override
  String get mapUnavailableTitle => 'Mapa no disponible';

  @override
  String get mapUnavailableMessage =>
      'El mapa interactivo aún no está configurado en esta versión.';

  @override
  String get mapTruncatedMessage =>
      'Se muestra un conjunto parcial de resultados: no todo lo que coincide está visible.';

  @override
  String get mapBeersEmptyMessage => 'Ninguna cerveza coincide con esta vista.';

  @override
  String get mapBreweriesEmptyMessage =>
      'Ninguna cervecería coincide con esta vista.';

  @override
  String get mapBeerPreviewViewDetailsAction => 'Ver detalles';

  @override
  String get mapErrorUnauthorized =>
      'Tu sesión ha caducado. Vuelve a iniciar sesión para continuar.';

  @override
  String get mapErrorServiceUnavailable =>
      'Esto no está disponible en este momento. Inténtalo de nuevo en un momento.';

  @override
  String get mapErrorNetwork =>
      'Revisa tu conexión a internet e inténtalo de nuevo.';

  @override
  String get mapErrorGeneric =>
      'No pudimos cargar el mapa. Inténtalo de nuevo.';
}
