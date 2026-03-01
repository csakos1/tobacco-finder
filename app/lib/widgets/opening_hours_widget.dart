import 'package:flutter/material.dart';

class OpeningHoursWidget extends StatelessWidget {
  final Map<String, dynamic>? hours;

  const OpeningHoursWidget({super.key, required this.hours});

  @override
  Widget build(BuildContext context) {
    if (hours == null) {
      return const Center(
        child: Text(
          "Nincs megadva nyitvatartás.",
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    }

    const days = [
      "Hétfő",
      "Kedd",
      "Szerda",
      "Csütörtök",
      "Péntek",
      "Szombat",
      "Vasárnap",
    ];
    final todayIndex = DateTime.now().weekday - 1;

    return Column(
      children: List.generate(7, (index) {
        final key = (index + 1).toString();

        String timeRange = hours![key]?.toString() ?? "Zárva";

        if (timeRange.length > 20 && timeRange.contains(';')) {
          timeRange = "Lásd fent";
        }

        final isToday = index == todayIndex;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                days[index],
                style: TextStyle(
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                  color: isToday
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 15,
                ),
              ),
              Text(
                timeRange,
                style: TextStyle(
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                  color: isToday
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
