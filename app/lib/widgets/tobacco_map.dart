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

  const TobaccoMap({
    super.key,
    required this.shops,
    required this.myPosition,
    required this.mapCenter,
    required this.onShopSelected,
    this.onCameraMove,
    this.onMapCreated,
  });

  @override
  State<TobaccoMap> createState() => _TobaccoMapState();
}

class _TobaccoMapState extends State<TobaccoMap> {
  late ClusterManager<ShopClusterItem> _manager;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  // Eltároljuk az aktuális témát, hogy tudjuk, mikor kell újrarajzolni a markereket
  bool? _lastIsDarkMode;

  @override
  void initState() {
    super.initState();
    _manager = _initClusterManager();
  }

  @override
  void didUpdateWidget(covariant TobaccoMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shops != oldWidget.shops) {
      _manager.setItems(_getClusterItems());
    }
  }

  // --- Klaszterező inicializálása ---
  ClusterManager<ShopClusterItem> _initClusterManager() {
    return ClusterManager<ShopClusterItem>(
      _getClusterItems(),
      _updateMarkers,
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

  void _updateMarkers(Set<Marker> markers) {
    setState(() {
      _markers = markers;
    });
  }

  // --- Markerek aszinkron legenerálása ---
  Future<Marker> _markerBuilder(dynamic clusterDynamic) async {
    final Cluster<ShopClusterItem> cluster =
        clusterDynamic as Cluster<ShopClusterItem>;

    final bool isCluster = cluster.isMultiple;
    // Lekérjük a state-ből az utolsó ismert témát
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
        } else {
          widget.onShopSelected(cluster.items.first.shop);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Ha megváltozott a téma, kényszerítjük a klaszterezőt a markerek újrarajzolására
    if (_lastIsDarkMode != null && _lastIsDarkMode != isDarkMode) {
      _lastIsDarkMode = isDarkMode;
      Future.microtask(() => _manager.setItems(_getClusterItems()));
    } else {
      _lastIsDarkMode = isDarkMode;
    }

    _mapController?.setMapStyle(
      isDarkMode ? MapStyles.darkStyle : MapStyles.lightStyle,
    );

    // --- Színek dinamikus lekérése ---

    // JAVÍTÁS: A Material 3 AppBar alapértelmezetten a 'surface' színt használja,
    // ami világos módban kaphat egy minimális árnyalatot a seedColor-ból (nem tiszta fehér).
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
      // 30px-es lekerekítés marad
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30.0),
        child: GoogleMap(
          style: isDarkMode ? MapStyles.darkStyle : MapStyles.lightStyle,
          initialCameraPosition: CameraPosition(
            target: widget.mapCenter,
            zoom: 15.0,
          ),
          markers: _markers,

          // --- Frissített padding beállítások a Google logóhoz ---
          padding: const EdgeInsets.only(
            bottom: 10.0, // Az általad megadott érték (lejjebb)
            left: 12.0, // Az általad megadott érték (jobbra)
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
          myLocationEnabled: widget.myPosition != null,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
      ),
    );
  }
}
