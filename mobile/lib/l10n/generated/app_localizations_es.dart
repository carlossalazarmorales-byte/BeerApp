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
  String get navAdd => 'Añadir';

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
  String get scanSearchManuallyAction => 'Buscar manualmente';

  @override
  String get scanPermissionDeniedMessage =>
      'El acceso a la cámara solo es necesario para escanear códigos de barras. Si \"Reintentar cámara\" no muestra ningún aviso, activa el acceso a la cámara para BeerApp en los ajustes del sistema. Mientras tanto, aún puedes buscar cervezas manualmente.';

  @override
  String get scanTryCameraAgainAction => 'Reintentar cámara';

  @override
  String get scanUnsupportedMessage =>
      'El escaneo no está disponible en este dispositivo. Aún puedes buscar cervezas manualmente.';

  @override
  String get scanNotFoundMessage =>
      'No encontramos ninguna cerveza con ese código de barras en nuestro catálogo.';

  @override
  String get scanAgainAction => 'Escanear de nuevo';

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
  String get addBeerScreenTitle => 'Añadir una cerveza';

  @override
  String get addBeerSearchHint =>
      'Busca cervezas, cervecerías, estilos, países';

  @override
  String get addBeerNoResultsMessage =>
      'Ninguna cerveza coincide con tu búsqueda.';

  @override
  String get addBeerScanAction => 'Escanear código de barras';

  @override
  String get beerLockedSemanticLabel =>
      'Bloqueada. Aún no has registrado esta cerveza.';

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
  String get mapLegendZeroCatalog => 'Sin catálogo';

  @override
  String get mapLegendZeroHistory => 'Catálogo disponible';

  @override
  String get mapLegendHasHistory => 'En tu historial';

  @override
  String get mapLegendPointUntried => 'No está en tu historial';

  @override
  String get mapLegendPointTried => 'En tu historial';

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

  @override
  String get profileStatisticsCardTitle => 'Estadísticas';

  @override
  String get profileStatisticsCardSubtitle =>
      'Consulta tu actividad cervecera personal';

  @override
  String get statisticsScreenTitle => 'Estadísticas';

  @override
  String get statisticsEmptyMessage =>
      'Registra una cerveza o marca una como favorita para ver tus estadísticas aquí.';

  @override
  String get statisticsErrorUnauthorized =>
      'Tu sesión ha caducado. Vuelve a iniciar sesión para continuar.';

  @override
  String get statisticsErrorServiceUnavailable =>
      'Esto no está disponible en este momento. Inténtalo de nuevo en un momento.';

  @override
  String get statisticsErrorNetwork =>
      'Revisa tu conexión a internet e inténtalo de nuevo.';

  @override
  String get statisticsErrorGeneric =>
      'No pudimos cargar tus estadísticas. Inténtalo de nuevo.';

  @override
  String get statisticsTotalUniqueBeersLabel => 'Cervezas únicas';

  @override
  String get statisticsTotalLogsLabel => 'Registros totales';

  @override
  String get statisticsCountriesDiscoveredLabel => 'Países';

  @override
  String get statisticsStylesDiscoveredLabel => 'Estilos';

  @override
  String get statisticsBreweriesDiscoveredLabel => 'Cervecerías';

  @override
  String get statisticsAverageRatingLabel => 'Valoración media';

  @override
  String get statisticsAverageRatingNoneLabel => '—';

  @override
  String get statisticsAmountSpentSectionTitle => 'Cantidad gastada';

  @override
  String get statisticsAmountSpentEmptyLabel =>
      'Aún no hay registros con precio.';

  @override
  String get statisticsFavoritesSectionTitle => 'Favoritos';

  @override
  String get statisticsFavoriteStyleLabel => 'Estilo';

  @override
  String get statisticsFavoriteCountryLabel => 'País';

  @override
  String get statisticsFavoriteBreweryLabel => 'Cervecería';

  @override
  String get statisticsFavoriteNoneLabel => '—';

  @override
  String get statisticsMonthlyActivityChartTitle => 'Actividad mensual';

  @override
  String get statisticsYearlyActivityChartTitle => 'Actividad anual';

  @override
  String get statisticsYearlyActivityEmptyLabel =>
      'Aún no hay actividad registrada.';

  @override
  String get statisticsMonthJan => 'ene';

  @override
  String get statisticsMonthFeb => 'feb';

  @override
  String get statisticsMonthMar => 'mar';

  @override
  String get statisticsMonthApr => 'abr';

  @override
  String get statisticsMonthMay => 'may';

  @override
  String get statisticsMonthJun => 'jun';

  @override
  String get statisticsMonthJul => 'jul';

  @override
  String get statisticsMonthAug => 'ago';

  @override
  String get statisticsMonthSep => 'sep';

  @override
  String get statisticsMonthOct => 'oct';

  @override
  String get statisticsMonthNov => 'nov';

  @override
  String get statisticsMonthDec => 'dic';

  @override
  String get profileAchievementsCardTitle => 'Logros';

  @override
  String get profileAchievementsCardSubtitle =>
      'Consulta lo que has desbloqueado';

  @override
  String get achievementsScreenTitle => 'Logros';

  @override
  String get achievementsErrorUnauthorized =>
      'Tu sesión ha caducado. Vuelve a iniciar sesión para continuar.';

  @override
  String get achievementsErrorServiceUnavailable =>
      'Esto no está disponible en este momento. Inténtalo de nuevo en un momento.';

  @override
  String get achievementsErrorNetwork =>
      'Revisa tu conexión a internet e inténtalo de nuevo.';

  @override
  String get achievementsErrorGeneric =>
      'No pudimos cargar tus logros. Inténtalo de nuevo.';

  @override
  String get achievementsLockedLabel => 'Bloqueado';

  @override
  String achievementsUnlockedOnLabel(String date) {
    return 'Desbloqueado el $date';
  }

  @override
  String achievementsProgressFormat(int current, int target) {
    return '$current / $target';
  }

  @override
  String achievementsNewUnlockBannerOne(String name) {
    return 'Logro desbloqueado: $name';
  }

  @override
  String achievementsNewUnlockBannerMany(int count) {
    return '$count nuevos logros desbloqueados';
  }

  @override
  String get achievementsCategoryBeersTried => 'Cervezas probadas';

  @override
  String get achievementsCategoryCountries => 'Países';

  @override
  String get achievementsCategoryStyles => 'Estilos';

  @override
  String get achievementsCategoryBreweries => 'Cervecerías';

  @override
  String get achievementsCategoryReviews => 'Reseñas';

  @override
  String get achievementsCategoryRatings => 'Valoraciones';

  @override
  String get achievementsCategoryCollection => 'Colección';

  @override
  String get achievementsCategorySpecial => 'Especiales';

  @override
  String get achievementNameCollectionFirstFavorite => 'Primer favorito';

  @override
  String get achievementDescriptionCollectionFirstFavorite =>
      'Añade una cerveza a tus favoritos.';

  @override
  String get achievementNameCollectionFirstWishlist => 'Primer deseo';

  @override
  String get achievementDescriptionCollectionFirstWishlist =>
      'Añade una cerveza a tu lista de deseos.';

  @override
  String get achievementNameCollectionCurator => 'Curador';

  @override
  String get achievementDescriptionCollectionCurator =>
      'Ten al menos una cerveza favorita y una en tu lista de deseos.';

  @override
  String get profileEditProfileCardTitle => 'Editar perfil';

  @override
  String get profileEditProfileCardSubtitle =>
      'Nombre de usuario y nombre visible';

  @override
  String get profileSettingsCardTitle => 'Ajustes';

  @override
  String get profileSettingsCardSubtitle => 'Moneda, idioma y cuenta';

  @override
  String get editProfileScreenTitle => 'Editar perfil';

  @override
  String get displayNameHint => 'Nombre visible (opcional)';

  @override
  String get editProfileSaveAction => 'Guardar';

  @override
  String get editProfileSuccessMessage => 'Perfil actualizado.';

  @override
  String get settingsScreenTitle => 'Ajustes';

  @override
  String get settingsCurrencyRowTitle => 'Moneda preferida';

  @override
  String get settingsCurrencyNotSet => 'Sin definir';

  @override
  String get settingsCurrencyPickerTitle => 'Moneda preferida';

  @override
  String get settingsCurrencyClearOption => 'Sin definir';

  @override
  String get settingsCurrencyInvalidError => 'Esa moneda no es válida.';

  @override
  String get settingsLanguageRowTitle => 'Idioma';

  @override
  String get settingsLanguagePickerTitle => 'Idioma';

  @override
  String get settingsLanguageSystemOption => 'Predeterminado del sistema';

  @override
  String get settingsLanguageEnglishOption => 'English';

  @override
  String get settingsLanguageSpanishOption => 'Español';

  @override
  String get settingsChangePasswordRowTitle => 'Cambiar contraseña';

  @override
  String get settingsChangePasswordRowSubtitle =>
      'Te enviaremos un enlace por correo';

  @override
  String get settingsChangePasswordConfirmation =>
      'Revisa tu correo para restablecer tu contraseña.';

  @override
  String get settingsPrivacySettingsRowTitle => 'Ajustes de privacidad';

  @override
  String get settingsPrivacyPolicyRowTitle => 'Política de privacidad';

  @override
  String get settingsTermsOfServiceRowTitle => 'Términos del servicio';

  @override
  String get settingsLegalPlaceholderDescription =>
      'Este contenido aún no está disponible. Vuelve a consultarlo antes del lanzamiento.';

  @override
  String get settingsLegalLinkOpenFailed =>
      'No se pudo abrir el enlace. Inténtalo de nuevo más tarde.';

  @override
  String get startupFailureConfigurationTitle =>
      'BeerApp no está configurada correctamente';

  @override
  String get startupFailureConfigurationMessage =>
      'Esta versión de la app no tiene la configuración necesaria. Actualiza BeerApp o inténtalo de nuevo más tarde.';

  @override
  String get startupFailureInitializationTitle => 'BeerApp no pudo iniciarse';

  @override
  String get startupFailureInitializationMessage =>
      'Algo salió mal al iniciar la app. Inténtalo de nuevo.';

  @override
  String get settingsDeleteAccountRowTitle => 'Eliminar cuenta';

  @override
  String get settingsDeleteAccountRowSubtitle =>
      'Borra permanentemente tu cuenta y tus datos';

  @override
  String get deleteAccountDialogTitle => '¿Eliminar tu cuenta?';

  @override
  String get deleteAccountDialogMessage =>
      'Esto elimina permanentemente tu cuenta, incluidos tus registros, tu colección y tus logros. Esta acción no se puede deshacer.';

  @override
  String deleteAccountDialogConfirmHint(String username) {
    return 'Escribe tu nombre de usuario, $username, para confirmar.';
  }

  @override
  String get deleteAccountConfirmAction => 'Eliminar cuenta';

  @override
  String get deleteAccountGenericError =>
      'No se pudo eliminar tu cuenta. Inténtalo de nuevo.';

  @override
  String get profileContributionsCardTitle => 'Contribuciones';

  @override
  String get profileContributionsCardSubtitle =>
      'Sugiere cervezas y cervecerías que faltan';

  @override
  String get contributionsScreenTitle => 'Contribuciones';

  @override
  String get contributionsIntro =>
      'Las sugerencias se revisan antes de poder entrar en el catálogo. Nada de lo que envíes aquí aparece en el catálogo hasta entonces.';

  @override
  String get contributionsSuggestBeerAction => 'Sugerir una cerveza';

  @override
  String get contributionsSuggestBreweryAction => 'Sugerir una cervecería';

  @override
  String get contributionsHistoryTitle => 'Tus sugerencias';

  @override
  String get contributionsEmptyMessage => 'Todavía no has sugerido nada.';

  @override
  String get contributionKindBeer => 'Cerveza';

  @override
  String get contributionKindBrewery => 'Cervecería';

  @override
  String get contributionStatusPending => 'Pendiente de revisión';

  @override
  String get contributionStatusApproved => 'Aprobada';

  @override
  String get contributionStatusRejected => 'No aceptada';

  @override
  String get contributionStatusUnknown => 'Desconocido';

  @override
  String get contributionSubmitAction => 'Enviar sugerencia';

  @override
  String get contributionSuggestThisBeerAction => 'Sugerir esta cerveza';

  @override
  String get contributionValidationRequired => 'Este campo es obligatorio.';

  @override
  String contributionValidationTooLong(int max) {
    return 'Debe tener como máximo $max caracteres.';
  }

  @override
  String get contributionValidationAbv =>
      'Introduce un ABV entre 0 y 99,99 con como máximo 2 decimales.';

  @override
  String get contributionValidationBarcode =>
      'Introduce solo dígitos (8, 12 o 13 dígitos).';

  @override
  String get contributionValidationBreweryRequired =>
      'Elige una cervecería o escribe su nombre.';

  @override
  String get contributionValidationCountryRequired =>
      'Elige un país o escribe su nombre.';

  @override
  String get contributionOptionNotListed => 'No aparece';

  @override
  String get contributionOptionNoStyle => 'Sin estilo';

  @override
  String get suggestBeerScreenTitle => 'Sugerir una cerveza';

  @override
  String get suggestBeerNameHint => 'Nombre de la cerveza';

  @override
  String get suggestBeerBreweryLabel => 'Cervecería';

  @override
  String get suggestBeerProposedBreweryHint => 'Nombre de la cervecería';

  @override
  String get suggestBeerStyleLabel => 'Estilo (opcional)';

  @override
  String get suggestBeerProposedStyleHint => 'Nombre del estilo';

  @override
  String get suggestBeerAbvHint => 'ABV % (opcional)';

  @override
  String get suggestBeerBarcodeHint => 'Código de barras (opcional)';

  @override
  String get suggestBreweryScreenTitle => 'Sugerir una cervecería';

  @override
  String get suggestBreweryNameHint => 'Nombre de la cervecería';

  @override
  String get suggestBreweryCountryLabel => 'País';

  @override
  String get suggestBreweryProposedCountryHint => 'Nombre del país';

  @override
  String get suggestBreweryRegionHint => 'Región (opcional)';

  @override
  String get suggestBreweryCityHint => 'Ciudad (opcional)';

  @override
  String get contributionDuplicateSheetTitle =>
      'Se han encontrado entradas similares';

  @override
  String get contributionDuplicateSheetBody =>
      'Revísalas antes de enviar. Si la tuya es distinta, aún puedes enviarla.';

  @override
  String get contributionDuplicateSimilarBeers =>
      'Cervezas similares que ya están en el catálogo';

  @override
  String get contributionDuplicateSimilarBreweries =>
      'Cervecerías similares que ya están en el catálogo';

  @override
  String get contributionDuplicatePendingBarcode =>
      'Puede que otra sugerencia pendiente ya incluya este código de barras.';

  @override
  String get contributionDuplicateReviewAction => 'Revisar';

  @override
  String get contributionDuplicateSubmitAnywayAction => 'Enviar de todos modos';

  @override
  String get contributionDuplicateViewAction => 'Ver';

  @override
  String get contributionViewExistingBeerAction => 'Ver cerveza existente';

  @override
  String get contributionSubmittedTitle => 'Sugerencia recibida';

  @override
  String get contributionSubmittedBody =>
      'Está pendiente de revisión. No aparecerá en el catálogo hasta que se haya revisado.';

  @override
  String get contributionSubmittedDoneAction => 'Hecho';

  @override
  String get contributionDiscardTitle => '¿Descartar esta sugerencia?';

  @override
  String get contributionDiscardBody => 'Se perderán tus cambios.';

  @override
  String get contributionDiscardConfirmAction => 'Descartar';

  @override
  String get contributionDiscardCancelAction => 'Seguir editando';

  @override
  String get contributionErrorUnauthorized =>
      'Tu sesión ha caducado. Inicia sesión de nuevo.';

  @override
  String get contributionErrorServiceUnavailable =>
      'El servicio no está disponible temporalmente. Inténtalo de nuevo en breve.';

  @override
  String get contributionErrorNetwork =>
      'No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get contributionErrorValidation =>
      'Algunos datos no son válidos. Revisa los campos e inténtalo de nuevo.';

  @override
  String get contributionErrorNotFound =>
      'Una de las entradas del catálogo elegidas ya no existe. Elige de nuevo.';

  @override
  String get contributionErrorBarcodeInCatalog =>
      'Este código de barras ya pertenece a una cerveza del catálogo.';

  @override
  String get contributionErrorAlreadySubmitted =>
      'Ya tienes una sugerencia idéntica pendiente de revisión.';

  @override
  String get contributionErrorGeneric => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String collectionRatingSemanticLabel(int rating) {
    return 'Valoración: $rating de 5';
  }

  @override
  String get statisticsMonthlyChartSemanticEmpty =>
      'Actividad mensual: sin registros en los últimos 12 meses.';

  @override
  String statisticsMonthlyChartSemanticSummary(
    int total,
    String month,
    int count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total registros',
      one: '1 registro',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count registros',
      one: '1 registro',
    );
    return 'Actividad mensual de los últimos 12 meses: $_temp0 en total. Mes con más registros: $month, $_temp1.';
  }

  @override
  String statisticsYearlyChartSemanticEntry(int year, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count registros',
      one: '1 registro',
    );
    return '$year: $_temp0';
  }

  @override
  String statisticsYearlyChartSemanticSummary(String entries) {
    return 'Actividad anual: $entries.';
  }

  @override
  String statisticsMonthLongName(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      'january': 'enero',
      'february': 'febrero',
      'march': 'marzo',
      'april': 'abril',
      'may': 'mayo',
      'june': 'junio',
      'july': 'julio',
      'august': 'agosto',
      'september': 'septiembre',
      'october': 'octubre',
      'november': 'noviembre',
      'december': 'diciembre',
      'other': '',
    });
    return '$_temp0';
  }
}
