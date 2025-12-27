import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/shop.dart';
import '../utils/shop_logic.dart'; // Kell a nyitvatartás logikához
import 'shop_details_modal.dart';

class ShopList extends StatelessWidget {
  final List<Shop> shops;
  final LatLng? myPosition;
  final Distance distanceCalculator = const Distance();

  ShopList({
    super.key,
    required this.shops,
    required this.myPosition,
  });

  @override
  Widget build(BuildContext context) {
    // 1. RENDEZÉS: Lemásoljuk a listát, és sorba rendezzük távolság szerint
    List<Shop> sortedShops = List.from(shops);
    
    if (myPosition != null) {
      sortedShops.sort((a, b) {
        double distA = distanceCalculator.as(LengthUnit.Meter, myPosition!, LatLng(a.lat, a.long));
        double distB = distanceCalculator.as(LengthUnit.Meter, myPosition!, LatLng(b.lat, b.long));
        return distA.compareTo(distB); // Növekvő sorrend
      });
    }

    if (sortedShops.isEmpty) {
      return const Center(child: Text("Nincs megjeleníthető bolt."));
    }

    return ListView.builder(
      itemCount: sortedShops.length,
      padding: const EdgeInsets.all(8.0),
      itemBuilder: (context, index) {
        final shop = sortedShops[index];
        bool isOpen = ShopLogic.isOpenNow(shop.openingHours);

        // Távolság szöveg
        String distanceText = "";
        if (myPosition != null) {
          double dist = distanceCalculator.as(LengthUnit.Meter, myPosition!, LatLng(shop.lat, shop.long));
          distanceText = dist > 1000 
              ? "${(dist / 1000).toStringAsFixed(1)} km" 
              : "${dist.round()} m";
        }

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            onTap: () {
              // Ugyanazt a részletes ablakot hívjuk meg, mint a térképen!
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => ShopDetailsModal(shop: shop, myPosition: myPosition),
              );
            },
            // Ikon a bal oldalon
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.store, color: Colors.blue[700]),
            ),
            // Bolt neve
            title: Text(
              shop.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            // Cím és távolság
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text("${shop.city}, ${shop.address}", style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 4),
                if (distanceText.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.directions_walk, size: 14, color: Colors.blue[400]),
                      const SizedBox(width: 4),
                      Text(distanceText, style: TextStyle(color: Colors.blue[600], fontWeight: FontWeight.w600)),
                    ],
                  )
              ],
            ),
            // NYITVA / ZÁRVA jelvény a jobb oldalon
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOpen ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isOpen ? Colors.green : Colors.red),
                  ),
                  child: Text(
                    isOpen ? "Nyitva" : "Zárva",
                    style: TextStyle(
                      color: isOpen ? Colors.green[700] : Colors.red[700],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}