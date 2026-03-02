import 'dart:async'; // ÚJ IMPORT A TIMER MIATT!
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/shop.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../widgets/tobacco_map.dart';
import '../widgets/shop_list.dart';
import '../widgets/shop_details_modal.dart';
import '../screens/settings_screen.dart';
import '../utils/shop_logic.dart'; // <-- Ezt is be kell húzni a szűréshez!

// --- ÚJ: A szűrő állapotai ---
enum ShopFilter { none, openNow, nonStop }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();

  List<Shop> shops = [];
  bool isLoading = true;
  LatLng? myPosition;
  LatLng mapCenter = const LatLng(47.50712, 19.04557);

  int _selectedIndex = 0;
  bool _isLocating = false;

  // --- ÚJ VÁLTOZÓK A TÉRKÉP MOZGATÁSÁHOZ ---
  Timer? _debounce;
  LatLng? _lastFetchPosition; // Hol töltöttünk le utoljára boltokat?
  bool _isFetchingArea = false; // Tölt-e épp a háttérben?

  // --- ÚJ: Az aktuális szűrő ---
  ShopFilter _currentFilter = ShopFilter.none;

  @override
  void dispose() {
    _debounce?.cancel(); // Ne felejtsük el törölni a timert kilépéskor
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _firstLoad();
  }

  // --- ÚJ: Dinamikusan generált szűrt lista ---
  List<Shop> get _filteredShops {
    if (_currentFilter == ShopFilter.openNow) {
      return shops.where((s) => ShopLogic.isOpenNow(s.openingHours)).toList();
    } else if (_currentFilter == ShopFilter.nonStop) {
      return shops.where((s) => ShopLogic.isNonStop(s.openingHours)).toList();
    }
    return shops; // Ha nincs szűrő (none), mehet a teljes lista
  }

  void _sortShopsByDistance() {
    if (myPosition == null) return;

    const Distance distance = Distance();

    shops.sort((a, b) {
      if (a.lat == null || a.long == null) return 1;
      if (b.lat == null || b.long == null) return -1;

      final double distA = distance.as(
        LengthUnit.Meter,
        myPosition!,
        LatLng(a.lat!, a.long!),
      );
      final double distB = distance.as(
        LengthUnit.Meter,
        myPosition!,
        LatLng(b.lat!, b.long!),
      );
      return distA.compareTo(distB);
    });
  }

  Future<void> _firstLoad() async {
    // 1. OPTIMALIZÁLÁS: Először próbáljunk pozíciót szerezni (Cache-ből)
    LatLng? initialPosition;
    try {
      initialPosition = await _locationService.getLastKnownPosition();
    } catch (e) {
      debugPrint("Hiba a cache pozíció lekérésnél: $e");
    }

    // Ha nincs cache, próbáljunk gyorsan frisset szerezni (ha az app engedélyekkel indul)
    if (initialPosition == null) {
      try {
        // Itt döntés kérdése: várunk a GPS-re, vagy betöltünk mindent.
        // A sebesség érdekében érdemes megvárni a GPS-t, mert 20km-nyi boltot letölteni
        // sokkal gyorsabb, mint 6000-et.
        initialPosition = await _locationService.determinePosition();
      } catch (e) {
        debugPrint("GPS hiba induláskor: $e");
      }
    }

    // Beállítjuk a pozíciót, ha megvan
    if (initialPosition != null) {
      myPosition = initialPosition;
      mapCenter = initialPosition;

      // Ha ez az első indulás, mozgassuk oda a térképet (bár a MapController még nem biztos, hogy él)
      // A mapCenter változó átadása a TobaccoMap-nek elintézi ezt.
    }

    // 2. BOLTOK LETÖLTÉSE (Kicsi vagy Nagy adatbázis?)
    try {
      List<Shop> fetchedShops;

      if (myPosition != null) {
        fetchedShops = await _apiService.fetchNearby(
          myPosition!.latitude,
          myPosition!.longitude,
        );
        _lastFetchPosition = myPosition; // ÚJ: Eltároljuk a letöltés helyét!
      } else {
        fetchedShops = await _apiService.fetchShops();
        _lastFetchPosition = mapCenter; // ÚJ
      }

      shops = fetchedShops;
    } catch (e) {
      debugPrint("Bolt letöltési hiba: $e");
    }

    // Rendezés
    if (myPosition != null) {
      _sortShopsByDistance();
    }

    // 3. UI FELOLDÁS
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }

    // 4. HÁTTÉRFOLYAMAT: Ha csak cache pozíciónk volt, kérjünk pontosabbat
    // és frissítsük a listát, ha a user jelentősen máshol van.
    if (myPosition != null) {
      _locationService
          .determinePosition()
          .then((freshPosition) async {
            if (freshPosition != null && mounted) {
              const Distance distance = Distance();
              // Csak akkor frissítünk mindent, ha több mint 500 métert tévedett a cache
              if (distance.as(
                    LengthUnit.Meter,
                    myPosition!,
                    LatLng(freshPosition.latitude, freshPosition.longitude),
                  ) >
                  500) {
                // Új boltok kellenek, mert messze vagyunk a cache-től!
                var newShops = await _apiService.fetchNearby(
                  freshPosition.latitude,
                  freshPosition.longitude,
                );

                setState(() {
                  myPosition = freshPosition;
                  shops = newShops;
                  _sortShopsByDistance();
                });

                // Ha térképen vagyunk, animáljunk oda
                if (_selectedIndex == 0) {
                  _animatedMapMove(freshPosition, 15.0);
                }
              } else {
                // Ha közel vagyunk, elég csak a marker pozíciót pontosítani
                setState(() {
                  myPosition = freshPosition;
                  _sortShopsByDistance();
                });
              }
            }
          })
          .catchError((e) {
            debugPrint("Pontosítás sikertelen: $e");
          });
    }
  }

  // Egy új változó, hogy lássuk, épp dolgozik-e a GPS
  //bool _isLocating = false;

  Future<void> _handleLocationPress() async {
    // 1. Bekapcsoljuk a pörgést
    setState(() {
      _isLocating = true;
    });

    try {
      // Elindítjuk a GPS keresést a háttérben (még nem várjuk meg!)
      final gpsFuture = _locationService.determinePosition();

      // Közben, ha van cache pozíció, odamozgunk (hogy lásson valamit a user)
      try {
        final cachedPosition = await _locationService.getLastKnownPosition();
        if (cachedPosition != null && _selectedIndex == 0) {
          // Itt a 'await' miatt megvárjuk, amíg odaér a térkép!
          // Ez kb. 1 mp, addig a gpsFuture is dolgozik a háttérben.
          await _animatedMapMove(cachedPosition, 15.0);
        }
      } catch (_) {}

      // Most várjuk meg a friss GPS jelet
      final freshPosition = await gpsFuture;

      if (freshPosition != null) {
        // Adatok frissítése
        var newShops = await _apiService.fetchNearby(
          freshPosition.latitude,
          freshPosition.longitude,
        );

        if (mounted) {
          setState(() {
            myPosition = freshPosition;
            shops = newShops;
            _lastFetchPosition = freshPosition; // ÚJ: Frissítjük a bázispontot
            _sortShopsByDistance();
          });

          // Ha még mindig a térképen vagyunk, animáljunk a pontos helyre
          if (_selectedIndex == 0) {
            // Itt is megvárjuk az animáció végét!
            await _animatedMapMove(freshPosition, 15.0);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nem sikerült meghatározni a helyzetet.'),
          ),
        );
      }
    } finally {
      // 3. CSAK A LEGVÉGÉN kapcsoljuk ki a pörgést (finally blokk = mindig lefut)
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  // --- ÚJ METÓDUSOK A TÉRKÉP MOZGATÁSÁHOZ ---

  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    // KIVETTÜK a "if (!hasGesture) return;" sort!
    // Így akkor is lefut, ha a térkép csúszása (inercia) megállt.

    // Ha még fut a timer, leállítjuk (Debounce logika)
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Indítunk egy 800 milliszekundumos várakozást
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _fetchMapArea(camera.center);
    });
  }

  Future<void> _fetchMapArea(LatLng newCenter) async {
    // Ne töltsünk, ha túl közel vagyunk a korábbi letöltés helyéhez
    if (_lastFetchPosition != null) {
      const distance = Distance();
      final double distMoved = distance.as(
        LengthUnit.Kilometer,
        _lastFetchPosition!,
        newCenter,
      );

      // JAVÍTÁS: 10 km helyett 2 km-es elmozdulásnál már töltsön!
      if (distMoved < 2.0) return;
    }

    setState(() {
      _isFetchingArea = true; // Jelezzük a UI-nak, hogy töltünk
    });

    try {
      debugPrint(
        "Új boltok lekérése innen: ${newCenter.latitude}, ${newCenter.longitude}",
      );

      final newShops = await _apiService.fetchNearby(
        newCenter.latitude,
        newCenter.longitude,
      );

      // Profi trükk: Összefésüljük a régi és az új boltokat id alapján
      final existingIds = shops.map((s) => s.id).toSet();
      final uniqueNewShops = newShops
          .where((s) => !existingIds.contains(s.id))
          .toList();

      debugPrint("Talált új boltok száma: ${uniqueNewShops.length}");

      if (uniqueNewShops.isNotEmpty) {
        setState(() {
          // Új listát hozunk létre a régi és az új boltok összefűzésével.
          // Így a Flutter észreveszi a változást és frissíti a térképet!
          shops = [...shops, ...uniqueNewShops];
          _sortShopsByDistance(); // Újrarendezzük a listát
        });
      }

      _lastFetchPosition =
          newCenter; // Sikeres letöltés után elmentjük az új pontot
    } catch (e) {
      debugPrint("Hiba a terület keresésekor: $e");
    } finally {
      if (mounted) {
        setState(() => _isFetchingArea = false);
      }
    }
  }

  // JAVÍTÁS: Future<void>, hogy meg tudjuk várni a végét
  Future<void> _animatedMapMove(LatLng destLocation, double destZoom) async {
    if (!mounted) return;

    // 1. OPTIMALIZÁLÁS: Ha már ott vagyunk (pl. < 5 méter), ne animáljunk feleslegesen!
    // Ez oldja meg, hogy ne pörögjön tovább a gomb, ha már jó helyen a térkép.
    final currentCenter = _mapController.camera.center;
    const distance = Distance();
    if (distance.as(LengthUnit.Meter, currentCenter, destLocation) < 5 &&
        (_mapController.camera.zoom - destZoom).abs() < 0.1) {
      return; // Azonnal visszatérünk, nincs várakozás
    }

    try {
      final startLat = _mapController.camera.center.latitude;
      final startLng = _mapController.camera.center.longitude;
      final startZoom = _mapController.camera.zoom;

      final latTween = Tween<double>(
        begin: startLat,
        end: destLocation.latitude,
      );
      final lngTween = Tween<double>(
        begin: startLng,
        end: destLocation.longitude,
      );
      final zoomTween = Tween<double>(begin: startZoom, end: destZoom);

      final controller = AnimationController(
        duration: const Duration(milliseconds: 1000),
        vsync: this,
      );

      final Animation<double> animation = CurvedAnimation(
        parent: controller,
        curve: Curves.fastOutSlowIn,
      );

      controller.addListener(() {
        try {
          _mapController.move(
            LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
            zoomTween.evaluate(animation),
          );
        } catch (e) {
          // Ha navigálás közben hiba van, elnyeljük
        }
      });

      // 2. SZINKRONIZÁLÁS: Itt várjuk meg a végét!
      await controller.forward();
      controller.dispose();
    } catch (e) {
      print("Animációs hiba: $e");
    }
  }

  void _showShopDetails(Shop shop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          ShopDetailsModal(shop: shop, myPosition: myPosition),
    );
  }

  void _onShopSelectedFromList(Shop shop) {
    if (shop.lat != null && shop.long != null) {
      setState(() {
        _selectedIndex = 0;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animatedMapMove(LatLng(shop.lat!, shop.long!), 16.0);
        // Kicsit késleltetjük a modalt, hogy látszódjon az animáció vége
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _showShopDetails(shop);
        });
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Dohánybolt Kereső",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
        ),
        centerTitle: false, // Balra igazítjuk a címet, hogy legyen hely jobbra
        actions: [
          // Itt a fogaskerék ikon
          Padding(
            padding: const EdgeInsets.only(right: 8.0), // Kis margó a szélétől
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

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              // <--- ÚJ: Stack-be tettük, hogy lebegő indikátort mutathassunk
              children: [
                IndexedStack(
                  index: _selectedIndex,
                  children: [
                    // 0. index: Térkép
                    TobaccoMap(
                      shops: _filteredShops, // <-- Szűrt listát kap!
                      myPosition: myPosition,
                      mapCenter: mapCenter,
                      mapController: _mapController,
                      onShopSelected: _showShopDetails,
                      onPositionChanged: _onMapPositionChanged,
                    ),
                    // 1. index: Lista
                    ShopList(
                      shops: _filteredShops, // <-- Szűrt listát kap!
                      myPosition: myPosition,
                      onShopSelected: _onShopSelectedFromList,
                      // --- ÚJ PARAMÉTEREK ---
                      currentFilter: _currentFilter,
                      onFilterChanged: (ShopFilter newFilter) {
                        setState(() {
                          _currentFilter = newFilter;
                        });
                      },
                    ),
                  ],
                ),

                // ÚJ: Elegáns kis lebegő indikátor, ha a háttérben töltünk be új várost
                if (_isFetchingArea && _selectedIndex == 0)
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
              ],
            ),

      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: _isLocating ? null : _handleLocationPress,
              tooltip: 'Helymeghatározás',
              child: _isLocating
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
