import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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
        
        // --- 1. SAJÁT POZÍCIÓ (Kicsi, diszkrét, középre igazított pötty) ---
        if (myPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: myPosition!,
                width: 22, // Sokkal kisebb méret
                height: 22,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue, // A "mag" színe
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3), // Vastag fehér keret
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),

        // --- 2. BOLTOK (Kisebb PIN, Pötty a lyukban) ---
        MarkerLayer(
          markers: shops.map((shop) {
            bool isOpen = ShopLogic.isOpenNow(shop.openingHours);
            
            // Ikon méret beállítása (ez alapján számoljuk a pötty helyét)
            const double iconSize = 42.0; 

            return Marker(
              point: LatLng(shop.lat, shop.long),
              width: iconSize, // A marker mérete igazodik az ikonhoz
              height: iconSize,
              // Felfelé toljuk, hogy a PIN hegye legyen a ponton
              alignment: Alignment.topCenter, 
              child: GestureDetector(
                onTap: () {
                  onShopSelected(shop);
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // A) Az alap PIN
                    Icon(
                      Icons.location_on, 
                      color: colorScheme.primary, 
                      size: iconSize
                    ),
                    
                    // B) A státusz jelző (Pontosan a lyuk közepére igazítva)
                    Positioned(
                      // Ez a "magic number" igazítja a lyukba. 
                      // 42-es méretnél a fenti 8-9 pixel a tökéletes pozíció.
                      top: 8.5, 
                      child: Container(
                        width: 12, // Épp kitölti a lyukat
                        height: 12,
                        decoration: BoxDecoration(
                          color: isOpen ? const Color(0xFF4CAF50) : const Color(0xFFE53935), // Élénk zöld/piros
                          shape: BoxShape.circle,
                          // Opcionális: egy nagyon vékony fehér keret, hogy elváljon a sötétkék pintől
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}