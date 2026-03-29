// app/lib/controllers/home_controller.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/shop.dart';
import '../models/place_suggestion.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/shop_cache_service.dart';
import '../utils/shop_logic.dart';
import '../main.dart' show initialMapPosition;

enum ShopFilter { none, openNow, nonStop }

class HomeController extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final ShopCacheService _cacheService = ShopCacheService();

  GoogleMapController? mapController;
  Timer? _debounce;

  // ---------------------------------------------------------------
  // MEMÓRIA LIMIT: A boltlista maximális mérete.
  // Ha a user sokat pásztáz és a lista túllépi ezt a számot,
  // a térkép középpontjától legtávolabbi boltokat eldobjuk.
  // Ez megvéd a végtelen listanövekedéstől és a klaszterező lassulásától.
  // ---------------------------------------------------------------
  static const int _maxShopCount = 500;

  // Állapotváltozók (State)
  List<Shop> shops = [];
  bool isLoading = true;

  // --- Hibaüzenet állapota ---
  String? errorMessage;

  // ---------------------------------------------------------------
  // OFFLINE MÓD: Ha az API hívás elbukik és a cache-ből töltöttünk,
  // ez a flag true-ra áll. A UI egy bannert mutat a usernek.
  // Amint egy API hívás sikerül, automatikusan false-ra vált.
  // ---------------------------------------------------------------
  bool isOffline = false;

  LatLng? myPosition;
  LatLng mapCenter = const LatLng(47.50712, 19.04557);

  // --- Iránytű és kamera állapotok ---
  double mapBearing = 0.0;
  double currentZoom = 15.0;
  LatLng currentTarget = const LatLng(47.50712, 19.04557);

  // Getter: Megnézzük, hogy el van-e forgatva a térkép (nem 0 fokon áll)
  bool get isMapRotated => mapBearing > 0.5 && mapBearing < 359.5;

  int selectedIndex = 0;
  bool isLocating = false;
  bool isFetchingArea = false;
  bool isMapReady = false;

  LatLng? _lastFetchPosition;
  ShopFilter currentFilter = ShopFilter.none;

  // ---------------------------------------------------------------
  // KERESÉSI PIN: A keresett hely piros jelölője a térképen.
  // Amíg aktív, a térképen egy külön piros pin mutatja a keresett helyet.
  // ---------------------------------------------------------------
  LatLng? searchPinPosition;

  bool _isDisposed = false;

  HomeController() {
    // ---------------------------------------------------------------
    // Elmentett pozíció használata kezdő térképközéppontnak.
    // Így cold start-nál nem Budapest közepén nyílik a térkép,
    // hanem az utolsó ismert tartózkodási helyen.
    // ---------------------------------------------------------------
    final savedPosition = initialMapPosition;
    if (savedPosition != null) {
      mapCenter = savedPosition;
      currentTarget = savedPosition;
    }

    // ---------------------------------------------------------------
    // BIZTONSÁGOS ASYNC INDÍTÁS: A konstruktor nem lehet async,
    // ezért a _firstLoad() Future-jét explicit kezeljük.
    // A .catchError() biztosítja, hogy ha bármi váratlan kivétel
    // kiszökik a _firstLoad() top-level try-catch-éből,
    // az NE legyen unhandled exception.
    // ---------------------------------------------------------------
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
    super.dispose();
  }

  List<Shop> get filteredShops {
    if (currentFilter == ShopFilter.openNow) {
      return shops.where((s) => ShopLogic.isOpenNow(s.openingHours)).toList();
    } else if (currentFilter == ShopFilter.nonStop) {
      return shops.where((s) => ShopLogic.isNonStop(s.openingHours)).toList();
    }
    return shops;
  }

  void setFilter(ShopFilter newFilter) {
    currentFilter = newFilter;
    notifyListeners();
  }

  void setSelectedIndex(int index) {
    selectedIndex = index;
    notifyListeners();
  }

  void setMapController(GoogleMapController controller) {
    mapController = controller;
    _tryRevealMap();
  }

  /// A térkép fedő overlay eltávolítása.
  /// Mindkét feltétel teljesülése kell:
  ///   1. A GoogleMapController létrejött (onMapCreated lefutott)
  ///   2. Az első adatbetöltés befejeződött (isLoading == false)
  /// Ezután egy rövid késleltetéssel várunk a tile-ok renderelésére.
  void _tryRevealMap() {
    if (isMapReady || _isDisposed) return;
    if (mapController == null || isLoading) return;

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!_isDisposed && !isMapReady) {
        isMapReady = true;
        notifyListeners();
      }
    });
  }

  void _sortShopsByDistance() {
    if (myPosition == null) return;

    shops.sort((a, b) {
      if (a.lat == null || a.long == null) return 1;
      if (b.lat == null || b.long == null) return -1;

      final double distA = Geolocator.distanceBetween(
        myPosition!.latitude,
        myPosition!.longitude,
        a.lat!,
        a.long!,
      );
      final double distB = Geolocator.distanceBetween(
        myPosition!.latitude,
        myPosition!.longitude,
        b.lat!,
        b.long!,
      );
      return distA.compareTo(distB);
    });
  }

  // ---------------------------------------------------------------
  // MEMÓRIA KARBANTARTÁS: Túl távoli boltok eldobása.
  //
  // Ha a boltlista meghaladja a [_maxShopCount] limitet,
  // a [referencePoint]-tól (térkép középpont) legtávolabbi
  // boltokat vágjuk le. Így a user közvetlen környéke mindig
  // megmarad, de a 30+ km-re lévő régi boltok felszabadulnak.
  // ---------------------------------------------------------------
  void _pruneDistantShops(LatLng referencePoint) {
    if (shops.length <= _maxShopCount) return;

    // Távolság szerinti rendezés a referencia ponttól (legközelebbi elöl)
    shops.sort((a, b) {
      final double distA = (a.lat != null && a.long != null)
          ? Geolocator.distanceBetween(
              referencePoint.latitude,
              referencePoint.longitude,
              a.lat!,
              a.long!,
            )
          : double.infinity;
      final double distB = (b.lat != null && b.long != null)
          ? Geolocator.distanceBetween(
              referencePoint.latitude,
              referencePoint.longitude,
              b.lat!,
              b.long!,
            )
          : double.infinity;
      return distA.compareTo(distB);
    });

    // A legközelebbi _maxShopCount bolt megtartása, a többi eldobása
    shops = shops.sublist(0, _maxShopCount);

    debugPrint(
      "Boltlista vágva: ${shops.length} bolt megtartva "
      "(limit: $_maxShopCount)",
    );
  }

  // ---------------------------------------------------------------
  // OFFLINE ÁLLAPOT KEZELÉS
  //
  // _setOnline() / _setOffline(): Egységes állapotváltás,
  // hogy ne kelljen minden API hívás helyén kézzel kezelni.
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

  // ---------------------------------------------------------------
  // NEARBY FETCH + CACHE: Az elsődleges adatlekérési minta.
  //
  // 1. Megpróbálja az API-t hívni
  // 2. Siker → cache-eli az eredményt + online állapot
  // 3. Hiba → megpróbálja a cache-ből betölteni + offline állapot
  // 4. Ha cache sincs → exception-t dob (a hívó kezeli)
  //
  // Ez a metódus a SRP (Single Responsibility) jegyében
  // kizárólag az adat-lekérés + cache logikát tartalmazza.
  // A UI állapotot (isLoading, errorMessage) a hívó kezeli.
  // ---------------------------------------------------------------
  Future<List<Shop>> _fetchNearbyWithCache(double lat, double lng) async {
    try {
      final shops = await _apiService.fetchNearby(lat, lng);

      // Sikeres API válasz → háttérben cache-eljük
      _setOnline();
      _cacheService.saveNearbyShops(shops); // Fire-and-forget

      return shops;
    } catch (e) {
      debugPrint('API hiba, cache fallback próba: $e');

      // API hiba → megpróbáljuk a cache-t
      final cachedShops = await _cacheService.loadNearbyShops();

      if (cachedShops != null && cachedShops.isNotEmpty) {
        _setOffline();
        debugPrint(
          'Offline mód: ${cachedShops.length} bolt betöltve a cache-ből',
        );
        return cachedShops;
      }

      // Nincs cache sem → továbbdobjuk a hibát
      rethrow;
    }
  }

  // ---------------------------------------------------------------
  // ELSŐ BETÖLTÉS: Cached pozíció → boltok lekérése → háttér GPS.
  //
  // Top-level try-catch biztosítja, hogy semmilyen váratlan kivétel
  // ne szökjön ki kezelés nélkül. Ez kritikus, mert a konstruktor
  // nem képes await-elni a Future-t, és egy unhandled async exception
  // a teljes Dart zone-t crashelheti.
  // ---------------------------------------------------------------
  Future<void> _firstLoad() async {
    try {
      errorMessage = null; // Induláskor nincs hiba

      LatLng? cachedPosition;
      try {
        cachedPosition = await _locationService.getLastKnownPosition();
      } catch (_) {}

      if (cachedPosition != null && !_isDisposed) {
        myPosition = cachedPosition;
        mapCenter = cachedPosition;
        // Mentjük a pozíciót cold start fallback-nek
        _locationService.savePosition(cachedPosition);
        notifyListeners();

        try {
          shops = await _fetchNearbyWithCache(
            cachedPosition.latitude,
            cachedPosition.longitude,
          );
          _lastFetchPosition = cachedPosition;
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
        _sortShopsByDistance();
      }

      if (!_isDisposed) {
        isLoading = false;
        notifyListeners();

        // Ellenőrizzük, hogy a térkép kész-e a megjelenítésre
        _tryRevealMap();

        if (myPosition != null && errorMessage == null) {
          animatedMapMove(myPosition!, 15.0);
        }
      }

      // Csak akkor kérünk friss GPS-t a háttérben, ha nem volt hiba
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
                    shops = await _fetchNearbyWithCache(
                      freshPosition.latitude,
                      freshPosition.longitude,
                    );
                    myPosition = freshPosition;
                    _locationService.savePosition(freshPosition);
                    _sortShopsByDistance();
                    notifyListeners();
                    if (selectedIndex == 0) {
                      animatedMapMove(freshPosition, 15.0);
                    }
                  } catch (_) {}
                } else {
                  myPosition = freshPosition;
                  _locationService.savePosition(freshPosition);
                  _sortShopsByDistance();
                  notifyListeners();
                }
              }
            })
            .catchError((e) {
              debugPrint("Pontosítás sikertelen: $e");
            });
      }
    } catch (e, stack) {
      // ---------------------------------------------------------------
      // VÉGSŐ VÉDELEM: Ha bármi előre nem látott kivétel keletkezik,
      // itt elkapjuk, logoljuk, és hibaüzenetet mutatunk a usernek.
      // Enélkül az async exception kezelés nélkül maradna.
      // ---------------------------------------------------------------
      debugPrint('Váratlan hiba a _firstLoad-ban: $e\n$stack');
      if (!_isDisposed) {
        errorMessage =
            'Váratlan hiba történt az induláskor.\nKérlek próbáld újra.';
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> handleLocationPress(VoidCallback onError) async {
    isLocating = true;
    notifyListeners();

    try {
      final gpsFuture = _locationService.determinePosition();
      try {
        final cachedPosition = await _locationService.getLastKnownPosition();
        if (cachedPosition != null && selectedIndex == 0) {
          await animatedMapMove(cachedPosition, 15.0);
        }
      } catch (_) {}

      final freshPosition = await gpsFuture;

      if (freshPosition != null) {
        final newShops = await _fetchNearbyWithCache(
          freshPosition.latitude,
          freshPosition.longitude,
        );

        if (!_isDisposed) {
          myPosition = freshPosition;
          shops = newShops;
          _lastFetchPosition = freshPosition;
          _locationService.savePosition(freshPosition);
          _sortShopsByDistance();
          notifyListeners();

          if (selectedIndex == 0) {
            await animatedMapMove(freshPosition, 15.0);
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

  void onMapPositionChanged(CameraPosition position) {
    // --- Kamera adatainak mentése és forgás figyelése ---
    currentTarget = position.target;
    currentZoom = position.zoom;

    // Csak akkor frissítjük az UI-t, ha tényleg fordult a térkép
    if ((mapBearing - position.bearing).abs() > 0.5) {
      mapBearing = position.bearing;
      notifyListeners();
    }
    // ---------------------------------------------------------

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _fetchMapArea(position.target);
    });
  }

  // --- Iránytű kattintás logika ---
  Future<void> resetCompass() async {
    if (mapController == null) return;
    try {
      await mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: currentTarget, // Ott maradunk, ahol vagyunk
            zoom: currentZoom, // Olyan közelről, ahogy voltunk
            bearing: 0.0, // Vissza Északra!
            tilt: 0.0, // Extra: A 3D dőlést is alaphelyzetbe tesszük
          ),
        ),
      );
    } catch (e) {
      debugPrint("Iránytű hiba: $e");
    }
  }

  // ---------------------------------------------------------------
  // TÉRKÉP PÁSZTÁZÁS: Új boltok lekérése + memória-korlát betartása.
  //
  // Ha a user 2+ km-t mozdult az utolsó fetch óta, új nearby query
  // megy a backend felé. Az eredményt a meglévő listába merge-öljük
  // (deduplikálva), majd ha a lista túlnőtte a limitet,
  // a _pruneDistantShops levágja a legtávolabbi boltokat.
  //
  // OFFLINE: Pásztázáskor NEM használunk cache fallback-et,
  // mert a cache a korábbi pozícióhoz tartozik — félrevezető lenne.
  // Offline módban a pásztázás csendben nem csinál semmit.
  // ---------------------------------------------------------------
  Future<void> _fetchMapArea(LatLng newCenter) async {
    // Offline módban a pásztázás nem kérdez le új adatot
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
      final newShops = await _apiService.fetchNearby(
        newCenter.latitude,
        newCenter.longitude,
      );

      // Ha eddig offline voltunk, de most sikerült → online-ra váltunk
      _setOnline();

      final existingIds = shops.map((s) => s.id).toSet();
      final uniqueNewShops = newShops
          .where((s) => !existingIds.contains(s.id))
          .toList();

      if (uniqueNewShops.isNotEmpty) {
        shops = [...shops, ...uniqueNewShops];

        // Memória-limit betartása: túl távoli boltok eldobása
        _pruneDistantShops(newCenter);

        _sortShopsByDistance();
      }
      _lastFetchPosition = newCenter;
    } catch (e) {
      debugPrint("Hiba a terület keresésekor: $e");
      // Pásztázásnál nem váltunk offline módra — a meglévő adattal
      // a user továbbra is böngészhet. Csak az új terület nem tölt be.
    } finally {
      if (!_isDisposed) {
        isFetchingArea = false;
        notifyListeners();
      }
    }
  }

  Future<void> animatedMapMove(LatLng destLocation, double destZoom) async {
    if (_isDisposed || mapController == null) return;
    try {
      await mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(destLocation, destZoom),
      );
    } catch (e) {
      debugPrint("Animációs hiba: $e");
    }
  }

  // ---------------------------------------------------------------
  // KERESÉSI PIN: Kezelés
  // ---------------------------------------------------------------

  /// Keresési eredmény beállítása: pin lerakása + kamera mozgatása.
  ///
  /// Zoom stratégia típusonként:
  ///   - Pontos cím (house): zoom 17 — nincs extent, közeli nézet
  ///   - Utca: bounds + bőséges padding (150px) — a teljes utca látszódjon
  ///   - Város/település: fix zoom szint (13–14) a pont közepére
  ///     (A Photon adminisztratív extent-je városoknál gyakran túl nagy,
  ///     pl. egy megyei jogú város kiterjedése átfoghat sok tíz km-t.)
  void setSearchPin(PlaceSuggestion place) {
    searchPinPosition = LatLng(place.lat, place.lon);
    notifyListeners();

    final type = place.type;

    if (type == 'house') {
      // Pontos cím → közeli zoom, nincs extent
      animatedMapMove(searchPinPosition!, 17.0);
    } else if (type == 'street' && place.extent != null) {
      // Utca → extent bounds használata
      final ext = place.extent!;
      final bounds = LatLngBounds(
        southwest: LatLng(ext[1], ext[0]),
        northeast: LatLng(ext[3], ext[2]),
      );
      mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 150.0));
    } else if (type == 'city' || type == 'locality') {
      animatedMapMove(searchPinPosition!, 13.0);
    } else if (type == 'district' || type == 'county' || type == 'state') {
      animatedMapMove(searchPinPosition!, 14.0);
    } else {
      // Egyéb (pl. POI) → közepes zoom
      animatedMapMove(searchPinPosition!, 15.0);
    }
  }

  void clearSearchPin() {
    if (searchPinPosition != null) {
      searchPinPosition = null;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------
  // PULL-TO-REFRESH: Friss nearby lekérés az aktuális GPS pozícióval.
  //
  // Ha van ismert pozíció, azt használjuk azonnali fetch-re,
  // közben háttérben friss GPS-t kérünk. Ha a friss pozíció
  // jelentősen eltér (>500m), újra lekérdezzük a boltokat.
  // Ha nincs ismert pozíció, megpróbálunk friss GPS-t szerezni.
  // ---------------------------------------------------------------
  Future<void> refreshShops() async {
    // Azonnali fetch a jelenlegi ismert pozícióval
    if (myPosition != null) {
      try {
        final freshShops = await _fetchNearbyWithCache(
          myPosition!.latitude,
          myPosition!.longitude,
        );

        if (!_isDisposed) {
          shops = freshShops;
          _lastFetchPosition = myPosition;
          _sortShopsByDistance();
          notifyListeners();
        }
      } catch (e) {
        debugPrint("Pull-to-refresh hiba: $e");
        // Hiba esetén csendben visszatérünk — a lista marad ami volt
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

          // Ha jelentősen mozdult, újra lekérdezzük
          if (distMoved > 500) {
            final updatedShops = await _fetchNearbyWithCache(
              freshPosition.latitude,
              freshPosition.longitude,
            );

            if (!_isDisposed) {
              shops = updatedShops;
              _lastFetchPosition = freshPosition;
              _sortShopsByDistance();
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

          final freshShops = await _fetchNearbyWithCache(
            freshPosition.latitude,
            freshPosition.longitude,
          );

          if (!_isDisposed) {
            shops = freshShops;
            _lastFetchPosition = freshPosition;
            _sortShopsByDistance();
            notifyListeners();
          }
        }
      } catch (e) {
        debugPrint("Pull-to-refresh GPS hiba: $e");
      }
    }
  }

  // --- Újrapróbálkozás metódus a UI gombjának ---
  Future<void> retryInitialLoad() async {
    if (isLoading) return; // Ha már tölt, ne csináljon semmit!
    errorMessage = null;
    isLoading = true;
    notifyListeners();
    await _firstLoad();
  }

  // ---------------------------------------------------------------
  // TÁVOLSÁG SZÖVEG: Formázott távolság a felhasználótól.
  // ---------------------------------------------------------------
  String getFormattedDistance(Shop shop) {
    if (myPosition == null || shop.lat == null || shop.long == null) return '';
    final dist = Geolocator.distanceBetween(
      myPosition!.latitude,
      myPosition!.longitude,
      shop.lat!,
      shop.long!,
    );
    if (dist < 1000) {
      return '${dist.round()} m';
    } else {
      return '${(dist / 1000).toStringAsFixed(1)} km';
    }
  }
}
