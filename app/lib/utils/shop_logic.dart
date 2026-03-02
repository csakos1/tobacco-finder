import 'package:flutter/material.dart';

class ShopLogic {
  static bool isOpenNow(Map<String, dynamic>? hours) {
    if (hours == null) return false;

    final now = DateTime.now();
    final currentDayStr = now.weekday.toString();

    String? todayHours = hours[currentDayStr]?.toString();
    if (todayHours == null || todayHours.toLowerCase() == "zárva") {
      return false;
    }

    if (todayHours == "00:00-24:00" || todayHours == "0-24") {
      return true;
    }

    try {
      final parts = todayHours.split('-');
      if (parts.length != 2) return false;

      final openTime = _parseTime(parts[0], now);
      final closeTime = _parseTime(parts[1], now);

      if (closeTime.isBefore(openTime)) {
        closeTime.add(const Duration(days: 1));
      }

      return now.isAfter(openTime) && now.isBefore(closeTime);
    } catch (e) {
      debugPrint("Hiba a nyitvatartás elemzésekor: $todayHours");
      return false;
    }
  }

  // --- ÚJ FÜGGVÉNY A 0-24 SZŰRÉSHEZ ---
  static bool isNonStop(Map<String, dynamic>? hours) {
    if (hours == null) return false;

    final now = DateTime.now();
    final currentDayStr = now.weekday.toString();

    String? todayHours = hours[currentDayStr]?.toString();
    // A megadott JSON formátum alapján ellenőrizzük:
    return todayHours == "00:00-24:00" || todayHours == "0-24";
  }

  static DateTime _parseTime(String timeStr, DateTime now) {
    final parts = timeStr.split(':');
    final h = int.parse(parts[0].trim());
    final m = int.parse(parts[1].trim());
    return DateTime(now.year, now.month, now.day, h, m);
  }
}
