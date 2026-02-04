import 'package:flutter/material.dart';
import '../main.dart'; // A themeNotifier eléréséhez

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            pinned: true,
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
                        // Itt használjuk a ValueListenableBuilder-t, hogy a felirat frissüljön
                        subtitleWidget: ValueListenableBuilder<ThemeMode>(
                          valueListenable: themeNotifier,
                          builder: (context, mode, _) =>
                              Text(_getThemeName(mode)),
                        ),
                        icon: Icons.palette_outlined,
                        onTap: () => _showThemeDialog(context),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Material 3 Expressive Dialog
  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, currentMode, _) {
            return AlertDialog(
              icon: const Icon(
                Icons.palette_outlined,
              ), // Expressive stílus: Ikon felül
              title: const Text("Téma választása"),
              contentPadding: const EdgeInsets.only(
                top: 20,
                bottom: 24,
              ), // Nagyobb térköz
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildThemeOption(
                    context,
                    ThemeMode.system,
                    "Rendszer beállításai",
                    Icons.brightness_auto,
                    currentMode,
                  ),
                  _buildThemeOption(
                    context,
                    ThemeMode.light,
                    "Világos",
                    Icons.light_mode_outlined,
                    currentMode,
                  ),
                  _buildThemeOption(
                    context,
                    ThemeMode.dark,
                    "Sötét",
                    Icons.dark_mode_outlined,
                    currentMode,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Mégse"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    ThemeMode mode,
    String label,
    IconData icon,
    ThemeMode currentMode,
  ) {
    return RadioListTile<ThemeMode>(
      value: mode,
      groupValue: currentMode,
      onChanged: (ThemeMode? value) {
        if (value != null) {
          themeNotifier.value = value;
          Navigator.pop(context); // Bezárjuk kiválasztáskor
        }
      },
      title: Text(label),
      secondary: Icon(icon),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
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

  String _getThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return "Rendszer beállításai";
      case ThemeMode.light:
        return "Világos";
      case ThemeMode.dark:
        return "Sötét";
    }
  }
}

// --- SEGÉDOSZTÁLYOK ---

class _GroupItem {
  final String title;
  final String? subtitle;
  final Widget?
  subtitleWidget; // Új: Widget is lehet a felirat (a frissítéshez)
  final IconData icon;
  final VoidCallback onTap;

  _GroupItem({
    required this.title,
    this.subtitle,
    this.subtitleWidget,
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
                  // Kezeli a statikus szöveget és a dinamikus widgetet is
                  subtitle:
                      item.subtitleWidget ??
                      (item.subtitle != null ? Text(item.subtitle!) : null),

                  // JAVÍTÁS: A trailing (nyíl) eltávolítva!
                  trailing: null,

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
