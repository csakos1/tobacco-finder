// app/lib/widgets/offline_banner.dart
import 'package:flutter/material.dart';

// ---------------------------------------------------------------
// OFFLINE BANNER
//
// Egy Material 3 stílusú, animáltan megjelenő/eltűnő banner,
// ami a Scaffold tetejére (AppBar alá) csúszik be.
//
// Jelzi a felhasználónak, hogy az app cache-elt adatokat mutat,
// mert nem tudott csatlakozni a szerverhez.
//
// Az AnimatedSlide + AnimatedOpacity kombináció smooth megjelenést
// biztosít anélkül, hogy explicit AnimationController-re lenne szükség.
// ---------------------------------------------------------------
class OfflineBanner extends StatelessWidget {
  /// Ha true, a banner látható (becsúszik). Ha false, elrejtőzik.
  final bool isVisible;

  const OfflineBanner({super.key, required this.isVisible});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      offset: isVisible ? Offset.zero : const Offset(0, -1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isVisible ? 1.0 : 0.0,
        child: Material(
          // Enyhe elevation, hogy vizuálisan elkülönüljön a tartalomtól
          elevation: 2,
          color: colorScheme.tertiaryContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 18,
                    color: colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Offline mód — az adatok nem feltétlenül aktuálisak',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
