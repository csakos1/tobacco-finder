// app/lib/services/haptic_service.dart
import 'package:flutter/services.dart';
import 'app_settings.dart';

/// Központi haptic feedback szolgáltatás.
/// Egyetlen felelőssége: ellenőrzi a felhasználói beállítást,
/// és ha engedélyezve van, kiváltja a kért rezgéstípust.
class HapticService {
  const HapticService._();

  /// Finom, rövid rezgés — navigáció és szűrők ki/bekapcsolásához.
  static void lightImpact() {
    if (!AppSettings.instance.isHapticEnabled) return;
    HapticFeedback.lightImpact();
  }

  /// Közepes rezgés — jövőbeli felhasználásra.
  static void mediumImpact() {
    if (!AppSettings.instance.isHapticEnabled) return;
    HapticFeedback.mediumImpact();
  }

  /// Szelekciós rezgés — jövőbeli felhasználásra.
  static void selectionClick() {
    if (!AppSettings.instance.isHapticEnabled) return;
    HapticFeedback.selectionClick();
  }
}
