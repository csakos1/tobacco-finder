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
      // Térkép stílus frissítése az új témához
      _mapController?.setMapStyle(
        isDarkMode ? MapStyles.darkStyle : MapStyles.lightStyle,
      );

      // Klaszterező kényszerítése a markerek újrarajzolására (sötét/világos ikonok)
      _manager.setItems(_getClusterItems());
    }
  }

  @override
  void didUpdateWidget(covariant TobaccoMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shops != oldWidget.shops) {
      _manager.setItems(_getClusterItems());
    }

    // Keresési pin változott → marker újragenerálás
    if (widget.searchPinPosition != oldWidget.searchPinPosition) {
      _rebuildSearchPinMarker();
    }
  }

  // --- Klaszterező inicializálása ---
  ClusterManager<ShopClusterItem> _initClusterManager() {
    return ClusterManager<ShopClusterItem>(
      _getClusterItems(),
      _updateClusterMarkers,
      markerBuilder: _markerBuilder,
      levels: const [1, 4.25, 6.75, 10, 12.0, 13.0, 14.0, 15.0, 16],
      extraPercent: 0.2,
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
            zoom: 15.0,
          ),
          markers: _allMarkers,

          padding: EdgeInsets.only(
            bottom: 10.0 + widget.bottomPadding,
            left: 12.0,
            top: 16.0,
          ),

          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            _manager.setMapId(controller.mapId);

            controller.setMapStyle(
              isDarkMode ? MapStyles.darkStyle : MapStyles.lightStyle,
            );

            if (widget.onMapCreated != null) {
              widget.onMapCreated!(controller);
            }
          },
          onCameraMove: (CameraPosition position) {
            _manager.onCameraMove(position);
            if (widget.onCameraMove != null) {
              widget.onCameraMove!(position);
            }
          },
          onCameraIdle: _manager.updateMap,

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
