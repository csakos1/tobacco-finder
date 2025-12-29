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
    
    // Távolság számítása
    String? distanceString;
    if (myPosition != null && shop.lat != null && shop.long != null) {
      final double dist = const Distance().as(LengthUnit.Meter, myPosition!, LatLng(shop.lat!, shop.long!));
      distanceString = dist > 1000 
          ? "${(dist / 1000).toStringAsFixed(1)} km" 
          : "${dist.round()} m";
    }

    bool isOpen = ShopLogic.isOpenNow(shop.openingHours);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30), // Kicsit nagyobb padding
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Fogantyú"
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Fejléc: Név + Távolság
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  shop.name,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (distanceString != null)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    distanceString,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer, 
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Cím sor
          Row(
            children: [
              Icon(Icons.map_outlined, size: 20, color: colorScheme.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "${shop.city}, ${shop.address}",
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Nyitvatartás Fejléc
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Nyitvatartás", 
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isOpen ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isOpen ? Colors.green.shade200 : Colors.red.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOpen ? Icons.check_circle_outline : Icons.schedule,
                      size: 14,
                      color: isOpen ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOpen ? "NYITVA" : "ZÁRVA",
                      style: TextStyle(
                        color: isOpen ? Colors.green.shade800 : Colors.red.shade800,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Lista
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: shop.openingHours != null 
                  ? _buildOpeningHoursList(shop.openingHours!, context)
                  : [const Center(child: Text("Nincs megadva nyitvatartás.", style: TextStyle(fontStyle: FontStyle.italic)))],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOpeningHoursList(Map<String, dynamic> hours, BuildContext context) {
    const days = ["Hétfő", "Kedd", "Szerda", "Csütörtök", "Péntek", "Szombat", "Vasárnap"];
    final todayIndex = DateTime.now().weekday - 1;

    return List.generate(7, (index) {
      final key = (index + 1).toString();
      
      // Tisztítás: Ha null vagy üres, akkor "Zárva"
      String timeRange = hours[key]?.toString() ?? "Zárva";
      
      // Ha a scraper nem tudta parse-olni és nyers string maradt (pl "Mo-Su..."),
      // akkor próbáljuk meg szépen kiírni, vagy vágni.
      if (timeRange.length > 20 && timeRange.contains(';')) {
         timeRange = "Lásd fent"; // Vagy egyedi logika
      }

      final isToday = index == todayIndex;

      return Padding(
        padding: const EdgeInsets.only(bottom: 8), // Térköz a sorok között
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              days[index], 
              style: TextStyle(
                // Mai nap vastag és színes
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: isToday ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontSize: 15,
              )
            ),
            Text(
              timeRange,
              style: TextStyle(
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: isToday ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
              )
            ),
          ],
        ),
      );
    });
  }
}