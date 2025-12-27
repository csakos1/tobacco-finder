import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/shop.dart';
import '../utils/shop_logic.dart';

class ShopDetailsModal extends StatelessWidget {
  final Shop shop;
  final LatLng? myPosition;
  final Distance distanceCalculator = const Distance();

  ShopDetailsModal({super.key, required this.shop, this.myPosition});

  @override
  Widget build(BuildContext context) {
    // Távolság számítás
    String distanceText = "Ismeretlen";
    if (myPosition != null) {
      double dist = distanceCalculator.as(
          LengthUnit.Meter, myPosition!, LatLng(shop.lat, shop.long));
      distanceText = dist > 1000
          ? "${(dist / 1000).toStringAsFixed(1)} km"
          : "${dist.round()} m";
    }

    bool isOpen = ShopLogic.isOpenNow(shop.openingHours);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cím és Státusz
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      shop.name,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isOpen ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isOpen ? "NYITVA" : "ZÁRVA",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(children: [
                const Icon(Icons.location_on, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(child: Text('${shop.city}, ${shop.address}'))
              ]),
              const SizedBox(height: 5),
              Row(children: [
                const Icon(Icons.directions_walk, color: Colors.blue),
                const SizedBox(width: 8),
                Text("$distanceText tőled")
              ]),

              const Divider(height: 30),

              const Text("Nyitvatartás",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              if (shop.openingHours != null)
                ...List.generate(7, (index) {
                  int dayIndex = index + 1;
                  String dayName = [
                    "Hétfő", "Kedd", "Szerda", "Csütörtök", "Péntek", "Szombat", "Vasárnap"
                  ][index];
                  String hours = shop.openingHours![dayIndex.toString()] ?? "Zárva";

                  bool isToday = DateTime.now().weekday == dayIndex;

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: isToday
                        ? BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.blue.withOpacity(0.3)))
                        : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(dayName,
                            style: TextStyle(
                                fontWeight: isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                        Text(hours,
                            style: TextStyle(
                                fontWeight: isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                      ],
                    ),
                  );
                })
              else
                const Text("Nincs adat a nyitvatartásról.",
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
            ],
          ),
        );
      },
    );
  }
}