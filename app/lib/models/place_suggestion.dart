// app/lib/models/place_suggestion.dart

class PlaceSuggestion {
  final String name;
  final String? city;
  final String? street;
  final double lat;
  final double lon;

  PlaceSuggestion({
    required this.name,
    this.city,
    this.street,
    required this.lat,
    required this.lon,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final props = json['properties'];
    final coords =
        json['geometry']['coordinates']; // A GeoJSON [lon, lat] sorrendet használ!

    return PlaceSuggestion(
      name: props['name'] ?? '',
      city: props['city'] ?? props['town'] ?? props['village'],
      street: props['street'],
      lat: coords[1].toDouble(),
      lon: coords[0].toDouble(),
    );
  }

  // Egy szép formázott cím a listaelemek alá
  String get formattedAddress {
    List<String> parts = [];
    if (city != null && city != name) parts.add(city!);
    if (street != null && street != name) parts.add(street!);
    if (parts.isEmpty) return 'Magyarország';
    return parts.join(', ');
  }
}
