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
      initialChildSize: 0.60, // <--- FELJEBB VETTÜK (0.55 -> 0.60), TÖBB LÁTSZIK
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            // KISEBB PADDING (24 helyett 16 és 20)
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. Drag Handle ---
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16), // KISEBB HELY (24 -> 16)
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
                        // KISEBB CÍM (HeadlineSmall -> TitleLarge)
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // KISEBB CHIP
                      decoration: BoxDecoration(
                        color: isOpen 
                            ? Colors.green.withOpacity(0.15) 
                            : colorScheme.errorContainer.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isOpen ? "Nyitva" : "Zárva",
                        style: textTheme.labelSmall?.copyWith( // KISEBB BETŰ
                          color: isOpen ? Colors.green.shade800 : colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8), // KISEBB TÉRKÖZ (16 -> 8)

                // --- 3. Cím információ ---
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, 
                      color: colorScheme.primary, size: 18 // KISEBB IKON
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${shop.city}, ${shop.address}',
                        style: textTheme.bodyMedium?.copyWith( // BodyLarge -> BodyMedium
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // --- 4. Távolság ---
                if (distanceText != "Ismeretlen")
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.near_me_rounded, 
                          size: 14, 
                          color: colorScheme.onSecondaryContainer
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "$distanceText tőled",
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16), // KISEBB TÉRKÖZ (24 -> 16)
                Divider(color: colorScheme.outlineVariant, thickness: 1, height: 1),
                const SizedBox(height: 16),

                // --- 5. Nyitvatartás lista ---
                Text(
                  "Nyitvatartás",
                  style: textTheme.titleMedium?.copyWith( // TitleLarge -> TitleMedium
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8), // KISEBB TÉRKÖZ

                if (shop.openingHours != null)
                  ...List.generate(7, (index) {
                    int dayIndex = index + 1;
                    String dayName = [
                      "Hétfő", "Kedd", "Szerda", "Csütörtök", "Péntek", "Szombat", "Vasárnap"
                    ][index];
                    String hours = shop.openingHours![dayIndex.toString()] ?? "Zárva";

                    bool isToday = DateTime.now().weekday == dayIndex;

                    return Container(
                      // SOKKAL VÉKONYABB SOROK (Vertical 12 -> 6)
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: isToday
                          ? BoxDecoration(
                              color: colorScheme.primaryContainer.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(8), // Kisebb kerekítés
                            )
                          : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dayName,
                            style: textTheme.bodyMedium?.copyWith( // Kisebb betű
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: isToday ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            hours,
                            style: textTheme.bodyMedium?.copyWith(
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
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13, // Kisebb
                      ),
                    ),
                  ),
                  
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}