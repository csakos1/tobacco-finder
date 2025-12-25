import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart'; // Ez az új GPS csomag

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TobaccoMapPage(),
    );
  }
}

class TobaccoMapPage extends StatefulWidget {
  const TobaccoMapPage({super.key});

  @override
  State<TobaccoMapPage> createState() => _TobaccoMapPageState();
}

class _TobaccoMapPageState extends State<TobaccoMapPage> {
  List<dynamic> shops = [];
  bool isLoading = true;
  LatLng? myPosition;
  final Distance distanceCalculator = const Distance();
  LatLng mapCenter = const LatLng(47.50712, 19.04557);

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _determinePosition();
    await fetchShops();
  }

  // --- 1. GPS POZÍCIÓ LEKÉRÉSE ---
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      myPosition = LatLng(position.latitude, position.longitude);
      mapCenter = myPosition!;
    });
  }

  // --- 2. BOLTOK LETÖLTÉSE ---
  Future<void> fetchShops() async {
    try {
      const String baseUrl = 'http://localhost:3000/shops';
      var response = await Dio().get(baseUrl);
      
      setState(() {
        shops = response.data;
        isLoading = false;
      });
    } catch (e) {
      print("HIBA: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // --- 3. NYITVATARTÁS LOGIKA ---
  bool isOpenNow(Map<String, dynamic>? hours) {
    if (hours == null) return false;
    
    DateTime now = DateTime.now();
    int weekday = now.weekday;
    String? todayHours = hours[weekday.toString()];

    if (todayHours == null || todayHours == "Zárva") return false;
    if (todayHours == "00:00-24:00") return true;

    try {
      List<String> parts = todayHours.split('-');
      List<String> startParts = parts[0].split(':');
      List<String> endParts = parts[1].split(':');

      DateTime openTime = DateTime(now.year, now.month, now.day, int.parse(startParts[0]), int.parse(startParts[1]));
      DateTime closeTime = DateTime(now.year, now.month, now.day, int.parse(endParts[0]), int.parse(endParts[1]));
      
      if (closeTime.isBefore(openTime)) {
         closeTime = closeTime.add(const Duration(days: 1));
      }

      return now.isAfter(openTime) && now.isBefore(closeTime);
    } catch (e) {
      return false; 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              options: MapOptions(
                initialCenter: mapCenter,
                initialZoom: 15.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'hu.csakos.tobacco_finder',
                  retinaMode: true,
                ),
                if (myPosition != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: myPosition!,
                        width: 60,
                        height: 60,
                        child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 50),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: shops.map((shop) {
                    return Marker(
                      point: LatLng(shop['lat'], shop['long']),
                      width: 80,
                      height: 80,
                      child: GestureDetector(
                        onTap: () {
                          _showShopDetails(context, shop);
                        },
                        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _determinePosition,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  // --- 4. RÉSZLETES INFORMÁCIÓ ABLAK ---
  void _showShopDetails(BuildContext context, dynamic shop) {
    String distanceText = "Ismeretlen";
    if (myPosition != null) {
      double dist = distanceCalculator.as(LengthUnit.Meter, myPosition!, LatLng(shop['lat'], shop['long']));
      distanceText = dist > 1000 ? "${(dist / 1000).toStringAsFixed(1)} km" : "${dist.round()} m";
    }

    Map<String, dynamic>? openingHours = shop['openingHours'];
    bool isOpen = isOpenNow(openingHours);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          shop['name'], 
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isOpen ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isOpen ? "NYITVA" : "ZÁRVA",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  Row(children: [const Icon(Icons.location_on, color: Colors.grey), const SizedBox(width: 8), Expanded(child: Text('${shop['city']}, ${shop['address']}'))]),
                  const SizedBox(height: 5),
                  Row(children: [const Icon(Icons.directions_walk, color: Colors.blue), const SizedBox(width: 8), Text("$distanceText tőled")]),
                  
                  const Divider(height: 30),
                  
                  const Text("Nyitvatartás", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  
                  if (openingHours != null)
                    ...List.generate(7, (index) {
                      int dayIndex = index + 1;
                      String dayName = ["Hétfő", "Kedd", "Szerda", "Csütörtök", "Péntek", "Szombat", "Vasárnap"][index];
                      String hours = openingHours[dayIndex.toString()] ?? "Zárva";
                      
                      bool isToday = DateTime.now().weekday == dayIndex;

                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: isToday 
                            ? BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.withOpacity(0.3))) 
                            : null,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(dayName, style: TextStyle(fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
                            Text(hours, style: TextStyle(fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
                          ],
                        ),
                      );
                    })
                  else
                    const Text("Nincs adat a nyitvatartásról.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                  
                  // ITT VOLT A GOMB, MOST MÁR ÜRES
                ],
              ),
            );
          },
        );
      },
    );
  }
}