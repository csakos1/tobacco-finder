// app/lib/controllers/home_controller.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/shop.dart';
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
  LatLng? myPosition;
  LatLng mapCenter = const LatLng(47.50712, 19.04557);

  int selectedIndex = 0;
  bool isLocating = false;
  bool isFetchingArea = false;
  bool isMapReady = false;

  LatLng? _lastFetchPosition;
  ShopFilter currentFilter = ShopFilter.none;

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

  // Szűrt lista lekérése
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

  Future<void> _firstLoad() async {
    LatLng? initialPosition;
    try {
      initialPosition = await _locationService.getLastKnownPosition();
    } catch (e) {
      debugPrint("Hiba a cache pozíció lekérésnél: $e");
    }

    if (initialPosition == null) {
      try {
        initialPosition = await _locationService.determinePosition();
      } catch (e) {
        debugPrint("GPS hiba induláskor: $e");
      }
    }

    if (initialPosition != null) {
      myPosition = initialPosition;
      mapCenter = initialPosition;
    }

    try {
      if (myPosition != null) {
        shops = await _apiService.fetchNearby(
          myPosition!.latitude,
          myPosition!.longitude,
        );
        _lastFetchPosition = myPosition;
      } else {
        shops = await _apiService.fetchShops();
        _lastFetchPosition = mapCenter;
      }
    } catch (e) {
      debugPrint("Bolt letöltési hiba: $e");
    }

    if (myPosition != null) {
      _sortShopsByDistance();
    }

    if (!_isDisposed) {
      isLoading = false;
      notifyListeners();
      if (myPosition != null) {
        animatedMapMove(myPosition!, 15.0);
      }
    }

    if (myPosition != null) {
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
      onError(); // Szólunk a UI-nak, hogy mutassa a SnackBart
    } finally {
      if (!_isDisposed) {
        isLocating = false;
        notifyListeners();
      }
    }
  }

  void onMapPositionChanged(CameraPosition position) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _fetchMapArea(position.target);
    });
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

  // Távolság kiszámítása és formázása a UI számára
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
