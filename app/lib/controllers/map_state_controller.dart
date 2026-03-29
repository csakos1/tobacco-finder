// app/lib/controllers/map_state_controller.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/place_suggestion.dart';

// ---------------------------------------------------------------
// TÉRKÉP ÁLLAPOT VEZÉRLŐ
//
// Kizárólag a térkép UI-jával kapcsolatos állapotot tartja:
// kamera pozíció, bearing (iránytű), zoom, keresési pin,
// és a térkép fedő overlay (isMapReady).
//
// Saját ChangeNotifier → a notifyListeners() hívásai CSAK
// a térképet figyelő widgeteket építik újra (iránytű, overlay),
// NEM az egész Scaffold-ot (lista, szűrők, FAB, stb.).
// ---------------------------------------------------------------
class MapStateController extends ChangeNotifier {
  GoogleMapController? mapController;

  // --- Kamera állapot ---
  double mapBearing = 0.0;
  double currentZoom = 15.0;
  LatLng currentTarget;
  LatLng mapCenter;

  // --- Térkép megjelenítési állapot ---
  bool isMapReady = false;

  // --- Keresési pin ---
  LatLng? searchPinPosition;

  bool _isDisposed = false;

  /// Getter: el van-e forgatva a térkép (nem 0 fokon áll).
  bool get isMapRotated => mapBearing > 0.5 && mapBearing < 359.5;

  // ---------------------------------------------------------------
  // KONSTRUKTOR: A kezdő pozíciót kívülről kapja
  // (HomeController adja át az elmentett/default értéket).
  // ---------------------------------------------------------------
  MapStateController({required LatLng initialPosition})
    : currentTarget = initialPosition,
      mapCenter = initialPosition;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  // ---------------------------------------------------------------
  // KAMERA FRISSÍTÉS: A GoogleMap onCameraMove callback-jéből hívva.
  //
  // Mindig frissíti a target-et és a zoom-ot (szinkronban tartás),
  // de CSAK akkor hív notifyListeners()-t, ha a bearing (forgásszög)
  // ténylegesen változott. Így a térkép eltolása (pásztázás) nem
  // triggerel felesleges UI rebuild-et az iránytű widgetben.
  //
  // Visszatérési érték: a frissített target pozíció,
  // hogy a hívó (HomeController) használhassa a debounce fetch-hez.
  // ---------------------------------------------------------------
  LatLng updateCamera(CameraPosition position) {
    currentTarget = position.target;
    currentZoom = position.zoom;

    if ((mapBearing - position.bearing).abs() > 0.5) {
      mapBearing = position.bearing;
      notifyListeners();
    }

    return position.target;
  }

  // ---------------------------------------------------------------
  // MAP CONTROLLER: A GoogleMap onMapCreated callback-jéből hívva.
  // A tryRevealMap() hívás a HomeController feladata, mert az
  // ismeri az isLoading állapotot.
  // ---------------------------------------------------------------
  void setMapController(GoogleMapController controller) {
    mapController = controller;
  }

  // ---------------------------------------------------------------
  // TÉRKÉP FEDŐ OVERLAY ELTÁVOLÍTÁSA
  //
  // A HomeController hívja, amikor mindkét feltétel teljesül:
  //   1. A GoogleMapController létrejött
  //   2. Az adatbetöltés befejeződött
  //
  // Késleltetés: a tile-ok renderelésére várunk, hogy
  // ne villanjon be a nyers térkép a fedő mögül.
  // ---------------------------------------------------------------
  void tryRevealMap() {
    if (isMapReady || _isDisposed) return;
    if (mapController == null) return;

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!_isDisposed && !isMapReady) {
        isMapReady = true;
        notifyListeners();
      }
    });
  }

  // ---------------------------------------------------------------
  // ANIMÁLT KAMERA MOZGATÁS
  //
  // Publikus, mert a HomeController is hívja (pl. GPS pozícióra
  // ugrás, keresési eredmény), és belső használatra is kell
  // (setSearchPin zoom stratégia).
  // ---------------------------------------------------------------
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
  // IRÁNYTŰ: Visszaforgatás északra.
  // ---------------------------------------------------------------
  Future<void> resetCompass() async {
    if (mapController == null) return;
    try {
      await mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: currentTarget,
            zoom: currentZoom,
            bearing: 0.0,
            tilt: 0.0,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Iránytű hiba: $e");
    }
  }

  // ---------------------------------------------------------------
  // KERESÉSI PIN KEZELÉS
  //
  // Zoom stratégia típusonként:
  //   - Pontos cím (house): zoom 17
  //   - Utca: bounds + bőséges padding (150px)
  //   - Város/település: fix zoom szint (13–14)
  //   - Egyéb: közepes zoom (15)
  //
  // A Photon adminisztratív extent-je városoknál gyakran túl nagy,
  // ezért fix zoom szinteket használunk a pontos extent helyett.
  // ---------------------------------------------------------------
  void setSearchPin(PlaceSuggestion place) {
    searchPinPosition = LatLng(place.lat, place.lon);
    notifyListeners();

    final type = place.type;

    if (type == 'house') {
      animatedMapMove(searchPinPosition!, 17.0);
    } else if (type == 'street' && place.extent != null) {
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
      animatedMapMove(searchPinPosition!, 15.0);
    }
  }

  void clearSearchPin() {
    if (searchPinPosition != null) {
      searchPinPosition = null;
      notifyListeners();
    }
  }
}
