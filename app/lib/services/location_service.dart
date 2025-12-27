import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  // Ez a "lassú", pontos GPS
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
    return LatLng(position.latitude, position.longitude);
  }

  // ÚJ: Ez a villámgyors, cache-elt pozíció
  Future<LatLng?> getLastKnownPosition() async {
    // Csak akkor kérjük le, ha van engedély, különben hibát dobhat
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }
    
    Position? position = await Geolocator.getLastKnownPosition();
    if (position != null) {
      return LatLng(position.latitude, position.longitude);
    }
    return null;
  }
}