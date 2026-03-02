import 'dart:io';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/shop.dart';
import '../utils/shop_logic.dart';
import 'opening_hours_widget.dart';

class ShopDetailsModal extends StatelessWidget {
  final Shop shop;
  final LatLng? myPosition;

  const ShopDetailsModal({
    super.key,
    required this.shop,
    required this.myPosition,
  });

  Future<void> _launchMaps() async {
    final lat = shop.lat;
    final lon = shop.long;
    if (lat == null || lon == null) return;

    final Uri appleMapUrl = Uri.parse(
      'https://maps.apple.com/?daddr=$lat,$lon',
    );
    final Uri googleMapUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon',
    );

    if (Platform.isIOS) {
      if (await canLaunchUrl(appleMapUrl)) {
        await launchUrl(appleMapUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(googleMapUrl, mode: LaunchMode.externalApplication);
      }
    } else {
      await launchUrl(googleMapUrl, mode: LaunchMode.externalApplication);
    }
  }

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

    // --- NYITVATARTÁS SZÍNEK ---
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

    // --- ÚTVONAL GOMB SZÍNEI ---
    final Color routeBgColor = isDark
        ? const Color(0xFF007b8b)
        : const Color(0xFFc0eaf4);
    final Color routeTextColor = isDark
        ? const Color(0xFFc0eaf4)
        : const Color(0xFF002025);

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

          // --- FEJLÉC 1. SOR: Név és Távolság ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  shop.name,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
              ),
              if (distanceString != null)
                Container(
                  margin: const EdgeInsets.only(left: 12),
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

          const SizedBox(height: 12),

          // --- FEJLÉC 2. SOR: Cím + Útvonal gomb ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Cím rész ikonnal
              Expanded(
                child: Row(
                  // KÖZÉPRE IGAZÍTÁS, HOGY EGY VONALBAN LEGYEN A SZÖVEG ÉS AZ IKON
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 24, // Nagyobb méret (20-ról 24-re)
                      color: Color(0xFF007b8b),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "${shop.city}, ${shop.address}",
                        // NAGYOBB SZÖVEG (bodyMedium-ról bodyLarge-ra)
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Útvonaltervezés gomb
              SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  onPressed: _launchMaps,
                  icon: const Icon(Icons.directions_rounded, size: 18),
                  label: const Text(
                    "Útvonal",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: routeBgColor,
                    foregroundColor: routeTextColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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

          // Nyitvatartás Widget
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: OpeningHoursWidget(hours: shop.openingHours),
          ),
        ],
      ),
    );
  }
}
