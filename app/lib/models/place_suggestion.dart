// app/lib/models/place_suggestion.dart

import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlaceSuggestion {
  final String name;
  final String? city;
  final String? street;
  final String? houseNumber;
  final double lat;
  final double lon;

  /// A Photon API által visszaadott típus (pl. "city", "street", "house", "locality").
  /// Ez határozza meg a zoom szintet a térképen.
  final String? type;

  /// Bounding box a Photon API-ból: [west, north, east, south].
  /// Városoknál és utcáknál elérhető, pontos címeknél általában null.
  final List<double>? extent;

  PlaceSuggestion({
    required this.name,
    this.city,
    this.street,
    this.houseNumber,
    required this.lat,
    required this.lon,
    this.type,
    this.extent,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final props = json['properties'];
    final coords =
        json['geometry']['coordinates']; // A GeoJSON [lon, lat] sorrendet használ!

    // Extent kiolvasása ha létezik
    List<double>? parsedExtent;
    if (props['extent'] != null) {
      final rawExtent = props['extent'] as List;
      if (rawExtent.length == 4) {
        parsedExtent = rawExtent.map((e) => (e as num).toDouble()).toList();
      }
    }

    final String? houseNumber = props['housenumber'] as String?;
    final String? street = props['street'] as String?;
    final String rawName = props['name'] as String? ?? '';
    final String parsedType = props['type'] as String? ?? '';

    // Házszámos találatoknál a Photon sokszor üres name-et ad vissza,
    // vagy a name csak a házszám. Ilyenkor az utcanévből + házszámból
    // építjük fel az olvasható nevet.
    String displayName = rawName;
    if (parsedType == 'house' && street != null) {
      displayName = houseNumber != null ? '$street $houseNumber' : street;
    } else if (displayName.isEmpty && street != null) {
      displayName = street;
    }

    return PlaceSuggestion(
      name: displayName,
      city: props['city'] ?? props['town'] ?? props['village'],
      street: street,
      houseNumber: houseNumber,
      lat: coords[1].toDouble(),
      lon: coords[0].toDouble(),
      type: parsedType.isNotEmpty ? parsedType : null,
      extent: parsedExtent,
    );
  }

  /// A keresési eredmény egy pontos cím-e (ház szám szintű).
  bool get isExactAddress =>
      type == 'house' || type == 'building' || type == 'address';

  /// A keresési eredmény utca szintű-e.
  bool get isStreet => type == 'street' || type == 'highway';

  /// A keresési eredmény város/település szintű-e.
  bool get isSettlement =>
      type == 'city' ||
      type == 'town' ||
      type == 'village' ||
      type == 'district' ||
      type == 'borough' ||
      type == 'county';

  /// LatLngBounds a bounding box-ból (ha elérhető).
  /// Photon formátum: [west, north, east, south]
  LatLngBounds? get bounds {
    if (extent == null || extent!.length != 4) return null;

    final west = extent![0];
    final north = extent![1];
    final east = extent![2];
    final south = extent![3];

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  // Egy szép formázott cím a listaelemek alá
  String get formattedAddress {
    List<String> parts = [];
    if (city != null && city != name) parts.add(city!);

    // Utcanév kiírása — de csak ha nem egyezik a name-mel.
    // Házszámos találatoknál a name már tartalmazza az utca + házszámot,
    // ezért az utcát felesleges megismételni ha a name eleve a street-ből épül.
    if (street != null && street != name && !name.startsWith(street!)) {
      parts.add(street!);
    }

    if (parts.isEmpty) return 'Magyarország';
    return parts.join(', ');
  }
}
