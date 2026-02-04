import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        // JAVÍTÁS 1: A görgetés letiltása
        // Mivel nem lehet görgetni, a fejléc nem fog összemenni,
        // így a cím sosem csúszik be a gomb alá.
        physics: const NeverScrollableScrollPhysics(),

        slivers: [
          SliverAppBar.large(
            pinned: true, // Ez most mindegy is, mert nem görgetünk, de maradhat
            expandedHeight: 160.0,

            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                shape: const CircleBorder(),
              ),
            ),

            flexibleSpace: FlexibleSpaceBar(
              centerTitle: false,

              // JAVÍTÁS 2: Vissza az eredeti helyére (bal szél)
              // Mivel nincs görgetés, nem kell félni az ütközéstől.
              titlePadding: const EdgeInsets.only(left: 20.0, bottom: 16.0),

              title: Text(
                "Beállítások",
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGroupTitle(theme, "Általános"),

                  _SettingsGroup(
                    items: [
                      _GroupItem(
                        title: "Nyelv",
                        subtitle: "Magyar",
                        icon: Icons.language,
                        onTap: () {},
                      ),
                      _GroupItem(
                        title: "Téma",
                        icon: Icons.palette_outlined,
                        onTap: () {},
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _buildGroupTitle(theme, "Adatbázis"),
                  _SettingsGroup(
                    items: [
                      _GroupItem(
                        title: "Adatok frissítése",
                        subtitle: "Utolsó frissítés: Ma, 10:00",
                        icon: Icons.sync,
                        onTap: () {},
                      ),
                    ],
                  ),

                  // A nagy üres helyet (SizedBox height: 800) kivettem,
                  // mert tiltottuk a görgetést, így felesleges.
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, bottom: 12.0, top: 8.0),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// --- SEGÉDOSZTÁLYOK ---

class _GroupItem {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;

  _GroupItem({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.onTap,
  });
}

class _SettingsGroup extends StatelessWidget {
  final List<_GroupItem> items;

  const _SettingsGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    const double largeRadius = 24.0;
    const double smallRadius = 4.0;
    const double gap = 2.0;

    return Column(
      children: items.asMap().entries.map((entry) {
        final int index = entry.key;
        final _GroupItem item = entry.value;
        final bool isFirst = index == 0;
        final bool isLast = index == items.length - 1;

        BorderRadius borderRadius;

        if (items.length == 1) {
          borderRadius = BorderRadius.circular(largeRadius);
        } else if (isFirst) {
          borderRadius = const BorderRadius.vertical(
            top: Radius.circular(largeRadius),
            bottom: Radius.circular(smallRadius),
          );
        } else if (isLast) {
          borderRadius = const BorderRadius.vertical(
            top: Radius.circular(smallRadius),
            bottom: Radius.circular(largeRadius),
          );
        } else {
          borderRadius = BorderRadius.circular(smallRadius);
        }

        return Container(
          margin: EdgeInsets.only(bottom: isLast ? 0 : gap),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: borderRadius,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: item.onTap,
              borderRadius: borderRadius,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(
                  leading: Icon(
                    item.icon,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
