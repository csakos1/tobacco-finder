// app/lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/shop.dart';
import '../widgets/tobacco_map.dart';
import '../widgets/shop_list.dart';
import '../widgets/shop_details_modal.dart';
import '../screens/settings_screen.dart';
import '../controllers/home_controller.dart';
import '../widgets/place_search_bar.dart';
import 'dart:math' as math; // <-- ÚJ IMPORT a fájl tetejére

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            scrolledUnderElevation: _controller.selectedIndex == 0 ? 0.0 : null,
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

          body: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
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
                        getDistanceText: _controller.getFormattedDistance,
                        onShopSelected: _onShopSelectedFromList,
                        currentFilter: _controller.currentFilter,
                        onFilterChanged: _controller.setFilter,
                      ),
                    ],
                  ),

                  // --- ÚJ RÉTEG: Material 3 Iránytű ---
                  // Csak akkor jelenik meg, ha a térkép el van forgatva
                  if (_controller.selectedIndex == 0 &&
                      _controller.isMapRotated)
                    Positioned(
                      top: 88, // A keresősáv alá pozicionáljuk
                      left: 16, // Bal felülre
                      child: FloatingActionButton.small(
                        heroTag:
                            'compass_fab', // Konfliktus elkerülése a GPS gombbal
                        onPressed: _controller.resetCompass,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        elevation: 4,
                        // Itt történik a varázslat: az ikont ellentétesen forgatjuk a térképpel!
                        child: Transform.rotate(
                          angle: -_controller.mapBearing * (math.pi / 180),
                          child: const Icon(Icons.navigation_rounded, size: 22),
                        ),
                      ),
                    ),

                  // --- Keresősáv ---
                  if (_controller.selectedIndex == 0)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: PlaceSearchBar(
                        // A teljes szabad magasság mínusz 32px (16 felülre, 16 alulra)
                        maxAvailableHeight: constraints.maxHeight - 32.0,
                        onPlaceSelected: (LatLng location) {
                          _controller.animatedMapMove(location, 14.0);
                        },
                      ),
                    ),

                  // 2. RÉTEG: Keresés indikátor a térképen
                  if (_controller.isFetchingArea &&
                      _controller.selectedIndex == 0)
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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

                  // 3. RÉTEG: Közös Töltő és Hiba Képernyő ("A Függöny")
                  AnimatedOpacity(
                    opacity:
                        (_controller.isLoading ||
                            !_controller.isMapReady ||
                            _controller.errorMessage != null)
                        ? 1.0
                        : 0.0,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    child: IgnorePointer(
                      ignoring:
                          !(_controller.isLoading ||
                              !_controller.isMapReady ||
                              _controller.errorMessage != null),
                      child: Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: double.infinity,
                        height: double.infinity,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _controller.errorMessage != null
                              ? // --- HIBA UI ---
                                Center(
                                  key: const ValueKey('error_view'),
                                  child: SingleChildScrollView(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.wifi_off_rounded,
                                            size: 80,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error
                                                .withOpacity(0.8),
                                          ),
                                          const SizedBox(height: 24),
                                          Text(
                                            _controller.errorMessage ??
                                                "Ismeretlen hiba történt.",
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w500,
                                              height: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 32),
                                          ElevatedButton.icon(
                                            onPressed:
                                                _controller.retryInitialLoad,
                                            icon: const Icon(
                                              Icons.refresh_rounded,
                                            ),
                                            label: const Text(
                                              "Újrapróbálkozás",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 24,
                                                    vertical: 14,
                                                  ),
                                              backgroundColor: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              foregroundColor: Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              : // --- TÖLTŐ UI ---
                                const Center(
                                  key: ValueKey('loading_view'),
                                  child: CircularProgressIndicator(),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ); // <--- EZ A PONTOSVESSZŐ HIÁNYZOTT! Itt tér vissza a Stack a LayoutBuilder-ből.
            }, // <--- EZ A ZÁRÓJEL HIÁNYZOTT! Itt ér véget a LayoutBuilder builder funkciója.
          ), // <--- EZ A ZÁRÓJEL HIÁNYZOTT! Itt zárul be maga a LayoutBuilder.
          // Ha hiba van, VAGY nyitva a billentyűzet, a GPS gombot elrejtjük
          floatingActionButton:
              (!isKeyboardOpen &&
                  _controller.selectedIndex == 0 &&
                  _controller.errorMessage == null)
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

          // Ha hiba van, az alsó navigációt nem lehet kattintani
          bottomNavigationBar: IgnorePointer(
            ignoring: _controller.errorMessage != null,
            child: NavigationBar(
              height: 65,
              selectedIndex: _controller.selectedIndex,
              onDestinationSelected: _controller.setSelectedIndex,
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
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
          ),
        );
      },
    );
  }
}
