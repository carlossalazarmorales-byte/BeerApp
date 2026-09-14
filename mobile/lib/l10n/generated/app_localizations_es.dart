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
  String get loadingStateMessage => 'Cargando…';

  @override
  String get emptyStateDefaultMessage => 'Todavía no hay nada aquí.';

  @override
  String get errorStateDefaultMessage => 'Algo salió mal.';

  @override
  String get errorStateRetryLabel => 'Reintentar';
}
