// app/lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/shop.dart';
import '../widgets/tobacco_map.dart';
import '../widgets/shop_list.dart';
import '../widgets/shop_details_modal.dart';
import '../screens/settings_screen.dart';
import '../controllers/home_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Itt példányosítjuk a logikát tartalmazó controllert
  late final HomeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HomeController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showShopDetails(Shop shop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          ShopDetailsModal(shop: shop, myPosition: _controller.myPosition),
    );
  }

  void _onShopSelectedFromList(Shop shop) {
    if (shop.lat != null && shop.long != null) {
      _controller.setSelectedIndex(0);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.animatedMapMove(LatLng(shop.lat!, shop.long!), 16.0);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _showShopDetails(shop);
        });
      });
    } else {
      _showShopDetails(shop);
    }
  }

  @override
  Widget build(BuildContext context) {
    // A ListenableBuilder figyeli a Controllert, és csak akkor frissíti a UI-t, ha szükséges
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              "Dohánybolt Kereső",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
            ),
            centerTitle: false,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Beállítások',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              // 1. RÉTEG: Térkép vagy Lista
              IndexedStack(
                index: _controller.selectedIndex,
                children: [
                  TobaccoMap(
                    shops: _controller.filteredShops,
                    myPosition: _controller.myPosition,
                    mapCenter: _controller.mapCenter,
                    onShopSelected: _showShopDetails,
                    onCameraMove: _controller.onMapPositionChanged,
                    onMapCreated: _controller.setMapController,
                  ),
                  ShopList(
                    shops: _controller.filteredShops,
                    // A myPosition helyett most már csak a formázó függvényt adjuk át!
                    getDistanceText: _controller.getFormattedDistance,
                    onShopSelected: _onShopSelectedFromList,
                    currentFilter: _controller.currentFilter,
                    onFilterChanged: _controller.setFilter,
                  ),
                ],
              ),

              // 2. RÉTEG: Keresés indikátor
              if (_controller.isFetchingArea && _controller.selectedIndex == 0)
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text(
                            "Új boltok keresése...",
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 3. RÉTEG: Kezdeti töltőképernyő ("A Függöny")
              AnimatedOpacity(
                opacity: (_controller.isLoading || !_controller.isMapReady)
                    ? 1.0
                    : 0.0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                child: IgnorePointer(
                  ignoring: !(_controller.isLoading || !_controller.isMapReady),
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
            ],
          ),

          floatingActionButton: _controller.selectedIndex == 0
              ? FloatingActionButton(
                  onPressed: _controller.isLocating
                      ? null
                      : () {
                          _controller.handleLocationPress(() {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Nem sikerült meghatározni a helyzetet.',
                                  ),
                                ),
                              );
                            }
                          });
                        },
                  tooltip: 'Helymeghatározás',
                  child: _controller.isLocating
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Icon(Icons.my_location),
                )
              : null,

          bottomNavigationBar: NavigationBar(
            height: 65,
            selectedIndex: _controller.selectedIndex,
            onDestinationSelected: _controller.setSelectedIndex,
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
      },
    );
  }
}
