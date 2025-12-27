class Shop {
  final String id;
  final String name;
  final String address;
  final String city;
  final double lat;
  final double long;
  final Map<String, dynamic>? openingHours;

  Shop({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.lat,
    required this.long,
    this.openingHours,
  });

  // Ez a "gyár" készíti el az objektumot a JSON-ból
  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Névtelen bolt',
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      // Biztosítjuk, hogy szám legyen, akkor is, ha stringként jön
      lat: (json['lat'] is String) ? double.parse(json['lat']) : (json['lat'] as num).toDouble(),
      long: (json['long'] is String) ? double.parse(json['long']) : (json['long'] as num).toDouble(),
      openingHours: json['openingHours'],
    );
  }
}