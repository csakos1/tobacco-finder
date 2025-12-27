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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.55, // Kicsit kisebb indítás, hogy kényelmes legyen
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            // Material 3 szabvány: 28-as lekerekítés a felső sarkokon
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            // Nagyobb padding a széleken
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. Drag Handle (A kis szürke csík) ---
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // --- 2. Cím és Státusz ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        shop.name,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Ugyanaz a Chip dizájn, mint a listában
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isOpen 
                            ? Colors.green.withOpacity(0.15) 
                            : colorScheme.errorContainer.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isOpen ? "Nyitva" : "Zárva",
                        style: textTheme.labelMedium?.copyWith(
                          color: isOpen ? Colors.green.shade800 : colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),

                // --- 3. Cím információ ---
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, 
                      color: colorScheme.primary, size: 20
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${shop.city}, ${shop.address}',
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // --- 4. Távolság (Pasztell dobozban) ---
                if (distanceText != "Ismeretlen")
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.near_me_rounded, 
                              size: 16, 
                              color: colorScheme.onSecondaryContainer
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "$distanceText tőled",
                              style: textTheme.labelLarge?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 24),
                Divider(color: colorScheme.outlineVariant, thickness: 1),
                const SizedBox(height: 24),

                // --- 5. Nyitvatartás lista ---
                Text(
                  "Nyitvatartás",
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),

                if (shop.openingHours != null)
                  ...List.generate(7, (index) {
                    int dayIndex = index + 1;
                    String dayName = [
                      "Hétfő", "Kedd", "Szerda", "Csütörtök", "Péntek", "Szombat", "Vasárnap"
                    ][index];
                    String hours = shop.openingHours![dayIndex.toString()] ?? "Zárva";

                    // Mai nap kiemelése
                    bool isToday = DateTime.now().weekday == dayIndex;

                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: isToday
                          ? BoxDecoration(
                              // A mai nap kap egy halvány színes hátteret
                              color: colorScheme.primaryContainer.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(16),
                            )
                          : null, // A többi napnak nincs háttere
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dayName,
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: isToday ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            hours,
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: isToday ? colorScheme.primary : colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                else
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Nincs adat a nyitvatartásról.",
                      style: TextStyle(
                        fontStyle: FontStyle.italic, 
                        color: colorScheme.onSurfaceVariant
                      ),
                    ),
                  ),
                  
                // Extra térköz az alján
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }
}