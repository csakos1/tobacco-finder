import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/shop.dart';
import '../utils/shop_logic.dart';

class ShopList extends StatelessWidget {
  final List<Shop> shops;
  final LatLng? myPosition;
  final Distance distanceCalculator = const Distance();
  final Function(Shop) onShopSelected;

  ShopList({
    super.key,
    required this.shops,
    required this.myPosition,
    required this.onShopSelected,
  });

  @override
  Widget build(BuildContext context) {
    List<Shop> sortedShops = List.from(shops);

    if (myPosition != null) {
      sortedShops.sort((a, b) {
        if (a.lat == null || a.long == null) return 1;
        if (b.lat == null || b.long == null) return -1;
        double distA = distanceCalculator.as(
          LengthUnit.Meter,
          myPosition!,
          LatLng(a.lat!, a.long!),
        );
        double distB = distanceCalculator.as(
          LengthUnit.Meter,
          myPosition!,
          LatLng(b.lat!, b.long!),
        );
        return distA.compareTo(distB);
      });
    }

    if (sortedShops.isEmpty) {
      return const Center(child: Text("Nincs megjeleníthető bolt."));
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // Lekérjük, hogy sötét módban vagyunk-e
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      itemCount: sortedShops.length,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      itemBuilder: (context, index) {
        final shop = sortedShops[index];
        bool isOpen = ShopLogic.isOpenNow(shop.openingHours);

        String distanceText = "";

        if (myPosition != null && shop.lat != null && shop.long != null) {
          double dist = distanceCalculator.as(
            LengthUnit.Meter,
            myPosition!,
            LatLng(shop.lat!, shop.long!),
          );
          distanceText = dist > 1000
              ? "${(dist / 1000).toStringAsFixed(1)} km"
              : "${dist.round()} m";
        }

        // --- SZÍNEK (JAVÍTVA: Sötét mód kezelése a Listában is) ---
        Color statusBgColor;
        Color statusTextColor;

        if (isOpen) {
          if (isDark) {
            // Sötét mód: Sötétzöld háttér, Fehér szöveg (CSERE)
            statusBgColor = Colors.green.shade800;
            statusTextColor = Colors.white;
          } else {
            // Világos mód: Halvány háttér, Sötétzöld szöveg (EREDETI)
            statusBgColor = Colors.green.withOpacity(0.15);
            statusTextColor = Colors.green.shade800;
          }
        } else {
          // Zárva logika
          statusBgColor = colorScheme.errorContainer.withOpacity(0.6);
          statusTextColor = colorScheme.error;
        }

        return Card(
          elevation: 0,
          color: colorScheme.surfaceContainer,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onShopSelected(shop),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.store_rounded,
                      color: colorScheme.onPrimaryContainer,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop.name,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${shop.city}, ${shop.address}",
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),

                        if (distanceText.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer.withOpacity(
                                0.5,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.near_me_rounded,
                                  size: 14,
                                  color: colorScheme.onSecondaryContainer,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  distanceText,
                                  style: textTheme.labelMedium?.copyWith(
                                    color: colorScheme.onSecondaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // JAVÍTÁS: Itt használjuk a dinamikus színeket
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusBgColor, // Javított háttérszín
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isOpen ? "Nyitva" : "Zárva",
                      style: textTheme.labelSmall?.copyWith(
                        color: statusTextColor, // Javított szövegszín
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
