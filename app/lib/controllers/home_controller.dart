// app/lib/controllers/home_controller.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/shop.dart';
import '../models/shop_filter.dart';
import '../services/location_service.dart';
import '../services/app_settings.dart';
import '../repositories/shop_repository.dart';
import '../controllers/map_state_controller.dart';

// ---------------------------------------------------------------
// HOME CONTROLLER (Orchestrátor)
//
// Vékony ChangeNotifier, amely kizárólag a UI-szintű állapotot
// kezeli és koordinálja a specializált komponenseket:
//
//   - MapStateController → térkép kamera, iránytű, keresési pin
//   - ShopRepository     → API fetch, cache, merge, rendezés
//   - LocationService    → GPS pozíció, engedélyek
//
// Ezzel megszűnik a korábbi God Object anti-pattern:
// a notifyListeners() hívások célzottan csak a releváns
// UI részeket építik újra.
// ---------------------------------------------------------------
class HomeController extends ChangeNotifier {
  // --- Delegált komponensek ---
  late final MapStateController mapState;
  final ShopRepository _shopRepo = ShopRepository();
  final LocationService _locationService = LocationService();

  Timer? _debounce;

  // ---------------------------------------------------------------
  // MEMÓRIA LIMIT: A boltlista maximális mérete.
  // ---------------------------------------------------------------
  static const int _maxShopCount = 500;

  // --- Boltadat állapot ---
  List<Shop> shops = [];
  ShopFilter currentFilter = ShopFilter.none;

  // --- Betöltési állapot ---
  bool isLoading = true;
  String? errorMessage;

  // --- Hálózati állapot ---
  bool isOffline = false;

  // --- GPS állapot ---
  LatLng? myPosition;
  bool isLocating = false;

  // --- UI állapot ---
  int selectedIndex = 0;
  bool isFetchingArea = false;

  LatLng? _lastFetchPosition;
  bool _isDisposed = false;

  // ---------------------------------------------------------------
  // SZŰRT BOLTLISTA: A repository applyFilter metódusát használja.
  // ---------------------------------------------------------------
  List<Shop> get filteredShops => _shopRepo.applyFilter(shops, currentFilter);

