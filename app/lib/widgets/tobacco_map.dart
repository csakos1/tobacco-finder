import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart'; // FONTOS IMPORT
import 'package:latlong2/latlong.dart';
import '../models/shop.dart';
import '../utils/shop_logic.dart';

class TobaccoMap extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: mapCenter,
        initialZoom: 15.0, // Lehet kicsit kijjebb zoomolni alapból, pl 13.0
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'hu.csakos.tobacco_finder',
          retinaMode: true,
        ),

        // --- 1. CLUSTERING RÉTEG (A sima MarkerLayer HELYETT) ---
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 45, // Minél nagyobb, annál agresszívebben csoportosít
            size: const Size(40, 40),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(50),
            maxZoom: 15, // Ezen a zoom szinten és felette szétbontja a csoportokat
            
            // A markerek listája (ugyanaz a logika, mint eddig)
            markers: shops.map((shop) {
               // Ideális esetben ezt a logikát kiszervezheted, hogy ne itt fusson minden rendereléskor
               // de a clustering miatt ez már nem lesz olyan lassú.
               bool isOpen = ShopLogic.isOpenNow(shop.openingHours);
               const double iconSize = 42.0;

               return Marker(
                point: LatLng(shop.lat, shop.long),
                width: iconSize,
                height: iconSize,
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () => onShopSelected(shop),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.location_on, color: colorScheme.primary, size: iconSize),
                      Positioned(
                        top: 8.5,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isOpen ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            
            // Így nézzen ki maga a Cluster (a csoportosító kör)
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
                    )
                  ]
                ),
                alignment: Alignment.center,
                child: Text(
                  markers.length.toString(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        ),

        // --- 2. SAJÁT POZÍCIÓ (Marad a rétegek tetején) ---
        if (myPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: myPosition!,
                width: 22,
                height: 22,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
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