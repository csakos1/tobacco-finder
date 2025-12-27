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
    // Rendezés
    List<Shop> sortedShops = List.from(shops);
    if (myPosition != null) {
      sortedShops.sort((a, b) {
        double distA = distanceCalculator.as(LengthUnit.Meter, myPosition!, LatLng(a.lat, a.long));
        double distB = distanceCalculator.as(LengthUnit.Meter, myPosition!, LatLng(b.lat, b.long));
        return distA.compareTo(distB);
      });
    }

    if (sortedShops.isEmpty) {
      return const Center(child: Text("Nincs megjeleníthető bolt."));
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView.builder(
      itemCount: sortedShops.length,
      // Nagyobb térköz a lista körül
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      itemBuilder: (context, index) {
        final shop = sortedShops[index];
        bool isOpen = ShopLogic.isOpenNow(shop.openingHours);

        String distanceText = "";
        if (myPosition != null) {
          double dist = distanceCalculator.as(LengthUnit.Meter, myPosition!, LatLng(shop.lat, shop.long));
          distanceText = dist > 1000 
              ? "${(dist / 1000).toStringAsFixed(1)} km" 
              : "${dist.round()} m";
        }

        // --- MATERIAL 3 KÁRTYA DIZÁJN ---
        return Card(
          elevation: 0, // Nincs árnyék (Filled Card)
          color: colorScheme.surfaceContainer, // Halvány háttérszín
          margin: const EdgeInsets.only(bottom: 12), // Kártyák közti tér
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Kerekített sarkok
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onShopSelected(shop),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Ikon (Tonal containerben)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer, // Halványkék háttér
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.store_rounded, 
                      color: colorScheme.onPrimaryContainer, // Sötétkék ikon
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // 2. Szöveges tartalom
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
                            color: colorScheme.onSurfaceVariant, // Halványabb szürke
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        
                        // Távolság "Badge" (kis keretes doboz)
                        if (distanceText.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.surface, // Kontraszt a kártyához képest
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.directions_walk, size: 12, color: colorScheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  distanceText,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colorScheme.primary,
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

                  // 3. Státusz Chip (Nyitva/Zárva)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      // Ha nyitva: halványzöld, Ha zárva: halványpiros (errorContainer)
                      color: isOpen 
                          ? Colors.green.withOpacity(0.15) 
                          : colorScheme.errorContainer.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20), // Kapszula forma
                      border: Border.all(
                        color: isOpen ? Colors.transparent : colorScheme.error.withOpacity(0.2)
                      )
                    ),
                    child: Text(
                      isOpen ? "Nyitva" : "Zárva",
                      style: textTheme.labelSmall?.copyWith(
                        // Szöveg színe: sötétzöld vagy piros
                        color: isOpen ? Colors.green.shade800 : colorScheme.error,
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