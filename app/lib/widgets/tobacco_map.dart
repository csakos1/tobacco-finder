// app/lib/widgets/tobacco_map.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'
    hide ClusterManager, Cluster;
import 'package:google_maps_cluster_manager_2/google_maps_cluster_manager_2.dart';
import '../models/shop.dart';
import '../utils/shop_logic.dart';
import '../utils/map_styles.dart';
import '../utils/marker_generator.dart';

// Egy apró burkoló osztály a Klaszterező számára
class ShopClusterItem with ClusterItem {
  final Shop shop;
  ShopClusterItem(this.shop);

  @override
  LatLng get location => LatLng(shop.lat!, shop.long!);
}

class TobaccoMap extends StatefulWidget {
  final List<Shop> shops;
  final LatLng? myPosition;
  final LatLng mapCenter;
  final Function(Shop) onShopSelected;
  final void Function(CameraPosition)? onCameraMove;
  final void Function(GoogleMapController)? onMapCreated;
  final double bottomPadding;

  /// Callback a térkép üres területére koppintáskor.
  /// A HomeScreen ezt használja a billentyűzet bezárásához.
  final VoidCallback? onMapTapped;

  /// Keresési pin pozíciója. Ha nem null, egy piros pin jelenik meg ezen a ponton.
  final LatLng? searchPinPosition;

  /// Callback ami akkor hívódik, amikor a keresési pin-t el kell tüntetni.
  /// Akkor aktiválódik, ha a felhasználó egy boltos/klaszter pinre koppint.
  final VoidCallback? onSearchDismissed;

  const TobaccoMap({
    super.key,
    required this.shops,
    required this.myPosition,
    required this.mapCenter,
    required this.onShopSelected,
    this.onCameraMove,
    this.onMapCreated,
    this.bottomPadding = 0.0,
    this.onMapTapped,
    this.searchPinPosition,
    this.onSearchDismissed,
  });

  @override
  State<TobaccoMap> createState() => _TobaccoMapState();
}

class _TobaccoMapState extends State<TobaccoMap> {
  late ClusterManager<ShopClusterItem> _manager;
  GoogleMapController? _mapController;

  /// A klaszterező által generált markerek (boltok + klaszterek).
  Set<Marker> _clusterMarkers = {};

  /// A keresési pin markere (ha aktív). Cachelve van, hogy ne generáljuk újra minden frame-ben.
  Marker? _searchPinMarker;

  // Eltároljuk az aktuális témát, hogy tudjuk, mikor kell újrarajzolni a markereket
  bool? _lastIsDarkMode;

  // ---------------------------------------------------------------
  // A térkép kezdő zoom szintje. Konstansba kiemelve, hogy a
  // GoogleMap initialCameraPosition és a ClusterManager seed
  // mindig szinkronban legyen.
  // ---------------------------------------------------------------
  static const double _initialZoom = 15.0;

  // ---------------------------------------------------------------------------
  // SAJÁT ZOOM TRACKING
  //
  // A ClusterManager belső _zoom mezőjét a setMapId() aszinkron módon
  // felülírja a getZoomLevel() eredményével, ami animáció közben hibás
  // értéket adhat vissza. Ezért mi külön követjük az utolsó ismert
  // kamera pozíciót, és MINDEN updateMap/setItems hívás előtt
  // visszaírjuk a manager belső _zoom-ját az onCameraMove() seed-del.
  //
  // Ez a mező a _zoomGuard() metódussal együtt biztosítja, hogy a
  // klaszterezés mindig a valós zoom szinttel dolgozzon.
  // ---------------------------------------------------------------------------
  CameraPosition? _lastCameraPosition;

  @override
  void initState() {
    super.initState();
    _manager = _initClusterManager();
  }

  // ---------------------------------------------------------------------------
  // TÉMA-VÁLTÁS KEZELÉSE
  //
  // A didChangeDependencies() a helyes lifecycle hook a Theme.of(context)-ből
  // származó változások kezelésére. A framework automatikusan meghívja, amikor
  // bármely InheritedWidget (pl. Theme) megváltozik — tehát pontosan akkor fut,
  // amikor a téma vált. Így a build() tisztán deklaratív maradhat.
  // ---------------------------------------------------------------------------
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool themeChanged =
        _lastIsDarkMode != null && _lastIsDarkMode != isDarkMode;

    _lastIsDarkMode = isDarkMode;

