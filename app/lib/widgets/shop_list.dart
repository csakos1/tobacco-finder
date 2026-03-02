import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/shop.dart';
import '../utils/shop_logic.dart';
import 'opening_hours_widget.dart';
import '../screens/home_screen.dart'; // Ebből vesszük az enumot (ShopFilter)

class ShopList extends StatefulWidget {
  final List<Shop> shops;
  final LatLng? myPosition;
  final Function(Shop) onShopSelected;

  // ÚJ paraméterek a szűréshez
  final ShopFilter currentFilter;
  final Function(ShopFilter) onFilterChanged;

  const ShopList({
    super.key,
    required this.shops,
    required this.myPosition,
    required this.onShopSelected,
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  State<ShopList> createState() => _ShopListState();
}

class _ShopListState extends State<ShopList> {
  final Distance distanceCalculator = const Distance();
  String? _expandedShopId; // <-- Ebben tároljuk az éppen nyitott bolt ID-ját

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    List<Shop> sortedShops = List.from(widget.shops);

    if (widget.myPosition != null) {
      sortedShops.sort((a, b) {
        if (a.lat == null || a.long == null) return 1;
        if (b.lat == null || b.long == null) return -1;
        double distA = distanceCalculator.as(
          LengthUnit.Meter,
          widget.myPosition!,
          LatLng(a.lat!, a.long!),
        );
        double distB = distanceCalculator.as(
          LengthUnit.Meter,
          widget.myPosition!,
          LatLng(b.lat!, b.long!),
        );
        return distA.compareTo(distB);
      });
    }

    return Column(
      children: [
        // --- 1. RÖGZÍTETT SZŰRŐ FEJLÉC ---
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            children: [
              // "Nyitva" gomb
              FilterChip(
                label: const Text("Jelenleg nyitva"),
                selected: widget.currentFilter == ShopFilter.openNow,
                showCheckmark: false,
                avatar: Icon(
                  Icons.storefront,
                  size: 18,
                  color: widget.currentFilter == ShopFilter.openNow
                      ? colorScheme.onPrimary
                      : colorScheme.primary,
                ),
                selectedColor: colorScheme.primary,
                labelStyle: TextStyle(
                  color: widget.currentFilter == ShopFilter.openNow
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: widget.currentFilter == ShopFilter.openNow
                        ? Colors.transparent
                        : colorScheme.outlineVariant,
                  ),
                ),
                onSelected: (selected) {
                  widget.onFilterChanged(
                    selected ? ShopFilter.openNow : ShopFilter.none,
                  );
                },
              ),
              const SizedBox(width: 12),

              // "0-24" gomb
              FilterChip(
                label: const Text("0-24"),
                selected: widget.currentFilter == ShopFilter.nonStop,
                showCheckmark: false,
                avatar: Icon(
                  Icons.schedule,
                  size: 18,
                  color: widget.currentFilter == ShopFilter.nonStop
                      ? colorScheme.onTertiary
                      : colorScheme.tertiary,
                ),
                selectedColor: colorScheme.tertiary,
                labelStyle: TextStyle(
                  color: widget.currentFilter == ShopFilter.nonStop
                      ? colorScheme.onTertiary
                      : colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: widget.currentFilter == ShopFilter.nonStop
                        ? Colors.transparent
                        : colorScheme.outlineVariant,
                  ),
                ),
                onSelected: (selected) {
                  widget.onFilterChanged(
                    selected ? ShopFilter.nonStop : ShopFilter.none,
                  );
                },
              ),
            ],
          ),
        ),

        // --- 2. GÖRGETHETŐ LISTA ---
        Expanded(
          child: sortedShops.isEmpty
              ? const Center(
                  child: Text("Nincs a feltételeknek megfelelő bolt."),
                )
              : ListView.builder(
                  itemCount: sortedShops.length,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  itemBuilder: (context, index) {
                    final shop = sortedShops[index];
                    bool isOpen = ShopLogic.isOpenNow(shop.openingHours);

                    String distanceText = "";
                    if (widget.myPosition != null &&
                        shop.lat != null &&
                        shop.long != null) {
                      double dist = distanceCalculator.as(
                        LengthUnit.Meter,
                        widget.myPosition!,
                        LatLng(shop.lat!, shop.long!),
                      );
                      distanceText = dist > 1000
                          ? "${(dist / 1000).toStringAsFixed(1)} km"
                          : "${dist.round()} m";
                    }

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
                      statusBgColor = colorScheme.errorContainer.withOpacity(
                        0.6,
                      );
                      statusTextColor = colorScheme.error;
                    }

                    final isExpanded = _expandedShopId == shop.id;

                    return Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainer,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          // 1. Az Alap kártya rész (Mindig látszik)
                          InkWell(
                            onTap: () {
                              setState(() {
                                // Ha arra nyomunk, ami már nyitva van, becsukja, különben kinyitja (és az előzőt csukja)
                                _expandedShopId = isExpanded ? null : shop.id;
                              });
                            },
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          shop.name,
                                          style: textTheme.titleMedium
                                              ?.copyWith(
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
                                              color: colorScheme
                                                  .secondaryContainer
                                                  .withOpacity(0.5),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.near_me_rounded,
                                                  size: 14,
                                                  color: colorScheme
                                                      .onSecondaryContainer,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  distanceText,
                                                  style: textTheme.labelMedium
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSecondaryContainer,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
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
                            ),
                          ),

                          // 2. A Lenyíló rész (Nyitvatartás + Gomb)
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.fastOutSlowIn,
                            child: isExpanded
                                ? GestureDetector(
                                    // HitTestBehavior.opaque teszi lehetővé, hogy a belső üres részekre
                                    // kattintva is lefusson az onTap, így bezáruljon a panel.
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      setState(() {
                                        _expandedShopId = null;
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        left: 16.0,
                                        right: 16.0,
                                        bottom: 16.0,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Divider(
                                            color: colorScheme.outlineVariant
                                                .withOpacity(0.5),
                                          ),
                                          const SizedBox(height: 12),

                                          // Nyitvatartás dizájn használata
                                          Container(
                                            decoration: BoxDecoration(
                                              color: colorScheme
                                                  .surfaceContainerLow,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            padding: const EdgeInsets.all(16),
                                            child: OpeningHoursWidget(
                                              hours: shop.openingHours,
                                            ),
                                          ),

                                          const SizedBox(height: 16),

                                          // --- Mutasd Térképen Gomb (Material 3 Expressive) ---
                                          SizedBox(
                                            height:
                                                56, // Kifejezetten magas, feltűnő M3 gomb
                                            child: ElevatedButton.icon(
                                              onPressed: () {
                                                // Ugyanúgy meghívja az eredeti térkép-fókuszálós logikát!
                                                widget.onShopSelected(shop);
                                              },
                                              icon: const Icon(
                                                Icons.map_rounded,
                                              ),
                                              label: const Text(
                                                "Mutasd térképen",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                // A kért elsődleges témaszín alkalmazása:
                                                backgroundColor:
                                                    colorScheme.primary,
                                                foregroundColor:
                                                    colorScheme.onPrimary,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
