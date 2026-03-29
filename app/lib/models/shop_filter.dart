// app/lib/models/shop_filter.dart

/// A boltlista szűrési módjai.
///
/// A HomeScreen szűrő chip-jei és a HomeController szűrő logikája
/// egyaránt ezt az enumot használja. Külön fájlban van, hogy a
/// widgetek ne függjenek közvetlenül a controller importjától.
enum ShopFilter { none, openNow, nonStop }
