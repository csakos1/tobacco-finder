class ShopLogic {
  
  static bool isOpenNow(Map<String, dynamic>? hours) {
    if (hours == null) return false;

    DateTime now = DateTime.now();
    int weekday = now.weekday; // 1 = Hétfő ... 7 = Vasárnap
    String? todayHours = hours[weekday.toString()];

    if (todayHours == null || todayHours == "Zárva") return false;
    if (todayHours == "00:00-24:00") return true; // Non-stop

    try {
      List<String> parts = todayHours.split('-');
      List<String> startParts = parts[0].split(':');
      List<String> endParts = parts[1].split(':');

      DateTime openTime = DateTime(
          now.year, now.month, now.day, int.parse(startParts[0]), int.parse(startParts[1]));
      DateTime closeTime = DateTime(
          now.year, now.month, now.day, int.parse(endParts[0]), int.parse(endParts[1]));

      // Ha a zárás másnapra esik (pl. 02:00)
      if (closeTime.isBefore(openTime)) {
        closeTime = closeTime.add(const Duration(days: 1));
      }

      return now.isAfter(openTime) && now.isBefore(closeTime);
    } catch (e) {
      return false;
    }
  }
}