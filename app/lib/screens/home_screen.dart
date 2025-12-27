import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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

// 1. JAVÍTÁS: 'SingleTicker...' helyett sima 'TickerProviderStateMixin'
// Ez engedi, hogy többször is indítsunk animációt összeomlás nélkül.
class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();

  List<Shop> shops = [];
  bool isLoading = true;
  LatLng? myPosition;
  LatLng mapCenter = const LatLng(47.50712, 19.04557);
  
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _firstLoad();
  }

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

  // 2. JAVÍTÁS: A Google Maps-szerű gyors működés
  Future<void> _handleLocationPress() async {
    // A) Azonnal lekérjük az utolsó ismert helyet (ez cache-ből jön, nagyon gyors)
    final cachedPosition = await _locationService.getLastKnownPosition();
    
    if (cachedPosition != null) {
      // Ha van cache, azonnal odahúzzuk a térképet
      _animatedMapMove(cachedPosition, 15.0);
      setState(() {
        myPosition = cachedPosition;
      });
    }

    // B) A háttérben elindítjuk a pontos GPS bemérést
    final freshPosition = await _locationService.determinePosition();
    
    if (freshPosition != null) {
      // Ha megvan a friss pont (és különbözik a régitől), akkor finomítunk
      setState(() {
        myPosition = freshPosition;
      });
      if (_selectedIndex == 0) {
        _animatedMapMove(freshPosition, 15.0);
      }
    } else if (cachedPosition == null && mounted) {
      // Ha se cache, se friss nincs (pl. pince), akkor szólunk
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nem sikerült meghatározni a helyzetet.')),
      );
    }
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    // Biztonsági ellenőrzés: ha nincs felépülve a widget, ne animáljunk
    if (!mounted) return;

    final latTween = Tween<double>(
        begin: _mapController.camera.center.latitude, end: destLocation.latitude);
    final lngTween = Tween<double>(
        begin: _mapController.camera.center.longitude, end: destLocation.longitude);
    final zoomTween = Tween<double>(
        begin: _mapController.camera.zoom, end: destZoom);

    final controller = AnimationController(
        duration: const Duration(milliseconds: 1000),
        vsync: this);

    final Animation<double> animation = CurvedAnimation(
        parent: controller, curve: Curves.fastOutSlowIn);

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
        mapController: _mapController,
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
        onPressed: _handleLocationPress,
        tooltip: 'Helymeghatározás',
        child: const Icon(Icons.my_location),
      ),

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