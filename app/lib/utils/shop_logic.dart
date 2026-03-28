import 'package:flutter/material.dart';

class ShopLogic {
  /// Meghatározza, hogy az adott bolt jelenleg nyitva van-e.
  /// Kezeli az éjszakai nyitvatartást is (pl. "10:00-02:00"),
  /// beleértve az éjfél utáni időszakot az előző napi sáv alapján.
  static bool isOpenNow(Map<String, dynamic>? hours) {
    if (hours == null) return false;

    final now = DateTime.now();

    // 1. Ellenőrizzük a mai nap nyitvatartását
    if (_isOpenForDay(hours, now.weekday, now)) {
      return true;
    }

    // 2. Ha a mai napra nem stimmel, ellenőrizzük az előző napi éjszakai sávot.
    //    Pl. ha most kedd 01:00, és hétfőn "10:00-02:00" volt a nyitvatartás.
    final previousWeekday = now.weekday == 1 ? 7 : now.weekday - 1;
    return _isOpenForDayOvernight(hours, previousWeekday, now);
  }

  /// Ellenőrzi, hogy az adott nap nyitvatartása alapján most nyitva van-e.
  /// Normál és éjszakai (éjfél utánra nyúló) sávot is kezel.
  static bool _isOpenForDay(
    Map<String, dynamic> hours,
    int weekday,
    DateTime now,
  ) {
    final dayHours = hours[weekday.toString()]?.toString();
    if (dayHours == null || dayHours.toLowerCase() == "zárva") {
      return false;
    }

    if (dayHours == "00:00-24:00" || dayHours == "0-24") {
      return true;
    }

    try {
      final parts = dayHours.split('-');
      if (parts.length != 2) return false;

      final baseDate = DateTime(now.year, now.month, now.day);
      final openTime = _parseTime(parts[0], baseDate);
      var closeTime = _parseTime(parts[1], baseDate);

      // Éjszakai sáv: zárás < nyitás → zárást a következő napra toljuk
      if (closeTime.isBefore(openTime)) {
        closeTime = closeTime.add(const Duration(days: 1));
      }

      return now.isAfter(openTime) && now.isBefore(closeTime);
    } catch (e) {
      debugPrint("Hiba a nyitvatartás elemzésekor: $dayHours");
      return false;
    }
  }

  /// Csak az előző napi éjszakai (átnyúló) sávot ellenőrzi.
  /// Ha az előző nap nyitvatartása éjfél után zárt, és most abban az
  /// időszakban vagyunk, akkor nyitva van.
  static bool _isOpenForDayOvernight(
    Map<String, dynamic> hours,
    int weekday,
    DateTime now,
  ) {
    final dayHours = hours[weekday.toString()]?.toString();
    if (dayHours == null || dayHours.toLowerCase() == "zárva") {
      return false;
    }

    // Non-stop boltok az _isOpenForDay-ben már kezelve vannak
    if (dayHours == "00:00-24:00" || dayHours == "0-24") {
      return false;
    }

    try {
      final parts = dayHours.split('-');
      if (parts.length != 2) return false;

      // Az előző nap dátumát használjuk bázisként
      final previousDate = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1));
      final openTime = _parseTime(parts[0], previousDate);
      var closeTime = _parseTime(parts[1], previousDate);

      // Csak éjszakai sávok érdekelnek (ahol a zárás átnyúlik a következő napra)
      if (!closeTime.isBefore(openTime)) {
        return false;
      }

      closeTime = closeTime.add(const Duration(days: 1));

      return now.isAfter(openTime) && now.isBefore(closeTime);
    } catch (e) {
      debugPrint("Hiba az előző napi nyitvatartás elemzésekor: $dayHours");
      return false;
    }
  }

  /// Ellenőrzi, hogy a bolt 0-24 órás (non-stop) nyitvatartású-e az adott napon.
  static bool isNonStop(Map<String, dynamic>? hours) {
    if (hours == null) return false;

    final now = DateTime.now();
    final currentDayStr = now.weekday.toString();

    String? todayHours = hours[currentDayStr]?.toString();
    return todayHours == "00:00-24:00" || todayHours == "0-24";
  }

  /// Időpont szöveg (pl. "14:30") konvertálása DateTime-ra az adott napon belül.
  static DateTime _parseTime(String timeStr, DateTime baseDate) {
    final parts = timeStr.split(':');
    final h = int.parse(parts[0].trim());
    final m = int.parse(parts[1].trim());
    return DateTime(baseDate.year, baseDate.month, baseDate.day, h, m);
  }
}
