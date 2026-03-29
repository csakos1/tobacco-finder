// app/lib/services/shop_cache_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shop.dart';

// ---------------------------------------------------------------
// OFFLINE CACHE RÉTEG
//
// Az utolsó sikeres API response-t JSON-ként eltárolja
// SharedPreferences-ben. Ha az app nem tud csatlakozni a szerverhez
// (pl. metró, repülő, rossz térerő), a cache-elt adatokat mutatja.
//
// Két független slot van:
//   - 'nearby' → a GPS-alapú közeli boltok (elsődleges nézet)
//   - 'all'    → az összes bolt (tartalék, ha nincs GPS)
//
// A mentés timestamp-et is kap, így a UI tudja jelezni az adatok korát.
// ---------------------------------------------------------------
class ShopCacheService {
  static const String _nearbyShopsKey = 'cached_nearby_shops';
  static const String _nearbyTimestampKey = 'cached_nearby_timestamp';
  static const String _allShopsKey = 'cached_all_shops';
  static const String _allTimestampKey = 'cached_all_timestamp';

  // ---------------------------------------------------------------
  // MENTÉS: Boltlista → JSON string → SharedPreferences
  //
  // A compute() izolátumba helyezi a JSON encode-ot, hogy a
  // nagy listák (500+ bolt) ne blokkólják a UI szálat.
  // ---------------------------------------------------------------

  /// Közeli boltok cache-elése (GPS-alapú lekérdezés eredménye).
  Future<void> saveNearbyShops(List<Shop> shops) async {
    await _saveShops(shops, _nearbyShopsKey, _nearbyTimestampKey);
  }

  /// Összes bolt cache-elése (tartalék lekérdezés eredménye).
  Future<void> saveAllShops(List<Shop> shops) async {
    await _saveShops(shops, _allShopsKey, _allTimestampKey);
  }

  // ---------------------------------------------------------------
  // BETÖLTÉS: SharedPreferences → JSON string → Shop lista
  //
  // Ha nincs cache (első indítás), null-t ad vissza.
  // Ha a JSON parse hibás, töröljük a sérült adatot és null-t adunk.
  // ---------------------------------------------------------------

  /// Közeli boltok betöltése a cache-ből.
  Future<List<Shop>?> loadNearbyShops() async {
    return _loadShops(_nearbyShopsKey);
  }

  /// Összes bolt betöltése a cache-ből.
  Future<List<Shop>?> loadAllShops() async {
    return _loadShops(_allShopsKey);
  }

  /// A közeli boltok utolsó cache-elésének időpontja.
  Future<DateTime?> getNearbyTimestamp() async {
    return _getTimestamp(_nearbyTimestampKey);
  }

  /// Az összes bolt utolsó cache-elésének időpontja.
  Future<DateTime?> getAllTimestamp() async {
    return _getTimestamp(_allTimestampKey);
  }

  // ---------------------------------------------------------------
  // PRIVÁT SEGÉDMETÓDUSOK
  // ---------------------------------------------------------------

  Future<void> _saveShops(
    List<Shop> shops,
    String shopsKey,
    String timestampKey,
  ) async {
    try {
      final jsonString = await compute(_encodeShops, shops);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(shopsKey, jsonString);
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // Cache mentési hiba nem kritikus — az app működik nélküle is.
      debugPrint('ShopCache mentési hiba ($shopsKey): $e');
    }
  }

  Future<List<Shop>?> _loadShops(String shopsKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(shopsKey);

      if (jsonString == null || jsonString.isEmpty) return null;

      return await compute(_decodeShops, jsonString);
    } catch (e) {
      debugPrint('ShopCache betöltési hiba ($shopsKey): $e');
      // Sérült cache törlése, hogy ne akadjon be újra
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(shopsKey);
      } catch (_) {}
      return null;
    }
  }

  Future<DateTime?> _getTimestamp(String timestampKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final millis = prefs.getInt(timestampKey);
      if (millis == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------
  // TOP-LEVEL / STATIC FÜGGVÉNYEK a compute() izolátumhoz.
  // Nem lehetnek instance metódusok — a Dart compute() csak
  // top-level vagy static függvényt tud futtatni háttérszálon.
  // ---------------------------------------------------------------

  static String _encodeShops(List<Shop> shops) {
    final jsonList = shops.map((s) => s.toJson()).toList();
    return jsonEncode(jsonList);
  }

  static List<Shop> _decodeShops(String jsonString) {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList
        .map((json) => Shop.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
