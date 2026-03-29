class Shop {
  final String id;
  final String name;
  final String address;
  final String city;

  // VÁLTOZÁS: nullable lett (kérdőjel a végén)
  final double? lat;
  final double? long;

  final Map<String, dynamic>? openingHours;

  Shop({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    this.lat, // Nincs 'required'
    this.long, // Nincs 'required'
    this.openingHours,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Névtelen bolt',
      address: json['address'] ?? '',
      city: json['city'] ?? '',

      // VÁLTOZÁS: Ha null jön, marad null. Ha adat, akkor parse-oljuk.
      lat: json['lat'] != null
          ? (json['lat'] is String
                ? double.parse(json['lat'])
                : (json['lat'] as num).toDouble())
          : null,
      long: json['long'] != null
          ? (json['long'] is String
                ? double.parse(json['long'])
                : (json['long'] as num).toDouble())
          : null,

      openingHours: json['openingHours'],
    );
  }

  /// Szerializálás JSON-be az offline cache számára.
  /// A fromJson()-nel szimmetrikus — amit ez ír, azt fromJson() visszaolvassa.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'lat': lat,
      'long': long,
      'openingHours': openingHours,
    };
  }
}
