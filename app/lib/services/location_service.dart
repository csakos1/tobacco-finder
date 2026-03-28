// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  // ---------------------------------------------------------------
  // SharedPreferences kulcsok a pozíció perzisztálásához.
  // Cold start-nál a Geolocator cache üres lehet (pl. újraindítás után),
  // ezért saját mentést is tartunk.
  // ---------------------------------------------------------------
  static const String _latKey = 'last_lat';
  static const String _lngKey = 'last_lng';

  /// Pontos GPS pozíció lekérdezése (lassabb, de pontos).
  Future<LatLng?> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    Position position = await Geolocator.getCurrentPosition();
    final latLng = LatLng(position.latitude, position.longitude);

    // Minden sikeres GPS lekérdezésnél mentjük a pozíciót
    savePosition(latLng);

    return latLng;
  }

  /// Gyors, cache-elt pozíció a Geolocator-ból.
  Future<LatLng?> getLastKnownPosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    Position? position = await Geolocator.getLastKnownPosition();
    if (position != null) {
      return LatLng(position.latitude, position.longitude);
    }
    return null;
  }

  /// Pozíció mentése SharedPreferences-be (cold start fallback).
  Future<void> savePosition(LatLng position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_latKey, position.latitude);
      await prefs.setDouble(_lngKey, position.longitude);
    } catch (_) {
      // Mentési hiba nem kritikus — csendben lenyeljük
    }
  }

  /// Mentett pozíció szinkron betöltése egy már meglévő SharedPreferences példányból.
  /// A main()-ben hívjuk, ahol a prefs már rendelkezésre áll.
  static LatLng? loadSavedPosition(SharedPreferences prefs) {
    final lat = prefs.getDouble(_latKey);
    final lng = prefs.getDouble(_lngKey);
    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }
    return null;
  }
}
