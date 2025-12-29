import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/shop.dart';
import '../utils/shop_logic.dart';

class ShopDetailsModal extends StatelessWidget {
  final Shop shop;
  final LatLng? myPosition;

  const ShopDetailsModal({
    super.key, 
    required this.shop, 
    required this.myPosition
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    // Biztonságos távolság számítás
    String? distanceString;
    if (myPosition != null && shop.lat != null && shop.long != null) {
      final double dist = const Distance().as(LengthUnit.Meter, myPosition!, LatLng(shop.lat!, shop.long!));
      distanceString = dist > 1000 
          ? "${(dist / 1000).toStringAsFixed(1)} km" 
          : "${dist.round()} m";
    }

    // Nyitvatartás ellenőrzése
    bool isOpen = ShopLogic.isOpenNow(shop.openingHours);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kis fogantyú a modal tetején
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Row(
            children: [
              Expanded(
                child: Text(
                  shop.name,
                  style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (distanceString != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.near_me, size: 16, color: colorScheme.onSecondaryContainer),
                      const SizedBox(width: 4),
                      Text(
                        distanceString,
                        style: TextStyle(
                          color: colorScheme.onSecondaryContainer, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "${shop.city}, ${shop.address}",
                  style: textTheme.bodyLarge,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Nyitvatartás", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isOpen ? Colors.green.withOpacity(0.1) : colorScheme.errorContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isOpen ? "Jelenleg nyitva" : "Jelenleg zárva",
                  style: textTheme.labelLarge?.copyWith(
                    color: isOpen ? Colors.green.shade800 : colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Nyitvatartás lista generálása
          if (shop.openingHours != null)
            ..._buildOpeningHoursList(shop.openingHours!, context),
        ],
      ),
    );
  }

  List<Widget> _buildOpeningHoursList(Map<String, dynamic> hours, BuildContext context) {
    const days = ["Hétfő", "Kedd", "Szerda", "Csütörtök", "Péntek", "Szombat", "Vasárnap"];
    final todayIndex = DateTime.now().weekday - 1; // 0 = Hétfő

    return List.generate(7, (index) {
      // Az API 1-7 kulcsokat használ (stringként), ahol 1=Hétfő
      final key = (index + 1).toString();
      final timeRange = hours[key] ?? "-";
      final isToday = index == todayIndex;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              days[index], 
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday ? Theme.of(context).colorScheme.primary : null,
              )
            ),
            Text(
              timeRange,
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              )
            ),
          ],
        ),
      );
    });
  }
}