    if (themeChanged) {
      // ---------------------------------------------------------------
      // MARKER CACHE INVALIDÁLÁS
      //
      // A régi téma ikonjait ki kell dobni, hogy a setItems() által
      // triggerelt _markerBuilder() újra lerajzolja őket az új színekkel.
      // Ez szinkron és azonnali — a rajzolás csak cache-miss-nél történik.
      // ---------------------------------------------------------------
      MarkerGenerator.invalidateThemeCache();

      // Térkép stílus frissítése az új témához
      _mapController?.setMapStyle(
        isDarkMode ? MapStyles.darkStyle : MapStyles.lightStyle,
      );

      // Klaszterező kényszerítése a markerek újrarajzolására (sötét/világos ikonok)
      _zoomGuard();
      _manager.setItems(_getClusterItems());
    }
  }

  @override
  void didUpdateWidget(covariant TobaccoMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shops != oldWidget.shops) {
      // A setItems() belsőleg updateMap()-et hív, ami a _zoom-ot használja.
      // A _zoomGuard() biztosítja, hogy a _zoom a valós értéken legyen.
      _zoomGuard();
      _manager.setItems(_getClusterItems());
    }

    // Keresési pin változott → marker újragenerálás
    if (widget.searchPinPosition != oldWidget.searchPinPosition) {
      _rebuildSearchPinMarker();
    }
  }

  // ---------------------------------------------------------------------------
  // ZOOM GUARD: A ClusterManager belső _zoom mezőjének szinkronizálása.
  //
  // A setMapId() aszinkron getZoomLevel() hívása felülírhatja a _zoom-ot
  // hibás értékkel (pl. animáció közben). Ez a metódus visszaírja az
  // utolsó ismert helyes kamera pozícióból (vagy a kezdő zoom-ból).
  //
  // Hívási helyek: onCameraIdle, didUpdateWidget (setItems előtt),
  // didChangeDependencies (setItems előtt), setMapId.then() callback.
  // ---------------------------------------------------------------------------
  void _zoomGuard() {
    final position =
        _lastCameraPosition ??
        CameraPosition(target: widget.mapCenter, zoom: _initialZoom);
    _manager.onCameraMove(position);
  }

  // ---------------------------------------------------------------------------
  // KLASZTEREZŐ INICIALIZÁLÁSA
  //
  // stopClusteringZoom: E zoom szint felett a klaszterezés kikapcsol,
  // minden bolt egyedi markerként jelenik meg.
  // ---------------------------------------------------------------------------
  // --- Klaszterező inicializálása ---
  ClusterManager<ShopClusterItem> _initClusterManager() {
    return ClusterManager<ShopClusterItem>(
      _getClusterItems(),
      _updateClusterMarkers,
      markerBuilder: _markerBuilder,
      levels: const [1, 4.25, 6.75, 10, 12.0, 13.0, 14.0, 15.0, 16],
      extraPercent: 0.2,
      maxItemsForMaxDistAlgo: 2000,
      stopClusteringZoom: 14.5,
    );
  }

  List<ShopClusterItem> _getClusterItems() {
    return widget.shops
        .where((s) => s.lat != null && s.long != null)
        .map((s) => ShopClusterItem(s))
        .toList();
  }

  void _updateClusterMarkers(Set<Marker> markers) {
    setState(() {
      _clusterMarkers = markers;
    });
  }

  /// Az összes marker: klaszter markerek + keresési pin (ha aktív).
  Set<Marker> get _allMarkers {
    if (_searchPinMarker != null) {
      return {..._clusterMarkers, _searchPinMarker!};
    }
    return _clusterMarkers;
  }

  // ---------------------------------------------------------------
  // KERESÉSI PIN: Aszinkron generálás és cache-elés
  // ---------------------------------------------------------------
  Future<void> _rebuildSearchPinMarker() async {
    if (widget.searchPinPosition == null) {
      if (_searchPinMarker != null) {
        setState(() {
          _searchPinMarker = null;
        });
      }
      return;
    }

    final BitmapDescriptor icon = await MarkerGenerator.createSearchPinMarker();

    if (!mounted) return;

    setState(() {
      _searchPinMarker = Marker(
        markerId: const MarkerId('search_pin'),
        position: widget.searchPinPosition!,
        icon: icon,
        zIndex: 2.0, // A keresési pin mindig a többi marker felett legyen
      );
    });
  }

  // --- Markerek aszinkron legenerálása ---
  Future<Marker> _markerBuilder(dynamic clusterDynamic) async {
    final Cluster<ShopClusterItem> cluster =
        clusterDynamic as Cluster<ShopClusterItem>;

    final bool isCluster = cluster.isMultiple;
    final bool isDarkMode = _lastIsDarkMode ?? false;

    BitmapDescriptor icon;
    if (isCluster) {
      icon = await MarkerGenerator.createClusterMarker(
        cluster.count,
        isDarkMode,
      );
    } else {
      final shop = cluster.items.first.shop;
      final bool isOpen = ShopLogic.isOpenNow(shop.openingHours);
      icon = await MarkerGenerator.createShopMarker(isOpen, isDarkMode);
    }

    return Marker(
      markerId: MarkerId(cluster.getId()),
      position: cluster.location,
      icon: icon,
      onTap: () {
        if (isCluster) {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(cluster.location, 16.5),
          );
          // Klaszter koppintáskor is megszüntetjük a keresést
          widget.onSearchDismissed?.call();
        } else {
          // Boltra koppintás → keresés megszüntetése + bolt részletek
          widget.onSearchDismissed?.call();
          widget.onShopSelected(cluster.items.first.shop);
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD — Tisztán deklaratív, side effect-ek nélkül.
  // A téma-függő logika (stílus váltás, marker újraépítés) a
  // didChangeDependencies()-ben történik.
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final topColor =
        theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;

    final bottomColor =
        theme.navigationBarTheme.backgroundColor ??
        theme.colorScheme.surfaceContainer;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topColor, topColor, bottomColor, bottomColor],
          stops: const [0.0, 0.5, 0.5, 1.0],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30.0),
        child: GoogleMap(
          style: isDarkMode ? MapStyles.darkStyle : MapStyles.lightStyle,
          initialCameraPosition: CameraPosition(
            target: widget.mapCenter,
            zoom: _initialZoom,
          ),
          markers: _allMarkers,

          padding: EdgeInsets.only(
            bottom: 10.0 + widget.bottomPadding,
            left: 12.0,
            top: 16.0,
          ),

          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;

            // -----------------------------------------------------------------
            // ZOOM RACE CONDITION JAVÍTÁS — 3 lépés:
            //
            // 1. SEED: A _zoom inicializálása a kezdő kamera pozícióval,
            //    MIELŐTT a setMapId() bármi mást csinálna. Ez biztosítja,
            //    hogy a `late double _zoom` mező már inicializálva legyen,
            //    ha az onCameraIdle korábban tüzel, mint a setMapId awaittje.
            //
            // 2. setMapId(withUpdate: false): Beállítja a _mapId-t (ami KELL
            //    a getVisibleRegion bounds lekérdezéshez), de NEM triggerel
            //    azonnali updateMap()-et a potenciálisan hibás getZoomLevel
            //    eredményével.
            //
            // 3. RE-SEED: Miután a setMapId() awaittje lefut és felülírja
            //    a _zoom-ot, visszaállítjuk a helyes értékre.
            //
            // A tényleges első klaszterezés az onCameraIdle-ből jön, ami
            // szintén _zoomGuard()-dal van védve.
            // -----------------------------------------------------------------
            _manager.onCameraMove(
              CameraPosition(target: widget.mapCenter, zoom: _initialZoom),
            );

            _manager.setMapId(controller.mapId, withUpdate: false).then((_) {
              // A setMapId belső getZoomLevel() felülírta a _zoom-ot →
              // visszaállítjuk a helyes értékre
              _zoomGuard();
            });

            controller.setMapStyle(
              isDarkMode ? MapStyles.darkStyle : MapStyles.lightStyle,
            );

            if (widget.onMapCreated != null) {
              widget.onMapCreated!(controller);
            }
          },
          onCameraMove: (CameraPosition position) {
            // Saját tracking — mindig a legfrissebb valós kamera pozíció
            _lastCameraPosition = position;

            _manager.onCameraMove(position);
            if (widget.onCameraMove != null) {
              widget.onCameraMove!(position);
            }
          },
          onCameraIdle: () {
            // Zoom guard: biztosítja, hogy a _zoom a valós értéken legyen
            // a klaszterezés futtatása előtt (a setMapId async getZoomLevel
            // felülírhatta hibás értékkel).
            _zoomGuard();
            _manager.updateMap();
          },

          // Térkép üres területére koppintás → billentyűzet bezárása
          onTap: (_) {
            widget.onMapTapped?.call();
          },

          myLocationEnabled: widget.myPosition != null,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
        ),
      ),
    );
  }
}
