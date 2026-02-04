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
        // HA VAN POZÍCIÓ: Csak a közelieket töltjük (Backend módosítás kell hozzá!)
        // Ez a gyorsítás kulcsa!
        // Feltételezzük, hogy az ApiService-ben már ott a fetchNearby
        fetchedShops = await _apiService.fetchNearby(
          myPosition!.latitude,
          myPosition!.longitude,
        );
      } else {
        // HA NINCS POZÍCIÓ: Kénytelenek vagyunk mindent letölteni (Fallback)
        fetchedShops = await _apiService.fetchShops();
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
  bool _isLocating = false;

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
        Future.delayed(const Duration(milliseconds: 800), () {
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
    // 1. JAVÍTÁS: A 'build' elején lévő if/else TÖRLÉSRE KERÜLT.
    // Helyette lenn az IndexedStack-et használjuk.

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
              // Material 3-nál az 'outlined' ikonok az elterjedtek
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Beállítások',
              onPressed: () {
                // Átnavigálás az új képernyőre
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
          : IndexedStack(
              // <--- ITT A LÉNYEG: Ez oldja meg a szaggatást váltáskor!
              index: _selectedIndex,
              children: [
                // 0. index: Térkép (Megmarad a memóriában)
                TobaccoMap(
                  shops: shops,
                  myPosition: myPosition,
                  mapCenter: mapCenter,
                  mapController: _mapController,
                  onShopSelected: _showShopDetails,
                ),
                // 1. index: Lista (Megmarad a memóriában)
                ShopList(
                  shops: shops,
                  myPosition: myPosition,
                  onShopSelected: _onShopSelectedFromList,
                ),
              ],
            ),

      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: _isLocating
                  ? null
                  : _handleLocationPress, // Ha tölt, nem nyomható
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
