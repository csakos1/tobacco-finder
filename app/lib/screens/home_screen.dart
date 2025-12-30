import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps; // Google Maps típusok
import 'package:latlong2/latlong.dart'; // Számításokhoz marad a latlong2
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
  
  // A régi MapController törölve lett, mert a Google Maps máshogy működik

  List<Shop> shops = [];
  bool isLoading = true;
  LatLng? myPosition; // Ez marad latlong2 típusú a távolságszámítás miatt
  
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _firstLoad();
  }

  // Távolság alapú rendezés (latlong2-t használ)
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

  Future<void> _handleLocationPress() async {
    final cachedPosition = await _locationService.getLastKnownPosition();
    
    if (cachedPosition != null) {
      setState(() {
        myPosition = cachedPosition;
        _sortShopsByDistance();
      });
    }

    final freshPosition = await _locationService.determinePosition();
    
    if (freshPosition != null) {
      setState(() {
        myPosition = freshPosition;
        _sortShopsByDistance(); 
      });
      // A TobaccoMap widget figyeli a userLocation változását (didUpdateWidget),
      // így automatikusan odamozgatja a kamerát, nem kell manuális vezérlés.
    } else if (cachedPosition == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nem sikerült meghatározni a helyzetet.')),
      );
    }
  }

  void _showShopDetails(Shop shop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ShopDetailsModal(shop: shop, myPosition: myPosition),
    );
  }

  void _onShopSelectedFromList(Shop shop) {
    if (shop.lat != null && shop.long != null) {
      setState(() {
        _selectedIndex = 0; // Átváltás térkép nézetre
      });

      // Google Maps esetén a kameramozgatást a widget state-je kezeli,
      // vagy a controlleren keresztül kellene, de a legegyszerűbb, ha
      // most csak megmutatjuk a részleteket.
      WidgetsBinding.instance.addPostFrameCallback((_) {
         _showShopDetails(shop);
      });
    } else {
      _showShopDetails(shop);
    }
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget currentView;
    
    if (_selectedIndex == 0) {
      // KONVERZIÓ: latlong2 -> google_maps_flutter LatLng
      gmaps.LatLng? googleUserLocation;
      if (myPosition != null) {
        googleUserLocation = gmaps.LatLng(myPosition!.latitude, myPosition!.longitude);
      }

      currentView = TobaccoMap(
        shops: shops, 
        userLocation: googleUserLocation, 
        onShopSelected: _showShopDetails,
        // mapCenter és mapController paraméterek TÖRÖLVE lettek
      );
    } else {
      currentView = ShopList(
        shops: shops, 
        myPosition: myPosition,
        onShopSelected: _onShopSelectedFromList,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dohánybolt Kereső',
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 22,
          ),
        ),
        centerTitle: false,
        scrolledUnderElevation: 4.0,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : currentView,
      
      floatingActionButton: _selectedIndex == 0 ? FloatingActionButton(
        onPressed: _handleLocationPress,
        tooltip: 'Helymeghatározás',
        child: const Icon(Icons.my_location),
      ) : null,

      bottomNavigationBar: NavigationBar(
        height: 65,
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.map),
            icon: Icon(Icons.map_outlined),
            label: 'Térkép',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.view_list),
            icon: Icon(Icons.view_list_outlined),
            label: 'Lista',
          ),
        ],
      ),
    );
  }
}