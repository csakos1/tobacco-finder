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
import 'dart:math' as math;

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

  /// Billentyűzet és focus bezárása bárhonnan
  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _showShopDetails(Shop shop) {
    // ---------------------------------------------------------------
    // JAVÍTÁS: Mielőtt megnyitjuk a modalt, elengedjük a focus-t.
    // Így a modal bezárásakor a SearchBar NEM kapja vissza a focus-t
    // és a billentyűzet NEM jön fel magától.
    // ---------------------------------------------------------------
    _dismissKeyboard();

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
    // ---------------------------------------------------------------
    // NINCS MediaQuery.of(context) itt!
    // Minden viewInsets-függő widget saját maga olvassa ki izoláltan.
    // ---------------------------------------------------------------

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            forceMaterialTransparency: _controller.selectedIndex == 0,
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
                        bottomPadding: 0.0,
                        // ÚJ: Térképre koppintás → billentyűzet bezárása
                        onMapTapped: _dismissKeyboard,
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

                  // --- Iránytű ---
                  if (_controller.selectedIndex == 0 &&
                      _controller.isMapRotated)
                    Positioned(
                      top: 88,
                      left: 16,
                      child: FloatingActionButton.small(
                        heroTag: 'compass_fab',
                        onPressed: _controller.resetCompass,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        elevation: 4,
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
                        parentConstraintsHeight: constraints.maxHeight,
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
                              ? Center(
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
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            "Ellenőrizd az internetkapcsolatot és próbáld újra.",
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withOpacity(0.6),
                                                ),
                                          ),
                                          const SizedBox(height: 32),
                                          FilledButton.icon(
                                            onPressed:
                                                _controller.retryInitialLoad,
                                            icon: const Icon(Icons.refresh),
                                            label: const Text(
                                              'Újrapróbálkozás',
                                            ),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: Theme.of(
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
                              : const Center(
                                  key: ValueKey('loading_view'),
                                  child: CircularProgressIndicator(),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // --- FAB: Izolált widget, saját maga olvassa a billentyűzet állapotát ---
          floatingActionButton:
              _controller.selectedIndex == 0 && _controller.errorMessage == null
              ? _KeyboardAwareFab(
                  isLocating: _controller.isLocating,
                  onPressed: () {
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
                )
              : null,

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

/// Izolált widget a FAB számára — CSAK ez épül újra a billentyűzet animáció során.
class _KeyboardAwareFab extends StatelessWidget {
  final bool isLocating;
  final VoidCallback onPressed;

  const _KeyboardAwareFab({required this.isLocating, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    if (isKeyboardOpen) return const SizedBox.shrink();

    return FloatingActionButton(
      onPressed: isLocating ? null : onPressed,
      tooltip: 'Helymeghatározás',
      child: isLocating
          ? const Padding(
              padding: EdgeInsets.all(12.0),
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            )
          : const Icon(Icons.my_location),
    );
  }
}
