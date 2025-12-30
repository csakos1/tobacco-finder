import 'package:flutter/material.dart';
// KIVETTÜK: import 'package:flutter_map/flutter_map.dart'; // Ez már nem kell
import 'package:latlong2/latlong.dart'; // Ez marad a távolságszámításhoz!
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps; // ÚJ: Google Maps import aliassal

import '../models/shop.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../widgets/tobacco_map.dart';
import '../widgets/shop_list.dart';
import '../widgets/shop_details_modal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  
  // A régi MapController nem kell, a Google térkép máshogy kezeli
  // final MapController _mapController = MapController(); 

  List<Shop> shops = [];
  bool isLoading = true;
  
  // Ez továbbra is a latlong2 típusa, mert ezzel számoljuk a távolságot!
  LatLng? myPosition; 
  
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _firstLoad();
  }

  void _sortShopsByDistance() {
    if (myPosition == null) return;
    
    const Distance distance = Distance();
    
    shops.sort((a, b) {
      if (a.lat == null || a.long == null) return 1;
      if (b.lat == null || b.long == null) return -1;

      final double distA = distance.as(LengthUnit.Meter, myPosition!, LatLng(a.lat!, a.long!));
      final double distB = distance.as(LengthUnit.Meter, myPosition!, LatLng(b.lat!, b.long!));
      return distA.compareTo(distB);
    });
  }

  Future<void> _firstLoad() async {
    final position = await _locationService.determinePosition();
    if (position != null) {
      setState(() {
        myPosition = position;
      });
    }

    final fetchedShops = await _apiService.fetchShops();
    
    shops = fetchedShops;
    if (myPosition != null) {
      _sortShopsByDistance();
    }

    setState(() {
      isLoading = false;
    });
  }

  void _onShopSelected(Shop shop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ShopDetailsModal(
        shop: shop,
        myPosition: myPosition,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // 1. TÉRKÉP NÉZET
          TobaccoMap(
            shops: shops,
            // KONVERZIÓ: Itt alakítjuk át a latlong2-t Google Maps típusra!
            userLocation: myPosition != null 
                ? google_maps.LatLng(myPosition!.latitude, myPosition!.longitude) 
                : null,
            onShopSelected: _onShopSelected,
          ),
          
          // 2. LISTA NÉZET
          isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ShopList(
                  shops: shops, 
                  myPosition: myPosition,
                  onShopTap: _onShopSelected,
                ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Térkép',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_outlined),
            selectedIcon: Icon(Icons.list),
            label: 'Lista',
          ),
        ],
      ),
      // Lebegő gomb csak a térképnél (0. index) jelenjen meg
      floatingActionButton: _selectedIndex == 0 
          ? FloatingActionButton(
              onPressed: () async {
                // Újrakérjük a pozíciót
                final pos = await _locationService.determinePosition();
                if (pos != null) {
                  setState(() {
                    myPosition = pos;
                    _sortShopsByDistance();
                  });
                  // Megjegyzés: A Google térkép automatikusan követi a userLocation változást 
                  // a TobaccoMap widgetben megírt logika miatt (_moveCameraToUser).
                }
              },
              child: const Icon(Icons.my_location),
            )
          : null,
    );
  }
}