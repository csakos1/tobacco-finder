// app/lib/controllers/home_controller.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/shop.dart';
import '../models/place_suggestion.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../utils/shop_logic.dart';
import '../main.dart' show initialMapPosition;

enum ShopFilter { none, openNow, nonStop }

class HomeController extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();

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
        final freshShops = await _apiService.fetchNearby(
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
            final updatedShops = await _apiService.fetchNearby(
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

          final freshShops = await _apiService.fetchNearby(
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
          shops = await _apiService.fetchNearby(
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
                    shops = await _apiService.fetchNearby(
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
        final newShops = await _apiService.fetchNearby(
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
  // ---------------------------------------------------------------
  Future<void> _fetchMapArea(LatLng newCenter) async {
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
  ///     pl. Siófok extent-je kiterjed a fél Balatonra)
  Future<void> setSearchPin(PlaceSuggestion place) async {
    if (_isDisposed || mapController == null) return;

    searchPinPosition = LatLng(place.lat, place.lon);
    notifyListeners();

    if (place.isExactAddress) {
      // Pontos cím → szoros közelítés
      await animatedMapMove(searchPinPosition!, 17.0);
    } else if (place.isStreet) {
      // Utca → bounds-ot használjuk ha van, nagy paddinggel
      final LatLngBounds? bounds = place.bounds;
      if (bounds != null) {
        await _animateToBounds(bounds, padding: 150.0, fallbackZoom: 16.0);
      } else {
        await animatedMapMove(searchPinPosition!, 16.0);
      }
    } else if (place.isSettlement) {
      // Város/település → fix zoom szint, NEM az extent alapján.
      // A Photon admin extent-je megbízhatatlan: kisebb városoknál (pl. Siófok)
      // az adminisztratív határ sokkal nagyobb mint a tényleges beépített terület.
      final double zoom = _settlementZoom(place.type);
      await animatedMapMove(searchPinPosition!, zoom);
    } else {
      // Egyéb típus (pl. locality, region, POI)
      final LatLngBounds? bounds = place.bounds;
      if (bounds != null) {
        await _animateToBounds(bounds, padding: 100.0, fallbackZoom: 14.0);
      } else {
        await animatedMapMove(searchPinPosition!, 15.0);
      }
    }
  }

  /// Bounds-ra illesztés fallback-kel.
  Future<void> _animateToBounds(
    LatLngBounds bounds, {
    required double padding,
    required double fallbackZoom,
  }) async {
    if (_isDisposed || mapController == null) return;
    try {
      await mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, padding),
      );
    } catch (e) {
      debugPrint("Bounds animáció hiba: $e");
      final center = LatLng(
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
      );
      await animatedMapMove(center, fallbackZoom);
    }
  }

  /// Település típusához illő zoom szint.
  double _settlementZoom(String? type) {
    switch (type) {
      case 'city':
        return 13.0;
      case 'town':
        return 13.5;
      case 'village':
        return 14.5;
      case 'district':
      case 'borough':
        return 14.0;
      default:
        return 13.0;
    }
  }

  /// Keresési pin eltávolítása a térképről.
  void clearSearchPin() {
    if (searchPinPosition == null) return;

    searchPinPosition = null;
    notifyListeners();
  }

  String getFormattedDistance(Shop shop) {
    if (myPosition == null || shop.lat == null || shop.long == null) return "";
    final double dist = Geolocator.distanceBetween(
      myPosition!.latitude,
      myPosition!.longitude,
      shop.lat!,
      shop.long!,
    );
    return dist > 1000
        ? "${(dist / 1000).toStringAsFixed(1)} km"
        : "${dist.round()} m";
  }
}
