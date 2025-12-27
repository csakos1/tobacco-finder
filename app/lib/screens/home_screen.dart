import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/shop.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
// Importáljuk a két új widgetünket
import '../widgets/tobacco_map.dart';
import '../widgets/shop_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();

  List<Shop> shops = [];
  bool isLoading = true;
  LatLng? myPosition;
  LatLng mapCenter = const LatLng(47.50712, 19.04557);
  
  // Ez tárolja, melyik fülön vagyunk (0: Térkép, 1: Lista)
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final position = await _locationService.determinePosition();
    if (position != null) {
      setState(() {
        myPosition = position;
        mapCenter = position;
      });
    }

    final fetchedShops = await _apiService.fetchShops();
    setState(() {
      shops = fetchedShops;
      isLoading = false;
    });
  }

  // Fül váltáskor hívódik meg
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Kiválasztjuk, melyik widgetet mutassuk
    Widget currentView;
    if (_selectedIndex == 0) {
      currentView = TobaccoMap(
        shops: shops, 
        myPosition: myPosition, 
        mapCenter: mapCenter
      );
    } else {
      currentView = ShopList(
        shops: shops, 
        myPosition: myPosition
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dohánybolt Kereső'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.2),
        // Ha listán vagyunk, nem biztos, hogy kell a GPS gomb fent, de maradhat
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.blue),
            onPressed: _initializeData,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : currentView, // Itt jelenik meg a Térkép vagy a Lista
      
      // A Menü sáv alul
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Térkép',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Lista',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}