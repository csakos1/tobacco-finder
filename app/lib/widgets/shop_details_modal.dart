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
    required this.myPosition,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Távolság számítása
    String? distanceString;
    if (myPosition != null && shop.lat != null && shop.long != null) {
      final double dist = const Distance().as(
        LengthUnit.Meter,
        myPosition!,
        LatLng(shop.lat!, shop.long!),
      );
      distanceString = dist > 1000
          ? "${(dist / 1000).toStringAsFixed(1)} km"
          : "${dist.round()} m";
    }

    bool isOpen = ShopLogic.isOpenNow(shop.openingHours);

    // --- SZÍNEK ---
    Color statusBgColor;
    Color statusTextColor;

    if (isOpen) {
      if (isDark) {
        statusBgColor = Colors.green.shade800;
        statusTextColor = Colors.white;
      } else {
        statusBgColor = Colors.green.withOpacity(0.15);
        statusTextColor = Colors.green.shade800;
      }
    } else {
      statusBgColor = colorScheme.errorContainer.withOpacity(0.6);
      statusTextColor = colorScheme.error;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.near_me_rounded,
                        size: 14,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        distanceString,
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Cím sor
          Row(
            children: [
              // JAVÍTÁS: A kért szín (#00363e)
              const Icon(
                Icons.location_on_outlined,
                size: 20,
                color: Color(0xFF007b8b),
              ),
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

          // Nyitvatartás Fejléc + Státusz jelző
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Nyitvatartás",
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isOpen ? "Nyitva" : "Zárva",
                  style: textTheme.labelSmall?.copyWith(
                    color: statusTextColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
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
                  : [
                      const Center(
                        child: Text(
                          "Nincs megadva nyitvatartás.",
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOpeningHoursList(
    Map<String, dynamic> hours,
    BuildContext context,
  ) {
    const days = [
      "Hétfő",
      "Kedd",
      "Szerda",
      "Csütörtök",
      "Péntek",
      "Szombat",
      "Vasárnap",
    ];
    final todayIndex = DateTime.now().weekday - 1;

    return List.generate(7, (index) {
      final key = (index + 1).toString();

      String timeRange = hours[key]?.toString() ?? "Zárva";

      if (timeRange.length > 20 && timeRange.contains(';')) {
        timeRange = "Lásd fent";
      }

      final isToday = index == todayIndex;

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              days[index],
              style: TextStyle(
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: isToday
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontSize: 15,
              ),
            ),
            Text(
              timeRange,
              style: TextStyle(
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: isToday
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    });
  }
}
