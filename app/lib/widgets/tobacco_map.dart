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
  final void Function(CameraPosition)? onCameraMove; // <--- ÚJ PARAMÉTER
  final void Function(GoogleMapController)? onMapCreated;

  const TobaccoMap({
    super.key,
    required this.shops,
    required this.myPosition,
    required this.mapCenter,
    required this.onShopSelected,
    this.onCameraMove, // <--- ÚJ PARAMÉTER BEKÉRÉSE
    this.onMapCreated, // <--- ÚJ PARAMÉTER BEKÉRÉSEs
  });

  @override
  State<TobaccoMap> createState() => _TobaccoMapState();
}

class _TobaccoMapState extends State<TobaccoMap> {
  late ClusterManager<ShopClusterItem> _manager;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

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
      // ÚJ SOROK: Ezekkel szabályozzuk, hogy MIKOR essen szét a klaszter.
      // Ezzel a beállítással sokkal hamarabb megjelennek az egyedi boltok!
      levels: const [1, 4.25, 6.75, 10, 12.0, 13.0, 14.0, 15.0, 16],
      extraPercent:
          0.2, // Ne klaszterezze feleslegesen a messze lévő, nem látható boltokat
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
    // 1. Átalakítjuk a beérkező "ismeretlen" dolgot a mi típusunkra
    final Cluster<ShopClusterItem> cluster =
        clusterDynamic as Cluster<ShopClusterItem>;

    final bool isCluster = cluster.isMultiple;

    BitmapDescriptor icon;
    if (isCluster) {
      icon = await MarkerGenerator.createClusterMarker(cluster.count);
    } else {
      final shop = cluster.items.first.shop;
      final bool isOpen = ShopLogic.isOpenNow(shop.openingHours);
      icon = await MarkerGenerator.createShopMarker(isOpen);
    }

    return Marker(
      markerId: MarkerId(cluster.getId()),
      position: cluster.location,
      icon: icon,
      onTap: () {
        if (isCluster) {
          // Ha klaszterre kattint, ráközelít
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(cluster.location, 16.5),
          );
        } else {
          // Ha boltra kattint, megnyílik az ablak
          widget.onShopSelected(cluster.items.first.shop);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sötét vagy világos mód detektálása a rendszerből
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // ÚJ SOR: Ez kényszeríti a térképet, hogy azonnal váltson stílust, ha a téma változik!
    _mapController?.setMapStyle(
      isDarkMode ? MapStyles.darkStyle : MapStyles.lightStyle,
    );

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: widget.mapCenter,
        zoom: 15.0,
      ),
      markers: _markers,
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
        _manager.setMapId(controller.mapId);

        // Szólunk a HomeScreen-nek, hogy elkészült a térkép, és odaadjuk a vezérlőt!
        if (widget.onMapCreated != null) {
          widget.onMapCreated!(controller);
        }
      },
      onCameraMove: (CameraPosition position) {
        _manager.onCameraMove(position); // 1. Szólunk a klaszterezőnek
        if (widget.onCameraMove != null) {
          widget.onCameraMove!(position); // 2. Szólunk a HomeScreen-nek
        }
      },
      onCameraIdle: _manager.updateMap,

      // Saját UI elemek megtartása: kikapcsoljuk a beépített gombokat
      myLocationEnabled: widget.myPosition != null,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }
}
