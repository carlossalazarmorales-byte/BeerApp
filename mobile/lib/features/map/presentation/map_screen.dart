import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../design_system/components/cards/app_card.dart';
import '../../../design_system/components/inputs/app_text_field.dart';
import '../../../design_system/components/states/empty_state.dart';
import '../../../design_system/components/states/error_state.dart';
import '../../../design_system/components/states/loading_state.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/collection_refresh_signal.dart';
import '../../catalog/domain/catalog_repository.dart';
import '../data/map_config.dart';
import '../domain/map_mode.dart';
import '../domain/map_repository.dart';
import '../domain/models/map_beer.dart';
import '../domain/models/map_brewery.dart';
import 'beer_preview_card.dart';
import 'brewery_preview_card.dart';
import 'map_camera_fit.dart';
import 'map_cluster_utils.dart';
import 'map_controller.dart';
import 'map_data_synchronizer.dart';
import 'map_debug_log.dart';
import 'map_error_text.dart';
import 'map_mode_selector.dart';

/// The Map destination: a MapLibre world map of beer/brewery markers,
/// filtered by [MapController]'s single-select mode, with country/region
/// search and clustering. Replaces the Phase 1-7 placeholder.
class MapScreen extends StatefulWidget {
  const MapScreen({
    required this.repository,
    required this.catalogRepository,
    required this.refreshSignal,
    super.key,
  });

  final MapRepository repository;
  final CatalogRepository catalogRepository;
  final CollectionRefreshSignal refreshSignal;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _beersSourceId = 'map-beers-source';
  static const _breweriesSourceId = 'map-breweries-source';
  static const _beersClusterLayerId = 'map-beers-clusters';
  static const _beersClusterCountLayerId = 'map-beers-cluster-count';
  static const _beersPointsLayerId = 'map-beers-points';
  static const _breweriesClusterLayerId = 'map-breweries-clusters';
  static const _breweriesClusterCountLayerId = 'map-breweries-cluster-count';
  static const _breweriesPointsLayerId = 'map-breweries-points';

  static const List<Object> _hasPointCountFilter = ['has', 'point_count'];
  static const List<Object> _missingPointCountFilter = [
    '!',
    ['has', 'point_count'],
  ];
  static const List<Object> _clusterRadiusExpression = [
    'step',
    ['get', 'point_count'],
    16,
    10,
    20,
    50,
    26,
  ];

  static const double _clusterMaxZoom = 13;
  static const double _singlePointZoom = 12;

  /// Below this, a search result's bounding box is treated as a single
  /// point (all markers effectively co-located) -- `newLatLngBounds` on a
  /// zero-area box is meaningless/unstable, so this falls back to a fixed
  /// zoom centered on the box instead of attempting it.
  static const double _degenerateBoundsThreshold = 0.0005;

  late final MapController _controller = MapController(
    repository: widget.repository,
    catalogRepository: widget.catalogRepository,
    refreshSignal: widget.refreshSignal,
  );
  final TextEditingController _searchController = TextEditingController();

  MapLibreMapController? _mapLibreController;
  bool _sourcesReady = false;

