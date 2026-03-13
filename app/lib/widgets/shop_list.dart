import 'package:flutter/material.dart';
//import 'package:latlong2/latlong.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/shop.dart';
import '../utils/shop_logic.dart';
import 'opening_hours_widget.dart';
import '../screens/home_screen.dart'; // Ebből vesszük az enumot (ShopFilter)

class ShopList extends StatefulWidget {
  final List<Shop> shops;
  final LatLng? myPosition;
  final Function(Shop) onShopSelected;
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
  // A distanceCalculator sort KIKUKÁZTUK!
  String? _expandedShopId;

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
        double distA = Geolocator.distanceBetween(
          widget.myPosition!.latitude,
          widget.myPosition!.longitude,
          a.lat!,
          a.long!,
        );
        double distB = Geolocator.distanceBetween(
          widget.myPosition!.latitude,
          widget.myPosition!.longitude,
          b.lat!,
          b.long!,
        );
        return distA.compareTo(distB);
      });
    }

    return CustomScrollView(
      slivers: [
        // --- 1. RÖGZÍTETT SZŰRŐ FEJLÉC (SliverAppBar) ---
        SliverAppBar(
          pinned: true,
          floating: false,
          primary:
              false, // <-- FONTOS: Mivel van már egy AppBar felül, ez ne tegyen be status bar üres helyet
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          toolbarHeight: 56,
          // Szándékosan NINCS backgroundColor és surfaceTintColor megadva!
          // Így hajszálpontosan a fő AppBar (Theme) színét fogja felvenni görgetéskor.
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
        ),

        // --- 2. GÖRGETHETŐ LISTA ---
        if (sortedShops.isEmpty)
          const SliverFillRemaining(
            child: Center(child: Text("Nincs a feltételeknek megfelelő bolt.")),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final shop = sortedShops[index];
                bool isOpen = ShopLogic.isOpenNow(shop.openingHours);

                String distanceText = "";
                if (widget.myPosition != null &&
                    shop.lat != null &&
                    shop.long != null) {
                  double dist = Geolocator.distanceBetween(
                    widget.myPosition!.latitude,
                    widget.myPosition!.longitude,
                    shop.lat!,
                    shop.long!,
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
                  statusBgColor = colorScheme.errorContainer.withOpacity(0.6);
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
                                          color: colorScheme.secondaryContainer
                                              .withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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

                                      // Nyitvatartás dizájn
                                      Container(
                                        decoration: BoxDecoration(
                                          color:
                                              colorScheme.surfaceContainerLow,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(16),
                                        child: OpeningHoursWidget(
                                          hours: shop.openingHours,
                                        ),
                                      ),

                                      const SizedBox(height: 16),

                                      // Mutasd Térképen Gomb
                                      SizedBox(
                                        height: 56,
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            widget.onShopSelected(shop);
                                          },
                                          icon: const Icon(Icons.map_rounded),
                                          label: const Text(
                                            "Mutasd térképen",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
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
              }, childCount: sortedShops.length),
            ),
          ),
      ],
    );
  }
}
