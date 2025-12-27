import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // Kell a MapController miatt
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

// A 'SingleTickerProviderStateMixin' kell a sima animációhoz!
class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  
  // Ezzel irányítjuk a térképet
  final MapController _mapController = MapController();

  List<Shop> shops = [];
  bool isLoading = true; // Csak indításkor töltünk
  LatLng? myPosition;
  LatLng mapCenter = const LatLng(47.50712, 19.04557);
  
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _firstLoad();
  }

  // Ez csak az APP INDÍTÁSAKOR fut le (itt még lehet töltőképernyő)
  Future<void> _firstLoad() async {
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

  // Ez fut le, amikor rányomsz a gombra (NINCS töltőképernyő!)
  Future<void> _handleLocationPress() async {
    // Nem állítjuk az isLoading-et true-ra!
    
    // 1. Megpróbáljuk lekérni a pozíciót
    final position = await _locationService.determinePosition();
    
    if (position != null) {
      setState(() {
        myPosition = position;
        // Nem állítjuk át a mapCentert közvetlenül, mert az ugrást okozna
      });

      // 2. Ha Térkép nézetben vagyunk, animálva odahúzzuk
      if (_selectedIndex == 0) {
        _animatedMapMove(position, 15.0);
      }
    } else {
      // Opcionális: Dobhatsz egy kis üzenetet (SnackBar), ha nincs GPS
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nem sikerült meghatározni a helyzetet.')),
        );
      }
    }
  }

  // Ez a segédfüggvény végzi a "húzós" animációt
  void _animatedMapMove(LatLng destLocation, double destZoom) {
    // Létrehozunk egy animációt a jelenlegi és a célpont között
    final latTween = Tween<double>(
        begin: _mapController.camera.center.latitude, end: destLocation.latitude);
    final lngTween = Tween<double>(
        begin: _mapController.camera.center.longitude, end: destLocation.longitude);
    final zoomTween = Tween<double>(
        begin: _mapController.camera.zoom, end: destZoom);

    // Az animáció vezérlője
    final controller = AnimationController(
        duration: const Duration(milliseconds: 1000), // 1 másodperc alatt húzza oda
        vsync: this); // Ezért kellett a Mixin az osztály definíciónál

    final Animation<double> animation = CurvedAnimation(
        parent: controller, curve: Curves.fastOutSlowIn); // Szép gyorsuló-lassuló mozgás

    controller.addListener(() {
      _mapController.move(
          LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
          zoomTween.evaluate(animation));
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      }
    });

    controller.forward();
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
        mapCenter: mapCenter,
        mapController: _mapController, // Átadjuk a kontrollert
      );
    } else {
      currentView = ShopList(
        shops: shops, 
        myPosition: myPosition
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dohánybolt Kereső',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        scrolledUnderElevation: 4.0,
      ),
      
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : currentView,
      
      floatingActionButton: FloatingActionButton(
        onPressed: _handleLocationPress, // Az új, nem blokkoló függvény
        tooltip: 'Helymeghatározás',
        child: const Icon(Icons.my_location),
      ),

      bottomNavigationBar: NavigationBar(
        height: 65, // <--- ITT CSÖKKENTETTÜK A MAGASSÁGOT (Standard: 80)
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