  // ---------------------------------------------------------------
  // KONSTRUKTOR
  // ---------------------------------------------------------------
  HomeController() {
    // Elmentett pozíció használata kezdő térképközéppontnak
    final savedPosition = AppSettings.instance.initialMapPosition;
    final startPosition = savedPosition ?? const LatLng(47.50712, 19.04557);

    mapState = MapStateController(initialPosition: startPosition);

    // Biztonságos async indítás
    _firstLoad().catchError((Object error, StackTrace stack) {
      debugPrint('Kritikus hiba az első betöltésnél: $error\n$stack');
      if (!_isDisposed) {
        errorMessage =
            'Váratlan hiba történt az induláskor.\nKérlek próbáld újra.';
        isLoading = false;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debounce?.cancel();
    mapState.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  // SZŰRŐ VÁLTÁS
  // ---------------------------------------------------------------
  void setFilter(ShopFilter newFilter) {
    currentFilter = newFilter;
    notifyListeners();
  }

  // ---------------------------------------------------------------
  // TAB VÁLTÁS
  // ---------------------------------------------------------------
  void setSelectedIndex(int index) {
    selectedIndex = index;
    notifyListeners();
  }

  // ---------------------------------------------------------------
  // MAP CREATED: Közvetítés a MapStateController felé,
  // majd megkíséreljük a térkép fedő eltávolítását.
  // ---------------------------------------------------------------
  void onMapCreated(GoogleMapController controller) {
    mapState.setMapController(controller);
    if (!isLoading) {
      mapState.tryRevealMap();
    }
  }

  // ---------------------------------------------------------------
  // KAMERA MOZGÁS: A MapStateController frissíti a kamera adatokat,
  // a HomeController pedig kezeli a debounce fetch logikát.
  //
  // SoC: a térkép UI állapot (bearing, zoom) a MapStateController-é,
  // az adatlekérési logika (fetch, offline mód) a HomeController-é.
  // ---------------------------------------------------------------
  void onMapPositionChanged(CameraPosition position) {
    mapState.updateCamera(position);

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _fetchMapArea(position.target);
    });
  }

  // ---------------------------------------------------------------
  // GPS GOMB: Helymeghatározás + boltok frissítése.
  // ---------------------------------------------------------------
  Future<void> handleLocationPress(VoidCallback onError) async {
    isLocating = true;
    notifyListeners();

    try {
      final gpsFuture = _locationService.determinePosition();

      // Gyors cached pozícióra ugrás, ha van
      try {
        final cachedPosition = await _locationService.getLastKnownPosition();
        if (cachedPosition != null && selectedIndex == 0) {
          await mapState.animatedMapMove(cachedPosition, 15.0);
        }
      } catch (_) {}

      final freshPosition = await gpsFuture;

      if (freshPosition != null) {
        final result = await _shopRepo.fetchNearbyWithCache(
          freshPosition.latitude,
          freshPosition.longitude,
        );

        if (!_isDisposed) {
          myPosition = freshPosition;
          shops = result.shops;
          _lastFetchPosition = freshPosition;
          _locationService.savePosition(freshPosition);
          _applyOfflineState(result.isFromCache);
          _shopRepo.sortByDistance(shops, myPosition!);
          notifyListeners();

          if (selectedIndex == 0) {
            await mapState.animatedMapMove(freshPosition, 15.0);
          }
        }
      }
    } catch (e) {
      onError();
    } finally {
      if (!_isDisposed) {
        isLocating = false;
        notifyListeners();
      }
    }
  }

  // ---------------------------------------------------------------
  // PULL-TO-REFRESH: Friss nearby lekérés az aktuális GPS pozícióval.
  // ---------------------------------------------------------------
  Future<void> refreshShops() async {
    if (myPosition != null) {
      // Azonnali fetch a jelenlegi ismert pozícióval
      try {
        final result = await _shopRepo.fetchNearbyWithCache(
          myPosition!.latitude,
          myPosition!.longitude,
        );

        if (!_isDisposed) {
          shops = result.shops;
          _lastFetchPosition = myPosition;
          _applyOfflineState(result.isFromCache);
          _shopRepo.sortByDistance(shops, myPosition!);
          notifyListeners();
        }
      } catch (e) {
        debugPrint("Pull-to-refresh hiba: $e");
        return;
      }

      // Háttérben friss GPS pozíciót is kérünk
      try {
        final freshPosition = await _locationService.determinePosition();
        if (freshPosition != null && !_isDisposed) {
          final double distMoved = Geolocator.distanceBetween(
            myPosition!.latitude,
            myPosition!.longitude,
            freshPosition.latitude,
            freshPosition.longitude,
          );

          myPosition = freshPosition;
          _locationService.savePosition(freshPosition);

          if (distMoved > 500) {
            final updated = await _shopRepo.fetchNearbyWithCache(
              freshPosition.latitude,
              freshPosition.longitude,
            );

            if (!_isDisposed) {
              shops = updated.shops;
              _lastFetchPosition = freshPosition;
              _applyOfflineState(updated.isFromCache);
              _shopRepo.sortByDistance(shops, myPosition!);
              notifyListeners();
            }
          }
        }
      } catch (_) {
        // GPS pontosítás opcionális — ha nem sikerül, nem baj
      }
    } else {
      // Nincs pozíciónk → próbáljunk GPS-t szerezni
      try {
        final freshPosition = await _locationService.determinePosition();
        if (freshPosition != null && !_isDisposed) {
          myPosition = freshPosition;
          _locationService.savePosition(freshPosition);

          final result = await _shopRepo.fetchNearbyWithCache(
            freshPosition.latitude,
            freshPosition.longitude,
          );

          if (!_isDisposed) {
            shops = result.shops;
            _lastFetchPosition = freshPosition;
            _applyOfflineState(result.isFromCache);
            _shopRepo.sortByDistance(shops, myPosition!);
            notifyListeners();
          }
        }
      } catch (e) {
        debugPrint("Pull-to-refresh GPS hiba: $e");
      }
    }
  }

  // ---------------------------------------------------------------
  // ÚJRAPRÓBÁLKOZÁS: A hibaüzenet "Újrapróbálkozás" gombjához.
  // ---------------------------------------------------------------
  Future<void> retryInitialLoad() async {
    if (isLoading) return;
    errorMessage = null;
    isLoading = true;
    notifyListeners();
    await _firstLoad();
  }

  // ---------------------------------------------------------------
  // FORMÁZOTT TÁVOLSÁG: Delegálja a ShopRepository-nak.
  // ---------------------------------------------------------------
  String getFormattedDistance(Shop shop) {
    return _shopRepo.formatDistance(shop, myPosition);
  }

  // ---------------------------------------------------------------
  // PRIVÁT: ELSŐ BETÖLTÉS
  //
  // Cached pozíció → boltok lekérése → háttér GPS pontosítás.
  // ---------------------------------------------------------------
  Future<void> _firstLoad() async {
    try {
      errorMessage = null;

      LatLng? cachedPosition;
      try {
        cachedPosition = await _locationService.getLastKnownPosition();
      } catch (_) {}

      if (cachedPosition != null && !_isDisposed) {
        myPosition = cachedPosition;
        mapState.mapCenter = cachedPosition;
        _locationService.savePosition(cachedPosition);
        notifyListeners();

        try {
          final result = await _shopRepo.fetchNearbyWithCache(
            cachedPosition.latitude,
            cachedPosition.longitude,
          );
          shops = result.shops;
          _lastFetchPosition = cachedPosition;
          _applyOfflineState(result.isFromCache);
        } catch (e) {
          debugPrint("Nem sikerült betölteni a boltokat: $e");
          errorMessage =
              "Nem sikerült a boltokat betölteni.\nEllenőrizd az internetkapcsolatod.";
        }
      } else {
        errorMessage =
            "Nem sikerült meghatározni a helyzetedet.\nEllenőrizd a helymeghatározási engedélyeket.";
      }

      if (myPosition != null && errorMessage == null) {
        _shopRepo.sortByDistance(shops, myPosition!);
      }

      if (!_isDisposed) {
        isLoading = false;
        notifyListeners();

        // Megkíséreljük a térkép fedő eltávolítását
        mapState.tryRevealMap();

        if (myPosition != null && errorMessage == null) {
          mapState.animatedMapMove(myPosition!, 15.0);
        }
      }

      // Háttérben friss GPS-t kérünk (csak ha nem volt hiba)
      if (myPosition != null && errorMessage == null) {
        _locationService
            .determinePosition()
            .then((LatLng? freshPosition) async {
              if (freshPosition != null && !_isDisposed) {
                final double distMoved = Geolocator.distanceBetween(
                  myPosition!.latitude,
                  myPosition!.longitude,
                  freshPosition.latitude,
                  freshPosition.longitude,
                );

                if (distMoved > 500) {
                  try {
                    final result = await _shopRepo.fetchNearbyWithCache(
                      freshPosition.latitude,
                      freshPosition.longitude,
                    );
                    shops = result.shops;
                    myPosition = freshPosition;
                    _locationService.savePosition(freshPosition);
                    _applyOfflineState(result.isFromCache);
                    _shopRepo.sortByDistance(shops, myPosition!);
                    notifyListeners();
                    if (selectedIndex == 0) {
                      mapState.animatedMapMove(freshPosition, 15.0);
                    }
                  } catch (_) {}
                } else {
                  myPosition = freshPosition;
                  _locationService.savePosition(freshPosition);
                  _shopRepo.sortByDistance(shops, myPosition!);
                  notifyListeners();
                }
              }
            })
            .catchError((e) {
              debugPrint("Pontosítás sikertelen: $e");
            });
      }
    } catch (e, stack) {
      debugPrint('Váratlan hiba a _firstLoad-ban: $e\n$stack');
      if (!_isDisposed) {
        errorMessage =
            'Váratlan hiba történt az induláskor.\nKérlek próbáld újra.';
        isLoading = false;
        notifyListeners();
      }
    }
  }

  // ---------------------------------------------------------------
  // PRIVÁT: TÉRKÉP PÁSZTÁZÁS FETCH
  //
  // Ha a user 2+ km-t mozdult az utolsó fetch óta, új nearby query.
  // Az eredményt a meglévő listába merge-öljük (deduplikálva),
  // majd a memória-limit betartása érdekében a legtávolabbi
  // boltokat eldobjuk.
  // ---------------------------------------------------------------
  Future<void> _fetchMapArea(LatLng newCenter) async {
    if (isOffline) return;

    if (_lastFetchPosition != null) {
      final double distMovedMeters = Geolocator.distanceBetween(
        _lastFetchPosition!.latitude,
        _lastFetchPosition!.longitude,
        newCenter.latitude,
        newCenter.longitude,
      );
      if (distMovedMeters < 2000) return;
    }

    isFetchingArea = true;
    notifyListeners();

    try {
      final existingIds = shops.map((s) => s.id).toSet();
      final newShops = await _shopRepo.fetchNewAreaShops(
        newCenter.latitude,
        newCenter.longitude,
        existingIds,
      );

      // Ha eddig offline voltunk, de most sikerült → online-ra váltunk
      _setOnline();

      if (newShops.isNotEmpty) {
        shops = _shopRepo.mergeShops(shops, newShops);
        shops = _shopRepo.pruneDistant(
          shops,
          newCenter,
          maxCount: _maxShopCount,
        );

        if (myPosition != null) {
          _shopRepo.sortByDistance(shops, myPosition!);
        }
      }
      _lastFetchPosition = newCenter;
    } catch (e) {
      debugPrint("Hiba a terület keresésekor: $e");
      // Pásztázásnál nem váltunk offline módra — a meglévő adattal
      // a user továbbra is böngészhet.
    } finally {
      if (!_isDisposed) {
        isFetchingArea = false;
        notifyListeners();
      }
    }
  }

  // ---------------------------------------------------------------
  // PRIVÁT: OFFLINE ÁLLAPOT KEZELÉS
  //
  // Csak akkor hív notifyListeners()-t, ha tényleg változott.
  // ---------------------------------------------------------------
  void _setOnline() {
    if (isOffline) {
      isOffline = false;
      notifyListeners();
    }
  }

  void _setOffline() {
    if (!isOffline) {
      isOffline = true;
      notifyListeners();
    }
  }

  /// A ShopFetchResult isFromCache alapján állítja az offline állapotot.
  void _applyOfflineState(bool isFromCache) {
    if (isFromCache) {
      _setOffline();
    } else {
      _setOnline();
    }
  }
}
