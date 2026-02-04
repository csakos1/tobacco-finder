import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';

// Ezzel a globális változóval kezeljük a téma váltást az egész appban
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // A ValueListenableBuilder figyeli, ha változik a téma beállítás
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Dohánybolt Kereső',
          debugShowCheckedModeBanner: false,

          // --- TÉMA MÓD (Világos / Sötét / Rendszer) ---
          themeMode: currentMode,

          // --- VILÁGOS TÉMA (A meglévő kódod) ---
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            scaffoldBackgroundColor:
                Colors.white, // Explicit fehér háttér világos módban
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

          // --- SÖTÉT TÉMA (Az új kód) ---
          darkTheme: ThemeData(
            useMaterial3: true,
            // Sötét mód esetén a brightness: Brightness.dark fontos!
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
              surface: const Color(0xFF171A1F), // A kért szín: #171a1f
            ),
            // A Scaffold (képernyő) háttere is legyen a kért szín
            scaffoldBackgroundColor: const Color(0xFF171A1F),

            // A betűtípus beállítása sötét módra (fehér betűkkel)
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
