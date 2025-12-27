import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/shop.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
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
  
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Töltésjelző bekapcsolása frissítéskor
    setState(() {
      isLoading = true;
    });

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

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
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
      // M3: Az AppBar átlátszóbb, nincs nagy árnyék
      appBar: AppBar(
        title: const Text(
          'Dohánybolt Kereső',
          style: TextStyle(fontWeight: FontWeight.w600), // Vastagabb betű
        ),
        centerTitle: true, // Középre igazítva modernebb
        forceMaterialTransparency: false,
        scrolledUnderElevation: 4.0, // Ha görgetsz, finom árnyék jelenik meg
        // KIVETTÜK A GOMBOT INNEN
      ),
      
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : currentView,
      
      // M3: Visszakerült a jobb alsó sarokba a gomb!
      // A Material 3-ban ez már 'szögletesebb' (lekerekített négyzet).
      floatingActionButton: FloatingActionButton(
        onPressed: _initializeData,
        tooltip: 'Helymeghatározás',
        child: const Icon(Icons.my_location),
      ),

      // M3: Ez a modern alsó menü (NavigationBar a BottomNavigationBar helyett)
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected, // Csak a kiválasztottnak van felirata (opcionális, de szép)
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