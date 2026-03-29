// app/lib/repositories/shop_repository.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/shop.dart';
import '../models/shop_filter.dart';
import '../services/api_service.dart';
import '../services/shop_cache_service.dart';
import '../utils/shop_logic.dart';

// ---------------------------------------------------------------
// BOLT ADATRÉTEG (Repository)
//
// NEM ChangeNotifier — ez egy tiszta adatkezelő osztály.
// A UI állapotot (isLoading, isOffline, stb.) a hívó
// HomeController kezeli a visszatérési értékek alapján.
//
// Felelősségei:
//   - API hívás + cache fallback (offline mód)
//   - Boltlista merge/deduplikáció (pásztázásnál)
//   - Memória-limit betartása (távoli boltok eldobása)
//   - Távolság szerinti rendezés
//   - Szűrés (nyitva most / non-stop)
//   - Formázott távolság szöveg
// ---------------------------------------------------------------
class ShopRepository {
  final ApiService _apiService;
  final ShopCacheService _cacheService;

  ShopRepository({ApiService? apiService, ShopCacheService? cacheService})
    : _apiService = apiService ?? ApiService(),
      _cacheService = cacheService ?? ShopCacheService();

  // ---------------------------------------------------------------
  // NEARBY FETCH + CACHE: Az elsődleges adatlekérési minta.
  //
  // 1. Megpróbálja az API-t hívni
  // 2. Siker → cache-eli az eredményt, visszaadja (isFromCache: false)
  // 3. Hiba → megpróbálja a cache-ből betölteni (isFromCache: true)
  // 4. Ha cache sincs → exception-t dob (a hívó kezeli)
  //
  // A hívó (HomeController) a [ShopFetchResult.isFromCache] alapján
  // tudja beállítani az offline/online állapotot.
  // ---------------------------------------------------------------
  Future<ShopFetchResult> fetchNearbyWithCache(double lat, double lng) async {
    try {
      final shops = await _apiService.fetchNearby(lat, lng);

      // Sikeres API válasz → háttérben cache-eljük (fire-and-forget)
      _cacheService.saveNearbyShops(shops);

      return ShopFetchResult(shops: shops, isFromCache: false);
    } catch (e) {
      debugPrint('API hiba, cache fallback próba: $e');

      final cachedShops = await _cacheService.loadNearbyShops();

      if (cachedShops != null && cachedShops.isNotEmpty) {
        debugPrint(
          'Offline mód: ${cachedShops.length} bolt betöltve a cache-ből',
        );
        return ShopFetchResult(shops: cachedShops, isFromCache: true);
      }

      // Nincs cache sem → továbbdobjuk a hibát
      rethrow;
    }
  }

  // ---------------------------------------------------------------
  // TÉRKÉP PÁSZTÁZÁS: Csak az új (még nem ismert) boltok lekérése.
  //
  // Az API-t közvetlenül hívja (cache nélkül), mert a pásztázásnál
  // a cache a korábbi pozícióhoz tartozik — félrevezető lenne.
  //
  // Visszaad egy listát az ÚJ boltokról (amelyek nincsenek
  // az [existingIds] halmazban), vagy üres listát ha nincs új.
  // Ha hiba van, exception-t dob.
  // ---------------------------------------------------------------
  Future<List<Shop>> fetchNewAreaShops(
    double lat,
    double lng,
    Set<String> existingIds,
  ) async {
    final newShops = await _apiService.fetchNearby(lat, lng);

    return newShops.where((s) => !existingIds.contains(s.id)).toList();
  }

  // ---------------------------------------------------------------
  // RENDEZÉS: Boltlista távolság szerint (legközelebbi elöl).
  //
  // Módosítja az eredeti listát (in-place sort) a hatékonyság
  // kedvéért — ne kelljen másolatot készíteni 500 elemből.
  // ---------------------------------------------------------------
  void sortByDistance(List<Shop> shops, LatLng userPosition) {
    shops.sort((a, b) {
      if (a.lat == null || a.long == null) return 1;
      if (b.lat == null || b.long == null) return -1;

      final double distA = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        a.lat!,
        a.long!,
      );
      final double distB = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        b.lat!,
        b.long!,
      );
      return distA.compareTo(distB);
    });
  }

  // ---------------------------------------------------------------
  // MEMÓRIA KARBANTARTÁS: Túl távoli boltok eldobása.
  //
  // Ha a boltlista meghaladja a [maxCount] limitet,
  // a [referencePoint]-tól legtávolabbi boltokat vágjuk le.
  // A user közvetlen környéke mindig megmarad.
  //
  // Visszaadja a vágott listát (új lista objektum).
  // ---------------------------------------------------------------
  List<Shop> pruneDistant(
    List<Shop> shops,
    LatLng referencePoint, {
    int maxCount = 500,
  }) {
    if (shops.length <= maxCount) return shops;

    final sorted = List<Shop>.from(shops);
    sorted.sort((a, b) {
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

    debugPrint(
      "Boltlista vágva: $maxCount bolt megtartva (volt: ${shops.length})",
    );
    return sorted.sublist(0, maxCount);
  }

  // ---------------------------------------------------------------
  // MERGE: Meglévő + új boltok összefésülése (deduplikálva).
  // ---------------------------------------------------------------
  List<Shop> mergeShops(List<Shop> existing, List<Shop> newShops) {
    if (newShops.isEmpty) return existing;
    return [...existing, ...newShops];
  }

  // ---------------------------------------------------------------
  // SZŰRÉS: Az aktív filter alkalmazása a boltlistára.
  // ---------------------------------------------------------------
  List<Shop> applyFilter(List<Shop> shops, ShopFilter filter) {
    switch (filter) {
      case ShopFilter.openNow:
        return shops.where((s) => ShopLogic.isOpenNow(s.openingHours)).toList();
      case ShopFilter.nonStop:
        return shops.where((s) => ShopLogic.isNonStop(s.openingHours)).toList();
      case ShopFilter.none:
        return shops;
    }
  }

  // ---------------------------------------------------------------
  // FORMÁZOTT TÁVOLSÁG: Ember által olvasható szöveg.
  // ---------------------------------------------------------------
  String formatDistance(Shop shop, LatLng? userPosition) {
    if (userPosition == null || shop.lat == null || shop.long == null) {
      return '';
    }

    final dist = Geolocator.distanceBetween(
      userPosition.latitude,
      userPosition.longitude,
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

// ---------------------------------------------------------------
// FETCH EREDMÉNY: Az API/cache lekérdezés visszatérési típusa.
//
// A [isFromCache] flag jelzi a hívónak, hogy az adatok a cache-ből
// jöttek-e (offline mód) vagy friss API válaszból (online).
// Így a UI állapot (isOffline banner) kezelése a controller
// feladata marad — a repository nem ismer UI fogalmakat.
// ---------------------------------------------------------------
class ShopFetchResult {
  final List<Shop> shops;
  final bool isFromCache;

  const ShopFetchResult({required this.shops, this.isFromCache = false});
}
