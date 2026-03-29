// app/lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/shop.dart';
import '../widgets/tobacco_map.dart';
import '../widgets/shop_list.dart';
import '../widgets/shop_details_modal.dart';
import '../widgets/offline_banner.dart';
import '../screens/settings_screen.dart';
import '../controllers/home_controller.dart';
import '../controllers/map_state_controller.dart';
import '../widgets/place_search_bar.dart';
import 'dart:math' as math;
import '../services/haptic_service.dart';

// ---------------------------------------------------------------
// AZ OFFLINE BANNER MAGASSÁGA
//
// A banner: vertical padding (8+8) + icon/text sor (~20px) = ~36px.
// Ezt használjuk a Google logó és a FAB felfelé tolásához,
// hogy ne takarják ki egymást. Egy helyen definiálva, hogy ha
// a banner designja változik, csak itt kell módosítani.
// ---------------------------------------------------------------
const double _offlineBannerHeight = 40.0;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _controller;

  /// Kényelmi getter — a térkép UI állapotát a HomeController-en
  /// keresztül érjük el, de rövidebb hivatkozás kedvéért.
  MapStateController get _mapState => _controller.mapState;

  /// GlobalKey a PlaceSearchBar elérésére (keresés kívülről történő törléséhez).
  final _searchBarKey = GlobalKey<PlaceSearchBarState>();

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

  /// Keresés teljes megszüntetése: pin eltávolítás + keresősáv törlés.
  /// Hívódik amikor a felhasználó egy boltos/klaszter pinre koppint.
  void _dismissSearch() {
    _mapState.clearSearchPin();
    _searchBarKey.currentState?.clearSearch();
  }

  void _showShopDetails(Shop shop) {
    // ---------------------------------------------------------------
    // Mielőtt megnyitjuk a modalt, elengedjük a focus-t.
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
        _mapState.animatedMapMove(LatLng(shop.lat!, shop.long!), 16.0);
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

    // ---------------------------------------------------------------
    // KÜLSŐ BUILDER: A HomeController-re figyel.
    //
    // Ez újra fut, ha: boltlista, isLoading, errorMessage,
    // selectedIndex, filter, isOffline, isLocating, isFetchingArea
    // bármelyike változik.
    //
    // NEM fut újra, ha: csak a térkép bearing/zoom/searchPin változott
    // (azokat a MapStateController kezeli, saját belső builder-ekkel).
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
                        mapCenter: _mapState.mapCenter,
                        onShopSelected: _showShopDetails,
                        onCameraMove: _controller.onMapPositionChanged,
                        onMapCreated: _controller.onMapCreated,
                        // -------------------------------------------------
                        // OFFLINE: Ha a banner látható, a Google logót
                        // felfelé toljuk a banner magasságával.
                        // -------------------------------------------------
                        bottomPadding: _controller.isOffline
                            ? _offlineBannerHeight
                            : 0.0,
                        onMapTapped: _dismissKeyboard,
                        searchPinPosition: _mapState.searchPinPosition,
                        onSearchDismissed: _dismissSearch,
                      ),
                      ShopList(
                        shops: _controller.filteredShops,
                        getDistanceText: _controller.getFormattedDistance,
                        onShopSelected: _onShopSelectedFromList,
                        currentFilter: _controller.currentFilter,
                        onFilterChanged: (filter) {
                          HapticService.lightImpact();
                          _controller.setFilter(filter);
                        },
                        onRefresh: _controller.refreshShops,
                      ),
                    ],
                  ),

                  // ---------------------------------------------------------------
                  // TÉRKÉP FEDŐ OVERLAY
                  //
                  // BELSŐ BUILDER: A MapStateController-re figyel.
                  // Csak az isMapReady változásakor épül újra
                  // (egyszer, az induláskor).
                  // ---------------------------------------------------------------
                  if (_controller.selectedIndex == 0)
                    ListenableBuilder(
                      listenable: _mapState,
                      builder: (_, __) =>
                          _MapCoverOverlay(isMapReady: _mapState.isMapReady),
                    ),

                  // ---------------------------------------------------------------
                  // IRÁNYTŰ
                  //
                  // BELSŐ BUILDER: A MapStateController-re figyel.
                  // Csak a bearing változásakor épül újra — a boltlista,
                  // szűrő chipek, FAB és offline banner NEM rebuild-elődik.
                  //
                  // A Positioned a Stack közvetlen gyereke marad,
                  // a ListenableBuilder belsejébe kerül a tényleges widget.
                  // ---------------------------------------------------------------
                  if (_controller.selectedIndex == 0)
                    Positioned(
                      top: 88,
                      left: 16,
                      child: ListenableBuilder(
                        listenable: _mapState,
                        builder: (context, _) {
                          if (!_mapState.isMapRotated) {
                            return const SizedBox.shrink();
                          }
                          return FloatingActionButton.small(
                            heroTag: 'compass_fab',
                            onPressed: _mapState.resetCompass,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            elevation: 4,
                            child: Transform.rotate(
                              angle: -_mapState.mapBearing * (math.pi / 180),
                              child: const Icon(
                                Icons.navigation_rounded,
                                size: 22,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // --- Keresősáv ---
                  if (_controller.selectedIndex == 0)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: PlaceSearchBar(
                        key: _searchBarKey,
                        parentConstraintsHeight: constraints.maxHeight,
                        onPlaceSelected: (place) {
                          _mapState.setSearchPin(place);
                        },
                        onSearchCleared: () {
                          _mapState.clearSearchPin();
                        },
                      ),
                    ),

                  // ---------------------------------------------------------------
                  // OFFLINE BANNER: A body aljára pozícionálva, a NavigationBar
                  // felett. Mindkét tabon látható, ha offline módban vagyunk.
                  // ---------------------------------------------------------------
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: OfflineBanner(isVisible: _controller.isOffline),
                  ),

                  // 2. RÉTEG: Hibaállapot
                  if (_controller.errorMessage != null)
                    _buildErrorOverlay(context),
                ],
              );
            },
          ),

          floatingActionButton:
              _controller.selectedIndex == 0 && _controller.errorMessage == null
              ? _KeyboardAwareFab(
                  isLocating: _controller.isLocating,
                  // FAB-ot is felfelé toljuk offline módban
                  bottomOffset: _controller.isOffline
                      ? _offlineBannerHeight
                      : 0.0,
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
              onDestinationSelected: (index) {
                HapticService.lightImpact();
                _controller.setSelectedIndex(index);
              },
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

  /// Hibaállapot overlay — a térkép/lista fölé rajzolódik.
  Widget _buildErrorOverlay(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: Container(
        color: theme.colorScheme.surface.withOpacity(0.9),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 64,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  _controller.errorMessage!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _controller.isLoading
                      ? null
                      : _controller.retryInitialLoad,
                  icon: _controller.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(
                    _controller.isLoading ? 'Betöltés...' : 'Újrapróbálkozás',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Izolált widget a FAB számára.
///
/// CSAK ez épül újra a billentyűzet animáció során (MediaQuery izolálva).
/// A [bottomOffset] extra alsó margót ad a FAB-nak, pl. ha az offline
/// banner látható és nem akarjuk, hogy a kettő takarásban legyen.
class _KeyboardAwareFab extends StatelessWidget {
  final bool isLocating;
  final VoidCallback onPressed;
  final double bottomOffset;

  const _KeyboardAwareFab({
    required this.isLocating,
    required this.onPressed,
    this.bottomOffset = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    if (isKeyboardOpen) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomOffset),
      child: FloatingActionButton(
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
      ),
    );
  }
}

/// Térkép fedő overlay — elfedi a Google Maps betöltődés alatti
/// fehér/bézs hátterét és a pixeles tile-renderelést.
/// A surface színt használja, ami illeszkedik a sötét és világos témához is.
///
/// Amíg a térkép nem kész, egy töltésjelző pörög a közepén,
/// hogy a felhasználó lássa: az app dolgozik.
class _MapCoverOverlay extends StatefulWidget {
  final bool isMapReady;
  const _MapCoverOverlay({required this.isMapReady});

  @override
  State<_MapCoverOverlay> createState() => _MapCoverOverlayState();
}

class _MapCoverOverlayState extends State<_MapCoverOverlay> {
  /// Ha a fade-out animáció lefutott, teljesen eltávolítjuk a widgetet.
  bool _dismissed = false;

  @override
  void didUpdateWidget(_MapCoverOverlay old) {
    super.didUpdateWidget(old);
    if (widget.isMapReady && !old.isMapReady) {
      // Az AnimatedOpacity 400ms-ig fut → utána biztonságosan eltávolítjuk
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _dismissed = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ha a fade-out lefutott, üres widgetet adunk vissza
    if (_dismissed) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Positioned.fill(
      child: IgnorePointer(
        // Ha a térkép kész, ne blokkoljuk a touch eseményeket
        ignoring: widget.isMapReady,
        child: AnimatedOpacity(
          opacity: widget.isMapReady ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 400),
          child: Container(
            color: theme.colorScheme.surface,
            // ---------------------------------------------------------
            // TÖLTÉSJELZŐ: A térkép betöltődéséig középen pörgő indikátor.
            // Az AnimatedOpacity a teljes Container-t (háttér + indikátor)
            // együtt fade-eli ki, tehát az indikátor is simán eltűnik.
            // ---------------------------------------------------------
            child: Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
