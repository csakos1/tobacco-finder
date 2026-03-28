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

enum ShopFilter { none, openNow, nonStop }

class HomeController extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();

  GoogleMapController? mapController;
  Timer? _debounce;

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
    _firstLoad();
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
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!_isDisposed) {
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

  // --- Újrapróbálkozás metódus a UI gombjának ---
  Future<void> retryInitialLoad() async {
    if (isLoading) return; // Ha már tölt, ne csináljon semmit!

    errorMessage = null;
    isLoading = true;
    notifyListeners();
    await _firstLoad();
  }

  Future<void> _firstLoad() async {
    errorMessage = null; // Induláskor nincs hiba

    LatLng? cachedPosition;
    try {
      cachedPosition = await _locationService.getLastKnownPosition();
    } catch (_) {}

    if (cachedPosition != null && !_isDisposed) {
      myPosition = cachedPosition;
      mapCenter = cachedPosition;
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
                  _sortShopsByDistance();
                  notifyListeners();
                  if (selectedIndex == 0) {
                    animatedMapMove(freshPosition, 15.0);
                  }
                } catch (_) {}
              } else {
                myPosition = freshPosition;
                _sortShopsByDistance();
                notifyListeners();
              }
            }
          })
          .catchError((e) {
            debugPrint("Pontosítás sikertelen: $e");
          });
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
  /// Az extent alapján dönt a zoom szintről:
  ///   - pontos cím (nincs extent) → zoom 17
  ///   - utca/város (van extent) → bounding box-ra illesztés
  Future<void> setSearchPin(PlaceSuggestion place) async {
    if (_isDisposed || mapController == null) return;

    searchPinPosition = LatLng(place.lat, place.lon);
    notifyListeners();

    final LatLngBounds? bounds = place.bounds;

    if (bounds != null) {
      // Van bounding box → ráközelítünk az extent-re
      // A padding biztosítja, hogy ne legyenek szélén a határok
      try {
        await mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 60.0),
        );
      } catch (e) {
        debugPrint("Bounds animáció hiba: $e");
        // Fallback: egyszerű közelítés
        await animatedMapMove(searchPinPosition!, 14.0);
      }
    } else if (place.isExactAddress) {
      // Pontos cím, nincs extent → nagyon közel zoomolunk
      await animatedMapMove(searchPinPosition!, 17.0);
    } else {
      // Egyéb (pl. POI, locality) → közepes zoom
      await animatedMapMove(searchPinPosition!, 15.0);
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
