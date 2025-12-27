import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/shop.dart';
import 'shop_details_modal.dart';

class TobaccoMap extends StatelessWidget {
  final List<Shop> shops;
  final LatLng? myPosition;
  final LatLng mapCenter;

  const TobaccoMap({
    super.key,
    required this.shops,
    required this.myPosition,
    required this.mapCenter,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
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
        // Saját pozíció
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
        // Boltok
        MarkerLayer(
          markers: shops.map((shop) {
            return Marker(
              point: LatLng(shop.lat, shop.long),
              width: 80,
              height: 80,
              child: GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (context) => ShopDetailsModal(shop: shop, myPosition: myPosition),
                  );
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