import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart';
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
  
  // Google Map Controller referenciája
  gmaps.GoogleMapController? _mapController;

  List<Shop> shops = [];
  bool isLoading = true;
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

  Future<void> _handleLocationPress() async {
    final position = await _locationService.determinePosition();
    
    if (position != null) {
      setState(() {
        myPosition = position;
        _sortShopsByDistance();
      });

      if (_mapController != null) {
        _mapController!.animateCamera(
          gmaps.CameraUpdate.newLatLngZoom(
            gmaps.LatLng(position.latitude, position.longitude), 
            15.0
          )
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nem sikerült meghatározni a helyzetet.')),
        );
      }
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
      // 1. Átváltunk a térkép tabra
      setState(() {
        _selectedIndex = 0; 
      });

      // 2. Megvárjuk, amíg a Térkép widget felépül (ez a titka a fagyás elkerülésének)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Ha a kontroller létezik (már betöltött a térkép)
        if (_mapController != null) {
          _mapController!.animateCamera(
            gmaps.CameraUpdate.newLatLngZoom(
              gmaps.LatLng(shop.lat!, shop.long!), 
              16.0
            )
          );
          // Csak az animáció indítása után nyitjuk meg a modált
          _showShopDetails(shop);
        } else {
          // Ha valamiért még mindig nincs kontroller (ritka), akkor csak a modált nyitjuk
           _showShopDetails(shop);
        }
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
    
    // Térkép nézet
    if (_selectedIndex == 0) {
      gmaps.LatLng? googleUserLocation;
      if (myPosition != null) {
        googleUserLocation = gmaps.LatLng(myPosition!.latitude, myPosition!.longitude);
      }

      currentView = TobaccoMap(
        shops: shops, 
        userLocation: googleUserLocation, 
        onShopSelected: _showShopDetails,
        onMapCreated: (controller) {
          // Itt mentjük el a kontrollert, amikor a térkép létrejön
          _mapController = controller;
        },
      );
    } 
    // Lista nézet
    else {
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
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
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