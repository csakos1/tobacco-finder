// lib/main.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'services/app_settings.dart';

void main() async {
  // Ez kötelező, ha a runApp előtt async hívásokat (pl. SharedPreferences) végzünk
  WidgetsFlutterBinding.ensureInitialized();

  // A fontok az assets/fonts/ mappából töltődnek be (bundolva az APK-ban),
  // NEM a hálózatról. Ezzel megszűnik a FOUT és ~200-500ms cold start megtakarítás.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Elmentett beállítások betöltése és az AppSettings singleton inicializálása.
  // Ez váltja ki a korábbi top-level globális változókat.
  final prefs = await SharedPreferences.getInstance();
  AppSettings.initialize(prefs);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: settings.themeNotifier,
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
