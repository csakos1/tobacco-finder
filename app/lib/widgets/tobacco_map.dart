import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/shop.dart';

class TobaccoMap extends StatelessWidget {
  final List<Shop> shops;
  final LatLng? myPosition;
  final LatLng mapCenter;
  final MapController mapController;
  // ÚJ: Callback függvény a marker kattintáshoz
  final Function(Shop) onShopSelected;

  const TobaccoMap({
    super.key,
    required this.shops,
    required this.myPosition,
    required this.mapCenter,
    required this.mapController,
    required this.onShopSelected, // Kötelező
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: mapCenter,
        initialZoom: 15.0,
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
        if (myPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: myPosition!,
                width: 60,
                height: 60,
                child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 50),
              ),
            ],
          ),
        MarkerLayer(
          markers: shops.map((shop) {
            return Marker(
              point: LatLng(shop.lat, shop.long),
              width: 80,
              height: 80,
              child: GestureDetector(
                onTap: () {
                  // Szólunk a HomeScreen-nek, hogy erre a boltra nyomtak
                  onShopSelected(shop);
                },
                child: const Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}