  /// Pushes controller data to the map, doing no work when nothing changed.
  late final MapDataSynchronizer _synchronizer = MapDataSynchronizer(
    surface: _MapLibreSurface(() => _mapLibreController),
    beersSourceId: _beersSourceId,
    breweriesSourceId: _breweriesSourceId,
    beerLayerIds: const [
      _beersClusterLayerId,
      _beersClusterCountLayerId,
      _beersPointsLayerId,
    ],
    breweryLayerIds: const [
      _breweriesClusterLayerId,
      _breweriesClusterCountLayerId,
      _breweriesPointsLayerId,
    ],
  );
  String? _lastFitSignature;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _controller.loadInitial();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    unawaited(_syncMapData());
    _maybeFitCamera();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapLibreController = controller;
    controller.onFeatureTapped.add(_handleFeatureTapped);
  }

  Future<void> _onStyleLoaded() async {
    await _ensureSources();
    await _syncMapData();
  }

  Map<String, dynamic> get _emptyFeatureCollection => const {
    'type': 'FeatureCollection',
    'features': <Map<String, dynamic>>[],
  };

  Future<void> _ensureSources() async {
    final map = _mapLibreController;
    // Sources/layers for this map instance are added exactly once, whether
    // the style finishes loading before or after the first repository
    // response arrives -- every later update goes through setGeoJsonSource
    // in _syncMapData instead of re-adding sources/layers.
    if (map == null || _sourcesReady) return;
    _sourcesReady = true;

    await map.addSource(
      _beersSourceId,
      GeojsonSourceProperties(
        data: _emptyFeatureCollection,
        cluster: true,
        clusterMaxZoom: _clusterMaxZoom,
      ),
    );
    await map.addSource(
      _breweriesSourceId,
      GeojsonSourceProperties(
        data: _emptyFeatureCollection,
        cluster: true,
        clusterMaxZoom: _clusterMaxZoom,
      ),
    );

    await _addMarkerLayers(
      map,
      sourceId: _beersSourceId,
      clusterLayerId: _beersClusterLayerId,
      clusterCountLayerId: _beersClusterCountLayerId,
      pointsLayerId: _beersPointsLayerId,
    );
    await _addMarkerLayers(
      map,
      sourceId: _breweriesSourceId,
      clusterLayerId: _breweriesClusterLayerId,
      clusterCountLayerId: _breweriesClusterCountLayerId,
      pointsLayerId: _breweriesPointsLayerId,
    );

    // Breweries mode isn't the default -- start with its layers hidden so
    // beer and brewery markers are never both visible at once.
    await map.setLayerVisibility(_breweriesClusterLayerId, false);
    await map.setLayerVisibility(_breweriesClusterCountLayerId, false);
    await map.setLayerVisibility(_breweriesPointsLayerId, false);

    // The sources were just created EMPTY: whatever the synchronizer last sent
    // (for a previous map instance/style) is gone, so the next sync must
    // upload everything again.
    _synchronizer.invalidate();
  }

  Future<void> _addMarkerLayers(
    MapLibreMapController map, {
    required String sourceId,
    required String clusterLayerId,
    required String clusterCountLayerId,
    required String pointsLayerId,
  }) async {
    await map.addCircleLayer(
      sourceId,
      clusterLayerId,
      const CircleLayerProperties(
        circleColor: _AppMapColors.primaryHex,
        circleRadius: _clusterRadiusExpression,
        circleStrokeWidth: 2,
        circleStrokeColor: '#FFFFFF',
      ),
      filter: _hasPointCountFilter,
    );
    await map.addSymbolLayer(
      sourceId,
      clusterCountLayerId,
      const SymbolLayerProperties(
        textField: ['get', 'point_count_abbreviated'],
        textSize: 12,
        textColor: '#FFFFFF',
        textAllowOverlap: true,
        textIgnorePlacement: true,
      ),
      filter: _hasPointCountFilter,
    );
    await map.addCircleLayer(
      sourceId,
      pointsLayerId,
      const CircleLayerProperties(
        circleColor: _AppMapColors.primaryContainerHex,
        circleRadius: 8,
        circleStrokeWidth: 2,
        circleStrokeColor: _AppMapColors.primaryHex,
      ),
      filter: _missingPointCountFilter,
    );
  }

  Future<void> _syncMapData() async {
    if (_mapLibreController == null || !_sourcesReady) return;

    // Reads the LATEST controller state when it runs, and skips whatever the
    // map already has -- see MapDataSynchronizer.
    await _synchronizer.sync(
      () => MapSnapshot(
        beers: _controller.beers,
        breweries: _controller.breweries,
        mode: _controller.mode,
      ),
    );
  }

  Future<void> _handleFeatureTapped(
    math.Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) async {
    final map = _mapLibreController;
    if (map == null) return;

    final features = await map.queryRenderedFeatures(point, [layerId], null);
    if (features.isEmpty) return;
    final feature = features.first;
    final properties = feature is Map
        ? (feature['properties'] as Map?)?.cast<String, dynamic>()
        : null;
    if (properties == null) return;

    if (properties['cluster'] == true) {
      await _handleClusterTapped(map, layerId, feature, properties);
      return;
    }

    if (!mounted) return;
    if (layerId == _beersPointsLayerId) {
      final beer = _findBeer(properties['beer_id'] as String?);
      if (beer != null) _showBeerPreview(beer);
    } else if (layerId == _breweriesPointsLayerId) {
      final brewery = _findBrewery(properties['brewery_id'] as String?);
      if (brewery != null) _showBreweryPreview(brewery);
    }
  }

  /// Expands a tapped cluster by zooming to the zoom level MapLibre reports
  /// as the point where it splits, centered on the cluster **feature's own
  /// geometry** -- never the raw screen-tap `LatLng`, which is only where
  /// the user's finger landed on the (visually large, for a big cluster)
  /// cluster bubble and can be noticeably off from its true center. Every
  /// failure mode here (missing/invalid `cluster_id`, an unrecognized
  /// layer, missing geometry, a thrown or clearly-invalid expansion zoom)
  /// logs a debug-only diagnostic and leaves the camera untouched -- it
  /// never falls back to zooming to an arbitrary/guessed level, and never
  /// surfaces a raw MapLibre/provider error in the UI.
  Future<void> _handleClusterTapped(
    MapLibreMapController map,
    String layerId,
    Object feature,
    Map<String, dynamic> properties,
  ) async {
    final clusterId = parseClusterId(properties['cluster_id']);
    if (clusterId == null) {
      _logClusterIssue(
        'missing/invalid cluster_id on layer $layerId: '
        '${properties['cluster_id']} (${properties['cluster_id'].runtimeType})',
      );
      return;
    }

    final sourceId = clusterSourceIdForLayer(
      layerId,
      beersClusterLayerId: _beersClusterLayerId,
      beersClusterCountLayerId: _beersClusterCountLayerId,
      breweriesClusterLayerId: _breweriesClusterLayerId,
      breweriesClusterCountLayerId: _breweriesClusterCountLayerId,
      beersSourceId: _beersSourceId,
      breweriesSourceId: _breweriesSourceId,
    );
    if (sourceId == null) {
      _logClusterIssue('layer $layerId is not a known cluster layer');
      return;
    }

    final geometry = feature is Map ? feature['geometry'] : null;
    final clusterLatLng = geoJsonCoordinatesToLatLng(
      geometry is Map ? geometry['coordinates'] : null,
    );
    if (clusterLatLng == null) {
      _logClusterIssue(
        'cluster $clusterId on $sourceId has no usable geometry.coordinates: $geometry',
      );
      return;
    }

    final int expansionZoom;
    try {
      expansionZoom = await map.getClusterExpansionZoom(sourceId, clusterId);
    } catch (e, st) {
      logMapError('MapScreen.getClusterExpansionZoom', e, st);
      return;
    }
    // getClusterExpansionZoom documents 0 as its "not a known cluster on
    // this source" sentinel -- treated as invalid here rather than applied,
    // since animating to it would zoom out to a near-whole-world view
    // instead of expanding anything.
    if (expansionZoom <= 0) {
      _logClusterIssue(
        'invalid expansion zoom $expansionZoom for cluster $clusterId on $sourceId',
      );
      return;
    }

    await map.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(clusterLatLng.latitude, clusterLatLng.longitude),
        expansionZoom.toDouble(),
      ),
    );
  }

  void _logClusterIssue(String message) {
    logMapError(
      'MapScreen.handleClusterTapped',
      StateError(message),
      StackTrace.current,
    );
  }

  MapBeer? _findBeer(String? beerId) {
    if (beerId == null) return null;
    for (final beer in _controller.beers) {
      if (beer.beerId == beerId) return beer;
    }
    return null;
  }

  MapBrewery? _findBrewery(String? breweryId) {
    if (breweryId == null) return null;
    for (final brewery in _controller.breweries) {
      if (brewery.breweryId == breweryId) return brewery;
    }
    return null;
  }

  void _showBeerPreview(MapBeer beer) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => BeerPreviewCard(beer: beer),
    );
  }

  void _showBreweryPreview(MapBrewery brewery) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => BreweryPreviewCard(brewery: brewery),
    );
  }

  /// Fits the camera to the current mode's markers, but only right after a
  /// search resolves to a new country/region -- never on a plain mode
  /// switch or a signal-triggered refresh, so the user's own pan/zoom is
  /// never fought outside of an explicit search action.
  void _maybeFitCamera() {
    final map = _mapLibreController;
    if (map == null) return;

    final searchActive =
        _controller.appliedCountryId != null || _controller.query.isNotEmpty;
    final signature =
        '${_controller.mode}|${_controller.appliedCountryId}|${_controller.query}';
    // Notably: this must never accept (and must never record
    // _lastFitSignature for) the loading-start notification of a new
    // search -- at that point the controller's beers/breweries still hold
    // the *previous* result, and fitting to it (then marking the signature
    // "already fitted") would silently skip the real fit once the actual
    // filtered result arrives a moment later.
    final signatureToRecord = cameraFitSignatureToRecord(
      isLoading: _controller.isLoading,
      error: _controller.error,
      searchActive: searchActive,
      signature: signature,
      lastFitSignature: _lastFitSignature,
    );
    if (signatureToRecord == null) return;
    // Recorded even if the point set below turns out empty -- a completed
    // empty search is still a completed search (see
    // cameraFitSignatureToRecord's doc comment).
    _lastFitSignature = signatureToRecord;

    final points = _controller.mode == MapMode.breweries
        ? _controller.breweries
              .map((b) => (lat: b.latitude, lng: b.longitude))
              .toList()
        : _controller.beers
              .map((b) => (lat: b.latitude, lng: b.longitude))
              .toList();
    if (points.isEmpty) return;

    var minLat = double.infinity;
    var maxLat = -double.infinity;
    var minLng = double.infinity;
    var maxLng = -double.infinity;
    for (final p in points) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLng = math.min(minLng, p.lng);
      maxLng = math.max(maxLng, p.lng);
    }

    final isDegenerate =
        (maxLat - minLat) < _degenerateBoundsThreshold &&
        (maxLng - minLng) < _degenerateBoundsThreshold;
    if (isDegenerate) {
      unawaited(
        map.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2),
            _singlePointZoom,
          ),
        ),
      );
    } else {
      unawaited(
        map.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(minLat, minLng),
              northeast: LatLng(maxLat, maxLng),
            ),
            left: 48,
            top: 48,
            right: 48,
            bottom: 48,
          ),
        ),
      );
    }
  }

  String _emptyMessage(AppLocalizations l10n) =>
      _controller.mode == MapMode.breweries
      ? l10n.mapBreweriesEmptyMessage
      : l10n.mapBeersEmptyMessage;

  bool get _currentItemsEmpty => _controller.mode == MapMode.breweries
      ? _controller.breweries.isEmpty
      : _controller.beers.isEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (!MapConfig.isConfigured) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.navMap)),
        body: EmptyState(
          icon: Icons.map_outlined,
          message: l10n.mapUnavailableMessage,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMap)),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => Stack(
          children: [
            MapLibreMap(
              styleString: MapConfig.styleUrl!,
              initialCameraPosition: const CameraPosition(
                target: LatLng(20, 0),
                zoom: 1.4,
              ),
              onMapCreated: _onMapCreated,
              onStyleLoadedCallback: () => unawaited(_onStyleLoaded()),
            ),
            Positioned(
              top: AppSpacing.md,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: AppTextField(
                  controller: _searchController,
                  hintText: l10n.mapSearchHint,
                  leadingIcon: Icons.search,
                  onChanged: _controller.setQuery,
                ),
              ),
            ),
            Positioned(
              top: 64 + AppSpacing.lg,
              left: 0,
              right: 0,
              child: MapModeSelector(
                selected: _controller.mode,
                onChanged: _controller.setMode,
              ),
            ),
            if (_controller.isLoading && _currentItemsEmpty)
              const LoadingState(),
            if (_controller.error != null && _currentItemsEmpty)
              ErrorState(
                message: mapErrorText(context, _controller.error!),
                onRetry: _controller.refresh,
              ),
            if (!_controller.isLoading &&
                _controller.error == null &&
                _currentItemsEmpty)
              EmptyState(message: _emptyMessage(l10n)),
            if (_controller.truncated)
              Positioned(
                bottom: AppSpacing.lg,
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                child: _TruncatedBanner(message: l10n.mapTruncatedMessage),
              ),
          ],
        ),
      ),
    );
  }
}

/// Adapts MapLibre's controller to [MapSurface]. The controller is read lazily
/// because the platform view creates it after the screen's state exists; with
/// no controller yet, an operation is simply skipped (the next sync after the
/// style loads re-sends everything).
class _MapLibreSurface implements MapSurface {
  const _MapLibreSurface(this._controller);

  final MapLibreMapController? Function() _controller;

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> data,
  ) async {
    await _controller()?.setGeoJsonSource(sourceId, data);
  }

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) async {
    await _controller()?.setLayerVisibility(layerId, visible);
  }
}

class _TruncatedBanner extends StatelessWidget {
  const _TruncatedBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: AppRadii.mdRadius,
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Hex string constants for MapLibre style-spec `dynamic` color properties,
/// which take CSS color strings, not Flutter [Color] objects. Kept in sync
/// with `AppColors.primary`/`primaryContainer` by hand -- MapLibre's layer
/// properties don't accept a Flutter [Color] directly.
abstract final class _AppMapColors {
  static const String primaryHex = '#795900';
  static const String primaryContainerHex = '#FFBF00';
}
