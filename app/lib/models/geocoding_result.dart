// app/lib/models/geocoding_result.dart
//
// Típusbiztos eredmény wrapper a GeocodingService számára.
// Megkülönbözteti a "nincs találat" és a "hálózati hiba" állapotokat,
// ahelyett hogy mindkettőt üres listával reprezentálná.

import 'place_suggestion.dart';

sealed class GeocodingResult {
  const GeocodingResult();
}

/// Sikeres API válasz — a lista lehet üres (nincs találat) vagy teli.
class GeocodingSuccess extends GeocodingResult {
  final List<PlaceSuggestion> suggestions;

  const GeocodingSuccess(this.suggestions);

  bool get isEmpty => suggestions.isEmpty;
  bool get isNotEmpty => suggestions.isNotEmpty;
}

/// API hiba (hálózati hiba, szerver hiba, timeout, stb.)
class GeocodingError extends GeocodingResult {
  /// Gépi azonosító a hibatípushoz — a UI réteg ez alapján
  /// választja ki a megfelelő magyar nyelvű hibaüzenetet.
  final GeocodingErrorKind kind;

  /// Opcionális technikai részlet debugoláshoz (nem jelenik meg a UI-on).
  final String? debugMessage;

  const GeocodingError({required this.kind, this.debugMessage});
}

/// A lehetséges hibatípusok enumja.
/// Az UI réteg (PlaceSearchBar) ez alapján dönt a felhasználói üzenetről.
enum GeocodingErrorKind {
  /// Hálózati hiba (nincs internet, DNS feloldás sikertelen, stb.)
  network,

  /// Szerver oldali hiba (5xx válaszkód).
  server,

  /// Időtúllépés (connect vagy receive timeout).
  timeout,

  /// Egyéb, nem kategorizált hiba.
  unknown,
}
