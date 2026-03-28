// lib/main.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'services/location_service.dart';

// Ezzel a globális változóval kezeljük a téma váltást az egész appban
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

// Haptic feedback be/kikapcsolás — alapértelmezetten bekapcsolva
final ValueNotifier<bool> hapticNotifier = ValueNotifier(true);

/// Az utolsó mentett pozíció — cold start-nál erre nyílik a térkép
/// a Budapest közép hardkódolt érték helyett.
LatLng? initialMapPosition;

void main() async {
  // Ez kötelező, ha a runApp előtt async hívásokat (pl. SharedPreferences) végzünk
  WidgetsFlutterBinding.ensureInitialized();

  // Elmentett beállítások betöltése
  final prefs = await SharedPreferences.getInstance();

  // Téma betöltése
  final savedThemeIndex = prefs.getInt('theme_mode');
  if (savedThemeIndex != null) {
    themeNotifier.value = ThemeMode.values[savedThemeIndex];
  }

  // Haptic feedback beállítás betöltése (alapértelmezetten true)
  hapticNotifier.value = prefs.getBool('haptic_enabled') ?? true;

  // Utolsó mentett pozíció betöltése (cold start-hoz)
  initialMapPosition = LocationService.loadSavedPosition(prefs);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Dohánybolt Kereső',
          debugShowCheckedModeBanner: false,

          themeMode: currentMode,

          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            scaffoldBackgroundColor: Colors.white,
            textTheme: GoogleFonts.outfitTextTheme()
                .apply(bodyColor: Colors.black, displayColor: Colors.black)
                .copyWith(
                  headlineMedium: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                  ),
                  titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  titleMedium: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  bodyLarge: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                  bodyMedium: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                ),
          ),

          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
              surface: const Color(0xFF171A1F),
            ),
            scaffoldBackgroundColor: const Color(0xFF171A1F),
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme)
                .copyWith(
                  headlineMedium: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                  ),
                  titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  titleMedium: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  bodyLarge: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                  bodyMedium: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                ),
          ),

          home: const HomeScreen(),
        );
      },
    );
  }
}
