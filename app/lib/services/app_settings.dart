// app/lib/services/app_settings.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_service.dart';

// ---------------------------------------------------------------
// ALKALMAZÁS-SZINTŰ BEÁLLÍTÁSOK — SINGLETON SERVICE
//
// Egyetlen felelőssége: összefogja az app globális beállításait
// (téma, haptic, utolsó mentett pozíció), amelyeket korábban
// top-level változókként tartottunk a main.dart-ban.
//
// Előnyök a korábbi megoldáshoz képest:
//   - Nincs mutable top-level változó (initialMapPosition immutable)
//   - Nincs szoros csatolás a main.dart-ra (import ../main.dart eltűnik)
//   - A beállítások egy helyen, egy osztályban élnek
//   - Tesztelhető: a factory-t mock-olni lehet
//
// Inicializálás: main() → AppSettings.initialize(prefs) → runApp()
// Használat: AppSettings.instance.themeNotifier / .hapticEnabled / stb.
// ---------------------------------------------------------------
class AppSettings {
  // --- Singleton példány ---
  static AppSettings? _instance;

  /// Az inicializált singleton elérése.
  /// Hibát dob, ha az initialize() még nem futott le.
  static AppSettings get instance {
    assert(
      _instance != null,
      'AppSettings.initialize() hívása kötelező a runApp() előtt!',
    );
    return _instance!;
  }

  // --- Reaktív beállítások (ValueNotifier — a UI figyeli őket) ---

  /// Téma mód (system / light / dark).
  /// A MyApp ValueListenableBuilder-je figyeli.
  final ValueNotifier<ThemeMode> themeNotifier;

  /// Haptic feedback engedélyezve-e.
  /// A HapticService és a SettingsScreen olvassa.
  final ValueNotifier<bool> hapticNotifier;

  /// Az utolsó mentett GPS pozíció — cold start-nál erre nyílik a térkép.
  /// Immutable (final) — a HomeController csak egyszer olvassa a konstruktorban.
  final LatLng? initialMapPosition;

  // --- Privát konstruktor (kívülről nem példányosítható) ---
  AppSettings._({
    required this.themeNotifier,
    required this.hapticNotifier,
    required this.initialMapPosition,
  });

  // ---------------------------------------------------------------
  // FACTORY INICIALIZÁLÓ
  //
  // A main() hívja, miután a SharedPreferences elérhető.
  // Betölti az elmentett beállításokat és létrehozza a singletont.
  // ---------------------------------------------------------------
  static AppSettings initialize(SharedPreferences prefs) {
    // Téma betöltése
    final savedThemeIndex = prefs.getInt('theme_mode');
    final themeMode = savedThemeIndex != null
        ? ThemeMode.values[savedThemeIndex]
        : ThemeMode.system;

    // Haptic feedback betöltése (alapértelmezetten true)
    final hapticEnabled = prefs.getBool('haptic_enabled') ?? true;

    // Utolsó mentett pozíció betöltése (cold start-hoz)
    final savedPosition = LocationService.loadSavedPosition(prefs);

    _instance = AppSettings._(
      themeNotifier: ValueNotifier(themeMode),
      hapticNotifier: ValueNotifier(hapticEnabled),
      initialMapPosition: savedPosition,
    );

    return _instance!;
  }

  // ---------------------------------------------------------------
  // KÉNYELMI GETTER-EK ÉS SETTER-EK
  // ---------------------------------------------------------------

  /// A haptic feedback jelenleg engedélyezve van-e.
  bool get isHapticEnabled => hapticNotifier.value;

  /// Téma mód beállítása és azonnali perzisztálás.
  Future<void> setThemeMode(ThemeMode mode) async {
    themeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
  }

  /// Haptic feedback toggle és azonnali perzisztálás.
  Future<void> toggleHaptic() async {
    final newValue = !hapticNotifier.value;
    hapticNotifier.value = newValue;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('haptic_enabled', newValue);
  }
}
