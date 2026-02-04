import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dohánybolt Kereső',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // Pixel-szerű kék színvilág
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),

        // --- BETŰTÍPUS: OUTFIT (A Google Sans legjobb alternatívája) ---
        // Ez adja azt a modern, geometrikus "Android 16" érzést.
        textTheme: GoogleFonts.outfitTextTheme()
            .apply(bodyColor: Colors.black, displayColor: Colors.black)
            .copyWith(
              // Kicsit vastagabb, "Semibold" stílus a címeknek, ahogy kérted
              headlineMedium: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              titleMedium: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              bodyLarge: GoogleFonts.outfit(fontWeight: FontWeight.w500),
              bodyMedium: GoogleFonts.outfit(fontWeight: FontWeight.w500),
            ),
      ),
      home: const HomeScreen(),
    );
  }
}
