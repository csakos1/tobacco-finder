import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import '../models/shop.dart';
import '../utils/shop_logic.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

class TobaccoMap extends StatefulWidget {
  final List<Shop> shops;
  final LatLng? myPosition;
  final LatLng mapCenter;
  final MapController mapController;
  final Function(Shop) onShopSelected;

  const TobaccoMap({
    super.key,
    required this.shops,
    required this.myPosition,
    required this.mapCenter,
    required this.mapController,
    required this.onShopSelected,
  });

  @override
  State<TobaccoMap> createState() => _TobaccoMapState();
}

class _TobaccoMapState extends State<TobaccoMap> {
  // 1. JAVÍTÁS: Kezdőértéknek üres listát adunk, hogy biztonságos legyen
  List<Marker> _cachedMarkers = [];

  @override
  void initState() {
    super.initState();
    // 2. JAVÍTÁS: Innen KIVETTÜK a _buildMarkers()-t!
    // Itt még nem szabad Theme.of(context)-et hívni, mert összeomlik az app.
  }

  // 3. JAVÍTÁS: Ide tettük át a marker gyártást!
  // Ez a függvény fut le, amikor a Widget teljesen létrejött és már biztonságos a Context/Theme használata.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _buildMarkers();
  }

  @override
  void didUpdateWidget(covariant TobaccoMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ha változott a lista, újraépítjük a markereket
    if (widget.shops != oldWidget.shops) {
      _buildMarkers();
    }
  }

  void _buildMarkers() {
    // Itt használjuk a Theme-et, ami miatt a hiba volt
    final colorScheme = Theme.of(context).colorScheme;
    final validShops = widget.shops
        .where((s) => s.lat != null && s.long != null)
        .toList();

    // Nem kell setState, mert a didChangeDependencies és didUpdateWidget
    // után a Flutter automatikusan meghívja a build-et.
    _cachedMarkers = validShops.map((shop) {
      bool isOpen = ShopLogic.isOpenNow(shop.openingHours);
      const double iconSize = 42.0;

      return Marker(
        point: LatLng(shop.lat!, shop.long!),
        width: iconSize,
        height: iconSize,
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onTap: () => widget.onShopSelected(shop),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.location_on,
                color: colorScheme.primary,
                size: iconSize,
              ),
              Positioned(
                top: 10,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isOpen
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFE53935),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FlutterMap(
      mapController: widget.mapController,
      options: MapOptions(
        initialCenter: widget.mapCenter,
        initialZoom: 15.0,
        interactionOptions: const InteractionOptions(
          flags:
              InteractiveFlag.drag |
              InteractiveFlag.pinchZoom |
              InteractiveFlag.doubleTapZoom,
        ),
      ),
      children: [
        TileLayer(
          tileProvider: CancellableNetworkTileProvider(),
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'hu.csakos.tobacco_finder',
          retinaMode: false,
          panBuffer: 1,
        ),

        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 45,
            size: const Size(40, 40),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(50),
            maxZoom: 15,
            markers: _cachedMarkers, // A legyártott listát használjuk
            builder: (context, markers) {
              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 5,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  markers.length.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ),

        if (widget.myPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: widget.myPosition!,
                width: 22,
                height: 22,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
