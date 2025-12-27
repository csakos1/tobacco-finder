import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/shop.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../widgets/shop_details_modal.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Services
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();

  // State adatok
  List<Shop> shops = [];
  bool isLoading = true;
  LatLng? myPosition;
  LatLng mapCenter = const LatLng(47.50712, 19.04557); // Default Budapest

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // 1. Pozíció lekérése a service-ből
    final position = await _locationService.determinePosition();
    if (position != null) {
      setState(() {
        myPosition = position;
        mapCenter = position;
      });
    }

    // 2. Adatok lekérése a service-ből
    final fetchedShops = await _apiService.fetchShops();
    setState(() {
      shops = fetchedShops;
      isLoading = false;
    });
  }

  void _showShopDetails(BuildContext context, Shop shop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // backgroundColor: Colors.transparent, // <--- EZT A SORT VETTÜK KI
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // Itt adjuk át a modellt és a pozíciót a widgetnek
      builder: (context) => ShopDetailsModal(shop: shop, myPosition: myPosition),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
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
                        child: const Icon(Icons.person_pin_circle,
                            color: Colors.blue, size: 50),
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
                        onTap: () => _showShopDetails(context, shop),
                        child: const Icon(Icons.location_on,
                            color: Colors.red, size: 40),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _initializeData, // Újratöltés és újrapozicionálás
        child: const Icon(Icons.my_location),
      ),
    );
  }
}